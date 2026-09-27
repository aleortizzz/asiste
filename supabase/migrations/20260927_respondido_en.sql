-- Cuándo respondió cada familia (para la "actividad reciente" del Inicio).
--
-- 100% aditiva: agrega una columna nueva y un trigger. No borra ni cambia
-- ningún dato existente y no toca las funciones de confirmación
-- (confirmar_asistencia / responder_invitados): el trigger se engancha solo.
-- Se puede correr más de una vez sin problema.

-- 1) Columna nueva. Las filas existentes quedan en null (no sabemos cuándo
--    respondieron), salvo lo que se recupera en el paso 2.
alter table invitation_groups add column if not exists responded_at timestamptz;

-- 2) Recuperar lo que se pueda: en el flujo genérico (el invitado escribe los
--    nombres), confirmar_asistencia crea las filas de guests en el momento de
--    confirmar, así que su created_at ES la hora de la respuesta. Solo
--    completa filas que todavía no tienen fecha.
update invitation_groups ig
set responded_at = sub.answered_at
from (
  select group_id, max(created_at) as answered_at
  from guests
  group by group_id
) sub
where ig.id = sub.group_id
  and ig.status = 'confirmed'
  and not ig.named_by_host
  and ig.responded_at is null;

-- 3) De acá en adelante: cada vez que una respuesta escribe el status (las
--    RPC de RSVP siempre lo hacen, incluso si cambian de opinión), guardamos
--    la hora. `before update of status` no se dispara con ediciones del admin
--    que no tocan el status (nombre, cantidad de invitaciones, etc.).
create or replace function public.marcar_respondido_en()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status <> 'pending' then
    new.responded_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists invitation_groups_responded_at on invitation_groups;
create trigger invitation_groups_responded_at
  before update of status on invitation_groups
  for each row
  execute function public.marcar_respondido_en();
