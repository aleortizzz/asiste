-- ============================================================
-- Promo en los precios: precio «de antes» tachado y un cartel
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste").
-- Va después de 20261015_precios_planes.sql.
--
-- precio_antes: opcional, se muestra tachado al lado del precio (simula el
-- descuento). Lo que se cobra sigue siendo `precio`: precio_plan() no cambia.
-- precios_cartel: una sola fila con el texto del cartel que va arriba de los
-- precios («Precio lanzamiento», «Promo», …). Vacío o null = sin cartel.
-- ============================================================

alter table public.precios_planes add column if not exists precio_antes int;

alter table public.precios_planes drop constraint if exists precios_planes_antes_mayor;
alter table public.precios_planes add constraint precios_planes_antes_mayor
  check (precio_antes is null or precio_antes > precio);

grant update (precio, precio_antes, actualizado_en) on public.precios_planes to authenticated;

create table if not exists public.precios_cartel (
  id boolean primary key default true check (id),
  texto text check (texto is null or char_length(texto) <= 40),
  actualizado_en timestamptz not null default now()
);

insert into public.precios_cartel (id, texto) values (true, null)
on conflict (id) do nothing;

alter table public.precios_cartel enable row level security;

drop policy if exists "todos leen el cartel" on public.precios_cartel;
create policy "todos leen el cartel"
  on public.precios_cartel for select
  using (true);

drop policy if exists "el superadmin cambia el cartel" on public.precios_cartel;
create policy "el superadmin cambia el cartel"
  on public.precios_cartel for update
  using (soy_superadmin())
  with check (soy_superadmin());

revoke insert, update, delete on public.precios_cartel from anon, authenticated;
grant select on public.precios_cartel to anon, authenticated;
grant update (texto, actualizado_en) on public.precios_cartel to authenticated;
grant all on public.precios_cartel to service_role;
