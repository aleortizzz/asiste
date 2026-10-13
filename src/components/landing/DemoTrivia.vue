<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { Trophy, RotateCcw } from '@lucide/vue'

// Demo de la portada: el ranking arranca lleno y cada tanto termina alguien
// más y se acomoda (algunos saltan arriba de todo). Después de los últimos,
// el juego se cierra solo y aparece el ganador con papel picado (versión
// chica de components/trivia/WinnerCelebration.vue).
const TOTAL_Q = 20
const FIRST = [
  { name: 'Bruno Castillo', correct: 16, time: '3:48,5', ms: 228500 },
  { name: 'Abril Navarro', correct: 17, time: '2:12,0', ms: 132000 },
  { name: 'Lucas Herrera', correct: 12, time: '4:10,2', ms: 250200 },
  { name: 'Pilar Domínguez', correct: 14, time: '3:02,7', ms: 182700 },
  { name: 'Morena Iglesias', correct: 15, time: '2:55,1', ms: 175100 },
]
const LATER = [
  { name: 'Lola Benítez', correct: 17, time: '2:30,6', ms: 150600 },
  { name: 'Julieta Ramos', correct: 19, time: '2:41,3', ms: 161300 },
  { name: 'Tomás Aguirre', correct: 18, time: '2:59,9', ms: 179900 },
  { name: 'Facundo Ledesma', correct: 19, time: '3:05,8', ms: 185800 },
]
const STEP_MS = 1250

const done = ref([])
const phase = ref('playing') // 'playing' | 'winner'
const lastName = ref(null) // el último que terminó, para resaltarlo
let timer = null

// Más aciertos primero; si empatan, menos tiempo (como ranking_juego).
const ranking = computed(() => [...done.value].sort((a, b) => b.correct - a.correct || a.ms - b.ms))
const playing = computed(() => FIRST.length + LATER.length + 3 - done.value.length)
const winner = computed(() => ranking.value[0])

function start() {
  clearInterval(timer)
  done.value = [...FIRST]
  lastName.value = null
  phase.value = 'playing'
  let i = 0
  timer = setInterval(() => {
    if (i < LATER.length) {
      lastName.value = LATER[i].name
      done.value = [...done.value, LATER[i++]]
    } else {
      clearInterval(timer)
      phase.value = 'winner'
    }
  }, STEP_MS)
}

const COLORS = ['#4e1f6e', '#f5f28e', '#3fcb7f', '#f2685c', '#ffffff', '#ebe3f1']
const confetti = Array.from({ length: 28 }, (_, i) => ({
  left: `${Math.random() * 100}%`,
  background: COLORS[i % COLORS.length],
  width: `${5 + Math.random() * 5}px`,
  height: `${9 + Math.random() * 8}px`,
  animationDelay: `${0.3 + Math.random() * 1.2}s`,
  animationDuration: `${2.2 + Math.random() * 1.8}s`,
  '--drift': `${(Math.random() - 0.5) * 80}px`,
  '--spin': `${(Math.random() < 0.5 ? -1 : 1) * (360 + Math.random() * 360)}deg`,
}))

// paused: copia invisible que la landing usa solo para medir el alto (sin animar).
const props = defineProps({ paused: Boolean })
onMounted(() => (props.paused ? (done.value = [...FIRST]) : start()))
onUnmounted(() => clearInterval(timer))
</script>

