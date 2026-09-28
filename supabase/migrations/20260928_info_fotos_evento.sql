-- ============================================================
-- Estilo de la invitación en la página pública de fotos (/fotos/:id)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- 1) Deshace un intento de abrir/cerrar la subida de fotos que al final no se
--    usa (columna events.photos_mode y función subida_fotos_abierta). Con
--    "if exists", en una base que nunca lo tuvo esto no hace nada.
-- 2) info_fotos_evento(): nombre, plantilla y colores del evento para que la
--    página de fotos se vea como la invitación. Solo datos que la invitación
--    ya muestra públicamente.
-- ============================================================

-- 1) agregar_foto_invitados vuelve a ser la de antes (sin chequeo de horario).
create or replace function public.agregar_foto_invitados(
  p_event_id uuid,
  p_url text,
  p_path text,
  p_uploader_name text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_limit int := 500;
begin
  if not exists (select 1 from public.events where id = p_event_id) then
    raise exception 'Evento no encontrado';
  end if;

  select count(*) into v_count from public.event_photos where event_id = p_event_id;
  if v_count >= v_limit then
    raise exception 'Se llegó al máximo de % fotos para este evento.', v_limit;
  end if;

  insert into public.event_photos (event_id, url, path, uploader_name)
  values (p_event_id, p_url, p_path, nullif(trim(p_uploader_name), ''));

  return json_build_object('ok', true, 'count', v_count + 1, 'limit', v_limit);
end;
$$;

grant execute on function public.agregar_foto_invitados(uuid, text, text, text) to anon, authenticated;

-- 2) Primero se reemplaza info_fotos_evento (la versión anterior usaba
--    subida_fotos_abierta) y recién después se borra lo que sobra.
create or replace function public.info_fotos_evento(p_event_id uuid)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'event_name', e.name,
    'hero_title', e.hero_title,
    'template', e.template,
    'primary_color', e.primary_color,
    'bg_color', e.bg_color
  )
  from public.events e
  where e.id = p_event_id;
$$;

grant execute on function public.info_fotos_evento(uuid) to anon, authenticated;

drop function if exists public.subida_fotos_abierta(uuid);
alter table public.events drop column if exists photos_mode;
