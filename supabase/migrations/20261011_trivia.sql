-- ============================================================
-- Trivia para jugar durante la fiesta (botón en la página de fotos del QR)
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- Un juego por evento. El anfitrión arma preguntas de multiple choice y lo
-- abre en vivo (borrador → abierto → cerrado). Gana quien más acierta; si
-- empatan, quien tardó menos.
--
-- Para que no se pueda hacer trampa:
-- - El tiempo lo mide el servidor (started_at / submitted_at), no el celular.
-- - Las respuestas correctas nunca salen de la base mientras el juego está
--   abierto: las RPC públicas devuelven las preguntas sin `correct_index`.
-- - Cada respuesta se guarda al elegirla (responder_pregunta). Lo que llega
--   después del tiempo límite (+ unos segundos de gracia) se ignora y se
--   corrige con lo que ya estaba guardado.
-- - Al cerrar el juego, los intentos sin enviar se corrigen solos con lo que
--   alcanzaron a responder (trigger en trivia_games).
-- ============================================================

create table if not exists trivia_games (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade not null unique,
  title text not null default 'Trivia',
  time_limit_seconds int not null default 300 check (time_limit_seconds between 30 and 1800),
  status text not null default 'borrador' check (status in ('borrador', 'abierto', 'cerrado')),
  opened_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists trivia_questions (
  id uuid primary key default gen_random_uuid(),
  game_id uuid references trivia_games(id) on delete cascade not null,
  position int not null default 0,
  question text not null check (length(trim(question)) > 0),
  -- Array de 2 a 4 textos. correct_index apunta a uno de ellos.
  options jsonb not null check (
    jsonb_typeof(options) = 'array'
    and jsonb_array_length(options) between 2 and 4
  ),
  correct_index int not null check (correct_index >= 0),
  created_at timestamptz not null default now(),
  check (correct_index < jsonb_array_length(options))
);

create index if not exists trivia_questions_game_id_idx on trivia_questions (game_id, position);

create table if not exists trivia_attempts (
  id uuid primary key default gen_random_uuid(),
  game_id uuid references trivia_games(id) on delete cascade not null,
  -- Lo guarda el navegador del invitado: es su "llave" para seguir jugando
  -- y enviar. Nunca se muestra en el ranking.
  token uuid not null unique default gen_random_uuid(),
  player_name text not null,
  started_at timestamptz not null default now(),
  -- { "<id de la pregunta>": <índice de la opción elegida> }
  answers jsonb not null default '{}'::jsonb,
  submitted_at timestamptz,
  correct_count int,
  duration_ms int
);

create index if not exists trivia_attempts_game_id_idx on trivia_attempts (game_id);

-- ============================================================
-- Permisos del panel: el dueño del evento (y el superadmin) arma el juego y
-- las preguntas directo sobre las tablas. Los intentos solo los ve y borra:
-- se crean y se corrigen únicamente vía las RPC de más abajo.
-- ============================================================

grant select, insert, update, delete on public.trivia_games to authenticated;
grant select, insert, update, delete on public.trivia_questions to authenticated;
grant select, delete on public.trivia_attempts to authenticated;

alter table trivia_games enable row level security;
alter table trivia_questions enable row level security;
alter table trivia_attempts enable row level security;

drop policy if exists "admin gestiona el juego de su evento" on trivia_games;
create policy "admin gestiona el juego de su evento"
  on trivia_games for all
  using (exists (
    select 1 from events
    where events.id = trivia_games.event_id
    and events.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from events
    where events.id = trivia_games.event_id
    and events.owner_user_id = auth.uid()
  ));

drop policy if exists "admin gestiona las preguntas de su juego" on trivia_questions;
create policy "admin gestiona las preguntas de su juego"
  on trivia_questions for all
  using (exists (
    select 1 from trivia_games tg
    join events e on e.id = tg.event_id
    where tg.id = trivia_questions.game_id
    and e.owner_user_id = auth.uid()
  ))
  with check (exists (
    select 1 from trivia_games tg
    join events e on e.id = tg.event_id
    where tg.id = trivia_questions.game_id
    and e.owner_user_id = auth.uid()
  ));

drop policy if exists "admin ve y borra los intentos de su juego" on trivia_attempts;
create policy "admin ve y borra los intentos de su juego"
  on trivia_attempts for all
  using (exists (
    select 1 from trivia_games tg
    join events e on e.id = tg.event_id
    where tg.id = trivia_attempts.game_id
    and e.owner_user_id = auth.uid()
  ));

drop policy if exists "superadmin gestiona juegos" on trivia_games;
create policy "superadmin gestiona juegos"
  on trivia_games for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

drop policy if exists "superadmin gestiona preguntas" on trivia_questions;
create policy "superadmin gestiona preguntas"
  on trivia_questions for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()))
  with check (exists (select 1 from superadmins s where s.user_id = auth.uid()));

