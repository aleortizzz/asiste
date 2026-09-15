-- ============================================================
-- Asiste — Hito 2: modelo de datos + RLS del admin
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
-- ============================================================

-- gen_random_uuid() vive en la extensión pgcrypto.
create extension if not exists pgcrypto;

-- 1) Eventos: la fiesta. owner_user_id ata cada evento a un admin (auth.users).
-- guest_limit: tope total de invitados que se pueden repartir entre todas
-- las familias del evento. null = sin límite (ilimitado).
create table events (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references auth.users not null,
  name text not null,
  -- Tipo de evento — solo lo usa el panel para precargar textos genéricos.
  event_type text not null default 'cumpleanos'
    check (event_type in ('cumpleanos', 'casamiento')),
  -- Textos editables del hero/saludo/cierre de la invitación pública.
  -- Opcionales: si quedan en null, la landing usa un default genérico.
  hero_kicker text,
  hero_title text,
  hero_subtitle text,
  intro_text text,
  closing_text text,
  bg_color text not null default '#fdf7f1',
  music_url text, -- link de YouTube para la canción de la portada
  -- Fotos (Supabase Storage). Cada slot: array jsonb de { url, path }.
  banner jsonb not null default '[]'::jsonb,
  retrato jsonb not null default '[]'::jsonb,
  detalle jsonb not null default '[]'::jsonb,
  momentos jsonb not null default '[]'::jsonb,
  galeria jsonb not null default '[]'::jsonb,
  -- slots de fotos que NO se muestran en la invitación (la portada nunca).
  hidden_sections jsonb not null default '[]'::jsonb,
  event_date date,
  reception_time time,
  end_time time,
  venue_name text,
  venue_address text,
  maps_url text,
  dress_code text,
  rsvp_deadline date,
  notes text,
  gift_alias text,
  guest_limit int,
  created_at timestamptz not null default now()
);

-- 2) Mesas del salón, una por evento.
create table tables (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null,
  name text not null,
  capacity int not null default 0,
  created_at timestamptz not null default now()
);

-- 3) Grupo/familia = una invitación = un link (slug).
-- Ojo: NO tiene table_id — la mesa se asigna por invitado individual,
-- no por familia entera, porque una familia se puede dividir entre mesas.
-- named_by_host: si el anfitrión cargó los nombres de antemano, el
-- invitado ve esos nombres fijos con botones Asiste/No asiste en vez
-- de un formulario para escribirlos.
create table invitation_groups (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null,
  family_name text not null,
  slug text not null unique,
  allowed_guests int not null default 1,
  named_by_host boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'declined')),
  created_at timestamptz not null default now()
);

-- 4) Invitados individuales dentro de un grupo. table_id se asigna
-- desde el admin una vez que el invitado confirmó asistencia (Hito 5+).
-- rsvp_status: 'invited' = nombre precargado por el anfitrión, todavía
-- sin responder; 'attending' / 'not_attending' = ya respondió.
create table guests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references invitation_groups(id) on delete cascade not null,
  table_id uuid references tables(id) on delete set null,
  full_name text not null,
  rsvp_status text not null default 'invited' check (rsvp_status in ('invited', 'attending', 'not_attending')),
  created_at timestamptz not null default now()
);

-- 5) Log de aperturas de la invitación pública: cada fila es una vez que
-- alguien abrió /i/:slug. Lo escribe obtener_invitacion() (ver más abajo).
create table invitation_views (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references invitation_groups(id) on delete cascade not null,
  viewed_at timestamptz not null default now()
);

create index invitation_views_group_id_idx on invitation_views (group_id);

-- ============================================================
-- GRANTS — sin esto, "authenticated" no puede tocar la tabla en
-- absoluto, sin importar lo que digan las policies de RLS. RLS
-- filtra QUÉ FILAS ves; GRANT decide si podés intentar la operación.
-- Al crear tablas por SQL Editor (a diferencia del Table Editor de
-- la interfaz), Supabase no los agrega solo.
-- ============================================================

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.events to authenticated;
grant select, insert, update, delete on public.tables to authenticated;
grant select, insert, update, delete on public.invitation_groups to authenticated;
grant select, insert, update, delete on public.guests to authenticated;
grant select on public.invitation_views to authenticated;

