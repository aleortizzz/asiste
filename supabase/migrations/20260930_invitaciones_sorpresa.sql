-- ============================================================
-- Invitaciones sorpresa
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Caso: una invitación que el dueño del evento NO tiene que ver (ej. una
-- familia invitada de sorpresa para la quinceañera, que es quien usa la
-- cuenta). El link sigue funcionando igual para la familia; lo único que
-- cambia es quién la ve en el panel:
--   - dueño del evento: la base no le devuelve nada de esa invitación
--     (ni la familia, ni sus invitados, ni visitas, ni respuestas, ni
--     canciones). En Mesas ve sus lugares como «reservados», sin nombres.
--   - superadmin: ve todo (sus policies no cambian), con la marca.
--
-- Se hace con RLS y no escondiéndolo en la pantalla: así los datos ni
-- siquiera llegan al navegador de la cuenta del evento.
-- ============================================================

-- 1) La marca.
alter table public.invitation_groups
  add column if not exists sorpresa boolean not null default false;

-- 2) Policies del dueño: mismas de antes + "and not sorpresa".
--    El with check también la lleva: desde la cuenta del evento no se puede
--    crear ni marcar/desmarcar una sorpresa (eso lo hace el superadmin).
drop policy if exists "admin gestiona grupos de sus eventos" on public.invitation_groups;
create policy "admin gestiona grupos de sus eventos"
  on public.invitation_groups for all
  using (
    not sorpresa
    and exists (
      select 1 from public.events
      where events.id = invitation_groups.event_id
      and events.owner_user_id = auth.uid()
    )
  )
  with check (
    not sorpresa
    and exists (
      select 1 from public.events
      where events.id = invitation_groups.event_id
      and events.owner_user_id = auth.uid()
    )
  );

drop policy if exists "admin gestiona invitados de sus eventos" on public.guests;
create policy "admin gestiona invitados de sus eventos"
  on public.guests for all
  using (exists (
    select 1 from public.invitation_groups
    join public.events on events.id = invitation_groups.event_id
    where invitation_groups.id = guests.group_id
    and not invitation_groups.sorpresa
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.invitation_groups
    join public.events on events.id = invitation_groups.event_id
    where invitation_groups.id = guests.group_id
    and not invitation_groups.sorpresa
    and events.owner_user_id = auth.uid()
  ));

drop policy if exists "admin ve las vistas de sus invitados" on public.invitation_views;
create policy "admin ve las vistas de sus invitados"
  on public.invitation_views for select
  using (exists (
    select 1 from public.invitation_groups
    join public.events on events.id = invitation_groups.event_id
    where invitation_groups.id = invitation_views.group_id
    and not invitation_groups.sorpresa
    and events.owner_user_id = auth.uid()
  ));

drop policy if exists "admin ve el historial de sus invitados" on public.rsvp_log;
create policy "admin ve el historial de sus invitados"
  on public.rsvp_log for select
  using (exists (
    select 1 from public.invitation_groups
    join public.events on events.id = invitation_groups.event_id
    where invitation_groups.id = rsvp_log.group_id
    and not invitation_groups.sorpresa
    and events.owner_user_id = auth.uid()
  ));

-- 3) Canciones: hasta ahora no guardaban de qué invitación venían (solo el
--    nombre que escribió la persona, que puede delatar la sorpresa). Se
--    agrega group_id; las canciones viejas quedan en null y se ven igual.
alter table public.song_requests
  add column if not exists group_id uuid references public.invitation_groups(id) on delete set null;

drop policy if exists "admin gestiona canciones de su evento" on public.song_requests;
create policy "admin gestiona canciones de su evento"
  on public.song_requests for all
  using (
    exists (
      select 1 from public.events
      where events.id = song_requests.event_id
      and events.owner_user_id = auth.uid()
    )
    and not exists (
      select 1 from public.invitation_groups
      where invitation_groups.id = song_requests.group_id
      and invitation_groups.sorpresa
    )
  )
  with check (exists (
    select 1 from public.events
    where events.id = song_requests.event_id
    and events.owner_user_id = auth.uid()
  ));

-- Igual que antes, pero anotando group_id.
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
  v_group_id uuid;
  v_plan text;
begin
  select e.id, ig.id, e.plan into v_event_id, v_group_id, v_plan
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

  insert into song_requests (event_id, group_id, song_title, artist, youtube_video_id, requested_by)
  values (
    v_event_id,
    v_group_id,
    trim(p_song_title),
    nullif(trim(coalesce(p_artist, '')), ''),
    nullif(trim(coalesce(p_youtube_video_id, '')), ''),
    trim(p_requested_by)
  );

  return json_build_object('ok', true);
end;
$$;

-- 4) Mesas: el dueño no ve a los invitados sorpresa, pero ocupan lugar.
--    Esta función le dice cuántos lugares hay "reservados" en cada mesa,
--    sin nombres. Al superadmin no le devuelve nada: él ya los ve.
create or replace function public.lugares_reservados(p_event_id uuid)
returns table (table_id uuid, cantidad int)
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from superadmins where user_id = auth.uid()) then
    return;
  end if;
  if not exists (select 1 from events where id = p_event_id and owner_user_id = auth.uid()) then
    raise exception 'No autorizado';
  end if;

  return query
    select g.table_id, count(*)::int
    from guests g
    join invitation_groups ig on ig.id = g.group_id
    where ig.event_id = p_event_id
      and ig.sorpresa
      and g.rsvp_status = 'attending'
      and g.table_id is not null
    group by g.table_id;
end;
$$;

grant execute on function public.lugares_reservados(uuid) to authenticated;
