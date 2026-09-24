-- ============================================================
-- Plan del evento (básico/plus) + pedidos de canciones para la fiesta
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- "plan": gate de funciones pagas. 'basico' = solo invitación. 'plus' =
-- suma las funciones de interacción (por ahora, pedir canciones). Lo
-- setea el dueño de TizDigital a mano según lo que contrató cada cliente
-- (no hay billing automático todavía) — el host NO se lo puede subir
-- solo. La función de abajo también valida el plan server-side, no solo
-- el frontend, para que nadie lo salte editando el HTML.
-- ============================================================

alter table events
  add column if not exists plan text not null default 'basico'
    check (plan in ('basico', 'plus'));

create table if not exists song_requests (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null,
  song_title text not null,
  artist text,
  youtube_video_id text,
  requested_by text not null,
  created_at timestamptz not null default now()
);

create index if not exists song_requests_event_id_idx on song_requests (event_id);

grant select, delete on public.song_requests to authenticated;
alter table song_requests enable row level security;

-- Mismo patrón que event_photos: sin INSERT para authenticated/anon, las
-- filas se crean solo vía agregar_cancion_solicitada() (security definer).
drop policy if exists "admin gestiona canciones de su evento" on song_requests;
create policy "admin gestiona canciones de su evento"
  on song_requests for all
  using (exists (
    select 1 from events
    where events.id = song_requests.event_id
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from events
    where events.id = song_requests.event_id
    and events.owner_user_id = auth.uid()
  ));

drop policy if exists "superadmin gestiona canciones" on song_requests;
create policy "superadmin gestiona canciones"
  on song_requests for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

-- Reemplaza obtener_invitacion para sumar 'plan' al payload público — la
-- invitación lo necesita para decidir si muestra la sección de canciones.
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

-- Alta pública de un pedido de canción, vía slug (misma puerta angosta que
-- confirmar_asistencia). Valida server-side que el evento tenga plan
-- 'plus' — si el host bajó de plan después de mandar el link, esto lo
-- corta acá aunque alguien deje la pestaña vieja abierta.
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
  v_plan text;
begin
  select e.id, e.plan into v_event_id, v_plan
  from invitation_groups ig
  join events e on e.id = ig.event_id
  where ig.slug = p_slug;

  if v_event_id is null then
    raise exception 'Invitación no encontrada';
  end if;

  if v_plan <> 'plus' then
    raise exception 'Esta invitación no tiene habilitado el pedido de canciones';
  end if;

  if trim(coalesce(p_song_title, '')) = '' then
    raise exception 'Falta el nombre de la canción';
  end if;

  if trim(coalesce(p_requested_by, '')) = '' then
    raise exception 'Falta tu nombre';
  end if;

  insert into song_requests (event_id, song_title, artist, youtube_video_id, requested_by)
  values (
    v_event_id,
    trim(p_song_title),
    nullif(trim(coalesce(p_artist, '')), ''),
    nullif(trim(coalesce(p_youtube_video_id, '')), ''),
    trim(p_requested_by)
  );

  return json_build_object('ok', true);
end;
$$;

grant execute on function public.agregar_cancion_solicitada(text, text, text, text, text) to anon, authenticated;

-- Reemplaza listar_eventos_superadmin para sumar 'plan' — así el panel de
-- superadmin puede mostrar/activar el plan de cada cliente sin tocar SQL
-- a mano cada vez. Postgres no deja cambiar las columnas de un `returns
-- table` con create or replace (cambia el "row type" de los OUT params),
-- así que hay que borrarla primero.
drop function if exists public.listar_eventos_superadmin();

create or replace function public.listar_eventos_superadmin()
returns table (
  event_id uuid,
  event_name text,
  owner_email text,
  event_date date,
  plan text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from superadmins where user_id = auth.uid()) then
    raise exception 'No autorizado';
  end if;

  return query
    select e.id, e.name, u.email::text, e.event_date, e.plan, e.created_at
    from events e
    join auth.users u on u.id = e.owner_user_id
    order by e.created_at desc;
end;
$$;

grant execute on function public.listar_eventos_superadmin() to authenticated;
