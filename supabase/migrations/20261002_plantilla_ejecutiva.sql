-- ============================================================
-- Plantilla «Ejecutiva» (pensada para eventos empresariales)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Solo AGREGA: un valor nuevo para `template` y columnas nuevas con valores
-- por defecto. No cambia ni borra datos de los eventos que ya existen.
--
--   accent_color  color de los detalles (líneas finas, botón en modo oscuro).
--                 null = el de la plantilla (champagne).
--   theme_mode    'claro' (papel) u 'oscuro' (fondo del color principal).
--   tono          'vos' o 'usted': cómo le habla la invitación al invitado.
--   date_style    cómo se muestra la fecha en la portada: 'regresiva' (la
--                 cuenta regresiva de siempre), 'destacada' (el día grande)
--                 o 'discreta' (una línea + «Faltan N días»).
--   logo          logo de la empresa: [{ url, path }], igual que las fotos.
--   sponsors      logos de sponsors / co-organizadores: [{ url, path }, …].
-- ============================================================

-- 1) Valor nuevo para la plantilla. Un solo ALTER: sacar la regla vieja y
--    poner la nueva es atómico.
alter table public.events
  drop constraint if exists events_template_check,
  add constraint events_template_check
    check (template in ('clasico', 'partiful', 'craft', 'craft-v2', 'ejecutiva'));

-- 2) Columnas nuevas.
alter table public.events add column if not exists accent_color text;
alter table public.events add column if not exists theme_mode text not null default 'claro';
alter table public.events add column if not exists tono text not null default 'vos';
alter table public.events add column if not exists date_style text not null default 'regresiva';
alter table public.events add column if not exists logo jsonb not null default '[]'::jsonb;
alter table public.events add column if not exists sponsors jsonb not null default '[]'::jsonb;

alter table public.events
  drop constraint if exists events_theme_mode_check,
  add constraint events_theme_mode_check check (theme_mode in ('claro', 'oscuro')),
  drop constraint if exists events_tono_check,
  add constraint events_tono_check check (tono in ('vos', 'usted')),
  drop constraint if exists events_date_style_check,
  add constraint events_date_style_check check (date_style in ('regresiva', 'destacada', 'discreta'));

-- 3) La invitación pública recibe los datos nuevos (y el tipo de evento).
--    Mismo contenido que antes + un segundo objeto unido con «||»: así no se
--    llega al tope de 100 argumentos de json_build_object a medida que se
--    suman campos. Misma firma, así que «create or replace» alcanza.
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
    'sponsors', e.sponsors
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
