-- ============================================================
-- Secciones empresariales (plantilla Ejecutiva)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Solo AGREGA columnas, vacías por defecto. Cada sección se muestra si tiene
-- datos y se puede apagar desde el editor (hidden_sections: 'agenda',
-- 'acceso', 'contacto', 'redes').
--
--   agenda         programa del evento: [{ time: 'HH:MM', title, detail }, …]
--   access_info    cómo llegar: estacionamiento, acceso, transporte.
--   contact_name   contacto del organizador para consultas.
--   contact_email
--   contact_phone  WhatsApp, con código de país.
--   social_links   { linkedin, instagram, web } (links o @usuario).
-- ============================================================

alter table public.events add column if not exists agenda jsonb not null default '[]'::jsonb;
alter table public.events add column if not exists access_info text;
alter table public.events add column if not exists contact_name text;
alter table public.events add column if not exists contact_email text;
alter table public.events add column if not exists contact_phone text;
alter table public.events add column if not exists social_links jsonb not null default '{}'::jsonb;

-- La invitación pública recibe los datos nuevos (igual que antes + estos).
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
        'rsvp_status', g.rsvp_status
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
    'social_links', e.social_links
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