<template>
  <div class="relative">
    <!-- Ranking en vivo -->
    <div v-if="phase !== 'winner'" class="space-y-3">
      <div class="flex items-baseline justify-between gap-2">
        <p class="font-bold">¿Cuánto conocés a Valentina?</p>
        <p class="flex shrink-0 items-center gap-1.5 text-sm text-obsidian/55 tabular-nums">
          <span class="h-2 w-2 animate-pulse rounded-full bg-go"></span>
          {{ playing }} jugando en el salón
        </p>
      </div>
      <TransitionGroup name="rank" tag="div" class="relative space-y-2">
        <div
          v-for="(r, i) in ranking.slice(0, 5)"
          :key="r.name"
          class="flex items-center gap-3 rounded-[1.1rem] p-2 pl-3 transition-colors"
          :class="[i === 0 ? 'bg-sulfur' : 'bg-chalk', r.name === lastName ? 'ring-2 ring-accent' : '']"
        >
          <span class="grid h-8 w-8 shrink-0 place-items-center rounded-full font-bold" :class="i === 0 ? 'bg-obsidian text-sulfur' : 'bg-pumice'">
            <Trophy v-if="i === 0" :size="16" />
            <template v-else>{{ i + 1 }}</template>
          </span>
          <span class="min-w-0 flex-1 truncate font-bold">{{ r.name }}</span>
          <span class="shrink-0 text-sm tabular-nums"><strong>{{ r.correct }}/{{ TOTAL_Q }}</strong> <span class="text-obsidian/55">{{ r.time }}</span></span>
        </div>
      </TransitionGroup>
      <p class="h-5 px-1 text-sm text-obsidian/60">
        <template v-if="lastName">Terminó <strong>{{ lastName.split(' ')[0] }}</strong> y quedó {{ ranking.findIndex((r) => r.name === lastName) + 1 }}.º</template>
      </p>
    </div>

    <!-- Ganador -->
    <div v-else class="winner relative grid min-h-[17rem] place-items-center overflow-hidden rounded-[1.5rem] bg-accent p-6 text-center text-chalk">
      <span v-for="(c, i) in confetti" :key="i" class="confetti" :style="c"></span>
      <div class="relative space-y-2">
        <span class="trophy mx-auto grid h-16 w-16 place-items-center rounded-full bg-sulfur text-obsidian"><Trophy :size="30" /></span>
        <p class="text-xs font-bold tracking-widest uppercase opacity-75">Ganó</p>
        <p class="admin-display text-5xl">{{ winner.name.split(' ')[0] }}</p>
        <p class="text-sm opacity-80 tabular-nums">{{ winner.correct }} de {{ TOTAL_Q }} correctas en {{ winner.time }}</p>
        <p class="text-xs opacity-70">Empató con {{ ranking[1].name.split(' ')[0] }} y ganó por tiempo</p>
        <button type="button" @click="start" class="mx-auto mt-2 flex items-center gap-1.5 rounded-full bg-chalk px-4 py-2 text-sm font-bold text-obsidian">
          <RotateCcw :size="14" /> Jugar de nuevo
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.rank-move,
.rank-enter-active {
  transition: all 0.45s cubic-bezier(0.32, 0.72, 0, 1);
}
.rank-enter-from {
  opacity: 0;
  transform: translateX(-16px);
}
.rank-leave-active {
  display: none;
}

.confetti {
  position: absolute;
  top: -20px;
  border-radius: 2px;
  opacity: 0;
  animation-name: fall;
  animation-timing-function: linear;
  animation-iteration-count: infinite;
}
@keyframes fall {
  0% {
    opacity: 1;
    transform: translate3d(0, 0, 0) rotate(0);
  }
  100% {
    opacity: 1;
    transform: translate3d(var(--drift), 20rem, 0) rotate(var(--spin));
  }
}
@media (prefers-reduced-motion: no-preference) {
  .winner {
    animation: grow 0.5s cubic-bezier(0.32, 0.72, 0, 1);
  }
  .trophy {
    animation: pop 0.6s 0.2s cubic-bezier(0.34, 1.56, 0.64, 1) both;
  }
}
@media (prefers-reduced-motion: reduce) {
  .confetti {
    display: none;
  }
}
@keyframes grow {
  from {
    transform: scale(0.9);
    opacity: 0;
  }
}
@keyframes pop {
  from {
    transform: scale(0.3);
  }
}
</style>
