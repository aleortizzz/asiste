-- ============================================================
-- Tipo de evento (cumpleaños / casamiento)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Solo se usa en el panel: define qué textos genéricos se
-- precargan al armar la invitación. La invitación pública no
-- lo necesita, así que la RPC no cambia.
-- ============================================================

alter table events
  add column if not exists event_type text not null default 'cumpleanos';

alter table events drop constraint if exists events_event_type_check;
alter table events
  add constraint events_event_type_check check (event_type in ('cumpleanos', 'casamiento'));
