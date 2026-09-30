-- ============================================================
-- Tipo de evento: se suma 'empresarial' (cumpleaños / casamiento / empresarial)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- No toca ningún dato: solo amplía la regla de valores permitidos. Los
-- eventos que ya existen siguen con su tipo. Va en un solo ALTER TABLE para
-- que sacar la regla vieja y poner la nueva sea atómico (nunca queda la
-- columna sin regla, ni a medias si algo falla).
-- ============================================================

alter table public.events
  drop constraint if exists events_event_type_check,
  add constraint events_event_type_check
    check (event_type in ('cumpleanos', 'casamiento', 'empresarial'));
