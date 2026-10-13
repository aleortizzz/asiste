-- ============================================================
-- Plan Invitación: un solo link para todos y confirmación por WhatsApp
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
-- (después de 20261013_planes_funciones.sql)
--
-- - events.link_slug: el link que elige el organizador (/i/<link>), único.
--   Comparte el espacio de /i/ con los links de familia (invitation_groups.slug),
--   así que tampoco puede coincidir con uno de esos.
-- - events.whatsapp_rsvp: el número donde le llegan las confirmaciones.
-- - obtener_invitacion_link(): la invitación pública por ese link (solo plan
--   Invitación). La confirmación es un mensaje de WhatsApp: no se guarda nada.
-- - El plan Invitación no tiene panel de confirmaciones: no puede crear
--   links de familia.
-- ============================================================

alter table public.events
  add column if not exists link_slug text,
  add column if not exists whatsapp_rsvp text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'events_link_slug_formato') then
    alter table public.events add constraint events_link_slug_formato
      check (link_slug is null or link_slug ~ '^[a-z0-9]([a-z0-9-]{1,38}[a-z0-9])$');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'events_whatsapp_formato') then
    alter table public.events add constraint events_whatsapp_formato
      check (whatsapp_rsvp is null or whatsapp_rsvp ~ '^[0-9]{10,15}$');
  end if;
end;
$$;

create unique index if not exists events_link_slug_key on public.events (link_slug) where link_slug is not null;

-- ¿Está libre ese link? (para avisar mientras el organizador lo escribe)
create or replace function public.link_disponible(p_link text, p_event_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(p_link, '') ~ '^[a-z0-9]([a-z0-9-]{1,38}[a-z0-9])$'
     and not exists (select 1 from events where link_slug = p_link and id is distinct from p_event_id)
     and not exists (select 1 from invitation_groups where slug = p_link);
$$;

revoke execute on function public.link_disponible(text, uuid) from public, anon;
grant execute on function public.link_disponible(text, uuid) to authenticated;

-- Que un link de evento y uno de familia nunca coincidan.
create or replace function public.events_link_unico()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.link_slug is not null and new.link_slug is distinct from old.link_slug
     and exists (select 1 from invitation_groups where slug = new.link_slug) then
    raise exception 'Ese link ya está en uso. Probá con otro.';
  end if;
  return new;
end;
$$;

drop trigger if exists events_link_unico on public.events;
create trigger events_link_unico
  before update on public.events
  for each row execute function public.events_link_unico();

-- Links de familia: no pueden coincidir con un link de evento, y el plan
-- Invitación no los tiene (no tiene panel de confirmaciones).
-- (Dos funciones: el choque de links mira los eventos de todos los clientes,
-- así que corre con permisos de la base; el plan, con los de quien llama.)
create or replace function public.grupos_link_unico()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from events where link_slug = new.slug) then
    raise exception 'Ese link ya está en uso.';
  end if;
  return new;
end;
$$;

drop trigger if exists grupos_link_unico on public.invitation_groups;
create trigger grupos_link_unico
  before insert on public.invitation_groups
  for each row execute function public.grupos_link_unico();

create or replace function public.grupos_exigir_panel()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform exigir_plan(new.event_id, 'panel');
  return new;
end;
$$;

drop trigger if exists grupos_exigir_panel on public.invitation_groups;
create trigger grupos_exigir_panel
  before insert on public.invitation_groups
  for each row execute function public.grupos_exigir_panel();

-- La invitación pública por el link del organizador (solo plan Invitación).
create or replace function public.obtener_invitacion_link(p_link text)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result json;
begin
  select (jsonb_build_object(
    'rsvp_mode', 'whatsapp',
    'whatsapp', e.whatsapp_rsvp,
    'family_name', null,
    'allowed_guests', 0,
    'status', 'pending',
    'named_by_host', false,
    'guests', '[]'::jsonb,
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
    'gift_alias', e.gift_alias
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
    'rsvp_fields', '[]'::jsonb,
    'bilingual', e.bilingual,
    'texts_en', e.texts_en
  ))::json
  into result
  from events e
  where e.link_slug = p_link and e.plan = 'invitacion';

  if result is null then
    raise exception 'Invitación no encontrada';
  end if;
  return result;
end;
$$;

grant execute on function public.obtener_invitacion_link(text) to anon, authenticated;

-- Vista previa al compartir (og.php): también por el link del organizador.
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
  from public.events e
  left join public.invitation_groups ig on ig.event_id = e.id and ig.slug = p_slug
  where ig.slug = p_slug or (e.link_slug = p_slug and e.plan = 'invitacion')
  limit 1;
$$;
