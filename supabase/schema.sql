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
    check (event_type in ('cumpleanos', 'casamiento', 'empresarial')),
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
  -- true = pasada rsvp_deadline no se aceptan más respuestas (ver migrations/20260928_cierre_confirmaciones.sql).
  rsvp_deadline_strict boolean not null default false,
  notes text,
  gift_alias text,
  guest_limit int,
  created_at timestamptz not null default now(),
  -- Plan: 'gratis' (prueba, con límites) | 'invitacion' | 'plus' | 'premium'.
  -- Qué incluye cada uno: plan_incluye(). Solo lo cambia TizDigital (trigger
  -- events_proteger_plan). Ver supabase/migrations/20261013_planes.sql.
  plan text not null default 'gratis' check (plan in ('gratis', 'invitacion', 'plus', 'premium')),
  -- Plantilla visual, elección libre del host (como bg_color). Ver
  -- supabase/migrations/20260924_plantilla_invitacion.sql.
  template text not null default 'clasico' check (template in ('clasico', 'partiful', 'craft', 'craft-v2', 'ejecutiva')),
  -- Sello del sobre (opcional). Vacío = se infiere de hero_title. Ver
  -- supabase/migrations/20260925_sobre_monograma.sql.
  monogram text,
  -- Color de acento único: las plantillas son diseño/tipografía, el color lo
  -- elige el host. Ver supabase/migrations/20260925_color_principal.sql.
  primary_color text not null default '#9f1239',
  -- Línea corta opcional en la carta del sobre. Ver
  -- supabase/migrations/20260926_sobre_texto.sql.
  envelope_text text,
  -- Color propio del sobre (opcional, independiente del color principal).
  -- Ver supabase/migrations/20260926_color_sobre.sql.
  envelope_color text,
  -- Plantilla «Ejecutiva» (ver migrations/20261002_plantilla_ejecutiva.sql):
  -- color de detalles, claro/oscuro, usted/vos, estilo de la fecha en la
  -- portada, logo de la empresa y logos de sponsors.
  accent_color text,
  theme_mode text not null default 'claro' check (theme_mode in ('claro', 'oscuro')),
  tono text not null default 'vos' check (tono in ('vos', 'usted')),
  date_style text not null default 'regresiva' check (date_style in ('regresiva', 'destacada', 'discreta')),
  logo jsonb not null default '[]'::jsonb,
  sponsors jsonb not null default '[]'::jsonb,
  -- Mostrar el logo / los sponsors en blanco (para fondo oscuro). Ver
  -- migrations/20261002_logos_en_blanco.sql.
  logo_white boolean not null default false,
  sponsors_white boolean not null default false,
  -- Secciones empresariales (ver migrations/20261002_secciones_empresariales.sql):
  -- programa, cómo llegar, contacto del organizador y redes.
  agenda jsonb not null default '[]'::jsonb,
  access_info text,
  contact_name text,
  contact_email text,
  contact_phone text,
  social_links jsonb not null default '{}'::jsonb,
  -- Datos que se piden al confirmar: 'company', 'job_title', 'email', 'phone', 'dietary'.
  rsvp_fields jsonb not null default '[]'::jsonb,
  -- Invitación bilingüe (ver migrations/20261002_bilingue.sql).
  bilingual boolean not null default false,
  texts_en jsonb not null default '{}'::jsonb
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
  -- Hora de la última respuesta (la completa el trigger invitation_groups_responded_at).
  responded_at timestamptz,
  -- Invitación sorpresa: la cuenta del evento no la ve, solo el superadmin
  -- (ver migrations/20260930_invitaciones_sorpresa.sql).
  sorpresa boolean not null default false,
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
  created_at timestamptz not null default now(),
  -- Datos extra al confirmar (los que pida el evento en events.rsvp_fields).
  -- Ver migrations/20261002_confirmacion_completa.sql.
  company text,
  job_title text,
  email text,
  phone text,
  dietary text
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

-- invitation_groups: mismo patrón, vía event_id. Las sorpresa quedan
-- afuera: el dueño no las ve ni puede crearlas/marcarlas.
create policy "admin gestiona grupos de sus eventos"
  on invitation_groups for all
  using (
    not sorpresa
    and exists (
      select 1 from events
      where events.id = invitation_groups.event_id
      and events.owner_user_id = auth.uid()
    )
  )
  with check (
    not sorpresa
    and exists (
      select 1 from events
      where events.id = invitation_groups.event_id
      and events.owner_user_id = auth.uid()
    )
  );

-- guests: vía group_id -> event_id.
create policy "admin gestiona invitados de sus eventos"
  on guests for all
  using (exists (
    select 1 from invitation_groups
    join events on events.id = invitation_groups.event_id
    where invitation_groups.id = guests.group_id
    and not invitation_groups.sorpresa
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from invitation_groups
    join events on events.id = invitation_groups.event_id
    where invitation_groups.id = guests.group_id
    and not invitation_groups.sorpresa
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
    and not invitation_groups.sorpresa
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
  select ig.id, (jsonb_build_object(
    'family_name', ig.family_name,
    'allowed_guests', ig.allowed_guests,
    'status', ig.status,
    'named_by_host', ig.named_by_host,
    'event_name', e.name,
    'plan', e.plan,
    'template', e.template,
    'monogram', e.monogram,
    'primary_color', e.primary_color,
    'envelope_text', e.envelope_text,
    'envelope_color', e.envelope_color,
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
      select jsonb_agg(jsonb_build_object(
        'id', g.id,
        'full_name', g.full_name,
        'rsvp_status', g.rsvp_status,
        'company', g.company,
        'job_title', g.job_title,
        'email', g.email,
        'phone', g.phone,
        'dietary', g.dietary
      ) order by g.created_at)
      from guests g
      where g.group_id = ig.id
    ), '[]'::jsonb)
  ) || jsonb_build_object(
    'event_type', e.event_type,
    'accent_color', e.accent_color,
    'theme_mode', e.theme_mode,
    'tono', e.tono,
    'date_style', e.date_style,
    'logo', e.logo,
    'sponsors', e.sponsors,
    'logo_white', e.logo_white,
    'sponsors_white', e.sponsors_white
  ) || jsonb_build_object(
    'agenda', e.agenda,
    'access_info', e.access_info,
    'contact_name', e.contact_name,
    'contact_email', e.contact_email,
    'contact_phone', e.contact_phone,
    'social_links', e.social_links,
    'rsvp_fields', e.rsvp_fields,
    'bilingual', e.bilingual,
    'texts_en', e.texts_en
  ))::json
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
create or replace function public.texto_invitado(p_value text, p_max int default 200)
returns text
language sql
immutable
as $$
  select nullif(left(trim(coalesce(p_value, '')), p_max), '');
$$;

create or replace function public.confirmar_asistencia(
  p_slug text,
  p_guest_names text[],
  p_detalles jsonb default '[]'::jsonb
)
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

  insert into guests (group_id, full_name, rsvp_status, company, job_title, email, phone, dietary)
  select
    v_group.id,
    trim(n.name),
    'attending',
    public.texto_invitado(d.value ->> 'company'),
    public.texto_invitado(d.value ->> 'job_title'),
    public.texto_invitado(d.value ->> 'email'),
    public.texto_invitado(d.value ->> 'phone', 60),
    public.texto_invitado(d.value ->> 'dietary', 300)
  from unnest(p_guest_names) with ordinality as n(name, i)
  left join lateral (
    select p_detalles -> (n.i::int - 1) as value
    where jsonb_typeof(p_detalles) = 'array'
  ) d on true
  where trim(n.name) <> '';

  update invitation_groups set status = 'confirmed' where id = v_group.id;

  return json_build_object('status', 'confirmed');
end;
$$;

