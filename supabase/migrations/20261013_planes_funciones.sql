-- ============================================================
-- Planes: cada función bloqueada en la base según el plan
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
-- (después de 20261013_planes.sql y 20261013_seguridad.sql)
--
-- El panel muestra borroso lo que el plan no incluye (PlanGate.vue), pero eso
-- es solo la vitrina: acá se impide de verdad, aunque alguien lo intente
-- desde la consola del navegador.
-- - mesas: crear/editar mesas y sentar invitados.
-- - trivia: crear/editar el juego y sus preguntas, y que un invitado juegue.
-- - recepción: crear personal y usar la lista de la entrada.
-- (Canciones y fotos de invitados ya se controlan en 20261013_planes.sql y
-- 20261013_seguridad.sql.)
-- El superadmin puede todo. Los datos que ya existen no se tocan: si un
-- evento baja de plan, quedan guardados y vuelven a usarse al subir.
-- ============================================================

-- Plan de un evento (para los chequeos: el invitado o el personal no pueden
-- leer events directamente).
create or replace function public.plan_de_evento(p_event_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select plan from events where id = p_event_id;
$$;

revoke execute on function public.plan_de_evento(uuid) from public, anon;
grant execute on function public.plan_de_evento(uuid) to authenticated;

-- Corta si el plan del evento no incluye la función. Corre como quien llama
-- (no es security definer): así, lo que hace una función de la base por su
-- cuenta (current_user = su dueño) no se frena acá.
create or replace function public.exigir_plan(p_event_id uuid, p_funcion text)
returns void
language plpgsql
set search_path = public
as $$
begin
  if current_user in ('authenticated', 'anon')
     and not soy_superadmin()
     and not plan_incluye(plan_de_evento(p_event_id), p_funcion) then
    raise exception 'Tu plan no incluye esta función.';
  end if;
end;
$$;

grant execute on function public.exigir_plan(uuid, text) to anon, authenticated;

-- 1) Mesas
create or replace function public.tables_exigir_mesas()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform exigir_plan(new.event_id, 'mesas');
  return new;
end;
$$;

drop trigger if exists tables_exigir_mesas on public.tables;
create trigger tables_exigir_mesas
  before insert or update on public.tables
  for each row execute function public.tables_exigir_mesas();

create or replace function public.guests_exigir_mesas()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.table_id is not null and new.table_id is distinct from old.table_id then
    perform exigir_plan((select event_id from invitation_groups where id = new.group_id), 'mesas');
  end if;
  return new;
end;
$$;

drop trigger if exists guests_exigir_mesas on public.guests;
create trigger guests_exigir_mesas
  before update on public.guests
  for each row execute function public.guests_exigir_mesas();

-- 2) Trivia: armar el juego (dueño) y jugar (invitados, vía empezar_juego).
create or replace function public.trivia_games_exigir_plan()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform exigir_plan(new.event_id, 'trivia');
  return new;
end;
$$;

drop trigger if exists trivia_games_exigir_plan on public.trivia_games;
create trigger trivia_games_exigir_plan
  before insert or update on public.trivia_games
  for each row execute function public.trivia_games_exigir_plan();

create or replace function public.trivia_questions_exigir_plan()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform exigir_plan((select event_id from trivia_games where id = new.game_id), 'trivia');
  return new;
end;
$$;

drop trigger if exists trivia_questions_exigir_plan on public.trivia_questions;
create trigger trivia_questions_exigir_plan
  before insert or update on public.trivia_questions
  for each row execute function public.trivia_questions_exigir_plan();

-- Un intento nuevo lo crea empezar_juego (security definer), así que acá el
-- chequeo va sin excepción por current_user.
create or replace function public.trivia_attempts_exigir_plan()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not plan_incluye(plan_de_evento((select event_id from trivia_games where id = new.game_id)), 'trivia') then
    raise exception 'El juego no está disponible.';
  end if;
  return new;
end;
$$;

drop trigger if exists trivia_attempts_exigir_plan on public.trivia_attempts;
create trigger trivia_attempts_exigir_plan
  before insert on public.trivia_attempts
  for each row execute function public.trivia_attempts_exigir_plan();

-- 3) Recepción: el personal lo crea crear_recepcionista (security definer):
--    chequeo sin excepción por current_user (salvo el superadmin).
create or replace function public.event_staff_exigir_plan()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not soy_superadmin() and not plan_incluye(plan_de_evento(new.event_id), 'recepcion') then
    raise exception 'Tu plan no incluye la recepción.';
  end if;
  return new;
end;
$$;

drop trigger if exists event_staff_exigir_plan on public.event_staff;
create trigger event_staff_exigir_plan
  before insert on public.event_staff
  for each row execute function public.event_staff_exigir_plan();

-- La lista y las marcas pasan por acceso_recepcion: sin el plan, nadie entra
-- (salvo el superadmin).
create or replace function public.acceso_recepcion(p_event_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when exists (select 1 from public.superadmins where user_id = auth.uid()) then 'superadmin'
    when not public.plan_incluye(public.plan_de_evento(p_event_id), 'recepcion') then null
    when exists (select 1 from public.event_staff where event_id = p_event_id and user_id = auth.uid()) then 'personal'
    when exists (select 1 from public.events where id = p_event_id and owner_user_id = auth.uid()) then 'duenio'
  end;
$$;

-- 4) Superadmin: las cuentas que todavía no armaron su invitación (el evento
--    se crea recién al guardar la invitación por primera vez, así que no
--    aparecían en listar_eventos_superadmin). Sin las cuentas de recepción.
create or replace function public.listar_cuentas_sin_evento_superadmin()
returns table (
  user_id uuid,
  email text,
  created_at timestamptz,
  email_confirmado boolean,
  ultimo_ingreso timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not soy_superadmin() then
    raise exception 'No autorizado';
  end if;

  return query
    select u.id, u.email::text, u.created_at, u.email_confirmed_at is not null, u.last_sign_in_at
    from auth.users u
    where not exists (select 1 from events e where e.owner_user_id = u.id)
      and u.email not like '%@recepcion.tizdigital.com'
      and not exists (select 1 from superadmins s where s.user_id = u.id)
    order by u.created_at desc;
end;
$$;

revoke execute on function public.listar_cuentas_sin_evento_superadmin() from public, anon;
grant execute on function public.listar_cuentas_sin_evento_superadmin() to authenticated;