-- ============================================================
-- RLS — solo reglas del admin autenticado por ahora.
-- Las reglas públicas para /i/:slug se agregan recién en el Hito 5.
-- ============================================================

alter table events enable row level security;
alter table tables enable row level security;
alter table invitation_groups enable row level security;
alter table guests enable row level security;
alter table invitation_views enable row level security;

-- events: el admin solo ve/edita sus propios eventos.
create policy "admin gestiona sus eventos"
  on events for all
  using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);

-- tables: acceso solo si el evento dueño es del admin logueado.
create policy "admin gestiona mesas de sus eventos"
  on tables for all
  using (exists (
    select 1 from events
    where events.id = tables.event_id
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from events
    where events.id = tables.event_id
    and events.owner_user_id = auth.uid()
  ));

-- invitation_groups: mismo patrón, vía event_id.
create policy "admin gestiona grupos de sus eventos"
  on invitation_groups for all
  using (exists (
    select 1 from events
    where events.id = invitation_groups.event_id
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from events
    where events.id = invitation_groups.event_id
    and events.owner_user_id = auth.uid()
  ));

-- guests: vía group_id -> event_id.
create policy "admin gestiona invitados de sus eventos"
  on guests for all
  using (exists (
    select 1 from invitation_groups
    join events on events.id = invitation_groups.event_id
    where invitation_groups.id = guests.group_id
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from invitation_groups
    join events on events.id = invitation_groups.event_id
    where invitation_groups.id = guests.group_id
    and events.owner_user_id = auth.uid()
  ));

-- invitation_views: mismo patrón vía group_id -> event_id. Solo SELECT — se
-- escribe únicamente desde obtener_invitacion() (security definer).
create policy "admin ve las vistas de sus invitados"
  on invitation_views for select
  using (exists (
    select 1 from invitation_groups
    join events on events.id = invitation_groups.event_id
    where invitation_groups.id = invitation_views.group_id
    and events.owner_user_id = auth.uid()
  ));

-- ============================================================
-- HITO 5 — acceso público (RSVP) vía funciones RPC.
-- Nada de esto se expone como policy directa sobre las tablas:
-- si el público pudiera hacer SELECT * on invitation_groups, podría
-- listar TODAS las familias del evento, no solo la suya. En cambio,
-- dos funciones SECURITY DEFINER hacen de "puerta angosta": reciben
-- el slug como argumento y devuelven/tocan solo esa fila.
--
-- SECURITY DEFINER hace que la función corra con los permisos de
-- quien la creó (el dueño de la tabla, típicamente "postgres" en
-- Supabase) — por eso puede leer/escribir sin que "anon" tenga
-- GRANT ni policy propia sobre estas tablas. `set search_path`
-- evita el ataque clásico de "search_path hijacking" en funciones
-- SECURITY DEFINER.
-- ============================================================

