-- ============================================================
-- Copiar el evento de un cliente a otra cuenta (ej. la del superadmin),
-- para probar cambios sin tocar el original.
-- Pegar en Supabase → SQL Editor (proyecto "asiste"), completar los dos
-- mails de abajo y ejecutar.
--
-- Qué hace:
--   - SOLO LEE el evento original: no lo modifica ni borra nada.
--   - Crea un evento nuevo en la cuenta destino, con el nombre + « (copia)»,
--     y copia mesas, invitaciones (con links NUEVOS) e invitados, con sus
--     respuestas y su mesa.
--   - No copia: visitas, historial de respuestas, canciones ni fotos de los
--     invitados.
--   - Fotos de la invitación: la copia usa las mismas imágenes, pero SIN el
--     `path` del archivo. Así, sacar una foto en la copia la quita solo de la
--     copia; nunca borra el archivo del servidor (que sigue usando el
--     original).
--   - Es todo o nada: si algo falla (mail mal escrito, la cuenta destino ya
--     tiene evento…), no queda nada a medias.
-- ============================================================

do $$
declare
  -- ⬇⬇ Completar ⬇⬇
  v_origen_email  text := 'MAIL_DE_ORIGEN';
  v_destino_email text := 'MAIL_DE_DESTINO';
  -- true = si la cuenta destino ya tiene un evento, SE BORRA (con sus mesas,
  -- invitaciones e invitados) y se reemplaza por la copia. Usar solo si ese
  -- evento es de prueba. false = frena sin tocar nada.
  v_reemplazar_destino boolean := false;
  -- ⬆⬆⬆⬆⬆⬆⬆⬆⬆⬆⬆⬆

  v_origen uuid;
  v_destino uuid;
  v_evento_origen uuid;
  v_evento_nuevo uuid := gen_random_uuid();
  v_cant int;
begin
  select id into v_origen from auth.users where lower(email) = lower(trim(v_origen_email));
  if v_origen is null then
    raise exception 'No existe ninguna cuenta con el mail %', v_origen_email;
  end if;

  select id into v_destino from auth.users where lower(email) = lower(trim(v_destino_email));
  if v_destino is null then
    raise exception 'No existe ninguna cuenta con el mail %', v_destino_email;
  end if;

  -- Nunca borrar el evento original por confundir los mails.
  if v_origen = v_destino then
    raise exception 'El mail de origen y el de destino son la misma cuenta. No se copió nada.';
  end if;

  select count(*) into v_cant from public.events where owner_user_id = v_origen;
  if v_cant <> 1 then
    raise exception 'La cuenta % tiene % eventos (se esperaba 1).', v_origen_email, v_cant;
  end if;
  select id into v_evento_origen from public.events where owner_user_id = v_origen;

  -- El panel carga UN evento por cuenta: si la destino ya tiene uno, o se
  -- reemplaza (si se pidió) o se frena acá.
  if exists (select 1 from public.events where owner_user_id = v_destino) then
    if not v_reemplazar_destino then
      raise exception 'La cuenta % ya tiene un evento. No se copió nada.', v_destino_email;
    end if;
    -- El on delete cascade se lleva mesas, invitaciones, invitados, visitas,
    -- historial y canciones de ESE evento (el de la cuenta destino).
    delete from public.events where owner_user_id = v_destino;
    raise notice 'Se borró el evento de prueba de %.', v_destino_email;
  end if;

  -- 1) Evento: todas las columnas tal cual, salvo id, dueño, nombre, fecha
  --    de creación y las fotos (sin path). Con to_jsonb/jsonb_populate_record
  --    no hace falta listar columna por columna.
  insert into public.events
  select (jsonb_populate_record(
    null::public.events,
    to_jsonb(e) || jsonb_build_object(
      'id', v_evento_nuevo,
      'owner_user_id', v_destino,
      'name', e.name || ' (copia)',
      'created_at', now(),
      'banner',   (select coalesce(jsonb_agg(x - 'path' order by n), '[]'::jsonb) from jsonb_array_elements(e.banner)   with ordinality as t(x, n)),
      'retrato',  (select coalesce(jsonb_agg(x - 'path' order by n), '[]'::jsonb) from jsonb_array_elements(e.retrato)  with ordinality as t(x, n)),
      'detalle',  (select coalesce(jsonb_agg(x - 'path' order by n), '[]'::jsonb) from jsonb_array_elements(e.detalle)  with ordinality as t(x, n)),
      'momentos', (select coalesce(jsonb_agg(x - 'path' order by n), '[]'::jsonb) from jsonb_array_elements(e.momentos) with ordinality as t(x, n)),
      'galeria',  (select coalesce(jsonb_agg(x - 'path' order by n), '[]'::jsonb) from jsonb_array_elements(e.galeria)  with ordinality as t(x, n))
    )
  )).*
  from public.events e
  where e.id = v_evento_origen;

  -- 2) Mesas, con una tabla temporal id viejo → id nuevo para reubicar a
  --    los invitados.
  create temp table map_mesas on commit drop as
    select id as old_id, gen_random_uuid() as new_id from public.tables where event_id = v_evento_origen;

  insert into public.tables (id, event_id, name, capacity, created_at)
  select m.new_id, v_evento_nuevo, t.name, t.capacity, t.created_at
  from public.tables t join map_mesas m on m.old_id = t.id;

  -- 3) Invitaciones, con link (slug) nuevo: el de la copia no tiene que
  --    abrir la invitación original ni al revés.
  create temp table map_grupos on commit drop as
    select id as old_id, gen_random_uuid() as new_id from public.invitation_groups where event_id = v_evento_origen;

  insert into public.invitation_groups
    (id, event_id, family_name, slug, allowed_guests, named_by_host, status, responded_at, sorpresa, created_at)
  select m.new_id, v_evento_nuevo, g.family_name, substr(md5(random()::text || m.new_id::text), 1, 10),
         g.allowed_guests, g.named_by_host, g.status, g.responded_at, g.sorpresa, g.created_at
  from public.invitation_groups g join map_grupos m on m.old_id = g.id;

  -- 4) Invitados, en su invitación y su mesa nuevas.
  insert into public.guests (group_id, table_id, full_name, rsvp_status, created_at)
  select mg.new_id, mm.new_id, x.full_name, x.rsvp_status, x.created_at
  from public.guests x
  join map_grupos mg on mg.old_id = x.group_id
  left join map_mesas mm on mm.old_id = x.table_id;

  raise notice 'Listo: evento copiado (id %).', v_evento_nuevo;
end;
$$;

-- Para revisar: debería aparecer el original y la copia, con los mismos números.
select e.name, u.email,
       (select count(*) from public.tables t where t.event_id = e.id) as mesas,
       (select count(*) from public.invitation_groups g where g.event_id = e.id) as invitaciones,
       (select count(*) from public.guests x join public.invitation_groups g on g.id = x.group_id where g.event_id = e.id) as invitados
from public.events e
join auth.users u on u.id = e.owner_user_id
order by e.created_at desc
limit 5;
