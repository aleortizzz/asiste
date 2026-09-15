-- ============================================================
-- Fotos subidas por los invitados durante el evento (vía QR en las mesas)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Bucket separado de "event-photos" (ese es para las fotos curadas de la
-- invitación; este es para lo que suba cualquiera desde el QR, sin login).
-- Para no "reventar" el storage: el navegador comprime cada foto antes de
-- subirla (front), y acá hay un tope duro de cantidad por evento que la
-- función rechaza al llegar al límite.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'guest-uploads', 'guest-uploads', true, 8388608,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = true,
      file_size_limit = 8388608,
      allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

-- Cualquiera puede subir (no hay login en la fiesta). Nadie puede editar ni
-- borrar directo — eso lo hace el dueño del evento vía RLS de más abajo,
-- porque para borrar hay que ser "authenticated" y dueño del evento.
drop policy if exists "guest-uploads anyone insert" on storage.objects;
create policy "guest-uploads anyone insert" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'guest-uploads');

drop policy if exists "guest-uploads owner delete" on storage.objects;
create policy "guest-uploads owner delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'guest-uploads'
    and exists (
      select 1 from events
      where events.id::text = (storage.foldername(name))[1]
      and events.owner_user_id = auth.uid()
    )
  );

drop policy if exists "guest-uploads superadmin delete" on storage.objects;
create policy "guest-uploads superadmin delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'guest-uploads'
    and exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

-- ============================================================
-- Tabla: catálogo de las fotos (la galería pública lee de acá, no lista el
-- bucket directo).
-- ============================================================

create table if not exists event_photos (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null,
  url text not null,
  path text not null,
  created_at timestamptz not null default now()
);

create index if not exists event_photos_event_id_idx on event_photos (event_id);

grant select, delete on public.event_photos to authenticated;
alter table event_photos enable row level security;

-- Sin INSERT acá para "authenticated"/"anon": las filas nuevas se crean
-- únicamente vía agregar_foto_invitados() (security definer), que es donde
-- vive el tope de cantidad. Solo SELECT/DELETE directos, y solo del dueño.
drop policy if exists "admin ve y borra fotos de su evento" on event_photos;
create policy "admin ve y borra fotos de su evento"
  on event_photos for all
  using (exists (
    select 1 from events
    where events.id = event_photos.event_id
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from events
    where events.id = event_photos.event_id
    and events.owner_user_id = auth.uid()
  ));

drop policy if exists "superadmin gestiona fotos de invitados" on event_photos;
create policy "superadmin gestiona fotos de invitados"
  on event_photos for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

-- ============================================================
-- RPCs públicas: agregar una foto (con tope duro) y listar la galería.
-- ============================================================

create or replace function public.agregar_foto_invitados(
  p_event_id uuid,
  p_url text,
  p_path text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_limit int := 500; -- tope duro por evento, ajustable acá si hace falta.
begin
  if not exists (select 1 from events where id = p_event_id) then
    raise exception 'Evento no encontrado';
  end if;

  select count(*) into v_count from event_photos where event_id = p_event_id;
  if v_count >= v_limit then
    raise exception 'Se llegó al máximo de % fotos para este evento.', v_limit;
  end if;

  insert into event_photos (event_id, url, path) values (p_event_id, p_url, p_path);

  return json_build_object('ok', true, 'count', v_count + 1, 'limit', v_limit);
end;
$$;

grant execute on function public.agregar_foto_invitados(uuid, text, text) to anon, authenticated;

create or replace function public.listar_fotos_invitados(p_event_id uuid)
returns table (id uuid, url text, created_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select id, url, created_at
  from event_photos
  where event_id = p_event_id
  order by created_at desc;
$$;

grant execute on function public.listar_fotos_invitados(uuid) to anon, authenticated;
