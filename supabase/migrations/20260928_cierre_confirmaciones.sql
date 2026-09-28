-- Fecha límite que cierra las confirmaciones (opcional por evento).
--
-- 100% aditiva: agrega una columna (apagada por defecto), un trigger y una
-- función nueva. No borra ni cambia datos, y NO reescribe ninguna de las
-- funciones que usan los invitados (obtener_invitacion, confirmar_asistencia,
-- responder_invitados). Los eventos existentes quedan exactamente como están:
-- fecha límite solo informativa. Se puede correr más de una vez.

-- 1) false = la fecha límite solo se muestra para apurar (como hasta ahora).
--    true  = pasada esa fecha, no se aceptan más respuestas.
alter table events add column if not exists rsvp_deadline_strict boolean not null default false;

-- 2) ¿Las confirmaciones de este evento ya cerraron? "Pasada la fecha" =
--    desde el día siguiente a rsvp_deadline, en hora de Argentina.
create or replace function public.confirmaciones_cerradas(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select e.rsvp_deadline_strict
        and e.rsvp_deadline is not null
        and (now() at time zone 'America/Argentina/Buenos_Aires')::date > e.rsvp_deadline
     from events e
     where e.id = p_event_id),
    false
  );
$$;

-- 3) Bloqueo del lado del servidor: las funciones de RSVP siempre terminan
--    escribiendo el status del grupo; si el evento ya cerró, este trigger
--    corta con un error y TODA la respuesta se deshace (los cambios a los
--    invitados que la función hizo antes quedan revertidos, es una sola
--    transacción). Con rsvp_deadline_strict = false nunca hace nada.
create or replace function public.bloquear_respuesta_fuera_de_termino()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'pending' and public.confirmaciones_cerradas(new.event_id) then
    raise exception 'Las confirmaciones para este evento ya cerraron.';
  end if;
  return new;
end;
$$;

drop trigger if exists invitation_groups_cierre_confirmaciones on invitation_groups;
create trigger invitation_groups_cierre_confirmaciones
  before update of status on invitation_groups
  for each row
  execute function public.bloquear_respuesta_fuera_de_termino();

-- 4) Para la invitación pública: si el evento cierra las confirmaciones y si
--    ya cerraron. Función aparte (en vez de tocar obtener_invitacion) y que
--    devuelve solo esto — nada de datos de otras familias.
create or replace function public.estado_confirmaciones(p_slug text)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'rsvp_deadline_strict', e.rsvp_deadline_strict,
    'rsvp_closed', public.confirmaciones_cerradas(e.id)
  )
  from invitation_groups ig
  join events e on e.id = ig.event_id
  where ig.slug = p_slug;
$$;

grant execute on function public.estado_confirmaciones(text) to anon, authenticated;
