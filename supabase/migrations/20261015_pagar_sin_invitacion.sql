-- ============================================================
-- Pagar antes de armar la invitación
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste").
-- Va después de 20261015_pagos.sql y 20261015_precios_planes.sql.
--
-- Antes, para pagar había que tener el evento creado (registrarse →
-- confirmar el mail → armar la invitación → recién ahí pagar). Ahora se
-- puede comprar de entrada desde la landing:
-- - Un pago puede no tener evento (event_id null): queda atado a la cuenta.
-- - Cuando la cuenta crea su evento, nace con el mejor plan que ya pagó
--   (events_proteger_plan) y los pagos sueltos se atan a ese evento.
-- - Si el pago se aprueba y la cuenta ya tiene evento, se ata y sube el plan
--   como siempre (aplicar_pago).
-- ============================================================

alter table public.pagos alter column event_id drop not null;
create index if not exists pagos_user_sin_evento_idx on public.pagos(user_id) where event_id is null;

-- El mejor plan que una cuenta pagó y todavía no está en ningún evento.
-- 'gratis' si no hay. Cada uno ve solo el suyo (el superadmin y las Edge
-- Functions, cualquiera).
create or replace function public.plan_pagado_sin_evento(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select plan from pagos
      where user_id = p_user and event_id is null and estado = 'aprobado'
        and (auth.uid() is null or auth.uid() = p_user or soy_superadmin())
      order by precio_plan(plan) desc
      limit 1
    ),
    'gratis'
  );
$$;

revoke execute on function public.plan_pagado_sin_evento(uuid) from public, anon;
grant execute on function public.plan_pagado_sin_evento(uuid) to authenticated, service_role;

-- El evento nuevo nace con lo que ya pagó (antes: siempre 'gratis').
create or replace function public.events_proteger_plan()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_user not in ('authenticated', 'anon') or soy_superadmin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.plan := plan_pagado_sin_evento(new.owner_user_id);
    new.landing_demo := false;
    new.prueba_invitaciones := 0;
    new.prueba_visitas := 0;
    new.prueba_primera_visita := null;
  elsif new.plan is distinct from old.plan
     or new.landing_demo is distinct from old.landing_demo
     or new.prueba_invitaciones is distinct from old.prueba_invitaciones
     or new.prueba_visitas is distinct from old.prueba_visitas
     or new.prueba_primera_visita is distinct from old.prueba_primera_visita then
    raise exception 'El plan lo cambia TizDigital.';
  end if;
  return new;
end;
$$;

-- Después de crear el evento, los pagos sueltos de la cuenta pasan a ser de
-- ese evento (aprobados y pendientes: si uno se aprueba después, ya sabe a
-- qué evento subirle el plan). security definer: el dueño no escribe pagos.
create or replace function public.events_atar_pagos()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update pagos set event_id = new.id where user_id = new.owner_user_id and event_id is null;
  return null;
end;
$$;

drop trigger if exists events_atar_pagos on public.events;
create trigger events_atar_pagos
  after insert on public.events
  for each row execute function public.events_atar_pagos();

-- aplicar_pago: igual que antes, pero si el pago no tiene evento busca el de
-- la cuenta. Si todavía no hay, el pago queda aprobado y suelto: el evento
-- nace con ese plan.
create or replace function public.aplicar_pago(
  p_pago_id uuid,
  p_mp_payment_id text,
  p_mp_status text,
  p_monto numeric
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pago pagos;
  v_event_id uuid;
  v_plan_actual text;
  v_estado text;
begin
  select * into v_pago from pagos where id = p_pago_id for update;
  if not found then
    return json_build_object('ok', false, 'motivo', 'no existe el pago');
  end if;

  v_estado := case p_mp_status
    when 'approved' then 'aprobado'
    when 'rejected' then 'rechazado'
    when 'cancelled' then 'cancelado'
    when 'refunded' then 'devuelto'
    when 'charged_back' then 'devuelto'
    else 'pendiente'
  end;

  if v_pago.estado = 'aprobado' then
    if v_estado = 'devuelto' then
      update pagos set estado = 'devuelto', mp_status = p_mp_status where id = p_pago_id;
    end if;
    return json_build_object('ok', true, 'motivo', 'ya estaba aprobado');
  end if;

  if v_estado = 'aprobado' and p_monto < v_pago.monto then
    update pagos set mp_payment_id = p_mp_payment_id, mp_status = p_mp_status where id = p_pago_id;
    return json_build_object('ok', false, 'motivo', 'el monto no coincide');
  end if;

  v_event_id := coalesce(v_pago.event_id, (select id from events where owner_user_id = v_pago.user_id limit 1));

  update pagos
  set estado = v_estado,
      event_id = v_event_id,
      mp_payment_id = p_mp_payment_id,
      mp_status = p_mp_status,
      aprobado_en = case when v_estado = 'aprobado' then now() else null end
  where id = p_pago_id;

  if v_estado = 'aprobado' and v_event_id is not null then
    select plan into v_plan_actual from events where id = v_event_id for update;
    if precio_plan(v_pago.plan) > precio_plan(v_plan_actual) then
      update events set plan = v_pago.plan where id = v_event_id;
    end if;
  end if;

  return json_build_object('ok', true, 'estado', v_estado, 'sin_evento', v_event_id is null);
end;
$$;

revoke execute on function public.aplicar_pago(uuid, text, text, numeric) from public, anon, authenticated;
grant execute on function public.aplicar_pago(uuid, text, text, numeric) to service_role;
