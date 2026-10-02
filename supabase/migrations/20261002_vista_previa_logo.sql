-- ============================================================
-- Vista previa de links (WhatsApp, etc.) con el logo de la empresa
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Misma función de solo lectura que arma la vista previa de /i/:slug (no
-- registra visitas), con datos nuevos para la plantilla Ejecutiva: el logo,
-- los colores, la hora y el lugar. Todo lo que devuelve ya se ve en la
-- invitación pública. Misma firma: «create or replace» alcanza.
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
