-- ============================================================
-- Precios de los planes, editables desde Superadmin
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste").
-- Va después de 20261015_pagos.sql.
--
-- Antes los precios estaban fijos en precio_plan() y en src/lib/plans.js.
-- Ahora viven en esta tabla: la base cobra con lo que dice acá (crear-pago
-- usa precio_cambio_plan → precio_plan), y la landing y el panel la leen
-- para mostrar lo mismo. Cualquiera puede leerla (la landing es pública);
-- solo el superadmin la cambia.
--
-- Los de salón (salon_fiesta, salon_abono) por ahora solo se muestran en la
-- landing: no se cobran por Mercado Pago.
--
-- Un cambio de precio no toca los pagos ya iniciados: cada pago guarda su
-- monto al crearse.
-- ============================================================

create table if not exists public.precios_planes (
  plan text primary key check (plan in ('invitacion', 'plus', 'premium', 'salon_fiesta', 'salon_abono')),
  precio int not null check (precio > 0),
  actualizado_en timestamptz not null default now()
);

-- Los precios de hoy. Si ya existen, no se pisan (así se puede correr de nuevo).
insert into public.precios_planes (plan, precio) values
  ('invitacion', 35000),
  ('plus', 70000),
  ('premium', 120000),
  ('salon_fiesta', 70000),
  ('salon_abono', 250000)
on conflict (plan) do nothing;

alter table public.precios_planes enable row level security;

drop policy if exists "todos leen los precios" on public.precios_planes;
create policy "todos leen los precios"
  on public.precios_planes for select
  using (true);

drop policy if exists "el superadmin cambia los precios" on public.precios_planes;
create policy "el superadmin cambia los precios"
  on public.precios_planes for update
  using (soy_superadmin())
  with check (soy_superadmin());

revoke insert, update, delete on public.precios_planes from anon, authenticated;
grant select on public.precios_planes to anon, authenticated;
-- Solo el precio: el superadmin no agrega ni borra planes desde el navegador.
grant update (precio, actualizado_en) on public.precios_planes to authenticated;
grant all on public.precios_planes to service_role;

-- precio_plan lee la tabla. Deja de ser immutable (el resultado cambia si
-- cambia un precio): stable. Solo los planes que se venden por MP.
create or replace function public.precio_plan(p_plan text)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select precio from precios_planes where plan = p_plan and p_plan in ('invitacion', 'plus', 'premium')),
    0
  );
$$;

create or replace function public.precio_cambio_plan(p_actual text, p_nuevo text)
returns int
language sql
stable
as $$
  select case
    when p_nuevo not in ('invitacion', 'plus', 'premium') then null
    when precio_plan(p_nuevo) <= precio_plan(p_actual) then null
    else precio_plan(p_nuevo) - precio_plan(p_actual)
  end;
$$;