drop policy if exists "superadmin gestiona intentos" on trivia_attempts;
create policy "superadmin gestiona intentos"
  on trivia_attempts for all
  using (exists (select 1 from superadmins s where s.user_id = auth.uid()));

-- ============================================================
-- Corrección (interna, no se expone a los invitados)
-- ============================================================

-- Cuenta cuántas de las respuestas coinciden con la correcta. Las claves que
-- no son preguntas de este juego se ignoran solas (no matchean el join).
create or replace function public.trivia_contar_aciertos(p_game_id uuid, p_answers jsonb)
returns int
language sql
stable
set search_path = public
as $$
  select count(*)::int
  from public.trivia_questions q
  where q.game_id = p_game_id
    and p_answers ? q.id::text
    and jsonb_typeof(p_answers -> q.id::text) = 'number'
    and (p_answers ->> q.id::text)::int = q.correct_index;
$$;

-- Cierra un intento: corrige y calcula cuánto tardó. La duración nunca
-- supera el tiempo límite (si llegó tarde, cuenta como que usó todo).
create or replace function public.trivia_finalizar_intento(p_attempt_id uuid, p_end timestamptz)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_limit int;
  v_end timestamptz;
begin
  select * into v_attempt from trivia_attempts where id = p_attempt_id for update;
  if v_attempt.submitted_at is not null then
    return;
  end if;

  select time_limit_seconds into v_limit from trivia_games where id = v_attempt.game_id;
  v_end := least(p_end, v_attempt.started_at + make_interval(secs => v_limit));

  update trivia_attempts set
    submitted_at = v_end,
    correct_count = trivia_contar_aciertos(v_attempt.game_id, v_attempt.answers),
    duration_ms = greatest(0, (extract(epoch from (v_end - v_attempt.started_at)) * 1000)::int)
  where id = p_attempt_id;
end;
$$;

revoke execute on function public.trivia_contar_aciertos(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.trivia_finalizar_intento(uuid, timestamptz) from public, anon, authenticated;

-- Al abrir o cerrar el juego desde el panel se anotan las horas; al cerrarlo,
-- los que estaban jugando quedan corregidos con lo que alcanzaron a responder.
create or replace function public.trivia_cambio_estado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if new.status is distinct from old.status then
    if new.status = 'abierto' then
      new.opened_at := now();
      new.closed_at := null;
    elsif new.status = 'cerrado' then
      new.closed_at := now();
      for v_id in
        select id from trivia_attempts where game_id = new.id and submitted_at is null
      loop
        perform trivia_finalizar_intento(v_id, now());
      end loop;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trivia_cambio_estado on trivia_games;
create trigger trivia_cambio_estado
  before update on trivia_games
  for each row execute function public.trivia_cambio_estado();

-- ============================================================
-- RPC públicas (sin login): las usa /fotos y /juego
-- ============================================================

-- Estado liviano del juego: para mostrar u ocultar el botón en /fotos y para
-- la pantalla de inicio. Sin preguntas. null si el evento no tiene juego.
create or replace function public.info_juego(p_event_id uuid)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'status', g.status,
    'title', g.title,
    'time_limit_seconds', g.time_limit_seconds,
    'question_count', (select count(*) from public.trivia_questions q where q.game_id = g.id)
  )
  from public.trivia_games g
  where g.event_id = p_event_id;
$$;

grant execute on function public.info_juego(uuid) to anon, authenticated;

