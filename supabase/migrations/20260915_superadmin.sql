-- ============================================================
-- Panel superadmin: ver/gestionar el panel de cualquier cliente
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- No hay backend propio en esta app (SPA + Supabase directo), así que el
-- control de acceso del superadmin vive en RLS: se agrega una policy extra
-- en cada tabla que le da acceso total a quien esté en `superadmins`,
-- ADEMÁS de la policy existente de "solo el dueño". Postgres las combina
-- con OR, así que ninguna de las dos rompe a la otra.
-- ============================================================

create table if not exists superadmins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- `security definer` en este proyecto SIGUE necesitando el GRANT de base
-- (no alcanza con que el dueño de la función tenga acceso), así que hace
-- falta el select acá. Lo que hay que evitar es una policy que se consulte
-- A SÍ MISMA ("¿sos superadmin? → mirá en superadmins...") — eso es
-- referencia circular y Postgres la detecta como recursión infinita
-- (error 42P17). La policy de abajo compara auth.uid() contra la columna
-- directamente (sin subconsulta a esta tabla), así que no puede recursar:
-- cada cuenta solo ve su propia fila, suficiente para que el `exists(...)`
-- de soy_superadmin()/listar_eventos_superadmin() funcione.
grant select on public.superadmins to authenticated;
alter table superadmins enable row level security;

drop policy if exists "superadmin lee superadmins" on superadmins;
drop policy if exists "cada uno ve su propia fila de superadmins" on superadmins;
create policy "cada uno ve su propia fila de superadmins"
  on superadmins for select
  using (auth.uid() = user_id);

-- Primer superadmin: vos. Si en algún momento cambia el email de la cuenta
-- de administración, corré este insert de nuevo con el email correcto.
insert into superadmins (user_id)
select id from auth.users where email = 'aleortizjusto3@gmail.com'
on conflict (user_id) do nothing;

-- ============================================================
-- RLS extra: el superadmin puede leer y editar TODO, en las 4 tablas.
-- ============================================================

drop policy if exists "superadmin gestiona eventos" on events;
create policy "superadmin gestiona eventos"
  on events for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

drop policy if exists "superadmin gestiona mesas" on tables;
create policy "superadmin gestiona mesas"
  on tables for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

drop policy if exists "superadmin gestiona grupos" on invitation_groups;
create policy "superadmin gestiona grupos"
  on invitation_groups for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

drop policy if exists "superadmin gestiona invitados" on guests;
create policy "superadmin gestiona invitados"
  on guests for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

-- ============================================================
-- Storage: el superadmin puede subir/editar/borrar fotos en CUALQUIER
-- carpeta del bucket event-photos (no solo la propia). El front pasa el
-- owner_user_id del evento como carpeta al subir, así las fotos que subís
-- ayudando a alguien quedan en la carpeta de ese cliente, prolijo.
-- ============================================================

drop policy if exists "event-photos superadmin insert" on storage.objects;
create policy "event-photos superadmin insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'event-photos'
    and exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

drop policy if exists "event-photos superadmin update" on storage.objects;
create policy "event-photos superadmin update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'event-photos'
    and exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

drop policy if exists "event-photos superadmin delete" on storage.objects;
create policy "event-photos superadmin delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'event-photos'
    and exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- ============================================================
-- RPCs: saber si sos superadmin, y listar todos los eventos con el
-- email del dueño (auth.users no es consultable directo desde el cliente).
-- ============================================================

create or replace function public.soy_superadmin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (select 1 from superadmins where user_id = auth.uid());
$$;

grant execute on function public.soy_superadmin() to authenticated;

create or replace function public.listar_eventos_superadmin()
returns table (
  event_id uuid,
  event_name text,
  owner_email text,
  event_date date,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from superadmins where user_id = auth.uid()) then
    raise exception 'No autorizado';
  end if;

  return query
    select e.id, e.name, u.email::text, e.event_date, e.created_at
    from events e
    join auth.users u on u.id = e.owner_user_id
    order by e.created_at desc;
end;
$$;

grant execute on function public.listar_eventos_superadmin() to authenticated;
