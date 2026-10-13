-- ============================================================
-- Recepción: las sorpresas también se ven en las llegadas del panel
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
-- (después de 20261012_recepcion_cuentas.sql)
--
-- Decisión del 2026-10-12: el día del evento la cuenta del evento la mira la
-- familia (no la quinceañera), así que en Recepción las invitaciones
-- sorpresa aparecen con nombre, como cualquier invitado. En el resto del
-- panel (Invitados, Mesas, Movimientos, Canciones) siguen ocultas.
-- - recepcion_lista y recepcion_marcar ya no distinguen al dueño.
-- - recepcion_lista devuelve también table_id (el panel agrupa por mesa).
-- - llegadas_reservadas ya no hace falta.
-- ============================================================

drop function if exists public.llegadas_reservadas(uuid);

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
    'event', (select json_build_object('id', e.id, 'name', e.name, 'event_date', e.event_date)
              from events e where e.id = p_event_id),
    'guests', (
      select coalesce(json_agg(json_build_object(
        'id', g.id,
        'full_name', g.full_name,
        'group_id', ig.id,
        'family_name', ig.family_name,
        'table_id', t.id,
        'table_name', t.name,
        'arrived_at', g.arrived_at
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

create or replace function public.recepcion_marcar(p_event_id uuid, p_guest_ids uuid[], p_llego boolean)
returns json
language plpgsql
security definer
set search_path = public
as $$
begin
  if acceso_recepcion(p_event_id) is null then
    raise exception 'No autorizado';
  end if;

  update guests g set
    arrived_at = case when p_llego then coalesce(g.arrived_at, now()) end,
    arrived_by = case when p_llego then coalesce(g.arrived_by, auth.uid()) end
  from invitation_groups ig
  where ig.id = g.group_id
    and ig.event_id = p_event_id
    and g.id = any(p_guest_ids)
    and g.rsvp_status = 'attending';

  return (
    select coalesce(json_object_agg(g.id, g.arrived_at), '{}'::json)
    from guests g
    join invitation_groups ig on ig.id = g.group_id
    where g.id = any(p_guest_ids)
      and ig.event_id = p_event_id
  );
end;
$$;