-- Preguntas sin la respuesta correcta (uso interno de las dos de abajo).
create or replace function public.trivia_preguntas_publicas(p_game_id uuid)
returns json
language sql
stable
set search_path = public
as $$
  select coalesce(json_agg(json_build_object(
    'id', q.id,
    'question', q.question,
    'options', q.options
  ) order by q.position, q.created_at), '[]'::json)
  from public.trivia_questions q
  where q.game_id = p_game_id;
$$;

revoke execute on function public.trivia_preguntas_publicas(uuid) from public, anon, authenticated;

-- Arranca un intento: desde acá corre el reloj. Recién ahora se mandan las
-- preguntas, así nadie las lee antes de empezar.
create or replace function public.empezar_juego(p_event_id uuid, p_name text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game trivia_games;
  v_name text := texto_invitado(p_name, 40);
  v_attempt trivia_attempts;
begin
  select * into v_game from trivia_games where event_id = p_event_id;
  if v_game.id is null or v_game.status <> 'abierto' then
    raise exception 'El juego no está abierto.';
  end if;
  if v_name is null then
    raise exception 'Escribí tu nombre para jugar.';
  end if;
  if not exists (select 1 from trivia_questions where game_id = v_game.id) then
    raise exception 'El juego todavía no tiene preguntas.';
  end if;
  if (select count(*) from trivia_attempts where game_id = v_game.id) >= 1000 then
    raise exception 'Se llegó al máximo de jugadores.';
  end if;

  insert into trivia_attempts (game_id, player_name)
  values (v_game.id, v_name)
  returning * into v_attempt;

  return json_build_object(
    'token', v_attempt.token,
    'player_name', v_attempt.player_name,
    'started_at', v_attempt.started_at,
    'server_now', now(),
    'time_limit_seconds', v_game.time_limit_seconds,
    'answers', v_attempt.answers,
    'questions', trivia_preguntas_publicas(v_game.id)
  );
end;
$$;

grant execute on function public.empezar_juego(uuid, text) to anon, authenticated;

-- Para volver a la página (se cerró, se recargó, se quedó sin batería):
-- devuelve el intento y, si todavía puede jugar, las preguntas y lo que ya
-- había respondido. El reloj siguió corriendo mientras tanto.
create or replace function public.mi_intento_juego(p_token uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_game trivia_games;
  v_playing boolean;
begin
  select * into v_attempt from trivia_attempts where token = p_token;
  if v_attempt.id is null then
    return null;
  end if;
  select * into v_game from trivia_games where id = v_attempt.game_id;

  v_playing := v_attempt.submitted_at is null and v_game.status = 'abierto';

  return json_build_object(
    'player_name', v_attempt.player_name,
    'started_at', v_attempt.started_at,
    'submitted_at', v_attempt.submitted_at,
    'server_now', now(),
    'time_limit_seconds', v_game.time_limit_seconds,
    'answers', case when v_playing then v_attempt.answers end,
    'questions', case when v_playing then trivia_preguntas_publicas(v_game.id) end
  );
end;
$$;

grant execute on function public.mi_intento_juego(uuid) to anon, authenticated;

-- Guarda una respuesta apenas se elige (se puede cambiar mientras haya
-- tiempo). Fuera de tiempo no hace nada: queda lo último guardado. Los 15 s
-- de gracia (acá y en enviar_juego) son por la conexión: el envío automático
-- al llegar a 0 tarda un poco en llegar.
create or replace function public.responder_pregunta(p_token uuid, p_question_id uuid, p_option int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_game trivia_games;
  v_options int;
begin
  select * into v_attempt from trivia_attempts where token = p_token;
  if v_attempt.id is null then
    raise exception 'Intento no encontrado';
  end if;
  select * into v_game from trivia_games where id = v_attempt.game_id;

  if v_attempt.submitted_at is not null
     or v_game.status <> 'abierto'
     or now() > v_attempt.started_at + make_interval(secs => v_game.time_limit_seconds + 15) then
    return false;
  end if;

  select jsonb_array_length(options) into v_options
  from trivia_questions
  where id = p_question_id and game_id = v_game.id;
  if v_options is null or p_option is null or p_option < 0 or p_option >= v_options then
    raise exception 'Respuesta inválida';
  end if;

  update trivia_attempts
  set answers = answers || jsonb_build_object(p_question_id::text, p_option)
  where id = v_attempt.id;

  return true;
end;
$$;

grant execute on function public.responder_pregunta(uuid, uuid, int) to anon, authenticated;

-- Envía el intento. Si llega a tiempo, se toman las respuestas que manda el
-- celular (por si alguna no se llegó a guardar). Si llega tarde, se corrige
-- solo con lo que ya estaba guardado. Si ya estaba enviado, no cambia nada:
-- se puede reintentar sin miedo si se cortó la conexión.
create or replace function public.enviar_juego(p_token uuid, p_answers jsonb default null)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_game trivia_games;
begin
  select * into v_attempt from trivia_attempts where token = p_token;
  if v_attempt.id is null then
    raise exception 'Intento no encontrado';
  end if;
  select * into v_game from trivia_games where id = v_attempt.game_id;

  if v_attempt.submitted_at is null then
    if v_game.status = 'abierto'
       and now() <= v_attempt.started_at + make_interval(secs => v_game.time_limit_seconds + 15)
       and jsonb_typeof(p_answers) = 'object' then
      update trivia_attempts
      set answers = answers || p_answers
      where id = v_attempt.id;
    end if;
    perform trivia_finalizar_intento(v_attempt.id, now());
  end if;

  select * into v_attempt from trivia_attempts where id = v_attempt.id;
  return json_build_object(
    'correct_count', v_attempt.correct_count,
    'total', (select count(*) from trivia_questions where game_id = v_game.id),
    'duration_ms', v_attempt.duration_ms
  );
end;
$$;

grant execute on function public.enviar_juego(uuid, jsonb) to anon, authenticated;

-- Ranking en vivo: top 10 de los que ya enviaron + mi puesto (si paso mi
-- token). Con el juego cerrado, también mis respuestas con la correcta de
-- cada pregunta.
create or replace function public.ranking_juego(p_event_id uuid, p_token uuid default null)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_game trivia_games;
  v_top json;
  v_me json;
  v_review json;
  v_attempt trivia_attempts;
begin
  select * into v_game from trivia_games where event_id = p_event_id;
  if v_game.id is null then
    return null;
  end if;

  -- rank(): dos con mismo puntaje y mismo tiempo comparten el puesto.
  with ranking as (
    select a.token, a.player_name, a.correct_count, a.duration_ms,
           rank() over (order by a.correct_count desc, a.duration_ms asc) as position
    from trivia_attempts a
    where a.game_id = v_game.id and a.submitted_at is not null
  )
  select
    (select coalesce(json_agg(json_build_object(
       'name', r.player_name,
       'correct', r.correct_count,
       'duration_ms', r.duration_ms,
       'position', r.position,
       'me', p_token is not null and r.token = p_token
     ) order by r.position, r.duration_ms), '[]'::json)
     from (select * from ranking order by position, duration_ms limit 10) r),
    (select json_build_object(
       'name', r.player_name,
       'correct', r.correct_count,
       'duration_ms', r.duration_ms,
       'position', r.position
     ) from ranking r where p_token is not null and r.token = p_token)
  into v_top, v_me;

  if p_token is not null then
    if v_game.status = 'cerrado' then
      select * into v_attempt from trivia_attempts where token = p_token and game_id = v_game.id;
      if v_attempt.id is not null then
        select coalesce(json_agg(json_build_object(
          'question', q.question,
          'options', q.options,
          'correct_index', q.correct_index,
          'chosen', case when jsonb_typeof(v_attempt.answers -> q.id::text) = 'number'
                         then (v_attempt.answers ->> q.id::text)::int end
        ) order by q.position, q.created_at), '[]'::json)
        into v_review
        from trivia_questions q
        where q.game_id = v_game.id;
      end if;
    end if;
  end if;

  return json_build_object(
    'status', v_game.status,
    'title', v_game.title,
    'total', (select count(*) from trivia_questions where game_id = v_game.id),
    'players', (select count(*) from trivia_attempts where game_id = v_game.id and submitted_at is not null),
    'top', v_top,
    'me', v_me,
    'review', v_review
  );
end;
$$;

grant execute on function public.ranking_juego(uuid, uuid) to anon, authenticated;
