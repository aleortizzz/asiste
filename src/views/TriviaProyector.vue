<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import QRCode from 'qrcode'
import { supabase } from '../lib/supabase'
import { useGuestTheme } from '../composables/useGuestTheme'
import { formatDuration } from '../lib/trivia'
import WinnerCelebration from '../components/trivia/WinnerCelebration.vue'
import { Maximize, Users, Flag, Trophy } from '@lucide/vue'

// Ranking de la trivia para el proyector de la fiesta (/juego/:eventId/ranking).
// Sin login. Solo lectura: top 10 que se actualiza cada 5 s, estado del juego
// y un QR que lleva directo al juego. Pensado para pantalla horizontal.
const route = useRoute()
const eventId = route.params.eventId

const info = ref(null) // info_fotos_evento(): plantilla y colores
const { theme, pageStyle } = useGuestTheme(info)
const ranking = ref(null) // ranking_juego(): { status, title, total, players, top }
const game = ref(null) // info_juego(): por si todavía no hay nadie en el ranking
const qr = ref('')

const status = computed(() => ranking.value?.status ?? game.value?.status ?? 'borrador')
const closed = computed(() => status.value === 'cerrado')
const title = computed(() => ranking.value?.title || game.value?.title || 'Trivia')
const top = computed(() => ranking.value?.top ?? [])
const winner = computed(() => (closed.value ? top.value[0] : null))

// Al cerrarse el juego (o si la pantalla se abre ya cerrado): festejo a
// pantalla completa hasta que se toque «Ver ranking final».
const celebrating = ref(false)
watch(closed, (isClosed) => (celebrating.value = isClosed))
const displayFont = computed(() => ({ fontFamily: theme.value.display, fontWeight: theme.value.displayWeight }))

async function refresh() {
  const [r, g] = await Promise.all([
    supabase.rpc('ranking_juego', { p_event_id: eventId }),
    supabase.rpc('info_juego', { p_event_id: eventId }),
  ])
  // Si falla la red, se queda mostrando lo último que tenía.
  if (!r.error && r.data) ranking.value = r.data
  if (!g.error && g.data) game.value = g.data
}

let timer = null
let wakeLock = null

// Que la compu del proyector no apague la pantalla mientras está abierta.
async function keepAwake() {
  try {
    wakeLock = await navigator.wakeLock?.request('screen')
  } catch {
    /* el navegador no lo permite: no pasa nada */
  }
}
function onVisibility() {
  if (document.visibilityState === 'visible') keepAwake()
}

onMounted(async () => {
  const [a] = await Promise.all([supabase.rpc('info_fotos_evento', { p_event_id: eventId }), refresh()])
  if (!a.error && a.data) info.value = a.data
  qr.value = await QRCode.toDataURL(`${location.origin}/juego/${eventId}`, {
    width: 600,
    margin: 0,
    errorCorrectionLevel: 'M',
    color: { dark: '#1f1a24', light: '#ffffff' },
  })
  timer = setInterval(refresh, 5000)
  keepAwake()
  document.addEventListener('visibilitychange', onVisibility)
})

onUnmounted(() => {
  clearInterval(timer)
  wakeLock?.release?.()
  document.removeEventListener('visibilitychange', onVisibility)
})

// Pantalla completa: el botón se esconde mientras está activa.
const fullscreen = ref(false)
function onFullscreenChange() {
  fullscreen.value = !!document.fullscreenElement
}
onMounted(() => document.addEventListener('fullscreenchange', onFullscreenChange))
onUnmounted(() => document.removeEventListener('fullscreenchange', onFullscreenChange))
function goFullscreen() {
  document.documentElement.requestFullscreen?.().catch(() => {})
}
</script>

