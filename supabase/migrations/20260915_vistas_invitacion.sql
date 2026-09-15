-- ============================================================
-- Log de aperturas de la invitación pública
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Cada vez que alguien abre /i/:slug queda un registro con cuándo. Así el
-- admin puede ver "entró por última vez a las 18:30 pero no respondió".
-- ============================================================

create table if not exists invitation_views (
  id uuid primary key default gen_random_uuid(),
  group_id uuid references invitation_groups(id) on delete cascade not null,
  viewed_at timestamptz not null default now()
);

create index if not exists invitation_views_group_id_idx on invitation_views (group_id);

grant select on public.invitation_views to authenticated;
alter table invitation_views enable row level security;

-- El admin ve las visitas de los invitados de sus propios eventos (mismo
-- patrón que ya usan `guests`/`invitation_groups`: vía group_id -> event_id).
drop policy if exists "admin ve las vistas de sus invitados" on invitation_views;
create policy "admin ve las vistas de sus invitados"
  on invitation_views for select
  using (exists (
    select 1 from invitation_groups
    join events on events.id = invitation_groups.event_id
    where invitation_groups.id = invitation_views.group_id
    and events.owner_user_id = auth.uid()
  ));

drop policy if exists "superadmin gestiona vistas" on invitation_views;
create policy "superadmin gestiona vistas"
  on invitation_views for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

-- ============================================================
-- obtener_invitacion ahora registra la visita antes de devolver los datos.
-- No hace falta GRANT para "anon" sobre invitation_views: esta función ya
-- lee/escribe invitation_groups/guests sin que anon tenga permisos directos
-- sobre esas tablas (mismo mecanismo que usa hoy con SECURITY DEFINER).
-- ============================================================

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
