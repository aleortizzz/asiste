-- ============================================================
-- Sacar un like de una foto de invitados (tocar el corazón de nuevo)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Igual que dar_like_foto: público y anónimo. Que cada navegador solo saque
-- un like que dio lo controla la página (localStorage), no el servidor.
-- Nunca baja de 0.
-- ============================================================

create or replace function public.quitar_like_foto(p_photo_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  update public.event_photos set likes_count = greatest(likes_count - 1, 0)
  where id = p_photo_id
  returning likes_count into v_count;

  if v_count is null then
    raise exception 'Foto no encontrada';
  end if;

  return v_count;
end;
$$;

grant execute on function public.quitar_like_foto(uuid) to anon, authenticated;