<template>
  <div class="screen flex min-h-dvh" :style="pageStyle">
    <!-- ============ IZQUIERDA: título, estado y QR ============ -->
    <aside class="side flex w-[34%] shrink-0 flex-col items-center justify-center gap-[2.5vh] px-[3vw] py-[5vh] text-center">
      <p class="status inline-flex items-center gap-[0.6vw] rounded-full px-[1.4vw] py-[0.8vh] font-bold" :class="{ ended: closed }">
        <span v-if="!closed" class="live-dot"></span>
        <Flag v-else class="icon" />
        {{ closed ? 'Partida finalizada' : status === 'abierto' ? 'Partida en curso' : 'Todavía no empezó' }}
      </p>

      <h1 class="title leading-[1.05]" :class="{ small: closed }" :style="displayFont">{{ title }}</h1>

      <template v-if="!closed">
        <div class="qr rounded-[1.5vw] bg-white p-[1.2vw] shadow-xl">
          <img v-if="qr" :src="qr" alt="QR para jugar" class="block h-[30vh] w-[30vh]" />
        </div>
        <p class="hint font-semibold">Escaneá y jugá desde tu celular</p>
      </template>

      <!-- Ganador: medalla, etiqueta entre filetes, nombre con la tipografía
           de la invitación y dos datos como ficha. Todo en el color del evento. -->
      <section v-if="winner" class="winner flex w-[85%] flex-col items-center">
        <span class="medal grid place-items-center rounded-full">
          <Trophy class="medal-icon" :stroke-width="1.75" />
        </span>
        <p class="winner-label mt-[3vh] flex w-full items-center gap-[1vw] font-semibold uppercase">
          <span class="rule"></span>Ganador<span class="rule"></span>
        </p>
        <p class="winner-name mt-[1.2vh] break-words" :style="displayFont">{{ winner.name }}</p>
        <dl class="winner-stats mt-[2.8vh] flex items-stretch">
          <div class="px-[2vw]">
            <dt class="sr-only">Correctas</dt>
            <dd class="stat-value">{{ winner.correct }}<span class="stat-of">/{{ ranking.total }}</span></dd>
            <dd class="stat-label">correctas</dd>
          </div>
          <span class="stat-divider" aria-hidden="true"></span>
          <div class="px-[2vw]">
            <dt class="sr-only">Tiempo</dt>
            <dd class="stat-value">{{ formatDuration(winner.duration_ms) }}</dd>
            <dd class="stat-label">tiempo</dd>
          </div>
        </dl>
      </section>

      <p v-if="ranking?.players" class="players inline-flex items-center gap-[0.6vw] font-semibold">
        <Users class="icon" /> {{ ranking.players }} {{ ranking.players === 1 ? 'jugador' : 'jugadores' }}
      </p>
    </aside>

    <!-- ============ DERECHA: top 10 ============ -->
    <main class="flex flex-1 flex-col justify-center py-[4vh] pr-[4vw] pl-[1vw]">
      <div v-if="!top.length" class="text-center">
        <p class="empty font-bold" :style="displayFont">{{ status === 'abierto' ? 'Esperando jugadores…' : 'Ranking' }}</p>
        <p class="hint mt-[1.5vh]">Acá aparecen los 10 mejores apenas terminen de jugar.</p>
      </div>

      <template v-else>
        <div class="head flex items-center gap-[1.5vw] px-[1.5vw] pb-[1.2vh] font-semibold">
          <span class="w-[4.5vw] shrink-0 text-center">#</span>
          <span class="flex-1">Jugador</span>
          <span class="w-[10vw] shrink-0 text-right">Correctas</span>
          <span class="w-[10vw] shrink-0 text-right">Tiempo</span>
        </div>
        <TransitionGroup appear tag="ol" name="rank" class="relative flex flex-col gap-[1vh]">
          <li
            v-for="(r, i) in top"
            :key="r.name + r.duration_ms"
            :style="{ '--i': i }"
            class="row flex items-center gap-[1.5vw] rounded-[1.2vw] px-[1.5vw] py-[0.8vh]"
            :class="{ first: closed && r.position === 1 }"
          >
            <span class="place grid shrink-0 place-items-center rounded-full font-bold" :class="`p${r.position}`">
              <Trophy v-if="r.position === 1" class="trophy" :stroke-width="2.5" aria-label="1" />
              <template v-else>{{ r.position }}</template>
            </span>
            <span class="name min-w-0 flex-1 truncate font-bold">{{ r.name }}</span>
            <span class="num w-[10vw] shrink-0 text-right font-bold">
              {{ r.correct }}<span class="total">/{{ ranking.total }}</span>
            </span>
            <span class="num time w-[10vw] shrink-0 text-right">{{ formatDuration(r.duration_ms) }}</span>
          </li>
        </TransitionGroup>
        <p class="hint mt-[2vh] text-center">Si empatan en correctas, gana quien tardó menos.</p>
      </template>
    </main>

    <WinnerCelebration
      v-if="celebrating && winner"
      :winner="winner"
      :total="ranking.total"
      button-text="Ver ranking final"
      @close="celebrating = false"
    />

    <button
      v-if="!fullscreen"
      type="button"
      @click="goFullscreen"
      class="fs fixed right-4 bottom-4 inline-flex items-center gap-2 rounded-full px-4 py-2 text-sm font-semibold"
    >
      <Maximize :size="16" /> Pantalla completa
    </button>
  </div>
</template>

<style scoped>
/* Todo en vh / vw: se ve igual en un proyector, una tele o la compu. */
.screen {
  font-size: 2.4vh;
  overflow: hidden;
  /* Algunas fuentes de las plantillas tienen números «antiguos» (de alturas
     distintas): en el ranking van parejos y del mismo ancho. */
  font-variant-numeric: lining-nums tabular-nums;
}
.side {
  background: var(--tint);
}
.icon {
  width: 1em;
  height: 1em;
}
.status {
  font-size: 2.2vh;
  background: rgb(22 163 74 / 0.14);
  color: #15803d;
}
.status.ended {
  background: var(--page-bg);
  color: var(--ink);
}
.title {
  font-size: 6.5vh;
  color: var(--accent-text);
  transition: font-size 0.6s ease;
}
/* Con el juego cerrado, el protagonista es el ganador. */
.title.small {
  font-size: 4.2vh;
  opacity: 0.85;
}
.hint,
.players {
  color: var(--muted);
}
.players {
  font-size: 2.6vh;
}
.empty {
  font-size: 7vh;
  color: var(--accent-text);
}