grant execute on function public.confirmar_asistencia(text, text[], jsonb) to anon, authenticated;

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
  set rsvp_status = case when (r.value ->> 'attending')::boolean then 'attending' else 'not_attending' end,
      company   = case when r.value ? 'company'   then public.texto_invitado(r.value ->> 'company') else g.company end,
      job_title = case when r.value ? 'job_title' then public.texto_invitado(r.value ->> 'job_title') else g.job_title end,
      email     = case when r.value ? 'email'     then public.texto_invitado(r.value ->> 'email') else g.email end,
      phone     = case when r.value ? 'phone'     then public.texto_invitado(r.value ->> 'phone', 60) else g.phone end,
      dietary   = case when r.value ? 'dietary'   then public.texto_invitado(r.value ->> 'dietary', 300) else g.dietary end
  from jsonb_array_elements(p_respuestas) as r(value)
  where g.id = (r.value ->> 'id')::uuid and g.group_id = v_group_id;

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

drop function if exists public.listar_eventos_superadmin();

create or replace function public.listar_eventos_superadmin()
returns table (
  event_id uuid,
  event_name text,
  owner_email text,
  event_date date,
  plan text,
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
    select e.id, e.name, u.email::text, e.event_date, e.plan, e.created_at
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

-- ============================================================
-- CANCIONES SOLICITADAS — feature de plan "plus". Ver
-- supabase/migrations/20260924_canciones_plan.sql para el detalle.
-- ============================================================

create table song_requests (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null,
  -- De qué invitación vino (para ocultar las de invitaciones sorpresa).
  group_id uuid references invitation_groups(id) on delete set null,
  song_title text not null,
  artist text,
  youtube_video_id text,
  requested_by text not null,
  created_at timestamptz not null default now()
);

create index song_requests_event_id_idx on song_requests (event_id);

grant select, delete on public.song_requests to authenticated;
alter table song_requests enable row level security;

create policy "admin gestiona canciones de su evento"
  on song_requests for all
  using (
    exists (
      select 1 from events
      where events.id = song_requests.event_id
      and events.owner_user_id = auth.uid()
    )
    and not exists (
      select 1 from invitation_groups
      where invitation_groups.id = song_requests.group_id
      and invitation_groups.sorpresa
    )
  )
  with check (exists (
    select 1 from events
    where events.id = song_requests.event_id
    and events.owner_user_id = auth.uid()
  ));

create policy "superadmin gestiona canciones"
  on song_requests for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

-- Alta pública de un pedido de canción, vía slug (misma puerta angosta que
-- confirmar_asistencia). Valida server-side que el evento tenga plan
-- 'plus' — si el host bajó de plan después de mandar el link, esto lo
-- corta acá aunque alguien deje la pestaña vieja abierta.
create or replace function public.agregar_cancion_solicitada(
  p_slug text,
  p_song_title text,
  p_artist text,
  p_youtube_video_id text,
  p_requested_by text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_id uuid;
  v_group_id uuid;
  v_plan text;
begin
  select e.id, ig.id, e.plan into v_event_id, v_group_id, v_plan
  from invitation_groups ig
  join events e on e.id = ig.event_id
  where ig.slug = p_slug;

  if v_event_id is null then
    raise exception 'Invitación no encontrada';
  end if;

  if v_plan <> 'plus' then
    raise exception 'Esta invitación no tiene habilitado el pedido de canciones';
  end if;

  if trim(coalesce(p_song_title, '')) = '' then
    raise exception 'Falta el nombre de la canción';
  end if;

  if trim(coalesce(p_requested_by, '')) = '' then
    raise exception 'Falta tu nombre';
  end if;

  insert into song_requests (event_id, group_id, song_title, artist, youtube_video_id, requested_by)
  values (
    v_event_id,
    v_group_id,
    trim(p_song_title),
    nullif(trim(coalesce(p_artist, '')), ''),
    nullif(trim(coalesce(p_youtube_video_id, '')), ''),
    trim(p_requested_by)
  );

  return json_build_object('ok', true);
end;
$$;

grant execute on function public.agregar_cancion_solicitada(text, text, text, text, text) to anon, authenticated;


-- Hora de respuesta de cada familia (ver migrations/20260927_respondido_en.sql).
create or replace function public.marcar_respondido_en()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status <> 'pending' then
    new.responded_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists invitation_groups_responded_at on invitation_groups;
create trigger invitation_groups_responded_at
  before update of status on invitation_groups
  for each row
  execute function public.marcar_respondido_en();


-- Historial de respuestas (ver migrations/20260927_historial_respuestas.sql).
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
      and not invitation_groups.sorpresa
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



-- Cierre opcional de confirmaciones (ver migrations/20260928_cierre_confirmaciones.sql).
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

-- Vista previa de los links al compartirlos (WhatsApp, Telegram, etc.)
--
-- Las usa public/og.php, que arma el título, la descripción y la foto que
-- muestra WhatsApp. Son solo de lectura a propósito: obtener_invitacion()
-- registra una visita en invitation_views, y el robot de WhatsApp no tiene
-- que contar como «la familia abrió el link».
--
-- Devuelven solo datos que la invitación ya muestra públicamente.
-- ============================================================

create or replace function public.vista_previa_invitacion(p_slug text)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'family_name', ig.family_name,
    'event_name', e.name,
    'event_type', e.event_type,
    'hero_title', e.hero_title,
    'event_date', e.event_date,
    -- Primera foto disponible: portada, después saludo, momentos, galería.
    'image', coalesce(
      e.banner -> 0 ->> 'url',
      e.retrato -> 0 ->> 'url',
      e.momentos -> 0 ->> 'url',
      e.galeria -> 0 ->> 'url'
    ),
    -- Para la Ejecutiva: tarjeta con el logo en vez de una foto.
    'template', e.template,
    'logo', e.logo -> 0 ->> 'url',
    'logo_white', e.logo_white,
    'theme_mode', e.theme_mode,
    'primary_color', e.primary_color,
    'accent_color', e.accent_color,
    'bg_color', e.bg_color,
    'reception_time', e.reception_time,
    'venue_name', e.venue_name
  )
  from public.invitation_groups ig
  join public.events e on e.id = ig.event_id
  where ig.slug = p_slug;
$$;

grant execute on function public.vista_previa_invitacion(text) to anon, authenticated;

create or replace function public.vista_previa_fotos(p_event_id uuid)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'event_name', e.name,
    'event_type', e.event_type,
    'hero_title', e.hero_title,
    'event_date', e.event_date,
    'image', coalesce(
      e.banner -> 0 ->> 'url',
      e.retrato -> 0 ->> 'url',
      e.momentos -> 0 ->> 'url',
      e.galeria -> 0 ->> 'url'
    )
  )
  from public.events e
  where e.id = p_event_id;
$$;

grant execute on function public.vista_previa_fotos(uuid) to anon, authenticated;

-- ============================================================
-- Página pública de fotos (/fotos/:id): nombre, plantilla y colores del
-- evento para que se vea como la invitación.
-- ============================================================
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

-- ============================================================
-- Sacar un like de una foto de invitados (tocar el corazón de nuevo)
--
-- Igual que dar_like_foto: público y anónimo. Que cada navegador solo saque
-- un like que dio lo controla la página (localStorage), no el servidor.
-- Nunca baja de 0.
-- ============================================================

create or replace function public.quitar_like_foto(p_photo_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  update public.event_photos set likes_count = greatest(likes_count - 1, 0)
  where id = p_photo_id
  returning likes_count into v_count;

  if v_count is null then
    raise exception 'Foto no encontrada';
  end if;

  return v_count;
end;
$$;

grant execute on function public.quitar_like_foto(uuid) to anon, authenticated;


-- Lugares de invitados sorpresa por mesa (ver migrations/20260930_invitaciones_sorpresa.sql).
create or replace function public.lugares_reservados(p_event_id uuid)
returns table (table_id uuid, cantidad int)
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from superadmins where user_id = auth.uid()) then
    return;
  end if;
  if not exists (select 1 from events where id = p_event_id and owner_user_id = auth.uid()) then
    raise exception 'No autorizado';
  end if;

  return query
    select g.table_id, count(*)::int
    from guests g
    join invitation_groups ig on ig.id = g.group_id
    where ig.event_id = p_event_id
      and ig.sorpresa
      and g.rsvp_status = 'attending'
      and g.table_id is not null
    group by g.table_id;
end;
$$;

grant execute on function public.lugares_reservados(uuid) to authenticated;


