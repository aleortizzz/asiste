-- ============================================================
-- Recepción: las cuentas del personal se crean desde la base
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
-- (después de 20261012_recepcion.sql)
--
-- Antes se creaban con signUp desde el navegador, pero el proyecto pide
-- confirmar el mail: Supabase mandaba un mail de confirmación a una dirección
-- inventada (rebotaba) y la cuenta quedaba sin poder entrar. Ahora:
-- - crear_recepcionista crea la cuenta ya confirmada, sin mandar nada.
-- - quitar_recepcionista borra también la cuenta (el usuario queda libre).
-- - cambiar_clave_recepcionista: el personal no tiene mail para recuperar
--   la contraseña, así que se la cambia el organizador.
-- ============================================================

-- 1) Limpiar las cuentas que quedaron sin confirmar con el método anterior
--    (borra también su fila de event_staff, por el on delete cascade).
delete from auth.users
where email like '%@recepcion.tizdigital.com'
  and email_confirmed_at is null;

drop function if exists public.agregar_recepcionista(uuid, uuid, text, text);

-- 2) Crear
create or replace function public.crear_recepcionista(
  p_event_id uuid,
  p_username text,
  p_password text,
  p_display_name text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text := lower(trim(coalesce(p_username, '')));
  v_email text := lower(trim(coalesce(p_username, ''))) || '@recepcion.tizdigital.com';
  v_name text := left(trim(coalesce(p_display_name, '')), 60);
  v_user_id uuid := gen_random_uuid();
  v_row event_staff;
begin
  if not puede_administrar_evento(p_event_id) then
    raise exception 'No autorizado';
  end if;
  if v_name = '' then
    raise exception 'Escribí el nombre de la persona.';
  end if;
  if v_username !~ '^[a-z0-9.-]{3,30}$' then
    raise exception 'Usuario inválido';
  end if;
  if length(coalesce(p_password, '')) < 6 then
    raise exception 'La contraseña tiene que tener al menos 6 caracteres.';
  end if;
  if exists (select 1 from auth.users where email = v_email) then
    raise exception 'Ese usuario ya existe';
  end if;

  -- Los tokens van en '' (no null): con null, el login de Supabase falla.
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated',
    v_email, extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    jsonb_build_object('role', 'recepcion', 'display_name', v_name),
    now(), now(), '', '', '', ''
  );

  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (
    gen_random_uuid(), v_user_id, v_user_id::text,
    jsonb_build_object('sub', v_user_id::text, 'email', v_email, 'email_verified', true),
    'email', now(), now(), now()
  );

  insert into event_staff (event_id, user_id, username, display_name)
  values (p_event_id, v_user_id, v_username, v_name)
  returning * into v_row;

  return row_to_json(v_row);
end;
$$;

grant execute on function public.crear_recepcionista(uuid, text, text, text) to authenticated;

-- 3) Quitar: saca a la persona del evento y, si no trabaja en otro, borra la cuenta.
create or replace function public.quitar_recepcionista(p_staff_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row event_staff;
begin
  select * into v_row from event_staff where id = p_staff_id;
  if v_row.id is null or not puede_administrar_evento(v_row.event_id) then
    raise exception 'No autorizado';
  end if;

  delete from event_staff where id = p_staff_id;

  delete from auth.users u
  where u.id = v_row.user_id
    and u.email like '%@recepcion.tizdigital.com'
    and not exists (select 1 from event_staff s where s.user_id = u.id);
end;
$$;

grant execute on function public.quitar_recepcionista(uuid) to authenticated;

-- 4) Cambiar la contraseña (y cerrar las sesiones abiertas con la vieja).
create or replace function public.cambiar_clave_recepcionista(p_staff_id uuid, p_password text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row event_staff;
begin
  select * into v_row from event_staff where id = p_staff_id;
  if v_row.id is null or not puede_administrar_evento(v_row.event_id) then
    raise exception 'No autorizado';
  end if;
  if length(coalesce(p_password, '')) < 6 then
    raise exception 'La contraseña tiene que tener al menos 6 caracteres.';
  end if;

  update auth.users
  set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
      updated_at = now()
  where id = v_row.user_id
    and email like '%@recepcion.tizdigital.com';

  delete from auth.sessions where user_id = v_row.user_id;
end;
$$;

grant execute on function public.cambiar_clave_recepcionista(uuid, text) to authenticated;
