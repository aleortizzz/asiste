-- ============================================================
-- Superadmin › Registros: eliminar una cuenta que no armó su invitación
-- (pruebas, registros por error, alguien que se quiere registrar de nuevo).
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste").
--
-- Solo cuentas SIN evento: las que tienen uno se manejan desde Clientes
-- (y events.owner_user_id no tiene cascade, así que el delete fallaría).
-- Nunca un superadmin ni una cuenta de recepción. Lo demás que cuelga de
-- la cuenta (identidades de Google, sesiones, pagos, avisos_registro) se
-- borra solo por cascade.
-- ============================================================

create or replace function public.eliminar_cuenta_superadmin(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not soy_superadmin() then
    raise exception 'No autorizado';
  end if;
  if exists (select 1 from superadmins where user_id = p_user_id) then
    raise exception 'No se puede eliminar una cuenta de superadmin.';
  end if;
  if exists (select 1 from events where owner_user_id = p_user_id) then
    raise exception 'Esa cuenta tiene un evento: eliminalo antes desde Clientes.';
  end if;

  delete from auth.users
  where id = p_user_id
    and email not like '%@recepcion.tizdigital.com';
end;
$$;

revoke execute on function public.eliminar_cuenta_superadmin(uuid) from public, anon;
grant execute on function public.eliminar_cuenta_superadmin(uuid) to authenticated;
