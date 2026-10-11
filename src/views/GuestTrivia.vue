<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useGuestTheme } from '../composables/useGuestTheme'
import { seededShuffle, formatDuration } from '../lib/trivia'
import { Trophy, Timer, ChevronLeft, ChevronRight, Check, X, Send, Camera, Hourglass, RotateCw, ListChecks, Flag } from '@lucide/vue'

// Trivia para los invitados (/juego/:eventId, se llega desde la página de
// fotos del QR). Sin login: el intento se identifica con un token que queda
// en este navegador. El tiempo lo mide el servidor y las respuestas se guardan
// una por una (ver migrations/20261011_trivia.sql); acá solo se muestran.
const route = useRoute()
const eventId = route.params.eventId
const TOKEN_KEY = `trivia-token-${eventId}`
const NAME_KEY = 'guest-photo-name' // el mismo nombre que en la página de fotos
const answersKey = (t) => `trivia-answers-${t}`

function read(key) {
  try {
    return localStorage.getItem(key)
  } catch {
    return null
  }
}
function write(key, value) {
  try {
    if (value == null) localStorage.removeItem(key)
    else localStorage.setItem(key, value)
  } catch {
    /* modo privado */
  }
}

const info = ref(null) // info_fotos_evento(): plantilla y colores
const { theme, pageStyle } = useGuestTheme(info)
const game = ref(null) // info_juego(): { status, title, time_limit_seconds, question_count }
const token = ref(read(TOKEN_KEY))

// loading | waiting | intro | playing | summary | sending | result | removed
const screen = ref('loading')
const message = ref('') // error para mostrar en la pantalla actual

const displayFont = computed(() => ({ fontFamily: theme.value.display, fontWeight: theme.value.displayWeight }))

// --- Arranque ---------------------------------------------------------------------------
async function loadGame() {
  const { data, error } = await supabase.rpc('info_juego', { p_event_id: eventId })
  if (!error) game.value = data
  return !error
}

onMounted(async () => {
  const [a] = await Promise.all([supabase.rpc('info_fotos_evento', { p_event_id: eventId }), loadGame()])
  if (!a.error && a.data) info.value = a.data
  await decideScreen()
})

// Decide en qué pantalla arrancar según el juego y si este celular ya jugó.
async function decideScreen() {
  if (token.value) {
    const { data, error } = await supabase.rpc('mi_intento_juego', { p_token: token.value })
    if (!error && data) {
      if (!data.submitted_at && data.questions) return setupPlay(data)
      return showResult()
    }
    if (!error) forgetAttempt() // lo borraron desde el panel (o reiniciaron el juego)
  }
  if (game.value?.status === 'abierto') screen.value = 'intro'
  else if (game.value?.status === 'cerrado') showResult()
  else screen.value = 'waiting'
}

function forgetAttempt() {
  if (token.value) write(answersKey(token.value), null)
  write(TOKEN_KEY, null)
  token.value = null
}

// Antes de que abran el juego: miramos cada 5 s y pasamos solos al inicio.
let waitTimer = null
watch(screen, (s) => {
  clearInterval(waitTimer)
  if (s === 'waiting') {
    waitTimer = setInterval(async () => {
      if (document.visibilityState !== 'visible') return
      await loadGame()
      if (game.value?.status === 'abierto') screen.value = 'intro'
    }, 5000)
  }
})

// --- Inicio -----------------------------------------------------------------------------
const name = ref(read(NAME_KEY) || '')
const starting = ref(false)

async function start() {
  if (starting.value) return
  const clean = name.value.trim()
  if (!clean) return (message.value = 'Escribí tu nombre para jugar.')
  message.value = ''
  starting.value = true
  const { data, error } = await supabase.rpc('empezar_juego', { p_event_id: eventId, p_name: clean })
  starting.value = false
  if (error) {
    message.value = error.message || 'No se pudo empezar. Probá de nuevo.'
    await loadGame()
    if (game.value?.status === 'cerrado') showResult()
    else if (game.value?.status !== 'abierto') screen.value = 'waiting'
    return
  }
  write(NAME_KEY, clean)
  token.value = data.token
  write(TOKEN_KEY, data.token)
  setupPlay(data)
}

