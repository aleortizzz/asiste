-- Historial de respuestas: una fila por cada vez que una familia responde
-- (incluye cuando cambia de opinión). Lo usa la pantalla «Movimientos».
--
-- 100% aditiva: crea una tabla nueva y un trigger. No borra ni cambia ningún
-- dato existente y no toca las funciones de confirmación. Requiere haber
-- corrido antes 20260927_respondido_en.sql. Se puede correr más de una vez.

-- 1) Tabla de registro. attending_count = cuántos iban a ir en esa respuesta.
create table if not exists rsvp_log (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references invitation_groups(id) on delete cascade not null,
  status text not null check (status in ('confirmed', 'declined')),
  attending_count int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists rsvp_log_group_id_idx on rsvp_log (group_id);

-- 2) Solo lectura para el admin (las filas las escribe el trigger).
grant select on public.rsvp_log to authenticated;
alter table rsvp_log enable row level security;

drop policy if exists "admin ve el historial de sus invitados" on rsvp_log;
create policy "admin ve el historial de sus invitados"
  on rsvp_log for select
  using (exists (
    select 1 from invitation_groups
    join events on events.id = invitation_groups.event_id
    where invitation_groups.id = rsvp_log.group_id
      and events.owner_user_id = auth.uid()
  ));

drop policy if exists "superadmin ve el historial" on rsvp_log;
create policy "superadmin ve el historial"
  on rsvp_log for select
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()));

-- 3) Trigger: después de que una respuesta escribe el status, anota una fila.
--    Las funciones de RSVP actualizan los invitados ANTES que el status del
--    grupo, así que acá el conteo de "attending" ya es el de esta respuesta.
--    security definer: el invitado responde sin sesión, igual tiene que poder
--    escribir en el registro.
create or replace function public.registrar_respuesta()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'pending' then
    insert into rsvp_log (group_id, status, attending_count)
    values (
      new.id,
      new.status,
      (select count(*) from guests where group_id = new.id and rsvp_status = 'attending')
    );
  end if;
  return new;
end;
$$;

drop trigger if exists invitation_groups_rsvp_log on invitation_groups;
create trigger invitation_groups_rsvp_log
  after update of status on invitation_groups
  for each row
  execute function public.registrar_respuesta();

-- 4) Punto de partida: las respuestas que ya tienen hora (responded_at) entran
--    al historial con esa hora. Solo para familias que todavía no tienen
--    ninguna fila, así correrlo dos veces no duplica nada.
insert into rsvp_log (group_id, status, attending_count, created_at)
select
  ig.id,
  ig.status,
  (select count(*) from guests g where g.group_id = ig.id and g.rsvp_status = 'attending'),
  ig.responded_at
from invitation_groups ig
where ig.responded_at is not null
  and ig.status in ('confirmed', 'declined')
  and not exists (select 1 from rsvp_log l where l.group_id = ig.id);