-- Trivia para jugar durante la fiesta (ver migrations/20261011_trivia.sql).
create table if not exists trivia_games (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null unique,
  title text not null default 'Trivia',
  time_limit_seconds int not null default 300 check (time_limit_seconds between 30 and 1800),
  status text not null default 'borrador' check (status in ('borrador', 'abierto', 'cerrado')),
  opened_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists trivia_questions (
  id uuid primary key default gen_random_uuid(),
  game_id uuid references trivia_games(id) on delete cascade not null,
  position int not null default 0,
  question text not null check (length(trim(question)) > 0),
  -- Array de 2 a 4 textos. correct_index apunta a uno de ellos.
  options jsonb not null check (
    jsonb_typeof(options) = 'array'
    and jsonb_array_length(options) between 2 and 4
  ),
  correct_index int not null check (correct_index >= 0),
  created_at timestamptz not null default now(),
  check (correct_index < jsonb_array_length(options))
);

create index if not exists trivia_questions_game_id_idx on trivia_questions (game_id, position);

create table if not exists trivia_attempts (
  id uuid primary key default gen_random_uuid(),
  game_id uuid references trivia_games(id) on delete cascade not null,
  -- Lo guarda el navegador del invitado: es su "llave" para seguir jugando
  -- y enviar. Nunca se muestra en el ranking.
  token uuid not null unique default gen_random_uuid(),
  player_name text not null,
  started_at timestamptz not null default now(),
  -- { "<id de la pregunta>": <índice de la opción elegida> }
  answers jsonb not null default '{}'::jsonb,
  submitted_at timestamptz,
  correct_count int,
  duration_ms int
);

create index if not exists trivia_attempts_game_id_idx on trivia_attempts (game_id);

-- ============================================================
-- Permisos del panel: el dueño del evento (y el superadmin) arma el juego y
-- las preguntas directo sobre las tablas. Los intentos solo los ve y borra:
-- se crean y se corrigen únicamente vía las RPC de más abajo.
-- ============================================================

grant select, insert, update, delete on public.trivia_games to authenticated;
grant select, insert, update, delete on public.trivia_questions to authenticated;
grant select, delete on public.trivia_attempts to authenticated;

alter table trivia_games enable row level security;
alter table trivia_questions enable row level security;
alter table trivia_attempts enable row level security;

drop policy if exists "admin gestiona el juego de su evento" on trivia_games;
create policy "admin gestiona el juego de su evento"
  on trivia_games for all
  using (exists (
    select 1 from events
    where events.id = trivia_games.event_id
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from events
    where events.id = trivia_games.event_id
    and events.owner_user_id = auth.uid()
  ));

drop policy if exists "admin gestiona las preguntas de su juego" on trivia_questions;
create policy "admin gestiona las preguntas de su juego"
  on trivia_questions for all
  using (exists (
    select 1 from trivia_games tg
    join events e on e.id = tg.event_id
    where tg.id = trivia_questions.game_id
    and e.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from trivia_games tg
    join events e on e.id = tg.event_id
    where tg.id = trivia_questions.game_id
    and e.owner_user_id = auth.uid()
  ));

drop policy if exists "admin ve y borra los intentos de su juego" on trivia_attempts;
create policy "admin ve y borra los intentos de su juego"
  on trivia_attempts for all
  using (exists (
    select 1 from trivia_games tg
    join events e on e.id = tg.event_id
    where tg.id = trivia_attempts.game_id
    and e.owner_user_id = auth.uid()
  ));

drop policy if exists "superadmin gestiona juegos" on trivia_games;
create policy "superadmin gestiona juegos"
  on trivia_games for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

drop policy if exists "superadmin gestiona preguntas" on trivia_questions;
create policy "superadmin gestiona preguntas"
  on trivia_questions for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

drop policy if exists "superadmin gestiona intentos" on trivia_attempts;
create policy "superadmin gestiona intentos"
  on trivia_attempts for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()));

-- ============================================================
-- Corrección (interna, no se expone a los invitados)
-- ============================================================

-- Cuenta cuántas de las respuestas coinciden con la correcta. Las claves que
-- no son preguntas de este juego se ignoran solas (no matchean el join).
create or replace function public.trivia_contar_aciertos(p_game_id uuid, p_answers jsonb)
returns int
language sql
stable
set search_path = public
as $$
  select count(*)::int
  from public.trivia_questions q
  where q.game_id = p_game_id
    and p_answers ? q.id::text
    and jsonb_typeof(p_answers -> q.id::text) = 'number'
    and (p_answers ->> q.id::text)::int = q.correct_index;
$$;

