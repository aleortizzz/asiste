-- ============================================================
-- Invitación de ejemplo para la landing (/demo/invitacion)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
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

update public.events set landing_demo = true where id = '1fe06bdb-7905-48dc-ae51-f09ecc5b612a';

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