.head {
  font-size: 2vh;
  color: var(--muted);
}
/* Filas: tarjetas claras con borde de un pelo y sombra apenas, sobre el fondo
   de la página. El podio usa solo el color del evento: 1.º lleno, 2.º y 3.º
   en un tono suave con anillo, el resto neutro. */
.row {
  background: var(--field);
  border: 1px solid var(--line);
  box-shadow: 0 0.3vh 1.2vh -0.6vh rgb(0 0 0 / 0.12);
  font-size: 3.4vh;
}
.row.first {
  background: var(--accent);
  border-color: transparent;
  color: var(--accent-on);
  box-shadow: 0 1.6vh 4vh -1.8vh var(--accent);
  transform: scale(1.015);
}
.row.first .time,
.row.first .total {
  color: inherit;
  opacity: 0.72;
}
.place {
  width: 5.4vh;
  height: 5.4vh;
  font-family: 'Inter', ui-sans-serif, sans-serif;
  font-size: 2.5vh;
  color: var(--muted);
}
.trophy {
  width: 52%;
  height: 52%;
}
.place.p1 {
  background: var(--accent);
  color: var(--accent-on);
}
.place.p2,
.place.p3 {
  background: var(--tint);
  color: var(--accent-text);
  box-shadow: inset 0 0 0 0.25vh color-mix(in srgb, var(--accent) 30%, transparent);
}
.row.first .place.p1 {
  background: var(--accent-on);
  color: var(--accent);
}
.num {
  font-family: 'Inter', ui-sans-serif, sans-serif;
}
.total {
  font-size: 0.62em;
  font-weight: 600;
  color: var(--muted);
}
.time {
  font-size: 2.7vh;
  color: var(--muted);
}

/* Ganador (columna izquierda, juego cerrado). */
.winner {
  color: var(--ink);
  animation: winner-in 0.8s cubic-bezier(0.22, 1, 0.36, 1) both;
}
.medal {
  width: 13vh;
  height: 13vh;
  background: var(--accent);
  color: var(--accent-on);
  /* Dos anillos: uno del color del fondo y otro tenue del color del evento. */
  box-shadow:
    0 0 0 0.9vh var(--tint),
    0 0 0 1.25vh color-mix(in srgb, var(--accent) 28%, transparent),
    0 2.5vh 5vh -2vh var(--accent);
}
.medal-icon {
  width: 46%;
  height: 46%;
}
.winner-label {
  font-family: 'Inter', ui-sans-serif, sans-serif;
  font-size: 1.7vh;
  letter-spacing: 0.32em;
  color: var(--accent-text);
}
.rule {
  height: 1px;
  flex: 1;
  background: color-mix(in srgb, var(--accent) 35%, transparent);
}
.winner-name {
  font-size: 7.5vh;
  line-height: 1;
  color: var(--accent-text);
  max-width: 100%;
}
.winner-stats {
  font-family: 'Inter', ui-sans-serif, sans-serif;
}
.stat-value {
  font-size: 4vh;
  font-weight: 700;
  line-height: 1.1;
  color: var(--ink);
}
.stat-of {
  font-size: 0.55em;
  font-weight: 600;
  color: var(--muted);
}
.stat-label {
  margin-top: 0.4vh;
  font-size: 1.5vh;
  font-weight: 600;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--muted);
}
.stat-divider {
  width: 1px;
  background: var(--line);
}
@keyframes winner-in {
  from {
    opacity: 0;
    transform: translateY(2vh);
  }
}

.live-dot {
  width: 1.2vh;
  height: 1.2vh;
  border-radius: 999px;
  background: #16a34a;
  animation: blink 1.4s ease-in-out infinite;
}
@keyframes blink {
  50% {
    opacity: 0.3;
  }
}

/* Ranking en vivo: el que entra se desliza y brilla un momento, los demás se
   acomodan sin saltos y el que sale del top se desvanece en su lugar
   (absolute: deja de ocupar espacio enseguida). --i escalona si entran varios. */
.rank-move,
.rank-enter-active,
.rank-leave-active {
  transition:
    transform 0.8s cubic-bezier(0.22, 1, 0.36, 1),
    opacity 0.6s ease;
}
.rank-enter-active {
  transition-delay: calc(var(--i, 0) * 60ms);
  animation: rank-glow 2.2s ease-out calc(var(--i, 0) * 60ms) both;
}
.rank-enter-from {
  opacity: 0;
  transform: translateX(4vw) scale(0.96);
}
.rank-leave-active {
  position: absolute;
  inset-inline: 0;
}
.rank-leave-to {
  opacity: 0;
  transform: scale(0.94);
}
@keyframes rank-glow {
  0%,
  35% {
    box-shadow: 0 0 0 0.35vh var(--accent);
  }
  100% {
    box-shadow: 0 0 0 0.35vh transparent;
  }
}

.fs {
  background: var(--tint);
  color: var(--ink);
  opacity: 0.6;
  transition: opacity 150ms ease;
}
.fs:hover {
  opacity: 1;
}
</style>
