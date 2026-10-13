-- ============================================================
-- Seguridad: lo que encontró la revisión del 2026-10-13
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
-- (después de 20261013_planes.sql: usa plan_incluye y soy_superadmin)
--
-- 1) event-photos: cualquiera (sin cuenta) podía LISTAR el bucket y bajar
--    las fotos de las invitaciones de todos los clientes (las carpetas son
--    los ids de sus cuentas). Las fotos se siguen viendo por su URL pública
--    (el bucket es público); listar queda solo para el dueño de la carpeta
--    y el superadmin (que lista al borrar un evento).
-- 2) guest-uploads: cualquiera podía subir imágenes a cualquier ruta del
--    bucket (llenar el espacio o usarlo de hosting). Ahora solo dentro de la
--    carpeta de un evento que tenga las fotos de invitados habilitadas.
-- 3) agregar_foto_invitados aceptaba cualquier URL: se podía meter en la
--    galería de una fiesta una imagen de otro sitio. Ahora arma la URL ella
--    misma, a partir de un archivo que tiene que existir en la carpeta del
--    evento, y no registra dos veces el mismo archivo.
-- 4) Topes de largo en los nombres que se confirman desde la invitación.
-- ============================================================

-- 1) Listar event-photos: solo el dueño de la carpeta o el superadmin.
drop policy if exists "event-photos public read" on storage.objects;
drop policy if exists "event-photos dueño o superadmin listan" on storage.objects;
create policy "event-photos dueño o superadmin listan" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'event-photos'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.soy_superadmin())
  );

-- 2) Subir a guest-uploads: solo a la carpeta de un evento con fotos habilitadas.
--    (La policy corre como el invitado, que no puede leer events: por eso la función.)
create or replace function public.fotos_invitados_habilitadas(p_carpeta text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from events
    where id::text = p_carpeta and plan_incluye(plan, 'fotos')
  );
$$;

grant execute on function public.fotos_invitados_habilitadas(text) to anon, authenticated;

drop policy if exists "guest-uploads anyone insert" on storage.objects;
drop policy if exists "guest-uploads solo en eventos con fotos" on storage.objects;
create policy "guest-uploads solo en eventos con fotos" on storage.objects
  for insert to anon, authenticated
  with check (
    bucket_id = 'guest-uploads'
    and public.fotos_invitados_habilitadas((storage.foldername(name))[1])
  );

-- 3) Registrar una foto subida: la URL la arma la base (no la manda el
--    navegador) y el archivo tiene que existir en la carpeta del evento.
--    p_url queda en la firma para no romper la app, pero se ignora.
create or replace function public.agregar_foto_invitados(
  p_event_id uuid,
  p_url text,
  p_path text,
  p_uploader_name text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_limit int := 500; -- tope duro por evento, ajustable acá si hace falta.
  v_plan text;
begin
  select plan into v_plan from events where id = p_event_id;
  if v_plan is null then
    raise exception 'Evento no encontrado';
  end if;
  if not plan_incluye(v_plan, 'fotos') then
    raise exception 'Este evento no tiene habilitadas las fotos de invitados';
  end if;

  if p_path is null or p_path not like p_event_id::text || '/%' or p_path like '%..%'
     or not exists (select 1 from storage.objects where bucket_id = 'guest-uploads' and name = p_path) then
    raise exception 'Foto no encontrada';
  end if;
  if exists (select 1 from event_photos where path = p_path) then
    raise exception 'Esa foto ya está en la galería';
  end if;

  select count(*) into v_count from event_photos where event_id = p_event_id;
  if v_count >= v_limit then
    raise exception 'Se llegó al máximo de % fotos para este evento.', v_limit;
  end if;

  insert into event_photos (event_id, url, path, uploader_name)
  values (
    p_event_id,
    'https://yxcwotrrcekoldmkuxps.supabase.co/storage/v1/object/public/guest-uploads/' || p_path,
    p_path,
    texto_invitado(p_uploader_name, 40)
  );

  return json_build_object('ok', true, 'count', v_count + 1, 'limit', v_limit);
end;
$$;

grant execute on function public.agregar_foto_invitados(uuid, text, text, text) to anon, authenticated;

-- 4) Confirmación con nombres escritos por la familia: tope de 80 caracteres por nombre.
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
    left(trim(n.name), 80),
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
