-- ============================================================
-- Trivia: jugadores de ejemplo para ver cómo queda el ranking lleno
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Carga 20 intentos ya enviados en el juego del evento de abajo. Varios
-- con todas (o casi todas) bien y tiempos rápidos, así un jugador real
-- queda fuera del top 10. Se marcan con answers = {"_demo": true} para
-- borrarlos después sin tocar a nadie real (ver el final del archivo).
-- «Reiniciar» en el panel también los borra (junto con todo lo demás).
-- ============================================================

-- 1) Cargar
with juego as (
  select g.id, (select count(*) from trivia_questions q where q.game_id = g.id)::int as total
  from trivia_games g
  where g.event_id = '1fe06bdb-7905-48dc-ae51-f09ecc5b612a'
),
nombres as (
  select n, row_number() over () as i
  from unnest(array[
    'Sofía Martínez', 'Mateo González', 'Valentina López', 'Benjamín Rodríguez',
    'Martina Fernández', 'Thiago Pérez', 'Catalina Gómez', 'Lautaro Díaz',
    'Emilia Sánchez', 'Joaquín Romero', 'Isabella Torres', 'Felipe Álvarez',
    'Mía Ruiz', 'Santino Herrera', 'Delfina Medina', 'Bautista Castro',
    'Julieta Suárez', 'Tomás Rojas', 'Olivia Acosta', 'Facundo Molina'
  ]) as n
)
insert into trivia_attempts (game_id, player_name, started_at, submitted_at, answers, correct_count, duration_ms)
select
  j.id,
  nm.n,
  now() - interval '10 minutes',
  now() - interval '10 minutes' + make_interval(secs => 70 + nm.i * 9),
  '{"_demo": true}'::jsonb,
  -- Los primeros 13 con todas bien, después va bajando de a una cada dos.
  greatest(0, j.total - greatest(0, (nm.i::int - 12) / 2)),
  (70 + nm.i * 9) * 1000 + (nm.i * 137) % 1000
from juego j
cross join nombres nm;

-- 2) Borrar los de ejemplo (correr cuando termines de mirar)
-- delete from trivia_attempts
-- where answers = '{"_demo": true}'::jsonb
--   and game_id = (select id from trivia_games where event_id = '1fe06bdb-7905-48dc-ae51-f09ecc5b612a');
