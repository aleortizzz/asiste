-- ============================================================
-- Vista previa de los links al compartirlos (WhatsApp, Telegram, etc.)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
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
    )
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
