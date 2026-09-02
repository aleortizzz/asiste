-- ============================================================
-- Textos editables de la invitación pública
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Antes el hero de la invitación tenía "Te invito a mis / XV"
-- hardcodeado. Con esto, cada evento define sus propios textos
-- (sirve para XV, casamiento, cumpleaños, bautismo, lo que sea).
-- Todos opcionales: si quedan en null, la invitación usa un
-- texto por defecto genérico.
-- ============================================================

alter table events
  add column if not exists hero_kicker   text,  -- línea chica arriba del título ("Te invito a mis", "¡Nos casamos!")
  add column if not exists hero_title    text,  -- título grande en cursiva ("XV", "Ana & Luis", "50")
  add column if not exists hero_subtitle text,  -- línea bajo el título ("Antonella", "¡Te esperamos!")
  add column if not exists intro_text    text,  -- párrafo del saludo
  add column if not exists closing_text  text;  -- frase del cierre ("¡Los esperamos!")

-- La RPC pública tiene que devolver los campos nuevos.
create or replace function public.obtener_invitacion(p_slug text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  result json;
begin
  select json_build_object(
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
  into result
  from invitation_groups ig
  join events e on e.id = ig.event_id
  where ig.slug = p_slug;

  if result is null then
    raise exception 'Invitación no encontrada';
  end if;

  return result;
end;
$$;

grant execute on function public.obtener_invitacion(text) to anon, authenticated;
