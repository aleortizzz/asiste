-- ============================================================
-- Arreglo de 20261020_aviso_registros.sql: permisos para la Edge Function.
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste").
--
-- La función aviso-registro usa la clave service_role. Ese rol se saltea
-- RLS, pero igual necesita el GRANT de base: sin él, anotar la cuenta en
-- avisos_registro daba «permission denied» y la función contestaba
-- «error al anotar» (no llegaba ningún aviso).
-- ============================================================

grant select, insert on public.avisos_registro to service_role;
grant select, delete on public.push_subscriptions to service_role;
