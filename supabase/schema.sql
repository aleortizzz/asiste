-- ============================================================
-- Asiste — Hito 2: modelo de datos + RLS del admin
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
-- ============================================================

-- gen_random_uuid() vive en la extensión pgcrypto.
create extension if not exists pgcrypto;

-- 1) Eventos: la fiesta. owner_user_id ata cada evento a un admin (auth.users).
create table events (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references auth.users not null,
  name text not null,
  event_date date,
  venue_name text,
  venue_address text,
  created_at timestamptz not null default now()
);

-- 2) Mesas del salón, una por evento.
create table tables (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null,
  name text not null,
  capacity int not null default 0,
  created_at timestamptz not null default now()
);

-- 3) Grupo/familia = una invitación = un link (slug).
-- Ojo: NO tiene table_id — la mesa se asigna por invitado individual,
-- no por familia entera, porque una familia se puede dividir entre mesas.
-- named_by_host: si el anfitrión cargó los nombres de antemano, el
-- invitado ve esos nombres fijos con botones Asiste/No asiste en vez
-- de un formulario para escribirlos.
create table invitation_groups (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null,
  family_name text not null,
  slug text not null unique,
  allowed_guests int not null default 1,
  named_by_host boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'declined')),
  created_at timestamptz not null default now()
);

-- 4) Invitados individuales dentro de un grupo. table_id se asigna
-- desde el admin una vez que el invitado confirmó asistencia (Hito 5+).
-- rsvp_status: 'invited' = nombre precargado por el anfitrión, todavía
-- sin responder; 'attending' / 'not_attending' = ya respondió.
create table guests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references invitation_groups(id) on delete cascade not null,
  table_id uuid references tables(id) on delete set null,
  full_name text not null,
  rsvp_status text not null default 'invited' check (rsvp_status in ('invited', 'attending', 'not_attending')),
  created_at timestamptz not null default now()
);

-- ============================================================
-- GRANTS — sin esto, "authenticated" no puede tocar la tabla en
-- absoluto, sin importar lo que digan las policies de RLS. RLS
-- filtra QUÉ FILAS ves; GRANT decide si podés intentar la operación.
-- Al crear tablas por SQL Editor (a diferencia del Table Editor de
-- la interfaz), Supabase no los agrega solo.
-- ============================================================

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.events to authenticated;
grant select, insert, update, delete on public.tables to authenticated;
grant select, insert, update, delete on public.invitation_groups to authenticated;
grant select, insert, update, delete on public.guests to authenticated;

-- ============================================================
-- RLS — solo reglas del admin autenticado por ahora.
-- Las reglas públicas para /i/:slug se agregan recién en el Hito 5.
-- ============================================================

alter table events enable row level security;
alter table tables enable row level security;
alter table invitation_groups enable row level security;
alter table guests enable row level security;

-- events: el admin solo ve/edita sus propios eventos.
create policy "admin gestiona sus eventos"
  on events for all
  using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);

-- tables: acceso solo si el evento dueño es del admin logueado.
create policy "admin gestiona mesas de sus eventos"
  on tables for all
  using (exists (
    select 1 from events
    where events.id = tables.event_id
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from events
    where events.id = tables.event_id
    and events.owner_user_id = auth.uid()
  ));

-- invitation_groups: mismo patrón, vía event_id.
create policy "admin gestiona grupos de sus eventos"
  on invitation_groups for all
  using (exists (
    select 1 from events
    where events.id = invitation_groups.event_id
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from events
    where events.id = invitation_groups.event_id
    and events.owner_user_id = auth.uid()
  ));

-- guests: vía group_id -> event_id.
create policy "admin gestiona invitados de sus eventos"
  on guests for all
  using (exists (
    select 1 from invitation_groups
    join events on events.id = invitation_groups.event_id
    where invitation_groups.id = guests.group_id
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from invitation_groups
    join events on events.id = invitation_groups.event_id
    where invitation_groups.id = guests.group_id
    and events.owner_user_id = auth.uid()
  ));