-- Cierra un intento: corrige y calcula cuánto tardó. La duración nunca
-- supera el tiempo límite (si llegó tarde, cuenta como que usó todo).
create or replace function public.trivia_finalizar_intento(p_attempt_id uuid, p_end timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_limit int;
  v_end timestamptz;
begin
  select * into v_attempt from trivia_attempts where id = p_attempt_id for update;
  if v_attempt.submitted_at is not null then
    return;
  end if;

  select time_limit_seconds into v_limit from trivia_games where id = v_attempt.game_id;
  v_end := least(p_end, v_attempt.started_at + make_interval(secs => v_limit));

  update trivia_attempts set
    submitted_at = v_end,
    correct_count = trivia_contar_aciertos(v_attempt.game_id, v_attempt.answers),
    duration_ms = greatest(0, (extract(epoch from (v_end - v_attempt.started_at)) * 1000)::int)
  where id = p_attempt_id;
end;
$$;

revoke execute on function public.trivia_contar_aciertos(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.trivia_finalizar_intento(uuid, timestamptz) from public, anon, authenticated;

-- Al abrir o cerrar el juego desde el panel se anotan las horas; al cerrarlo,
-- los que estaban jugando quedan corregidos con lo que alcanzaron a responder.
create or replace function public.trivia_cambio_estado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if new.status is distinct from old.status then
    if new.status = 'abierto' then
      new.opened_at := now();
      new.closed_at := null;
    elsif new.status = 'cerrado' then
      new.closed_at := now();
      for v_id in
        select id from trivia_attempts where game_id = new.id and submitted_at is null
      loop
        perform trivia_finalizar_intento(v_id, now());
      end loop;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trivia_cambio_estado on trivia_games;
create trigger trivia_cambio_estado
  before update on trivia_games
  for each row execute function public.trivia_cambio_estado();

-- ============================================================
-- RPC públicas (sin login): las usa /fotos y /juego
-- ============================================================

-- Estado liviano del juego: para mostrar u ocultar el botón en /fotos y para
-- la pantalla de inicio. Sin preguntas. null si el evento no tiene juego.
create or replace function public.info_juego(p_event_id uuid)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'status', g.status,
    'title', g.title,
    'time_limit_seconds', g.time_limit_seconds,
    'question_count', (select count(*) from public.trivia_questions q where q.game_id = g.id)
  )
  from public.trivia_games g
  where g.event_id = p_event_id;
$$;

grant execute on function public.info_juego(uuid) to anon, authenticated;

-- Preguntas sin la respuesta correcta (uso interno de las dos de abajo).
create or replace function public.trivia_preguntas_publicas(p_game_id uuid)
returns json
language sql
stable
set search_path = public
as $$
  select coalesce(json_agg(json_build_object(
    'id', q.id,
    'question', q.question,
    'options', q.options
  ) order by q.position, q.created_at), '[]'::json)
  from public.trivia_questions q
  where q.game_id = p_game_id;
$$;

revoke execute on function public.trivia_preguntas_publicas(uuid) from public, anon, authenticated;

-- Arranca un intento: desde acá corre el reloj. Recién ahora se mandan las
-- preguntas, así nadie las lee antes de empezar.
create or replace function public.empezar_juego(p_event_id uuid, p_name text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game trivia_games;
  v_name text := texto_invitado(p_name, 40);
  v_attempt trivia_attempts;
begin
  select * into v_game from trivia_games where event_id = p_event_id;
  if v_game.id is null or v_game.status <> 'abierto' then
    raise exception 'El juego no está abierto.';
  end if;
  if v_name is null then
    raise exception 'Escribí tu nombre para jugar.';
  end if;
  if not exists (select 1 from trivia_questions where game_id = v_game.id) then
    raise exception 'El juego todavía no tiene preguntas.';
  end if;
  if (select count(*) from trivia_attempts where game_id = v_game.id) >= 1000 then
    raise exception 'Se llegó al máximo de jugadores.';
  end if;

  insert into trivia_attempts (game_id, player_name)
  values (v_game.id, v_name)
  returning * into v_attempt;

  return json_build_object(
    'token', v_attempt.token,
    'player_name', v_attempt.player_name,
    'started_at', v_attempt.started_at,
    'server_now', now(),
    'time_limit_seconds', v_game.time_limit_seconds,
    'answers', v_attempt.answers,
    'questions', trivia_preguntas_publicas(v_game.id)
  );
end;
$$;

grant execute on function public.empezar_juego(uuid, text) to anon, authenticated;

-- Para volver a la página (se cerró, se recargó, se quedó sin batería):
-- devuelve el intento y, si todavía puede jugar, las preguntas y lo que ya
-- había respondido. El reloj siguió corriendo mientras tanto.
create or replace function public.mi_intento_juego(p_token uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_game trivia_games;
  v_playing boolean;
begin
  select * into v_attempt from trivia_attempts where token = p_token;
  if v_attempt.id is null then
    return null;
  end if;
  select * into v_game from trivia_games where id = v_attempt.game_id;

  v_playing := v_attempt.submitted_at is null and v_game.status = 'abierto';

  return json_build_object(
    'player_name', v_attempt.player_name,
    'started_at', v_attempt.started_at,
    'submitted_at', v_attempt.submitted_at,
    'server_now', now(),
    'time_limit_seconds', v_game.time_limit_seconds,
    'answers', case when v_playing then v_attempt.answers end,
    'questions', case when v_playing then trivia_preguntas_publicas(v_game.id) end
  );
end;
$$;

grant execute on function public.mi_intento_juego(uuid) to anon, authenticated;

-- Guarda una respuesta apenas se elige (se puede cambiar mientras haya
-- tiempo). Fuera de tiempo no hace nada: queda lo último guardado. Los 15 s
-- de gracia (acá y en enviar_juego) son por la conexión: el envío automático
-- al llegar a 0 tarda un poco en llegar.
create or replace function public.responder_pregunta(p_token uuid, p_question_id uuid, p_option int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_game trivia_games;
  v_options int;
begin
  select * into v_attempt from trivia_attempts where token = p_token;
  if v_attempt.id is null then
    raise exception 'Intento no encontrado';
  end if;
  select * into v_game from trivia_games where id = v_attempt.game_id;

  if v_attempt.submitted_at is not null
     or v_game.status <> 'abierto'
     or now() > v_attempt.started_at + make_interval(secs => v_game.time_limit_seconds + 15) then
    return false;
  end if;

  select jsonb_array_length(options) into v_options
  from trivia_questions
  where id = p_question_id and game_id = v_game.id;
  if v_options is null or p_option is null or p_option < 0 or p_option >= v_options then
    raise exception 'Respuesta inválida';
  end if;

  update trivia_attempts
  set answers = answers || jsonb_build_object(p_question_id::text, p_option)
  where id = v_attempt.id;

  return true;
end;
$$;

grant execute on function public.responder_pregunta(uuid, uuid, int) to anon, authenticated;

-- Envía el intento. Si llega a tiempo, se toman las respuestas que manda el
-- celular (por si alguna no se llegó a guardar). Si llega tarde, se corrige
-- solo con lo que ya estaba guardado. Si ya estaba enviado, no cambia nada:
-- se puede reintentar sin miedo si se cortó la conexión.
create or replace function public.enviar_juego(p_token uuid, p_answers jsonb default null)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_game trivia_games;
begin
  select * into v_attempt from trivia_attempts where token = p_token;
  if v_attempt.id is null then
    raise exception 'Intento no encontrado';
  end if;
  select * into v_game from trivia_games where id = v_attempt.game_id;

  if v_attempt.submitted_at is null then
    if v_game.status = 'abierto'
       and now() <= v_attempt.started_at + make_interval(secs => v_game.time_limit_seconds + 15)
       and jsonb_typeof(p_answers) = 'object' then
      update trivia_attempts
      set answers = answers || p_answers
      where id = v_attempt.id;
    end if;
    perform trivia_finalizar_intento(v_attempt.id, now());
  end if;

  select * into v_attempt from trivia_attempts where id = v_attempt.id;
  return json_build_object(
    'correct_count', v_attempt.correct_count,
    'total', (select count(*) from trivia_questions where game_id = v_game.id),
    'duration_ms', v_attempt.duration_ms
  );
end;
$$;

grant execute on function public.enviar_juego(uuid, jsonb) to anon, authenticated;

-- Ranking en vivo: top 10 de los que ya enviaron + mi puesto (si paso mi
-- token). Con el juego cerrado, también mis respuestas con la correcta de
-- cada pregunta.
create or replace function public.ranking_juego(p_event_id uuid, p_token uuid default null)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_game trivia_games;
  v_top json;
  v_me json;
  v_review json;
  v_attempt trivia_attempts;
begin
  select * into v_game from trivia_games where event_id = p_event_id;
  if v_game.id is null then
    return null;
  end if;

  -- rank(): dos con mismo puntaje y mismo tiempo comparten el puesto.
  with ranking as (
    select a.token, a.player_name, a.correct_count, a.duration_ms,
           rank() over (order by a.correct_count desc, a.duration_ms asc) as position
    from trivia_attempts a
    where a.game_id = v_game.id and a.submitted_at is not null
  )
  select
    (select coalesce(json_agg(json_build_object(
       'name', r.player_name,
       'correct', r.correct_count,
       'duration_ms', r.duration_ms,
       'position', r.position,
       'me', p_token is not null and r.token = p_token
     ) order by r.position, r.duration_ms), '[]'::json)
     from (select * from ranking order by position, duration_ms limit 10) r),
    (select json_build_object(
       'name', r.player_name,
       'correct', r.correct_count,
       'duration_ms', r.duration_ms,
       'position', r.position
     ) from ranking r where p_token is not null and r.token = p_token)
  into v_top, v_me;

  if p_token is not null then
    if v_game.status = 'cerrado' then
      select * into v_attempt from trivia_attempts where token = p_token and game_id = v_game.id;
      if v_attempt.id is not null then
        select coalesce(json_agg(json_build_object(
          'question', q.question,
          'options', q.options,
          'correct_index', q.correct_index,
          'chosen', case when jsonb_typeof(v_attempt.answers -> q.id::text) = 'number'
                         then (v_attempt.answers ->> q.id::text)::int end
        ) order by q.position, q.created_at), '[]'::json)
        into v_review
        from trivia_questions q
        where q.game_id = v_game.id;
      end if;
    end if;
  end if;

  return json_build_object(
    'status', v_game.status,
    'title', v_game.title,
    'total', (select count(*) from trivia_questions where game_id = v_game.id),
    'players', (select count(*) from trivia_attempts where game_id = v_game.id and submitted_at is not null),
    'top', v_top,
    'me', v_me,
    'review', v_review
  );
end;
$$;

grant execute on function public.ranking_juego(uuid, uuid) to anon, authenticated;


-- Trivia: verde/rojo al responder y «Ver mis respuestas» (ver migrations/20261012_trivia_feedback.sql).
-- Cambia el tipo de retorno (boolean → json): hay que borrarla antes.
drop function if exists public.responder_pregunta(uuid, uuid, int);

create or replace function public.responder_pregunta(p_token uuid, p_question_id uuid, p_option int)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_game trivia_games;
  v_question trivia_questions;
begin
  select * into v_attempt from trivia_attempts where token = p_token for update;
  if v_attempt.id is null then
    raise exception 'Intento no encontrado';
  end if;
  select * into v_game from trivia_games where id = v_attempt.game_id;

  select * into v_question from trivia_questions
  where id = p_question_id and game_id = v_game.id;
  if v_question.id is null or p_option is null or p_option < 0 or p_option >= jsonb_array_length(v_question.options) then
    raise exception 'Respuesta inválida';
  end if;

  -- Ya respondida: no se cambia. Devolvemos el resultado de la que quedó.
  if v_attempt.answers ? p_question_id::text then
    return json_build_object(
      'ok', true,
      'locked', true,
      'option', (v_attempt.answers ->> p_question_id::text)::int,
      'correct', (v_attempt.answers ->> p_question_id::text)::int = v_question.correct_index
    );
  end if;

  -- Fuera de tiempo, ya enviado o juego cerrado: no se guarda.
  if v_attempt.submitted_at is not null
     or v_game.status <> 'abierto'
     or now() > v_attempt.started_at + make_interval(secs => v_game.time_limit_seconds + 15) then
    return json_build_object('ok', false);
  end if;

  update trivia_attempts
  set answers = answers || jsonb_build_object(p_question_id::text, p_option)
  where id = v_attempt.id;

  return json_build_object('ok', true, 'correct', p_option = v_question.correct_index);
end;
$$;

grant execute on function public.responder_pregunta(uuid, uuid, int) to anon, authenticated;

-- Lo guardado gana: `p_answers || answers` (a igual clave queda la de la
-- derecha, o sea la que ya estaba en la base).
create or replace function public.enviar_juego(p_token uuid, p_answers jsonb default null)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_game trivia_games;
begin
  select * into v_attempt from trivia_attempts where token = p_token;
  if v_attempt.id is null then
    raise exception 'Intento no encontrado';
  end if;
  select * into v_game from trivia_games where id = v_attempt.game_id;

  if v_attempt.submitted_at is null then
    if v_game.status = 'abierto'
       and now() <= v_attempt.started_at + make_interval(secs => v_game.time_limit_seconds + 15)
       and jsonb_typeof(p_answers) = 'object' then
      update trivia_attempts
      set answers = p_answers || answers
      where id = v_attempt.id;
    end if;
    perform trivia_finalizar_intento(v_attempt.id, now());
  end if;

  select * into v_attempt from trivia_attempts where id = v_attempt.id;
  return json_build_object(
    'correct_count', v_attempt.correct_count,
    'total', (select count(*) from trivia_questions where game_id = v_game.id),
    'duration_ms', v_attempt.duration_ms
  );
end;
$$;

-- { "<id de la pregunta>": true | false } de lo ya respondido (uso interno).
create or replace function public.trivia_resultados(p_game_id uuid, p_answers jsonb)
returns json
language sql
stable
set search_path = public
as $$
  select coalesce(json_object_agg(q.id, (p_answers ->> q.id::text)::int = q.correct_index), '{}'::json)
  from public.trivia_questions q
  where q.game_id = p_game_id
    and jsonb_typeof(p_answers -> q.id::text) = 'number';
$$;

revoke execute on function public.trivia_resultados(uuid, jsonb) from public, anon, authenticated;

create or replace function public.mi_intento_juego(p_token uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_game trivia_games;
  v_playing boolean;
begin
  select * into v_attempt from trivia_attempts where token = p_token;
  if v_attempt.id is null then
    return null;
  end if;
  select * into v_game from trivia_games where id = v_attempt.game_id;

  v_playing := v_attempt.submitted_at is null and v_game.status = 'abierto';

  return json_build_object(
    'player_name', v_attempt.player_name,
    'started_at', v_attempt.started_at,
    'submitted_at', v_attempt.submitted_at,
    'server_now', now(),
    'time_limit_seconds', v_game.time_limit_seconds,
    'answers', case when v_playing then v_attempt.answers end,
    'results', case when v_playing then trivia_resultados(v_game.id, v_attempt.answers) end,
    'questions', case when v_playing then trivia_preguntas_publicas(v_game.id) end
  );
end;
$$;

create or replace function public.ranking_juego(p_event_id uuid, p_token uuid default null)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_game trivia_games;
  v_top json;
  v_me json;
  v_review json;
  v_attempt trivia_attempts;
  v_closed boolean;
begin
  select * into v_game from trivia_games where event_id = p_event_id;
  if v_game.id is null then
    return null;
  end if;
  v_closed := v_game.status = 'cerrado';

  -- rank(): dos con mismo puntaje y mismo tiempo comparten el puesto.
  with ranking as (
    select a.token, a.player_name, a.correct_count, a.duration_ms,
           rank() over (order by a.correct_count desc, a.duration_ms asc) as position
    from trivia_attempts a
    where a.game_id = v_game.id and a.submitted_at is not null
  )
  select
    (select coalesce(json_agg(json_build_object(
       'name', r.player_name,
       'correct', r.correct_count,
       'duration_ms', r.duration_ms,
       'position', r.position,
       'me', p_token is not null and r.token = p_token
     ) order by r.position, r.duration_ms), '[]'::json)
     from (select * from ranking order by position, duration_ms limit 10) r),
    (select json_build_object(
       'name', r.player_name,
       'correct', r.correct_count,
       'duration_ms', r.duration_ms,
       'position', r.position
     ) from ranking r where p_token is not null and r.token = p_token)
  into v_top, v_me;

  -- Mis respuestas, solo si ya envié. La correcta, solo con el juego cerrado.
  if p_token is not null then
    select * into v_attempt from trivia_attempts
    where token = p_token and game_id = v_game.id and submitted_at is not null;
    if v_attempt.id is not null then
      select coalesce(json_agg(json_build_object(
        'question', q.question,
        'options', q.options,
        'chosen', a.chosen,
        'is_correct', a.chosen = q.correct_index,
        'correct_index', case when v_closed then q.correct_index end
      ) order by q.position, q.created_at), '[]'::json)
      into v_review
      from trivia_questions q
      cross join lateral (
        select case when jsonb_typeof(v_attempt.answers -> q.id::text) = 'number'
                    then (v_attempt.answers ->> q.id::text)::int end as chosen
      ) a
      where q.game_id = v_game.id;
    end if;
  end if;

  return json_build_object(
    'status', v_game.status,
    'title', v_game.title,
    'total', (select count(*) from trivia_questions where game_id = v_game.id),
    'players', (select count(*) from trivia_attempts where game_id = v_game.id and submitted_at is not null),
    'top', v_top,
    'me', v_me,
    'review', v_review
  );
end;
$$;

-- ============================================================
-- Recepción: el personal del salón marca quién llegó
--
-- - El dueño del evento (o el superadmin) crea usuarios de recepción desde
--   el panel: usuario + contraseña, sin mail real (ver src/lib/staff.js).
--   La cuenta se crea en la base ya confirmada (crear_recepcionista; ver
--   migrations/20261012_recepcion_cuentas.sql). Cada usuario queda atado al
--   evento en `event_staff`.
-- - Recepción entra a /recepcion: busca al invitado, ve su mesa y lo marca
--   como llegado (`guests.arrived_at`). Todo vía RPC: el personal no tiene
--   permisos directos sobre las tablas.
-- - Recepción ve también a los invitados sorpresa (esa gente llega igual), y
--   el dueño también, pero solo en Recepción: el día del evento esa pantalla
--   la mira la familia (ver migrations/20261012_recepcion_sorpresas.sql).
-- ============================================================

-- 1) Llegadas
alter table public.guests
  add column if not exists arrived_at timestamptz,
  add column if not exists arrived_by uuid references auth.users(id) on delete set null;

-- 2) Personal de recepción de cada evento
create table if not exists public.event_staff (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  username text not null,
  display_name text not null,
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create index if not exists event_staff_user_id_idx on public.event_staff (user_id);

-- El dueño ve a su personal; las filas (y las cuentas) se crean y se borran
-- con crear_recepcionista / quitar_recepcionista.
grant select, delete on public.event_staff to authenticated;
alter table public.event_staff enable row level security;

drop policy if exists "admin ve y borra el personal de su evento" on public.event_staff;
create policy "admin ve y borra el personal de su evento"
  on public.event_staff for all
  using (exists (
    select 1 from public.events
    where events.id = event_staff.event_id
    and events.owner_user_id = auth.uid()
  ));

drop policy if exists "superadmin gestiona personal" on public.event_staff;
create policy "superadmin gestiona personal"
  on public.event_staff for all
  using (exists (select 1 from public.superadmins s where s.user_id = auth.uid()));

drop policy if exists "cada uno ve sus propios eventos de recepcion" on public.event_staff;
create policy "cada uno ve sus propios eventos de recepcion"
  on public.event_staff for select
  using (user_id = auth.uid());

-- ============================================================
-- Permisos (uso interno)
-- ============================================================

-- ¿Puedo manejar este evento? Dueño o superadmin.
create or replace function public.puede_administrar_evento(p_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.events where id = p_event_id and owner_user_id = auth.uid())
      or exists (select 1 from public.superadmins where user_id = auth.uid());
$$;

-- Cómo entra cada uno a recepción: 'personal', 'superadmin' o 'duenio';
-- null = no puede. (Al principio el dueño no veía las sorpresas; desde
-- 20261012_recepcion_sorpresas.sql los tres ven lo mismo.)
create or replace function public.acceso_recepcion(p_event_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when exists (select 1 from public.superadmins where user_id = auth.uid()) then 'superadmin'
    when exists (select 1 from public.event_staff where event_id = p_event_id and user_id = auth.uid()) then 'personal'
    when exists (select 1 from public.events where id = p_event_id and owner_user_id = auth.uid()) then 'duenio'
  end;
$$;

revoke execute on function public.puede_administrar_evento(uuid) from public, anon;
revoke execute on function public.acceso_recepcion(uuid) from public, anon;
grant execute on function public.puede_administrar_evento(uuid) to authenticated;
grant execute on function public.acceso_recepcion(uuid) to authenticated;

-- ============================================================
-- RPC del panel (dueño / superadmin)
-- ============================================================

-- Crea la cuenta de recepción ya confirmada, sin mandar mails (el usuario
-- se guarda como <usuario>@recepcion.tizdigital.com, ver src/lib/staff.js).
create or replace function public.crear_recepcionista(
  p_event_id uuid,
  p_username text,
  p_password text,
  p_display_name text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text := lower(trim(coalesce(p_username, '')));
  v_email text := lower(trim(coalesce(p_username, ''))) || '@recepcion.tizdigital.com';
  v_name text := left(trim(coalesce(p_display_name, '')), 60);
  v_user_id uuid := gen_random_uuid();
  v_row event_staff;
begin
  if not puede_administrar_evento(p_event_id) then
    raise exception 'No autorizado';
  end if;
  if v_name = '' then
    raise exception 'Escribí el nombre de la persona.';
  end if;
  if v_username !~ '^[a-z0-9.-]{3,30}$' then
    raise exception 'Usuario inválido';
  end if;
  if length(coalesce(p_password, '')) < 6 then
    raise exception 'La contraseña tiene que tener al menos 6 caracteres.';
  end if;
  if exists (select 1 from auth.users where email = v_email) then
    raise exception 'Ese usuario ya existe';
  end if;

  -- Los tokens van en '' (no null): con null, el login de Supabase falla.
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated',
    v_email, extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    jsonb_build_object('role', 'recepcion', 'display_name', v_name),
    now(), now(), '', '', '', ''
  );

  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (
    gen_random_uuid(), v_user_id, v_user_id::text,
    jsonb_build_object('sub', v_user_id::text, 'email', v_email, 'email_verified', true),
    'email', now(), now(), now()
  );

  insert into event_staff (event_id, user_id, username, display_name)
  values (p_event_id, v_user_id, v_username, v_name)
  returning * into v_row;

  return row_to_json(v_row);
end;
$$;

grant execute on function public.crear_recepcionista(uuid, text, text, text) to authenticated;

-- Quitar: saca a la persona del evento y, si no trabaja en otro, borra la cuenta.
create or replace function public.quitar_recepcionista(p_staff_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row event_staff;
begin
  select * into v_row from event_staff where id = p_staff_id;
  if v_row.id is null or not puede_administrar_evento(v_row.event_id) then
    raise exception 'No autorizado';
  end if;

  delete from event_staff where id = p_staff_id;

  delete from auth.users u
  where u.id = v_row.user_id
    and u.email like '%@recepcion.tizdigital.com'
    and not exists (select 1 from event_staff s where s.user_id = u.id);
end;
$$;

grant execute on function public.quitar_recepcionista(uuid) to authenticated;

-- Cambiar la contraseña (y cerrar las sesiones abiertas con la vieja).
create or replace function public.cambiar_clave_recepcionista(p_staff_id uuid, p_password text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row event_staff;
begin
  select * into v_row from event_staff where id = p_staff_id;
  if v_row.id is null or not puede_administrar_evento(v_row.event_id) then
    raise exception 'No autorizado';
  end if;
  if length(coalesce(p_password, '')) < 6 then
    raise exception 'La contraseña tiene que tener al menos 6 caracteres.';
  end if;

  update auth.users
  set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
      updated_at = now()
  where id = v_row.user_id
    and email like '%@recepcion.tizdigital.com';

  delete from auth.sessions where user_id = v_row.user_id;
end;
$$;

grant execute on function public.cambiar_clave_recepcionista(uuid, text) to authenticated;


-- Borra todas las llegadas del evento (para después de probar). También las
-- de las sorpresas: el dueño no las ve, pero borrarlas no delata a nadie.
create or replace function public.reiniciar_llegadas(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not puede_administrar_evento(p_event_id) then
    raise exception 'No autorizado';
  end if;

  update guests g set arrived_at = null, arrived_by = null
  from invitation_groups ig
  where ig.id = g.group_id
    and ig.event_id = p_event_id
    and g.arrived_at is not null;
end;
$$;

grant execute on function public.reiniciar_llegadas(uuid) to authenticated;

-- ============================================================
-- RPC de recepción
-- ============================================================

-- Los eventos en los que trabajo (para la pantalla de inicio de recepción).
create or replace function public.mis_eventos_recepcion()
returns json
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(json_agg(json_build_object(
    'id', e.id,
    'name', e.name,
    'event_date', e.event_date
  ) order by e.event_date nulls last), '[]'::json)
  from public.event_staff s
  join public.events e on e.id = s.event_id
  where s.user_id = auth.uid();
$$;

grant execute on function public.mis_eventos_recepcion() to authenticated;

-- La lista de la entrada: los que confirmaron, con su invitación, su mesa y
-- si ya llegaron. Sorpresas incluidas, también para el dueño (ver
-- migrations/20261012_recepcion_sorpresas.sql).
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

grant execute on function public.recepcion_lista(uuid) to authenticated;

-- Marca (o desmarca) la llegada de una o varias personas. Si ya estaba
-- marcada, se queda con la primera hora (dos recepcionistas a la vez).
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

grant execute on function public.recepcion_marcar(uuid, uuid[], boolean) to authenticated;

-- ============================================================
-- Invitación de ejemplo para la landing (/demo/invitacion)
-- Ver migrations/20261013_invitacion_demo.sql
--
-- La portada de la landing muestra una invitación real dentro de un
-- celular. Se elige con `events.landing_demo` (hoy: la de Antonella, con
-- su permiso, 2026-10-13). invitacion_demo() devuelve lo mismo que
-- obtener_invitacion, pero:
-- - con una familia de ejemplo (no la de ningún invitado real),
-- - sin registrar visitas (no ensucia «entró hoy a las…»),
-- - y la página la muestra en modo vista previa: no se puede confirmar.
-- ============================================================

alter table public.events
  add column if not exists landing_demo boolean not null default false;


create or replace function public.invitacion_demo()
returns json
language sql
stable
security definer
set search_path = public
as $$
  select (jsonb_build_object(
    'family_name', 'Familia Romero',
    'allowed_guests', 3,
    'status', 'pending',
    'named_by_host', true,
    'event_name', e.name,
    'plan', e.plan,
    'template', e.template,
    'monogram', e.monogram,
    'primary_color', e.primary_color,
    'envelope_text', e.envelope_text,
    'envelope_color', e.envelope_color,
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
    'guests', jsonb_build_array(
      jsonb_build_object('id', '00000000-0000-0000-0000-00000000d001', 'full_name', 'Lucas Romero', 'rsvp_status', 'invited'),
      jsonb_build_object('id', '00000000-0000-0000-0000-00000000d002', 'full_name', 'Ana Romero', 'rsvp_status', 'invited'),
      jsonb_build_object('id', '00000000-0000-0000-0000-00000000d003', 'full_name', 'Mía Romero', 'rsvp_status', 'invited')
    )
  ) || jsonb_build_object(
    'event_type', e.event_type,
    'accent_color', e.accent_color,
    'theme_mode', e.theme_mode,
    'tono', e.tono,
    'date_style', e.date_style,
    'logo', e.logo,
    'sponsors', e.sponsors,
    'logo_white', e.logo_white,
    'sponsors_white', e.sponsors_white
  ) || jsonb_build_object(
    'agenda', e.agenda,
    'access_info', e.access_info,
    'contact_name', e.contact_name,
    'contact_email', e.contact_email,
    'contact_phone', e.contact_phone,
    'social_links', e.social_links,
    'rsvp_fields', e.rsvp_fields,
    'bilingual', e.bilingual,
    'texts_en', e.texts_en
  ))::json
  from public.events e
  where e.landing_demo
  order by e.created_at
  limit 1;
$$;

grant execute on function public.invitacion_demo() to anon, authenticated;

-- ============================================================
-- Planes: gratis / invitacion / plus / premium
-- Ver migrations/20261013_planes.sql
--
-- Decidido el 2026-10-13 (ver PROGRESO.md y la landing):
-- - gratis: todas las funciones, para armar y probar, con límites para que
--   no se pueda mandar a todos sin pagar:
--     · hasta 5 invitaciones (links de familia),
--     · la invitación lleva un cartel «Invitación de prueba» (en la página),
--     · el link se cierra a las 15 visitas o a las 24 h desde la primera
--       apertura (lo que pase primero). La vista previa del panel sigue andando.
-- - invitacion: solo la invitación, se confirma por WhatsApp.
-- - plus: + panel de confirmaciones, mesas y lista de la entrada.
-- - premium: + canciones, fotos, trivia y recepción.
-- Qué incluye cada plan está en plan_incluye() (y en src/lib/plans.js).
--
-- Además: el plan (y landing_demo) solo los cambia el superadmin. Antes la
-- policy del dueño le dejaba editar su evento entero, plan incluido.
-- ============================================================

-- 1) Los planes nuevos. Los eventos de antes pasan a premium (son los
--    clientes que ya teníamos); los creados desde la landing, a gratis.
--    Solo la primera vez (mientras existen los planes viejos 'basico' / 'plus'):
--    así correrla de nuevo no toca los planes nuevos.
do $$
declare
  c record;
  v_viejos boolean;
begin
  select exists (
    select 1 from pg_constraint
    where conrelid = 'public.events'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%basico%'
  ) into v_viejos;

  for c in
    select conname from pg_constraint
    where conrelid = 'public.events'::regclass and contype = 'c' and pg_get_constraintdef(oid) ilike '%plan%'
  loop
    execute format('alter table public.events drop constraint %I', c.conname);
  end loop;

  if v_viejos then
    update public.events
    set plan = case when created_at < '2026-10-13 06:00:00+00' then 'premium' else 'gratis' end;
    -- Los XV de Antonella, siempre con el plan completo.
    update public.events set plan = 'premium' where id = '1fe06bdb-7905-48dc-ae51-f09ecc5b612a';
  end if;
end;
$$;

alter table public.events alter column plan set default 'gratis';
alter table public.events add constraint events_plan_check check (plan in ('gratis', 'invitacion', 'plus', 'premium'));

-- 2) Qué incluye cada plan. El gratis es «el full» con límites.
create or replace function public.plan_incluye(p_plan text, p_funcion text)
returns boolean
language sql
immutable
as $$
  select case p_funcion
    when 'invitados_ilimitados' then p_plan in ('invitacion', 'plus', 'premium')
    when 'panel' then p_plan in ('gratis', 'plus', 'premium')
    when 'mesas' then p_plan in ('gratis', 'plus', 'premium')
    when 'lista_entrada' then p_plan in ('gratis', 'plus', 'premium')
    when 'canciones' then p_plan in ('gratis', 'premium')
    when 'fotos' then p_plan in ('gratis', 'premium')
    when 'trivia' then p_plan in ('gratis', 'premium')
    when 'recepcion' then p_plan in ('gratis', 'premium')
    else false
  end;
$$;

grant execute on function public.plan_incluye(text, text) to anon, authenticated;

-- 3) Contadores de la prueba gratis, en el evento: solo suben. Si se
--    contaran las filas de invitation_groups / invitation_views, borrar una
--    invitación (y sus visitas) devolvería lugares y visitas a la prueba.
alter table public.events
  add column if not exists prueba_invitaciones int not null default 0,
  add column if not exists prueba_visitas int not null default 0,
  add column if not exists prueba_primera_visita timestamptz;

-- 4) El plan, landing_demo y los contadores solo los cambian el superadmin,
--    las funciones de la base (security definer: current_user es el dueño
--    de la función, no 'authenticated') o el SQL Editor. Un evento nuevo
--    arranca siempre gratis y con los contadores en cero.
create or replace function public.events_proteger_plan()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user not in ('authenticated', 'anon') or soy_superadmin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.plan := 'gratis';
    new.landing_demo := false;
    new.prueba_invitaciones := 0;
    new.prueba_visitas := 0;
    new.prueba_primera_visita := null;
  elsif new.plan is distinct from old.plan
     or new.landing_demo is distinct from old.landing_demo
     or new.prueba_invitaciones is distinct from old.prueba_invitaciones
     or new.prueba_visitas is distinct from old.prueba_visitas
     or new.prueba_primera_visita is distinct from old.prueba_primera_visita then
    raise exception 'El plan lo cambia TizDigital.';
  end if;
  return new;
end;
$$;

drop trigger if exists events_proteger_plan on public.events;
create trigger events_proteger_plan
  before insert or update on public.events
  for each row execute function public.events_proteger_plan();

-- 5) Gratis: hasta 5 invitaciones creadas (borrar una no devuelve el lugar).
create or replace function public.invitaciones_tope_gratis()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan text;
  v_creadas int;
begin
  select plan, prueba_invitaciones into v_plan, v_creadas from events where id = new.event_id;
  if v_plan = 'gratis' then
    if v_creadas >= 5 and not exists (select 1 from superadmins where user_id = auth.uid()) then
      raise exception 'La prueba gratis permite hasta 5 invitaciones. Elegí un plan para invitar a todos.';
    end if;
    update events set prueba_invitaciones = prueba_invitaciones + 1 where id = new.event_id;
  end if;
  return new;
end;
$$;

drop trigger if exists invitaciones_tope_gratis on public.invitation_groups;
create trigger invitaciones_tope_gratis
  before insert on public.invitation_groups
  for each row execute function public.invitaciones_tope_gratis();

-- 6) Gratis: el link se cierra a las 15 visitas o a las 24 h desde la
--    primera apertura (contadores del evento). Cerrada, la invitación
--    devuelve solo lo necesario para una pantalla linda («todavía no está
--    publicada») y no suma visitas.
create or replace function public.obtener_invitacion(p_slug text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  result json;
  v_group_id uuid;
  v_event_id uuid;
  v_plan text;
  v_vistas int;
  v_primera timestamptz;
begin
  select ig.id, e.id, e.plan, (jsonb_build_object(
    'family_name', ig.family_name,
    'allowed_guests', ig.allowed_guests,
    'status', ig.status,
    'named_by_host', ig.named_by_host,
    'event_name', e.name,
    'plan', e.plan,
    'template', e.template,
    'monogram', e.monogram,
    'primary_color', e.primary_color,
    'envelope_text', e.envelope_text,
    'envelope_color', e.envelope_color,
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
      select jsonb_agg(jsonb_build_object(
        'id', g.id,
        'full_name', g.full_name,
        'rsvp_status', g.rsvp_status,
        'company', g.company,
        'job_title', g.job_title,
        'email', g.email,
        'phone', g.phone,
        'dietary', g.dietary
      ) order by g.created_at)
      from guests g
      where g.group_id = ig.id
    ), '[]'::jsonb)
  ) || jsonb_build_object(
    'event_type', e.event_type,
    'accent_color', e.accent_color,
    'theme_mode', e.theme_mode,
    'tono', e.tono,
    'date_style', e.date_style,
    'logo', e.logo,
    'sponsors', e.sponsors,
    'logo_white', e.logo_white,
    'sponsors_white', e.sponsors_white
  ) || jsonb_build_object(
    'agenda', e.agenda,
    'access_info', e.access_info,
    'contact_name', e.contact_name,
    'contact_email', e.contact_email,
    'contact_phone', e.contact_phone,
    'social_links', e.social_links,
    'rsvp_fields', e.rsvp_fields,
    'bilingual', e.bilingual,
    'texts_en', e.texts_en
  ))::json
  into v_group_id, v_event_id, v_plan, result
  from invitation_groups ig
  join events e on e.id = ig.event_id
  where ig.slug = p_slug;

  if result is null then
    raise exception 'Invitación no encontrada';
  end if;

  if v_plan = 'gratis' then
    select prueba_visitas, prueba_primera_visita into v_vistas, v_primera from events where id = v_event_id;

    if v_vistas >= 15 or (v_primera is not null and now() > v_primera + interval '24 hours') then
      return (
        select json_build_object(
          'locked', true,
          'event_name', e.name,
          'hero_title', e.hero_title,
          'primary_color', e.primary_color,
          'bg_color', e.bg_color
        )
        from events e where e.id = v_event_id
      );
    end if;

    update events
    set prueba_visitas = prueba_visitas + 1,
        prueba_primera_visita = coalesce(prueba_primera_visita, now())
    where id = v_event_id;
  end if;

  insert into invitation_views (group_id) values (v_group_id);

  return result;
end;
$$;

grant execute on function public.obtener_invitacion(text) to anon, authenticated;

-- 7) Canciones: ahora vienen con premium (y con la prueba gratis).
create or replace function public.agregar_cancion_solicitada(
  p_slug text,
  p_song_title text,
  p_artist text,
  p_youtube_video_id text,
  p_requested_by text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_id uuid;
  v_group_id uuid;
  v_plan text;
begin
  select e.id, ig.id, e.plan into v_event_id, v_group_id, v_plan
  from invitation_groups ig
  join events e on e.id = ig.event_id
  where ig.slug = p_slug;

  if v_event_id is null then
    raise exception 'Invitación no encontrada';
  end if;

  if not plan_incluye(v_plan, 'canciones') then
    raise exception 'Esta invitación no tiene habilitado el pedido de canciones';
  end if;

  if trim(coalesce(p_song_title, '')) = '' then
    raise exception 'Falta el nombre de la canción';
  end if;

  if trim(coalesce(p_requested_by, '')) = '' then
    raise exception 'Falta tu nombre';
  end if;

  insert into song_requests (event_id, group_id, song_title, artist, youtube_video_id, requested_by)
  values (
    v_event_id,
    v_group_id,
    left(trim(p_song_title), 150),
    texto_invitado(p_artist, 150),
    texto_invitado(p_youtube_video_id, 20),
    left(trim(p_requested_by), 60)
  );

  return json_build_object('ok', true);
end;
$$;

-- ============================================================
-- Seguridad: lo que encontró la revisión del 2026-10-13
-- Ver migrations/20261013_seguridad.sql
-- (después de 20261013_planes.sql: usa plan_incluye y soy_superadmin)
--
-- 1) event-photos: cualquiera (sin cuenta) podía LISTAR el bucket y bajar
--    las fotos de las invitaciones de todos los clientes (las carpetas son
--    los ids de sus cuentas). Las fotos se siguen viendo por su URL pública
--    (el bucket es público); listar queda solo para el dueño de la carpeta
--    y el superadmin (que lista al borrar un evento).
-- 2) guest-uploads: cualquiera podía subir imágenes a cualquier ruta del
--    bucket (llenar el espacio o usarlo de hosting). Ahora solo dentro de la
--    carpeta de un evento que tenga las fotos de invitados habilitadas.
-- 3) agregar_foto_invitados aceptaba cualquier URL: se podía meter en la
--    galería de una fiesta una imagen de otro sitio. Ahora arma la URL ella
--    misma, a partir de un archivo que tiene que existir en la carpeta del
--    evento, y no registra dos veces el mismo archivo.
-- 4) Topes de largo en los nombres que se confirman desde la invitación.
-- ============================================================