-- Lectura pública de una invitación por slug (para la landing /i/:slug).
create or replace function public.obtener_invitacion(p_slug text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  result json;
  v_group_id uuid;
begin
  select ig.id, json_build_object(
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
    'hidden_sections', e.hidden_sections,
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
  into v_group_id, result
  from invitation_groups ig
  join events e on e.id = ig.event_id
  where ig.slug = p_slug;

  if result is null then
    raise exception 'Invitación no encontrada';
  end if;

  insert into invitation_views (group_id) values (v_group_id);

  return result;
end;
$$;

grant execute on function public.obtener_invitacion(text) to anon, authenticated;

-- Escritura pública del RSVP — modo "genérico" (sin nombres precargados):
-- la familia escribe los nombres. Valida server-side que no se carguen
-- más nombres que "allowed_guests" — el cliente nunca podría forzar eso
-- porque no tiene permiso de escritura directa sobre la tabla.
create or replace function public.confirmar_asistencia(p_slug text, p_guest_names text[])
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group invitation_groups%rowtype;
  v_count int;
begin
  select * into v_group from invitation_groups where slug = p_slug;

  if v_group.id is null then
    raise exception 'Invitación no encontrada';
  end if;

  if v_group.named_by_host then
    raise exception 'Esta invitación ya tiene nombres cargados por el anfitrión';
  end if;

  v_count := coalesce(array_length(p_guest_names, 1), 0);

  if v_count = 0 then
    delete from guests where group_id = v_group.id;
    update invitation_groups set status = 'declined' where id = v_group.id;
    return json_build_object('status', 'declined');
  end if;

  if v_count > v_group.allowed_guests then
    raise exception 'Superaste el máximo de % invitaciones permitidas', v_group.allowed_guests;
  end if;

  delete from guests where group_id = v_group.id;

  insert into guests (group_id, full_name, rsvp_status)
  select v_group.id, trim(name), 'attending'
  from unnest(p_guest_names) as name
  where trim(name) <> '';

  update invitation_groups set status = 'confirmed' where id = v_group.id;

  return json_build_object('status', 'confirmed');
end;
$$;

grant execute on function public.confirmar_asistencia(text, text[]) to anon, authenticated;

-- Escritura pública del RSVP — modo "con nombres precargados": el
-- anfitrión ya cargó quiénes son, el invitado solo marca asiste/no
-- asiste por persona. p_respuestas es un jsonb tipo
-- [{"id": "<guest uuid>", "attending": true}, ...].
create or replace function public.responder_invitados(p_slug text, p_respuestas jsonb)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_attending_count int;
begin
  select ig.id into v_group_id
  from invitation_groups ig
  where ig.slug = p_slug and ig.named_by_host;

  if v_group_id is null then
    raise exception 'Invitación no encontrada';
  end if;

  update guests g
  set rsvp_status = case when (r.attending)::boolean then 'attending' else 'not_attending' end
  from jsonb_to_recordset(p_respuestas) as r(id uuid, attending boolean)
  where g.id = r.id and g.group_id = v_group_id;

  select count(*) filter (where rsvp_status = 'attending')
  into v_attending_count
  from guests where group_id = v_group_id;

  update invitation_groups
  set status = case when v_attending_count > 0 then 'confirmed' else 'declined' end
  where id = v_group_id;

  return json_build_object('attending_count', v_attending_count);
end;
$$;

grant execute on function public.responder_invitados(text, jsonb) to anon, authenticated;

-- ============================================================
-- SUPERADMIN — panel de soporte para ver/gestionar el evento de
-- cualquier cliente. Ver supabase/migrations/20260915_superadmin.sql
-- para el detalle y el comentario de por qué vive en RLS.
-- ============================================================

create table superadmins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- El GRANT hace falta (security definer acá no alcanza a saltearlo solo).
-- Lo que hay que evitar es una policy que se consulte A SÍ MISMA — eso es
-- recursión infinita (error 42P17). Esta compara auth.uid() contra la
-- columna directo, sin subconsulta a la tabla: cada cuenta ve su propia
-- fila, que es lo único que necesitan soy_superadmin()/listar_eventos_superadmin().
grant select on public.superadmins to authenticated;
alter table superadmins enable row level security;

create policy "cada uno ve su propia fila de superadmins"
  on superadmins for select
  using (auth.uid() = user_id);

create policy "superadmin gestiona eventos"
  on events for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

create policy "superadmin gestiona mesas"
  on tables for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

create policy "superadmin gestiona grupos"
  on invitation_groups for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

create policy "superadmin gestiona invitados"
  on guests for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

create policy "superadmin gestiona vistas"
  on invitation_views for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

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

-- ============================================================
-- FOTOS DE INVITADOS — subidas desde un QR en las mesas, sin login.
-- Ver supabase/migrations/20260915_fotos_invitados.sql para el detalle.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'guest-uploads', 'guest-uploads', true, 8388608,
  array['image/jpeg', 'image/png', 'image/webp']
);

create policy "guest-uploads anyone insert" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'guest-uploads');

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

create policy "guest-uploads superadmin delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'guest-uploads'
    and exists (select 1 from superadmins s where s.user_id = auth.uid())
  );

create table event_photos (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null,
  url text not null,
  path text not null,
  uploader_name text,
  likes_count int not null default 0,
  created_at timestamptz not null default now()
);

create index event_photos_event_id_idx on event_photos (event_id);

grant select, delete on public.event_photos to authenticated;
alter table event_photos enable row level security;

-- Sin INSERT para authenticated/anon: las filas se crean solo vía
-- agregar_foto_invitados() (security definer), donde vive el tope.
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

create policy "superadmin gestiona fotos de invitados"
  on event_photos for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

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
  v_limit int := 500; -- tope duro por evento, ajustable acá si hace falta.
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

-- Like público y anónimo: el límite de "uno por persona" lo hace el
-- navegador (localStorage), no el servidor.
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
