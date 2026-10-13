-- ============================================================
-- Recepción: el personal del salón marca quién llegó
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- - El dueño del evento (o el superadmin) crea usuarios de recepción desde
--   el panel: usuario + contraseña, sin mail real (ver src/lib/staff.js).
--   Cada usuario queda atado al evento en `event_staff`. (Cómo se crean las
--   cuentas cambió en 20261012_recepcion_cuentas.sql.)
-- - Recepción entra a /recepcion: busca al invitado, ve su mesa y lo marca
--   como llegado (`guests.arrived_at`). Todo vía RPC: el personal no tiene
--   permisos directos sobre las tablas.
-- - Recepción ve también a los invitados sorpresa (esa gente llega igual).
--   El dueño los sigue sin ver: en su panel cuentan como «reservados».
-- ============================================================

-- 1) Llegadas
alter table public.guests
  add column if not exists arrived_at timestamptz,
  add column if not exists arrived_by uuid references auth.users(id) on delete set null;

-- 2) Personal de recepción de cada evento
create table if not exists public.event_staff (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  username text not null,
  display_name text not null,
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create index if not exists event_staff_user_id_idx on public.event_staff (user_id);

-- El dueño ve y borra a su personal; las filas se crean solo con
-- agregar_recepcionista (que valida la cuenta).
grant select, delete on public.event_staff to authenticated;
alter table public.event_staff enable row level security;

drop policy if exists "admin ve y borra el personal de su evento" on public.event_staff;
create policy "admin ve y borra el personal de su evento"
  on public.event_staff for all
  using (exists (
    select 1 from public.events
    where events.id = event_staff.event_id
    and events.owner_user_id = auth.uid()
  ));

drop policy if exists "superadmin gestiona personal" on public.event_staff;
create policy "superadmin gestiona personal"
  on public.event_staff for all
  using (exists (select 1 from public.superadmins s where s.user_id = auth.uid()));

drop policy if exists "cada uno ve sus propios eventos de recepcion" on public.event_staff;
create policy "cada uno ve sus propios eventos de recepcion"
  on public.event_staff for select
  using (user_id = auth.uid());

-- ============================================================
-- Permisos (uso interno)
-- ============================================================

-- ¿Puedo manejar este evento? Dueño o superadmin.
create or replace function public.puede_administrar_evento(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.events where id = p_event_id and owner_user_id = auth.uid())
      or exists (select 1 from public.superadmins where user_id = auth.uid());
$$;

-- Cómo entra cada uno a recepción: 'personal' y 'superadmin' ven todo;
-- 'duenio' ve todo menos las invitaciones sorpresa; null = no puede.
create or replace function public.acceso_recepcion(p_event_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when exists (select 1 from public.superadmins where user_id = auth.uid()) then 'superadmin'
    when exists (select 1 from public.event_staff where event_id = p_event_id and user_id = auth.uid()) then 'personal'
    when exists (select 1 from public.events where id = p_event_id and owner_user_id = auth.uid()) then 'duenio'
  end;
$$;

revoke execute on function public.puede_administrar_evento(uuid) from public, anon;
revoke execute on function public.acceso_recepcion(uuid) from public, anon;
grant execute on function public.puede_administrar_evento(uuid) to authenticated;
grant execute on function public.acceso_recepcion(uuid) to authenticated;

-- ============================================================
-- RPC del panel (dueño / superadmin)
-- ============================================================

-- Ata una cuenta recién creada (desde el panel, con signUp) al evento. Valida
-- que la cuenta sea de recepción: su mail tiene que ser el del usuario.
create or replace function public.agregar_recepcionista(
  p_event_id uuid,
  p_user_id uuid,
  p_username text,
  p_display_name text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text := lower(trim(coalesce(p_username, '')));
  v_name text := trim(coalesce(p_display_name, ''));
  v_row event_staff;
begin
  if not puede_administrar_evento(p_event_id) then
    raise exception 'No autorizado';
  end if;
  if v_name = '' then
    raise exception 'Escribí el nombre de la persona.';
  end if;
  if not exists (
    select 1 from auth.users
    where id = p_user_id and email = v_username || '@recepcion.tizdigital.com'
  ) then
    raise exception 'Cuenta de recepción no encontrada';
  end if;

  insert into event_staff (event_id, user_id, username, display_name)
  values (p_event_id, p_user_id, v_username, left(v_name, 60))
  on conflict (event_id, user_id) do update set display_name = excluded.display_name
  returning * into v_row;

  return row_to_json(v_row);
end;
$$;

grant execute on function public.agregar_recepcionista(uuid, uuid, text, text) to authenticated;

-- El dueño no ve a los invitados sorpresa: le decimos cuántos son y cuántos
-- llegaron, sin nombres. Al superadmin no le devuelve nada: él ya los ve.
create or replace function public.llegadas_reservadas(p_event_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if exists (select 1 from superadmins where user_id = auth.uid()) then
    return json_build_object('total', 0, 'llegaron', 0);
  end if;
  if not exists (select 1 from events where id = p_event_id and owner_user_id = auth.uid()) then
    raise exception 'No autorizado';
  end if;

  return (
    select json_build_object('total', count(*), 'llegaron', count(g.arrived_at))
    from guests g
    join invitation_groups ig on ig.id = g.group_id
    where ig.event_id = p_event_id
      and ig.sorpresa
      and g.rsvp_status = 'attending'
  );
end;
$$;

grant execute on function public.llegadas_reservadas(uuid) to authenticated;

-- Borra todas las llegadas del evento (para después de probar). También las
-- de las sorpresas: el dueño no las ve, pero borrarlas no delata a nadie.
create or replace function public.reiniciar_llegadas(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not puede_administrar_evento(p_event_id) then
    raise exception 'No autorizado';
  end if;

  update guests g set arrived_at = null, arrived_by = null
  from invitation_groups ig
  where ig.id = g.group_id
    and ig.event_id = p_event_id
    and g.arrived_at is not null;
end;
$$;

grant execute on function public.reiniciar_llegadas(uuid) to authenticated;

-- ============================================================
-- RPC de recepción
-- ============================================================

-- Los eventos en los que trabajo (para la pantalla de inicio de recepción).
create or replace function public.mis_eventos_recepcion()
returns json
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(json_agg(json_build_object(
    'id', e.id,
    'name', e.name,
    'event_date', e.event_date
  ) order by e.event_date nulls last), '[]'::json)
  from public.event_staff s
  join public.events e on e.id = s.event_id
  where s.user_id = auth.uid();
$$;

grant execute on function public.mis_eventos_recepcion() to authenticated;

-- La lista de la entrada: los que confirmaron, con su invitación, su mesa y
-- si ya llegaron.
create or replace function public.recepcion_lista(p_event_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_access text := acceso_recepcion(p_event_id);
begin
  if v_access is null then
    raise exception 'No autorizado';
  end if;

  return json_build_object(
    'event', (select json_build_object('id', e.id, 'name', e.name, 'event_date', e.event_date)
              from events e where e.id = p_event_id),
    'guests', (
      select coalesce(json_agg(json_build_object(
        'id', g.id,
        'full_name', g.full_name,
        'group_id', ig.id,
        'family_name', ig.family_name,
        'table_name', t.name,
        'arrived_at', g.arrived_at
      ) order by ig.family_name, g.created_at), '[]'::json)
      from guests g
      join invitation_groups ig on ig.id = g.group_id
      left join tables t on t.id = g.table_id
      where ig.event_id = p_event_id
        and g.rsvp_status = 'attending'
        and (v_access <> 'duenio' or not ig.sorpresa)
    )
  );
end;
$$;

grant execute on function public.recepcion_lista(uuid) to authenticated;

-- Marca (o desmarca) la llegada de una o varias personas. Si ya estaba
-- marcada, se queda con la primera hora (dos recepcionistas a la vez).
create or replace function public.recepcion_marcar(p_event_id uuid, p_guest_ids uuid[], p_llego boolean)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_access text := acceso_recepcion(p_event_id);
begin
  if v_access is null then
    raise exception 'No autorizado';
  end if;

  update guests g set
    arrived_at = case when p_llego then coalesce(g.arrived_at, now()) end,
    arrived_by = case when p_llego then coalesce(g.arrived_by, auth.uid()) end
  from invitation_groups ig
  where ig.id = g.group_id
    and ig.event_id = p_event_id
    and g.id = any(p_guest_ids)
    and g.rsvp_status = 'attending'
    and (v_access <> 'duenio' or not ig.sorpresa);

  return (
    select coalesce(json_object_agg(g.id, g.arrived_at), '{}'::json)
    from guests g
    join invitation_groups ig on ig.id = g.group_id
    where g.id = any(p_guest_ids)
      and ig.event_id = p_event_id
      and (v_access <> 'duenio' or not ig.sorpresa)
  );
end;
$$;

grant execute on function public.recepcion_marcar(uuid, uuid[], boolean) to authenticated;