-- 1) Listar event-photos: solo el dueño de la carpeta o el superadmin.
drop policy if exists "event-photos public read" on storage.objects;
drop policy if exists "event-photos dueño o superadmin listan" on storage.objects;
create policy "event-photos dueño o superadmin listan" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'event-photos'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.soy_superadmin())
  );

-- 2) Subir a guest-uploads: solo a la carpeta de un evento con fotos habilitadas.
--    (La policy corre como el invitado, que no puede leer events: por eso la función.)
create or replace function public.fotos_invitados_habilitadas(p_carpeta text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from events
    where id::text = p_carpeta and plan_incluye(plan, 'fotos')
  );
$$;

grant execute on function public.fotos_invitados_habilitadas(text) to anon, authenticated;

drop policy if exists "guest-uploads anyone insert" on storage.objects;
drop policy if exists "guest-uploads solo en eventos con fotos" on storage.objects;
create policy "guest-uploads solo en eventos con fotos" on storage.objects
  for insert to anon, authenticated
  with check (
    bucket_id = 'guest-uploads'
    and public.fotos_invitados_habilitadas((storage.foldername(name))[1])
  );

-- 3) Registrar una foto subida: la URL la arma la base (no la manda el
--    navegador) y el archivo tiene que existir en la carpeta del evento.
--    p_url queda en la firma para no romper la app, pero se ignora.
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
  v_plan text;
