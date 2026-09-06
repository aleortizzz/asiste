-- ============================================================
-- Fotos de la invitación (Supabase Storage)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Cada slot guarda un array jsonb de { url, path }. `path` es la ruta
-- en Storage (para poder borrar el archivo). Slots:
--   banner   → 1 foto (portada / hero)
--   retrato  → varias (carrusel del saludo)
--   detalle  → 1 foto (sección "La celebración")
--   momentos → varias (carrusel "Momentos")
--   galeria  → hasta 8 (grid)
-- ============================================================

alter table events
  add column if not exists banner   jsonb not null default '[]'::jsonb,
  add column if not exists retrato  jsonb not null default '[]'::jsonb,
  add column if not exists detalle  jsonb not null default '[]'::jsonb,
  add column if not exists momentos jsonb not null default '[]'::jsonb,
  add column if not exists galeria  jsonb not null default '[]'::jsonb;

-- --- Bucket de Storage ---------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'event-photos', 'event-photos', true, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = true,
      file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

-- --- Policies de Storage ------------------------------------
-- Ruta: {uid}/{slot}/{uuid}.{ext} — el admin solo toca su propia carpeta.
drop policy if exists "event-photos public read" on storage.objects;
create policy "event-photos public read" on storage.objects
  for select using (bucket_id = 'event-photos');

drop policy if exists "event-photos owner insert" on storage.objects;
create policy "event-photos owner insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'event-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "event-photos owner update" on storage.objects;
create policy "event-photos owner update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'event-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "event-photos owner delete" on storage.objects;
create policy "event-photos owner delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'event-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- --- RPC pública: devolver los slots de fotos ---------------
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
    'hero_kicker', e.hero_kicker,
    'hero_title', e.hero_title,
    'hero_subtitle', e.hero_subtitle,
    'intro_text', e.intro_text,
    'closing_text', e.closing_text,
    'bg_color', e.bg_color,
    'music_url', e.music_url,
    'banner', e.banner,
    'retrato', e.retrato,
    'detalle', e.detalle,
    'momentos', e.momentos,
    'galeria', e.galeria,
    'event_date', e.event_date,
    'reception_time', e.reception_time,
    'end_time', e.end_time,
    'venue_name', e.venue_name,
    'venue_address', e.venue_address,
    'maps_url', e.maps_url,
    'dress_code', e.dress_code,
    'rsvp_deadline', e.rsvp_deadline,
    'notes', e.notes,
    'gift_alias', e.gift_alias,
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