// --- Jugando ----------------------------------------------------------------------------
const questions = ref([]) // [{ id, question, options: [{ text, i }] }] ya mezcladas
const answers = ref({}) // { [id de la pregunta]: índice original de la opción }
const results = ref({}) // { [id de la pregunta]: true | false } según el servidor
const checking = ref(null) // id de la pregunta que se está corrigiendo
const current = ref(0)
const playerName = ref('')
let deadline = 0 // en hora del servidor (ms)
let offset = 0 // hora del servidor - hora de este celular
const now = ref(Date.now())
let tick = null

const remainingMs = computed(() => Math.max(0, deadline - (now.value + offset)))
const remainingText = computed(() => {
  const s = Math.ceil(remainingMs.value / 1000)
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
})
const hurry = computed(() => remainingMs.value <= 30000)
const answeredCount = computed(() => questions.value.filter((q) => answers.value[q.id] != null).length)
const unanswered = computed(() =>
  questions.value.map((q, i) => (answers.value[q.id] == null ? i : -1)).filter((i) => i >= 0),
)
const question = computed(() => questions.value[current.value])

function setupPlay(data) {
  // Mismo token → mismo orden (de preguntas y de opciones), aunque recargue.
  questions.value = seededShuffle(data.questions, token.value).map((q) => ({
    id: q.id,
    question: q.question,
    options: seededShuffle(
      q.options.map((text, i) => ({ text, i })),
      `${token.value}:${q.id}`,
    ),
  }))
  let local = {}
  try {
    local = JSON.parse(read(answersKey(token.value)) || '{}')
  } catch {
    /* basura vieja */
  }
  // Lo del servidor gana: una respuesta guardada ya no se puede cambiar.
  answers.value = { ...local, ...(data.answers || {}) }
  results.value = data.results || {}
  playerName.value = data.player_name

  offset = Date.parse(data.server_now) - Date.now()
  deadline = Date.parse(data.started_at) + data.time_limit_seconds * 1000
  now.value = Date.now()

  const firstOpen = questions.value.findIndex((q) => answers.value[q.id] == null)
  current.value = firstOpen >= 0 ? firstOpen : 0
  screen.value = firstOpen >= 0 ? 'playing' : 'summary'

  startTick()
}

// Al llegar a 0 se envía solo.
function startTick() {
  clearInterval(tick)
  tick = setInterval(() => {
    now.value = Date.now()
    if (remainingMs.value <= 0) submit()
  }, 250)
}

// Al tocar una opción el servidor dice si es correcta: se pinta verde o roja y
// queda fija (si se pudiera cambiar, alguien probaría hasta que dé verde). Si
// le erró, no se muestra cuál era la correcta, así no se la pasan en la mesa.
let advanceTimer = null
async function choose(option) {
  const q = question.value
  if (!q || screen.value !== 'playing' || answers.value[q.id] != null || checking.value) return
  answers.value = { ...answers.value, [q.id]: option.i }
  write(answersKey(token.value), JSON.stringify(answers.value))
  checking.value = q.id

  const { data, error } = await supabase.rpc('responder_pregunta', {
    p_token: token.value,
    p_question_id: q.id,
    p_option: option.i,
  })
  checking.value = null
  if (error?.message?.includes('no encontrado')) return removed()
  // ok false = se terminó el tiempo o cerraron el juego: enviamos lo que hay.
  if (data?.ok === false) return submit()
  if (data) {
    // Si ya estaba respondida (otra pestaña), vale la que quedó guardada.
    if (data.locked) answers.value = { ...answers.value, [q.id]: data.option }
    results.value = { ...results.value, [q.id]: data.correct }
  }
  // Sin conexión queda elegida sin color; se manda igual al enviar.

  // Pasa sola a la próxima sin responder (después de ver el color). Si no
  // queda ninguna, al resumen para enviar.
  clearTimeout(advanceTimer)
  advanceTimer = setTimeout(() => {
    if (screen.value !== 'playing' || question.value?.id !== q.id) return
    const next = unanswered.value.find((i) => i > current.value) ?? unanswered.value[0]
    if (next == null) screen.value = 'summary'
    else current.value = next
  }, 900)
}

// Estado de una opción para pintarla.
function optionState(q, opt) {
  if (answers.value[q.id] !== opt.i) return ''
  if (checking.value === q.id) return 'checking'
  if (results.value[q.id] === true) return 'right'
  if (results.value[q.id] === false) return 'wrong'
  return 'chosen'
}

