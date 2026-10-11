<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import QRCode from 'qrcode'
import { supabase } from '../lib/supabase'
import { useGuestTheme } from '../composables/useGuestTheme'
import { formatDuration } from '../lib/trivia'
import { Maximize, Users, Flag } from '@lucide/vue'

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

      <h1 class="title leading-[1.05]" :style="displayFont">{{ title }}</h1>

      <template v-if="!closed">
        <div class="qr rounded-[1.5vw] bg-white p-[1.2vw] shadow-xl">
          <img v-if="qr" :src="qr" alt="QR para jugar" class="block h-[30vh] w-[30vh]" />
        </div>
        <p class="hint font-semibold">Escaneá y jugá desde tu celular</p>
      </template>

      <div v-if="winner" class="winner w-full rounded-[1.5vw] px-[1.5vw] py-[2.5vh]">
        <p class="winner-label font-bold tracking-[0.2em] uppercase">🏆 Ganó</p>
        <p class="winner-name mt-[0.5vh] font-bold break-words">{{ winner.name }}</p>
        <p class="winner-meta mt-[0.5vh] font-semibold">
          {{ winner.correct }}/{{ ranking.total }} correctas · {{ formatDuration(winner.duration_ms) }}
        </p>
      </div>

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
        <TransitionGroup tag="ol" name="rank" class="space-y-[1vh]">
          <li
            v-for="r in top"
            :key="r.name + r.duration_ms"
            class="row flex items-center gap-[1.5vw] rounded-[1.2vw] px-[1.5vw] py-[0.8vh]"
            :class="{ first: closed && r.position === 1 }"
          >
            <span class="place grid shrink-0 place-items-center rounded-full font-bold" :class="`p${r.position}`">
              {{ r.position }}
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
.row {
  background: var(--tint);
  font-size: 3.4vh;
}
.row.first {
  background: linear-gradient(135deg, #fde68a, #f59e0b);
  color: #451a03;
}
.row.first .time,
.row.first .total {
  color: inherit;
  opacity: 0.7;
}
.place {
  width: 5.4vh;
  height: 5.4vh;
  font-size: 2.8vh;
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
.row.first .place.p1 {
  background: #fff;
}
.num {
  font-family: 'Inter', ui-sans-serif, sans-serif;
}
.total {
  font-size: 0.65em;
  color: var(--muted);
}
.time {
  font-size: 2.8vh;
  color: var(--muted);
}

.winner {
  background: linear-gradient(135deg, #fde68a, #f59e0b);
  color: #451a03;
  animation: winner-in 0.6s cubic-bezier(0.17, 0.89, 0.32, 1.3);
}
.winner-label {
  font-size: 2vh;
}
.winner-name {
  font-size: 5vh;
  line-height: 1.1;
}
.winner-meta {
  font-size: 2.2vh;
  opacity: 0.75;
}
@keyframes winner-in {
  from {
    transform: scale(0.8);
    opacity: 0;
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

.rank-move {
  transition: transform 0.6s ease;
}
.rank-enter-active {
  transition: all 0.5s ease;
}
.rank-enter-from {
  opacity: 0;
  transform: translateX(3vw);
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