begin
  select plan into v_plan from events where id = p_event_id;
  if v_plan is null then
    raise exception 'Evento no encontrado';
  end if;
  if not plan_incluye(v_plan, 'fotos') then
    raise exception 'Este evento no tiene habilitadas las fotos de invitados';
  end if;

  if p_path is null or p_path not like p_event_id::text || '/%' or p_path like '%..%'
     or not exists (select 1 from storage.objects where bucket_id = 'guest-uploads' and name = p_path) then
    raise exception 'Foto no encontrada';
  end if;
  if exists (select 1 from event_photos where path = p_path) then
    raise exception 'Esa foto ya está en la galería';
  end if;

  select count(*) into v_count from event_photos where event_id = p_event_id;
  if v_count >= v_limit then
    raise exception 'Se llegó al máximo de % fotos para este evento.', v_limit;
  end if;

  insert into event_photos (event_id, url, path, uploader_name)
  values (
    p_event_id,
    'https://yxcwotrrcekoldmkuxps.supabase.co/storage/v1/object/public/guest-uploads/' || p_path,
    p_path,
    texto_invitado(p_uploader_name, 40)
  );

  return json_build_object('ok', true, 'count', v_count + 1, 'limit', v_limit);
end;
$$;

grant execute on function public.agregar_foto_invitados(uuid, text, text, text) to anon, authenticated;

-- 4) Confirmación con nombres escritos por la familia: tope de 80 caracteres por nombre.
create or replace function public.confirmar_asistencia(
  p_slug text,
  p_guest_names text[],
  p_detalles jsonb default '[]'::jsonb
)
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

  insert into guests (group_id, full_name, rsvp_status, company, job_title, email, phone, dietary)
  select
    v_group.id,
    left(trim(n.name), 80),
    'attending',
    public.texto_invitado(d.value ->> 'company'),
    public.texto_invitado(d.value ->> 'job_title'),
    public.texto_invitado(d.value ->> 'email'),
    public.texto_invitado(d.value ->> 'phone', 60),
    public.texto_invitado(d.value ->> 'dietary', 300)
  from unnest(p_guest_names) with ordinality as n(name, i)
  left join lateral (
    select p_detalles -> (n.i::int - 1) as value
    where jsonb_typeof(p_detalles) = 'array'
  ) d on true
  where trim(n.name) <> '';

  update invitation_groups set status = 'confirmed' where id = v_group.id;

  return json_build_object('status', 'confirmed');
end;
$$;

grant execute on function public.confirmar_asistencia(text, text[], jsonb) to anon, authenticated;
