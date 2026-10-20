-- ============================================================
-- Aviso push al superadmin cada vez que alguien se registra.
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste").
-- Antes: desplegar la Edge Function `aviso-registro` (ver functions/README.md).
--
-- Cómo funciona:
--   1. El superadmin toca «Activar avisos» en Superadmin › Registros: el
--      navegador da una «suscripción» (endpoint + claves) y se guarda acá.
--   2. Un trigger en auth.users, al crearse una cuenta, llama (con pg_net,
--      sin esperar respuesta) a la Edge Function con el id de la cuenta.
--   3. La función manda la notificación a las suscripciones guardadas.
--
-- Solo le llega al superadmin: push_subscriptions.user_id apunta a
-- superadmins (no a auth.users), así que una cuenta común no puede guardar
-- una suscripción aunque llame a la API a mano, y si alguien deja de ser
-- superadmin, sus suscripciones se borran solas (on delete cascade).
-- ============================================================

create extension if not exists pg_net with schema extensions;

-- 1) Suscripciones (una por navegador/dispositivo).
create table if not exists public.push_subscriptions (
  endpoint text primary key,
  user_id uuid not null references public.superadmins(user_id) on delete cascade,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

alter table public.push_subscriptions enable row level security;
grant select, insert, update, delete on public.push_subscriptions to authenticated;

drop policy if exists "superadmin gestiona sus suscripciones" on public.push_subscriptions;
create policy "superadmin gestiona sus suscripciones"
  on public.push_subscriptions for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and soy_superadmin());

-- 2) Cuentas ya avisadas. La Edge Function se puede llamar sin sesión (la
-- llama la base), así que no le cree al pedido: anota acá cada cuenta y, si
-- ya estaba, no vuelve a avisar. Nadie más la ve (sin grants).
create table if not exists public.avisos_registro (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.avisos_registro enable row level security;

-- 3) Trigger: cuenta nueva → Edge Function.
-- Las cuentas de recepción (las crea el organizador, no son clientes) no avisan.
-- Si la llamada falla, el registro sigue igual: nunca se corta un alta por un aviso.
create or replace function public.avisar_registro()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email like '%@recepcion.tizdigital.com' then
    return new;
  end if;

  begin
    perform net.http_post(
      url := 'https://yxcwotrrcekoldmkuxps.supabase.co/functions/v1/aviso-registro',
      body := jsonb_build_object('user_id', new.id),
      headers := '{"Content-Type": "application/json"}'::jsonb
    );
  exception when others then
    raise warning 'avisar_registro: %', sqlerrm;
  end;

  return new;
end;
$$;

revoke execute on function public.avisar_registro() from public, anon, authenticated;

drop trigger if exists avisar_registro on auth.users;
create trigger avisar_registro
  after insert on auth.users
  for each row execute function public.avisar_registro();
