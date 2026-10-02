-- ============================================================
-- Confirmación completa: datos extra de cada invitado al confirmar
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Solo AGREGA columnas (vacías) y acepta datos nuevos en las funciones de
-- confirmación DE FORMA OPCIONAL: si no vienen, todo funciona como antes.
-- Las invitaciones que ya existen no cambian.
--
--   events.rsvp_fields   qué datos se piden: lista con 'company', 'job_title',
--                        'email', 'phone', 'dietary'. Vacía = solo el nombre.
--   guests.company       empresa
--   guests.job_title     cargo
--   guests.email
--   guests.phone
--   guests.dietary       restricciones alimentarias
-- ============================================================

alter table public.events add column if not exists rsvp_fields jsonb not null default '[]'::jsonb;

alter table public.guests add column if not exists company text;
alter table public.guests add column if not exists job_title text;
alter table public.guests add column if not exists email text;
alter table public.guests add column if not exists phone text;
alter table public.guests add column if not exists dietary text;

-- Texto prolijo para guardar: sin espacios de más, vacío → null, con tope de largo.
create or replace function public.texto_invitado(p_value text, p_max int default 200)
returns text
language sql
immutable
as $$
  select nullif(left(trim(coalesce(p_value, '')), p_max), '');
$$;

-- ------------------------------------------------------------
-- 1) Confirmación con nombres que escribe la familia/invitado.
--    Parámetro nuevo p_detalles (opcional): un objeto por nombre, en el
--    mismo orden: { company, job_title, email, phone, dietary }.
--    Cambiar los parámetros de una función crea otra aparte, así que se
--    borra la versión vieja (2 parámetros) antes de crear la nueva. Quien
--    la llame con 2 parámetros sigue funcionando: p_detalles tiene default.
-- ------------------------------------------------------------
drop function if exists public.confirmar_asistencia(text, text[]);

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

-- ------------------------------------------------------------
-- 2) Respuesta con nombres precargados por el anfitrión. Misma firma: cada
--    respuesta puede traer además los datos extra. Un dato que no viene
--    deja el que ya estaba; uno que viene vacío lo borra.
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- 3) La invitación pública recibe qué datos pedir, y los que ya cargó cada
--    invitado de ESA invitación (para volver a mostrarlos si responde de nuevo).
-- ------------------------------------------------------------
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
    'rsvp_fields', e.rsvp_fields
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