function go(delta) {
  clearTimeout(advanceTimer)
  const target = current.value + delta
  if (target >= questions.value.length) screen.value = 'summary'
  else if (target >= 0) current.value = target
}

function goTo(i) {
  clearTimeout(advanceTimer)
  current.value = i
  screen.value = 'playing'
}

// --- Enviar -----------------------------------------------------------------------------
const myResult = ref(null) // { correct_count, total, duration_ms }

async function submit() {
  if (screen.value === 'sending' || screen.value === 'result' || screen.value === 'removed') return
  clearInterval(tick)
  clearTimeout(advanceTimer)
  message.value = ''
  screen.value = 'sending'
  const { data, error } = await supabase.rpc('enviar_juego', { p_token: token.value, p_answers: answers.value })
  if (error) {
    if (error.message?.includes('no encontrado')) return removed()
    // Sin conexión: se puede reintentar; el servidor no pierde lo ya guardado.
    message.value = 'No se pudieron enviar tus respuestas. Revisá la conexión y probá de nuevo.'
    screen.value = 'summary'
    // Si todavía hay tiempo, el reloj sigue (y al llegar a 0 reintenta solo).
    if (remainingMs.value > 0) startTick()
    return
  }
  myResult.value = data
  write(answersKey(token.value), null)
  showResult()
}

function removed() {
  clearInterval(tick)
  forgetAttempt()
  screen.value = 'removed'
}

async function playAgain() {
  message.value = ''
  screen.value = 'loading'
  await loadGame()
  await decideScreen()
}

// --- Resultado y ranking ----------------------------------------------------------------
const ranking = ref(null) // ranking_juego(): { status, title, total, players, top, me, review }
let rankTimer = null

async function fetchRanking() {
  const { data, error } = await supabase.rpc('ranking_juego', { p_event_id: eventId, p_token: token.value })
  if (!error && data) ranking.value = data
}

async function showResult() {
  screen.value = 'result'
  await fetchRanking()
  clearInterval(rankTimer)
  // En vivo mientras el juego sigue abierto; cerrado ya no cambia.
  rankTimer = setInterval(() => {
    if (document.visibilityState !== 'visible') return
    if (ranking.value?.status === 'cerrado') return clearInterval(rankTimer)
    fetchRanking()
  }, 5000)
}

const me = computed(() => ranking.value?.me)
const closed = computed(() => ranking.value?.status === 'cerrado')
const meInTop = computed(() => ranking.value?.top?.some((r) => r.me))
const ord = (n) => `${n}.º`

const reviewOpen = ref(false)
// is_correct lo manda el servidor desde 20261012_trivia_feedback.sql; si no
// viene (SQL viejo), se calcula con la correcta, que con el juego cerrado sí está.
const review = computed(() =>
  (ranking.value?.review ?? []).map((r) => ({
    ...r,
    is_correct: r.is_correct ?? (r.chosen != null && r.chosen === r.correct_index),
  })),
)
const reviewRight = computed(() => review.value.filter((r) => r.is_correct).length)

onUnmounted(() => {
  clearInterval(tick)
  clearInterval(waitTimer)
  clearInterval(rankTimer)
  clearTimeout(advanceTimer)
})

const LETTERS = ['A', 'B', 'C', 'D']
const photosLink = { name: 'guest-photos', params: { eventId } }
</script>

