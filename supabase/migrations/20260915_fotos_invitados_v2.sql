-- ============================================================
-- Fotos de invitados: nombre de quien sube, likes, orden por más votadas
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
-- ============================================================

alter table event_photos
  add column if not exists uploader_name text,
  add column if not exists likes_count int not null default 0;

-- Postgres identifica una función por nombre + tipos de parámetros: agregar
-- un parámetro nuevo NO reemplaza la versión vieja, crea una sobrecarga
-- aparte. Hay que borrar la firma anterior a mano antes de recrearla.
drop function if exists public.agregar_foto_invitados(uuid, text, text);
drop function if exists public.listar_fotos_invitados(uuid); -- cambia el tipo de retorno

-- agregar_foto_invitados ahora también guarda el nombre de quien sube.
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
  if not exists (select 1 from events where id = p_event_id) then
    raise exception 'Evento no encontrado';
  end if;

  select count(*) into v_count from event_photos where event_id = p_event_id;
  if v_count >= v_limit then
    raise exception 'Se llegó al máximo de % fotos para este evento.', v_limit;
  end if;

  insert into event_photos (event_id, url, path, uploader_name)
  values (p_event_id, p_url, p_path, nullif(trim(p_uploader_name), ''));

  return json_build_object('ok', true, 'count', v_count + 1, 'limit', v_limit);
end;
$$;

grant execute on function public.agregar_foto_invitados(uuid, text, text, text) to anon, authenticated;

-- Like público y anónimo (sin login): un click suma uno. El límite de "un
-- like por persona" lo hace el navegador (localStorage), no el servidor —
-- para esta app no vale la pena una tabla de likes por dispositivo.
create or replace function public.dar_like_foto(p_photo_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  update event_photos set likes_count = likes_count + 1
  where id = p_photo_id
  returning likes_count into v_count;

  if v_count is null then
    raise exception 'Foto no encontrada';
  end if;

  return v_count;
end;
$$;

grant execute on function public.dar_like_foto(uuid) to anon, authenticated;

-- La galería pública ahora ordena por más likes primero.
create or replace function public.listar_fotos_invitados(p_event_id uuid)
returns table (
  id uuid,
  url text,
  uploader_name text,
  likes_count int,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select id, url, uploader_name, likes_count, created_at
  from event_photos
  where event_id = p_event_id
  order by likes_count desc, created_at desc;
$$;

grant execute on function public.listar_fotos_invitados(uuid) to anon, authenticated;
