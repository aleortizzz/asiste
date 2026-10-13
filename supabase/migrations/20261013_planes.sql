-- ============================================================
-- Planes: gratis / invitacion / plus / premium
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
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