<template>
  <div class="trivia min-h-dvh" :style="pageStyle">
    <!-- ============ CARGANDO ============ -->
    <div v-if="screen === 'loading'" class="grid min-h-dvh place-items-center">
      <span class="spinner"></span>
    </div>

    <!-- ============ TODAVÍA NO ABRIÓ ============ -->
    <div v-else-if="screen === 'waiting'" class="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center px-6 text-center">
      <div class="badge grid h-20 w-20 place-items-center rounded-full"><Hourglass :size="34" /></div>
      <h1 class="mt-6 text-4xl leading-tight" :style="displayFont" style="color: var(--accent-text)">
        {{ game?.title || 'Trivia' }}
      </h1>
      <p class="mt-3" style="color: var(--muted)">
        El juego todavía no empezó. Cuando lo abran, esta pantalla cambia sola.
      </p>
      <router-link :to="photosLink" class="ghost mt-8 inline-flex items-center gap-2 rounded-full px-5 py-2.5 text-sm font-semibold">
        <Camera :size="16" /> Ir a las fotos
      </router-link>
    </div>

    <!-- ============ INICIO ============ -->
    <form
      v-else-if="screen === 'intro'"
      @submit.prevent="start"
      class="mx-auto flex min-h-dvh max-w-md flex-col justify-center px-6 py-10"
    >
      <div class="badge mx-auto grid h-20 w-20 place-items-center rounded-full"><Trophy :size="34" /></div>
      <h1 class="mt-6 text-center text-4xl leading-tight" :style="displayFont" style="color: var(--accent-text)">
        {{ game.title }}
      </h1>
      <ul class="rules mt-6 space-y-2.5 rounded-3xl p-5 text-[0.95rem]">
        <li>
          <strong>{{ game.question_count }} preguntas</strong> y
          <strong>{{ Math.round(game.time_limit_seconds / 60) }} {{ Math.round(game.time_limit_seconds / 60) === 1 ? 'minuto' : 'minutos' }}</strong>.
          El reloj arranca cuando tocás «Empezar».
        </li>
        <li>Gana quien más acierta. Si hay empate, gana quien terminó más rápido.</li>
        <li>Hay <strong>una sola partida</strong> por celular.</li>
        <li>Al tocar una opción vas a ver si acertaste. <strong>No se puede cambiar</strong>, así que pensala bien.</li>
      </ul>
      <label class="mt-6 block text-sm font-semibold" for="trivia-name">Tu nombre (así aparecés en el ranking)</label>
      <input
        id="trivia-name"
        v-model="name"
        type="text"
        autocomplete="name"
        maxlength="40"
        placeholder="Nombre y apellido"
        class="field mt-2 w-full rounded-full px-5 py-3.5 text-base"
      />
      <p v-if="message" class="mt-3 text-sm font-semibold" style="color: #dc2626">{{ message }}</p>
      <button type="submit" :disabled="starting" class="cta mt-5 w-full rounded-full py-4 text-lg font-bold disabled:opacity-60">
        {{ starting ? 'Preparando…' : 'Empezar' }}
      </button>
      <router-link :to="photosLink" class="mt-3 text-center text-sm font-semibold" style="color: var(--muted)">
        Volver a las fotos
      </router-link>
    </form>

    <!-- ============ JUGANDO / RESUMEN ============ -->
    <div v-else-if="screen === 'playing' || screen === 'summary'" class="mx-auto flex min-h-dvh max-w-md flex-col">
      <header class="bar sticky top-0 z-10 px-5 pt-4 pb-3">
        <div class="flex items-center justify-between gap-3">
          <p class="text-sm font-semibold" style="color: var(--muted)">
            <template v-if="screen === 'playing'">Pregunta {{ current + 1 }} de {{ questions.length }}</template>
            <template v-else>{{ answeredCount }} de {{ questions.length }} respondidas</template>
          </p>
          <span
            class="timer inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-base font-bold tabular-nums"
            :class="{ hurry }"
          >
            <Timer :size="16" /> {{ remainingText }}
          </span>
        </div>
        <div class="track mt-3 h-1.5 overflow-hidden rounded-full">
          <div class="fill h-full rounded-full transition-all duration-300" :style="{ width: `${(answeredCount / questions.length) * 100}%` }"></div>
        </div>
      </header>

      <!-- Una pregunta -->
      <main v-if="screen === 'playing' && question" :key="question.id" class="q-enter flex-1 px-5 pt-4 pb-32">
        <h2 class="text-2xl leading-snug font-bold">{{ question.question }}</h2>
        <div class="mt-6 space-y-3">
          <button
            v-for="(opt, j) in question.options"
            :key="opt.i"
            type="button"
            @click="choose(opt)"
            :disabled="answers[question.id] != null && answers[question.id] !== opt.i"
            class="option flex w-full items-center gap-3 rounded-2xl p-4 text-left text-base font-semibold"
            :class="optionState(question, opt)"
          >
            <span class="letter grid h-8 w-8 shrink-0 place-items-center rounded-full text-sm font-bold">{{ LETTERS[j] }}</span>
            <span class="min-w-0 flex-1">{{ opt.text }}</span>
            <Check v-if="optionState(question, opt) === 'right' || optionState(question, opt) === 'chosen'" :size="20" class="shrink-0" />
            <X v-else-if="optionState(question, opt) === 'wrong'" :size="20" class="shrink-0" />
            <span v-else-if="optionState(question, opt) === 'checking'" class="mini-spinner shrink-0"></span>
          </button>
        </div>
        <p
          v-if="results[question.id] != null"
          class="verdict mt-5 text-center text-lg font-bold"
          :class="results[question.id] ? 'right' : 'wrong'"
        >
          {{ results[question.id] ? '¡Correcto! 🎉' : 'Incorrecto' }}
        </p>
      </main>

      <!-- Resumen antes de enviar -->
      <main v-else class="q-enter flex-1 px-5 pt-6 pb-10 text-center">
        <h2 class="text-3xl leading-tight" :style="displayFont" style="color: var(--accent-text)">
          {{ unanswered.length ? '¡Casi!' : '¡Listo!' }}
        </h2>
        <p class="mt-2" style="color: var(--muted)">
          <template v-if="unanswered.length">
            Te {{ unanswered.length === 1 ? 'falta 1 pregunta' : `faltan ${unanswered.length} preguntas` }}. Tocá un número para
            ir, o enviá así.
          </template>
          <template v-else>Respondiste todas. Enviá ya: el tiempo sigue corriendo.</template>
        </p>
        <div class="mt-5 flex flex-wrap justify-center gap-2">
          <button
            v-for="(q, i) in questions"
            :key="q.id"
            type="button"
            @click="goTo(i)"
            class="dot grid h-10 w-10 place-items-center rounded-full text-sm font-bold"
            :class="answers[q.id] == null ? 'open' : results[q.id] === true ? 'right' : results[q.id] === false ? 'wrong' : ''"
            :aria-label="`Ir a la pregunta ${i + 1}`"
          >
            {{ i + 1 }}
          </button>
        </div>
        <p v-if="message" class="mt-5 text-sm font-semibold" style="color: #dc2626">{{ message }}</p>
        <button type="button" @click="submit" class="cta mt-6 inline-flex w-full items-center justify-center gap-2 rounded-full py-4 text-lg font-bold">
          <Send :size="19" /> {{ message ? 'Reintentar' : 'Enviar respuestas' }}
        </button>
      </main>

      <nav v-if="screen === 'playing'" class="navbar fixed inset-x-0 bottom-0 z-10">
        <div class="mx-auto flex max-w-md items-center justify-between gap-3 px-5 pt-6">
          <button type="button" @click="go(-1)" :disabled="current === 0" class="ghost inline-flex items-center gap-1 rounded-full py-2.5 pr-4 pl-3 text-sm font-semibold disabled:opacity-30">
            <ChevronLeft :size="18" /> Anterior
          </button>
          <button type="button" @click="go(1)" class="ghost inline-flex items-center gap-1 rounded-full py-2.5 pr-3 pl-4 text-sm font-semibold">
            {{ current === questions.length - 1 ? 'Terminar' : 'Siguiente' }} <ChevronRight :size="18" />
          </button>
        </div>
      </nav>
    </div>

    <!-- ============ ENVIANDO ============ -->
    <div v-else-if="screen === 'sending'" class="grid min-h-dvh place-items-center px-6 text-center">
      <div>
        <span class="spinner mx-auto block"></span>
        <p class="mt-4 font-semibold">Enviando tus respuestas…</p>
      </div>
    </div>

    <!-- ============ BORRADO DESDE EL PANEL ============ -->
    <div v-else-if="screen === 'removed'" class="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center px-6 text-center">
      <div class="badge grid h-20 w-20 place-items-center rounded-full"><RotateCw :size="32" /></div>
      <h1 class="mt-6 text-2xl font-bold">Tu partida ya no está</h1>
      <p class="mt-2" style="color: var(--muted)">Los organizadores reiniciaron el juego o borraron tu partida.</p>
      <button type="button" @click="playAgain" class="cta mt-6 rounded-full px-8 py-3.5 font-bold">Continuar</button>
    </div>

    <!-- ============ RESULTADO Y RANKING ============ -->
    <div v-else-if="screen === 'result'" class="mx-auto max-w-md px-5 pt-10 pb-16">
      <div v-if="!ranking" class="grid place-items-center py-20"><span class="spinner"></span></div>

      <template v-else>
        <!-- Estado del juego -->
        <p class="status mx-auto mb-6 flex w-fit items-center gap-2 rounded-full px-4 py-1.5 text-sm font-bold" :class="{ ended: closed }">
          <span v-if="!closed" class="live-dot"></span>
          <Flag v-else :size="15" />
          {{ closed ? 'Partida finalizada' : 'Partida en curso' }}
        </p>

        <!-- Mi resultado -->
        <section v-if="me" class="text-center">
          <div class="badge mx-auto grid h-20 w-20 place-items-center rounded-full" :class="{ gold: closed && me.position === 1 }">
            <Trophy :size="34" />
          </div>
          <h1 class="mt-5 text-4xl leading-tight" :style="displayFont" style="color: var(--accent-text)">
            <template v-if="closed && me.position === 1">¡Ganaste!</template>
            <template v-else>¡Listo, {{ me.name.split(' ')[0] }}!</template>
          </h1>
          <p class="mt-4 text-5xl font-bold tabular-nums">
            {{ me.correct }}<span class="text-2xl" style="color: var(--muted)">/{{ ranking.total }}</span>
          </p>
          <p class="mt-1 text-sm" style="color: var(--muted)">correctas en {{ formatDuration(me.duration_ms) }}</p>
          <p class="pos mt-5 inline-block rounded-full px-5 py-2 text-lg font-bold">
            {{ closed ? 'Quedaste' : 'Vas' }} {{ ord(me.position) }}
            <span class="font-semibold opacity-70">de {{ ranking.players }}</span>
          </p>
        </section>
        <section v-else class="text-center">
          <div class="badge mx-auto grid h-20 w-20 place-items-center rounded-full"><Trophy :size="34" /></div>
          <h1 class="mt-5 text-4xl leading-tight" :style="displayFont" style="color: var(--accent-text)">{{ ranking.title }}</h1>
        </section>

        <!-- Top 10 -->
        <h2 class="mt-8 text-lg font-bold">Top {{ Math.min(10, ranking.top.length) || '' }}</h2>
        <p v-if="!ranking.top.length" class="mt-3 text-sm" style="color: var(--muted)">Todavía nadie terminó.</p>
        <template v-else>
        <!-- Encabezados: sin ellos «29» y «3:12,4» no se entendía qué eran. -->
        <div class="mt-3 flex items-center gap-3 pr-4 pl-2.5 text-xs font-semibold" style="color: var(--muted)">
          <span class="w-8 shrink-0 text-center">#</span>
          <span class="flex-1">Jugador</span>
          <span class="w-16 shrink-0 text-right">Correctas</span>
          <span class="w-16 shrink-0 text-right">Tiempo</span>
        </div>
        <TransitionGroup tag="ol" name="rank" class="mt-1.5 space-y-2">
          <li
            v-for="r in ranking.top"
            :key="r.name + r.duration_ms"
            class="row flex items-center gap-3 rounded-2xl py-2.5 pr-4 pl-2.5"
            :class="{ mine: r.me }"
          >
            <span class="place grid h-8 w-8 shrink-0 place-items-center rounded-full text-sm font-bold" :class="`p${r.position}`">
              {{ r.position }}
            </span>
            <span class="min-w-0 flex-1 truncate font-semibold">{{ r.name }}<template v-if="r.me"> (vos)</template></span>
            <span class="w-16 shrink-0 text-right font-bold tabular-nums">
              {{ r.correct }}<span class="text-xs font-semibold opacity-60">/{{ ranking.total }}</span>
            </span>
            <span class="w-16 shrink-0 text-right text-sm tabular-nums" style="color: var(--muted)">{{ formatDuration(r.duration_ms) }}</span>
          </li>
        </TransitionGroup>
        <p class="mt-2 text-center text-xs" style="color: var(--muted)">Si empatan en correctas, gana quien tardó menos.</p>
        </template>
        <div v-if="me && !meInTop" class="mt-2">
          <p class="text-center leading-none" style="color: var(--muted)">⋮</p>
          <div class="row mine mt-2 flex items-center gap-3 rounded-2xl py-2.5 pr-4 pl-2.5">
            <span class="place grid h-8 w-8 shrink-0 place-items-center rounded-full text-sm font-bold">{{ me.position }}</span>
            <span class="min-w-0 flex-1 truncate font-semibold">{{ me.name }} (vos)</span>
            <span class="w-16 shrink-0 text-right font-bold tabular-nums">
              {{ me.correct }}<span class="text-xs font-semibold opacity-60">/{{ ranking.total }}</span>
            </span>
            <span class="w-16 shrink-0 text-right text-sm tabular-nums" style="color: var(--muted)">{{ formatDuration(me.duration_ms) }}</span>
          </div>
        </div>

        <!-- Mis respuestas: recién con el juego cerrado (mientras tanto, un rojo
             sin la correcta al lado parecía «todo mal»). -->
        <template v-if="me">
          <p v-if="!closed" class="mt-10 text-center text-sm" style="color: var(--muted)">
            Te vamos a mostrar tus respuestas cuando termine el juego 👀
          </p>
          <button
            v-else-if="review.length"
            type="button"
            @click="reviewOpen = true"
            class="cta mt-10 flex w-full items-center justify-center gap-2 rounded-full py-3.5 font-bold"
          >
            <ListChecks :size="18" /> Ver mis respuestas
          </button>
        </template>

        <router-link :to="photosLink" class="ghost mt-4 flex items-center justify-center gap-2 rounded-full py-3 text-sm font-semibold">
          <Camera :size="16" /> Volver a las fotos
        </router-link>
      </template>
    </div>

    <!-- ============ MIS RESPUESTAS ============ -->
    <transition name="sheet">
      <div v-if="reviewOpen && closed && review.length" class="review fixed inset-0 z-40 overflow-y-auto" :style="pageStyle">
        <header class="bar sticky top-0 z-10">
          <div class="mx-auto flex max-w-md items-center justify-between gap-3 px-5 py-4">
            <div>
              <h2 class="text-lg font-bold">Tus respuestas</h2>
              <p class="text-sm" style="color: var(--muted)">
                {{ reviewRight }} bien · {{ review.length - reviewRight }} mal o sin responder
              </p>
            </div>
            <button type="button" @click="reviewOpen = false" aria-label="Cerrar" class="ghost grid h-10 w-10 place-items-center rounded-full">
              <X :size="20" />
            </button>
          </div>
        </header>
        <div class="mx-auto max-w-md px-5 pb-12">
          <ol class="space-y-3">
            <li
              v-for="(r, i) in review"
              :key="i"
              class="answer rounded-2xl p-4"
              :class="r.is_correct ? 'is-right' : 'is-wrong'"
            >
              <p class="font-semibold">
                <span style="color: var(--muted)">{{ i + 1 }}.</span> {{ r.question }}
              </p>
              <p v-if="r.chosen == null" class="mt-2 flex items-center gap-2 text-sm" style="color: var(--muted)">
                <X :size="16" class="shrink-0" /> No la respondiste
              </p>
              <p v-else class="mt-2 flex items-center gap-2 text-sm font-semibold" :class="r.is_correct ? 'right' : 'wrong'">
                <Check v-if="r.is_correct" :size="16" class="shrink-0" />
                <X v-else :size="16" class="shrink-0" />
                {{ r.options[r.chosen] }}
              </p>
              <p v-if="!r.is_correct && r.correct_index != null" class="right mt-1 flex items-center gap-2 text-sm">
                <Check :size="16" class="shrink-0" /> {{ r.options[r.correct_index] }}
              </p>
            </li>
          </ol>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.trivia {
  -webkit-tap-highlight-color: transparent;
}
.badge {
  background: var(--tint);
  color: var(--accent-text);
}
.badge.gold {
  background: #fde68a;
  color: #92400e;
}
.rules,
.card {
  background: var(--tint);
}
.rules li {
  padding-left: 1.1rem;
  position: relative;
}
.rules li::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0.55em;
  width: 0.4rem;
  height: 0.4rem;
  border-radius: 999px;
  background: var(--accent);
}
.field {
  background: var(--field);
  color: var(--ink);
  border: 1.5px solid var(--line);
  outline: none;
}
.field:focus {
  border-color: var(--accent);
}
.cta {
  background: var(--accent);
  color: var(--accent-on);
  transition: transform 150ms ease;
}
.cta:active {
  transform: scale(0.97);
}
.ghost {
  background: var(--tint);
  color: var(--ink);
}

