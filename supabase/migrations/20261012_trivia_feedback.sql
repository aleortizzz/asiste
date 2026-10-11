-- ============================================================
-- Trivia: verde / rojo al responder, y «Ver mis respuestas» al terminar
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "asiste")
--
-- - responder_pregunta ahora dice si la respuesta es correcta (sin decir
--   cuál era la correcta si le erró). Por eso cada respuesta queda FIJA: si
--   se pudiera cambiar, alguien probaría opciones hasta que dé verde.
-- - enviar_juego ya no pisa respuestas guardadas: solo suma las que no se
--   llegaron a guardar (por la conexión).
-- - mi_intento_juego devuelve también bien / mal de lo ya respondido, para
--   que al recargar se sigan viendo los colores.
-- - ranking_juego devuelve mis respuestas apenas envío (bien / mal). La
--   correcta de cada pregunta recién con el juego cerrado, así no se la pasan
--   a los que siguen jugando.
-- ============================================================

-- Cambia el tipo de retorno (boolean → json): hay que borrarla antes.
drop function if exists public.responder_pregunta(uuid, uuid, int);

create or replace function public.responder_pregunta(p_token uuid, p_question_id uuid, p_option int)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_attempt trivia_attempts;
  v_game trivia_games;
  v_question trivia_questions;
begin
  select * into v_attempt from trivia_attempts where token = p_token for update;
  if v_attempt.id is null then
    raise exception 'Intento no encontrado';
  end if;
  select * into v_game from trivia_games where id = v_attempt.game_id;

  select * into v_question from trivia_questions
  where id = p_question_id and game_id = v_game.id;
  if v_question.id is null or p_option is null or p_option < 0 or p_option >= jsonb_array_length(v_question.options) then
    raise exception 'Respuesta inválida';
  end if;

  -- Ya respondida: no se cambia. Devolvemos el resultado de la que quedó.
  if v_attempt.answers ? p_question_id::text then
    return json_build_object(
      'ok', true,
      'locked', true,
      'option', (v_attempt.answers ->> p_question_id::text)::int,
      'correct', (v_attempt.answers ->> p_question_id::text)::int = v_question.correct_index
    );
  end if;

  -- Fuera de tiempo, ya enviado o juego cerrado: no se guarda.
  if v_attempt.submitted_at is not null
     or v_game.status <> 'abierto'
     or now() > v_attempt.started_at + make_interval(secs => v_game.time_limit_seconds + 15) then
    return json_build_object('ok', false);
  end if;

  update trivia_attempts
  set answers = answers || jsonb_build_object(p_question_id::text, p_option)
  where id = v_attempt.id;

  return json_build_object('ok', true, 'correct', p_option = v_question.correct_index);
end;
$$;

grant execute on function public.responder_pregunta(uuid, uuid, int) to anon, authenticated;

-- Lo guardado gana: `p_answers || answers` (a igual clave queda la de la
-- derecha, o sea la que ya estaba en la base).
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
      set answers = p_answers || answers
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

-- { "<id de la pregunta>": true | false } de lo ya respondido (uso interno).
create or replace function public.trivia_resultados(p_game_id uuid, p_answers jsonb)
returns json
language sql
stable
set search_path = public
as $$
  select coalesce(json_object_agg(q.id, (p_answers ->> q.id::text)::int = q.correct_index), '{}'::json)
  from public.trivia_questions q
  where q.game_id = p_game_id
    and jsonb_typeof(p_answers -> q.id::text) = 'number';
$$;

revoke execute on function public.trivia_resultados(uuid, jsonb) from public, anon, authenticated;

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
    'results', case when v_playing then trivia_resultados(v_game.id, v_attempt.answers) end,
    'questions', case when v_playing then trivia_preguntas_publicas(v_game.id) end
  );
end;
$$;

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
  v_closed boolean;
begin
  select * into v_game from trivia_games where event_id = p_event_id;
  if v_game.id is null then
    return null;
  end if;
  v_closed := v_game.status = 'cerrado';

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

  -- Mis respuestas, solo si ya envié. La correcta, solo con el juego cerrado.
  if p_token is not null then
    select * into v_attempt from trivia_attempts
    where token = p_token and game_id = v_game.id and submitted_at is not null;
    if v_attempt.id is not null then
      select coalesce(json_agg(json_build_object(
        'question', q.question,
        'options', q.options,
        'chosen', a.chosen,
        'is_correct', a.chosen = q.correct_index,
        'correct_index', case when v_closed then q.correct_index end
      ) order by q.position, q.created_at), '[]'::json)
      into v_review
      from trivia_questions q
      cross join lateral (
        select case when jsonb_typeof(v_attempt.answers -> q.id::text) = 'number'
                    then (v_attempt.answers ->> q.id::text)::int end as chosen
      ) a
      where q.game_id = v_game.id;
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
