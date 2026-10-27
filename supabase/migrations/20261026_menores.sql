-- ============================================================
-- Menores: marcar invitados como «menor de X años»
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
-- (después de 20261012_recepcion_sorpresas.sql)
--
-- Para salones que cobran por cubierto pero no cuentan a los más chicos
-- (ej. «los menores de 3 no pagan»): el organizador marca a cada uno desde
-- Invitados, el Inicio muestra «105 confirmados · 10 menores de 3 años» y
-- la lista de la entrada (PDF, Excel y Recepción) los señala.
--
--   guests.is_minor   lo marca el organizador, persona por persona
--   events.minor_age  la edad que se muestra («menores de 3 años»)
--
-- Solo AGREGA columnas con default: lo que ya existe sigue igual.
-- ============================================================

alter table public.guests add column if not exists is_minor boolean not null default false;

alter table public.events add column if not exists minor_age smallint not null default 3;
alter table public.events drop constraint if exists events_minor_age_check;
alter table public.events add constraint events_minor_age_check check (minor_age between 1 and 17);

-- Recepción: igual que en 20261012_recepcion_sorpresas.sql, más is_minor
-- de cada invitado y minor_age del evento.
create or replace function public.recepcion_lista(p_event_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if acceso_recepcion(p_event_id) is null then
    raise exception 'No autorizado';
  end if;

  return json_build_object(
    'event', (select json_build_object('id', e.id, 'name', e.name, 'event_date', e.event_date, 'minor_age', e.minor_age)
              from events e where e.id = p_event_id),
    'guests', (
      select coalesce(json_agg(json_build_object(
        'id', g.id,
        'full_name', g.full_name,
        'group_id', ig.id,
        'family_name', ig.family_name,
        'table_id', t.id,
        'table_name', t.name,
        'arrived_at', g.arrived_at,
        'is_minor', g.is_minor
      ) order by ig.family_name, g.created_at), '[]'::json)
      from guests g
      join invitation_groups ig on ig.id = g.group_id
      left join tables t on t.id = g.table_id
      where ig.event_id = p_event_id
        and g.rsvp_status = 'attending'
    )
  );
end;
$$;