.bar {
  background: var(--page-bg);
}
.timer {
  background: var(--tint);
  color: var(--ink);
  transition: background-color 200ms ease, color 200ms ease;
}
.timer.hurry {
  background: #dc2626;
  color: #fff;
  animation: pulse 1s ease-in-out infinite;
}
@keyframes pulse {
  50% {
    transform: scale(1.06);
  }
}
.track {
  background: var(--tint);
}
.fill {
  background: var(--accent);
}

.option {
  background: var(--field);
  color: var(--ink);
  border: 2px solid var(--line);
  transition: border-color 150ms ease, background-color 150ms ease, transform 120ms ease;
}
.option:active {
  transform: scale(0.98);
}
.option .letter {
  background: var(--tint);
  color: var(--accent-text);
}
.option:disabled {
  opacity: 0.45;
}
.option.chosen,
.option.checking {
  border-color: var(--accent);
  background: var(--tint);
}
.option.chosen .letter,
.option.checking .letter {
  background: var(--accent);
  color: var(--accent-on);
}
.option.right {
  border-color: #16a34a;
  background: rgb(22 163 74 / 0.12);
  animation: pop 0.3s ease-out;
}
.option.right .letter {
  background: #16a34a;
  color: #fff;
}
.option.wrong {
  border-color: #dc2626;
  background: rgb(220 38 38 / 0.1);
  animation: shake 0.35s ease-in-out;
}
.option.wrong .letter {
  background: #dc2626;
  color: #fff;
}
@keyframes pop {
  50% {
    transform: scale(1.03);
  }
}
@keyframes shake {
  25% {
    transform: translateX(-5px);
  }
  75% {
    transform: translateX(5px);
  }
}
.verdict {
  animation: q-in 0.2s ease-out;
}
.mini-spinner {
  width: 1.1rem;
  height: 1.1rem;
  border-radius: 999px;
  border: 2.5px solid var(--tint);
  border-top-color: var(--accent);
  animation: spin 0.8s linear infinite;
}
.navbar {
  background: linear-gradient(to top, var(--page-bg) 60%, transparent);
  padding-bottom: max(1.25rem, env(safe-area-inset-bottom));
}
.dot {
  background: var(--accent);
  color: var(--accent-on);
}
.dot.right {
  background: #16a34a;
  color: #fff;
}
.dot.wrong {
  background: #dc2626;
  color: #fff;
}
.dot.open {
  background: transparent;
  color: var(--ink);
  border: 2px dashed var(--muted);
}

