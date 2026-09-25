-- ============================================================
-- Color principal (acento) por evento
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Hasta ahora cada plantilla (Clásica/Partiful/Craft) hardcodeaba su propio
-- color de acento (rosa, negro, verde lima). Pasan a ser solo diseño y
-- tipografía — el color (fondo + acento) lo elige el host, igual para
-- cualquier plantilla. Ver useInvitationLogic.js (primaryColor,
-- envelopePalette) para cómo se deriva todo lo demás a partir de esto.
-- ============================================================

alter table events
  add column if not exists primary_color text not null default '#9f1239';

-- Reemplaza obtener_invitacion para sumar 'primary_color' al payload público.
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
    'plan', e.plan,
    'template', e.template,
    'monogram', e.monogram,
    'hero_kicker', e.hero_kicker,
    'hero_title', e.hero_title,
    'hero_subtitle', e.hero_subtitle,
    'intro_text', e.intro_text,
    'closing_text', e.closing_text,
    'bg_color', e.bg_color,
    'primary_color', e.primary_color,
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
