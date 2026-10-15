-- ============================================================
-- Pagos con Mercado Pago (Checkout Pro)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Cómo funciona (ver también supabase/functions/):
-- 1. En el panel («Tu plan») el organizador elige un plan. La Edge Function
--    `crear-pago` calcula el precio acá (precio_cambio_plan: si ya pagó un
--    plan, solo la diferencia), anota el pago como 'pendiente' y le pide a
--    Mercado Pago un link de cobro. El navegador nunca decide el precio.
-- 2. Mercado Pago avisa a la Edge Function `mp-webhook`. Esa función no le
--    cree al aviso: le vuelve a preguntar a MP por el pago con nuestra clave
--    y recién ahí llama a aplicar_pago().
-- 3. aplicar_pago() marca el pago y sube el plan del evento. Es idempotente:
--    MP manda el mismo aviso varias veces y no pasa nada.
--
-- La tabla la escriben solo las Edge Functions (con la service_role key).
-- El dueño puede leer sus pagos; nadie puede escribirlos desde el navegador.
-- ============================================================

-- 1) Precios: los mismos que src/lib/plans.js. La base es la que manda.
create or replace function public.precio_plan(p_plan text)
returns int
language sql
immutable
as $$
  select case p_plan
    when 'invitacion' then 35000
    when 'plus' then 70000
    when 'premium' then 120000
    else 0
  end;
$$;

-- Cuánto cuesta pasar de un plan a otro: la diferencia. Null si no es una
-- mejora (mismo plan, uno más barato, o un plan que no se vende).
create or replace function public.precio_cambio_plan(p_actual text, p_nuevo text)
returns int
language sql
immutable
as $$
  select case
    when p_nuevo not in ('invitacion', 'plus', 'premium') then null
    when precio_plan(p_nuevo) <= precio_plan(p_actual) then null
    else precio_plan(p_nuevo) - precio_plan(p_actual)
  end;
$$;

grant execute on function public.precio_plan(text) to anon, authenticated;
grant execute on function public.precio_cambio_plan(text, text) to anon, authenticated;

-- 2) Los pagos.
create table if not exists public.pagos (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_anterior text not null,
  plan text not null check (plan in ('invitacion', 'plus', 'premium')),
  monto int not null check (monto > 0),
  -- pendiente: se creó el link (o pagó en efectivo y todavía no se acreditó)
  -- aprobado: se cobró y se subió el plan
  -- rechazado / cancelado / devuelto: lo que diga MP
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'aprobado', 'rechazado', 'cancelado', 'devuelto')),
  mp_preference_id text,
  mp_payment_id text unique,
  mp_status text, -- el estado tal cual lo manda MP (approved, in_process, rejected…)
  creado_en timestamptz not null default now(),
  aprobado_en timestamptz
);

create index if not exists pagos_event_id_idx on public.pagos(event_id);

alter table public.pagos enable row level security;

drop policy if exists "el dueño y el superadmin ven los pagos" on public.pagos;
create policy "el dueño y el superadmin ven los pagos"
  on public.pagos for select
  using (user_id = auth.uid() or soy_superadmin());

-- Sin policies de insert/update/delete: desde el navegador no se escribe.
-- (La service_role de las Edge Functions saltea RLS.)
revoke insert, update, delete on public.pagos from anon, authenticated;
grant select on public.pagos to authenticated;
grant all on public.pagos to service_role;

-- 3) Aplicar lo que dijo Mercado Pago. Solo la llaman las Edge Functions.
--    p_monto es lo que MP dice que se cobró: si no coincide con lo anotado,
--    no se sube el plan (alguien tocó algo raro).
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
  v_plan_actual text;
  v_estado text;
begin
  -- for update: si llegan dos avisos a la vez, el segundo espera al primero.
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
    else 'pendiente' -- pending, in_process, authorized, in_mediation
  end;

  -- Ya aprobado: no se vuelve a aplicar. Si después lo devuelven, se anota
  -- pero el plan no se baja solo (eso lo decide TizDigital a mano).
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

  update pagos
  set estado = v_estado,
      mp_payment_id = p_mp_payment_id,
      mp_status = p_mp_status,
      aprobado_en = case when v_estado = 'aprobado' then now() else null end
  where id = p_pago_id;

  if v_estado = 'aprobado' then
    -- Solo sube: si mientras tanto el evento ya tiene un plan igual o mejor
    -- (lo cambió el superadmin, o pagó otro link), no lo baja.
    select plan into v_plan_actual from events where id = v_pago.event_id for update;
    if precio_plan(v_pago.plan) > precio_plan(v_plan_actual) then
      update events set plan = v_pago.plan where id = v_pago.event_id;
    end if;
  end if;

  return json_build_object('ok', true, 'estado', v_estado);
end;
$$;

revoke execute on function public.aplicar_pago(uuid, text, text, numeric) from public, anon, authenticated;
grant execute on function public.aplicar_pago(uuid, text, text, numeric) to service_role;