.pos {
  background: var(--accent);
  color: var(--accent-on);
}
.status {
  background: rgb(22 163 74 / 0.12);
  color: #15803d;
}
.status.ended {
  background: var(--tint);
  color: var(--ink);
}
.row {
  background: var(--tint);
}
.row.mine {
  background: var(--accent);
  color: var(--accent-on);
}
.row.mine span {
  color: inherit !important;
}
.place {
  background: var(--field);
}
.place.p1 {
  background: #fde68a;
  color: #92400e;
}
.place.p2 {
  background: #e5e7eb;
  color: #374151;
}
.place.p3 {
  background: #fed7aa;
  color: #9a3412;
}
.right {
  color: #16a34a;
  font-weight: 700;
}
.wrong {
  color: #dc2626;
}
.live-dot {
  width: 0.5rem;
  height: 0.5rem;
  border-radius: 999px;
  background: #16a34a;
  animation: blink 1.4s ease-in-out infinite;
}
@keyframes blink {
  50% {
    opacity: 0.3;
  }
}

.q-enter {
  animation: q-in 0.25s ease-out;
}
@keyframes q-in {
  from {
    opacity: 0;
    transform: translateX(1rem);
  }
}
.review {
  background: var(--page-bg);
}
.answer {
  background: var(--tint);
  border-left: 4px solid transparent;
}
.answer.is-right {
  border-left-color: #16a34a;
}
.answer.is-wrong {
  border-left-color: #dc2626;
}
.sheet-enter-active,
.sheet-leave-active {
  transition: transform 0.3s cubic-bezier(0.32, 0.72, 0, 1);
}
.sheet-enter-from,
.sheet-leave-to {
  transform: translateY(100%);
}
.rank-move {
  transition: transform 0.4s ease;
}

.spinner {
  width: 2rem;
  height: 2rem;
  border-radius: 999px;
  border: 3px solid var(--tint);
  border-top-color: var(--accent);
  animation: spin 0.8s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