-- ============================================================
-- HITO 5 — acceso público (RSVP) vía funciones RPC.
-- Nada de esto se expone como policy directa sobre las tablas:
-- si el público pudiera hacer SELECT * on invitation_groups, podría
-- listar TODAS las familias del evento, no solo la suya. En cambio,
-- dos funciones SECURITY DEFINER hacen de "puerta angosta": reciben
-- el slug como argumento y devuelven/tocan solo esa fila.
--
-- SECURITY DEFINER hace que la función corra con los permisos de
-- quien la creó (el dueño de la tabla, típicamente "postgres" en
-- Supabase) — por eso puede leer/escribir sin que "anon" tenga
-- GRANT ni policy propia sobre estas tablas. `set search_path`
-- evita el ataque clásico de "search_path hijacking" en funciones
-- SECURITY DEFINER.
-- ============================================================

-- Lectura pública de una invitación por slug (para la landing /i/:slug).
create or replace function public.obtener_invitacion(p_slug text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  result json;
begin
  select json_build_object(
    'family_name', ig.family_name,
    'allowed_guests', ig.allowed_guests,
    'status', ig.status,
    'named_by_host', ig.named_by_host,
    'event_name', e.name,
    'event_date', e.event_date,
    'venue_name', e.venue_name,
    'venue_address', e.venue_address,
    'guests', coalesce((
      select json_agg(json_build_object(
        'id', g.id,
        'full_name', g.full_name,
        'rsvp_status', g.rsvp_status
      ) order by g.created_at)
      from guests g
      where g.group_id = ig.id
    ), '[]'::json)
  )
  into result
  from invitation_groups ig
  join events e on e.id = ig.event_id
  where ig.slug = p_slug;

  if result is null then
    raise exception 'Invitación no encontrada';
  end if;

  return result;
end;
$$;

grant execute on function public.obtener_invitacion(text) to anon, authenticated;

-- Escritura pública del RSVP — modo "genérico" (sin nombres precargados):
-- la familia escribe los nombres. Valida server-side que no se carguen
-- más nombres que "allowed_guests" — el cliente nunca podría forzar eso
-- porque no tiene permiso de escritura directa sobre la tabla.
create or replace function public.confirmar_asistencia(p_slug text, p_guest_names text[])
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group invitation_groups%rowtype;
  v_count int;
begin
  select * into v_group from invitation_groups where slug = p_slug;

  if v_group.id is null then
    raise exception 'Invitación no encontrada';
  end if;

  if v_group.named_by_host then
    raise exception 'Esta invitación ya tiene nombres cargados por el anfitrión';
  end if;

  v_count := coalesce(array_length(p_guest_names, 1), 0);

  if v_count = 0 then
    delete from guests where group_id = v_group.id;
    update invitation_groups set status = 'declined' where id = v_group.id;
    return json_build_object('status', 'declined');
  end if;

  if v_count > v_group.allowed_guests then
    raise exception 'Superaste el máximo de % invitaciones permitidas', v_group.allowed_guests;
  end if;

  delete from guests where group_id = v_group.id;

  insert into guests (group_id, full_name, rsvp_status)
  select v_group.id, trim(name), 'attending'
  from unnest(p_guest_names) as name
  where trim(name) <> '';

  update invitation_groups set status = 'confirmed' where id = v_group.id;

  return json_build_object('status', 'confirmed');
end;
$$;

grant execute on function public.confirmar_asistencia(text, text[]) to anon, authenticated;

-- Escritura pública del RSVP — modo "con nombres precargados": el
-- anfitrión ya cargó quiénes son, el invitado solo marca asiste/no
-- asiste por persona. p_respuestas es un jsonb tipo
-- [{"id": "<guest uuid>", "attending": true}, ...].
create or replace function public.responder_invitados(p_slug text, p_respuestas jsonb)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_attending_count int;
begin
  select ig.id into v_group_id
  from invitation_groups ig
  where ig.slug = p_slug and ig.named_by_host;

  if v_group_id is null then
    raise exception 'Invitación no encontrada';
  end if;

  update guests g
  set rsvp_status = case when (r.attending)::boolean then 'attending' else 'not_attending' end
  from jsonb_to_recordset(p_respuestas) as r(id uuid, attending boolean)
  where g.id = r.id and g.group_id = v_group_id;

  select count(*) filter (where rsvp_status = 'attending')
  into v_attending_count
  from guests where group_id = v_group_id;

  update invitation_groups
  set status = case when v_attending_count > 0 then 'confirmed' else 'declined' end
  where id = v_group_id;

  return json_build_object('attending_count', v_attending_count);
end;
$$;

grant execute on function public.responder_invitados(text, jsonb) to anon, authenticated;
