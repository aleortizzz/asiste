<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'

// Demo de la portada: los movimientos van llegando en vivo (como en
// Movimientos del panel), con filtros.
const KINDS = { si: 'bg-go', no: 'bg-nogo', cancion: 'bg-accent', visto: 'bg-pumice' }
const POOL = [
  { who: 'Familia Romero', what: 'confirmó 4 personas', kind: 'si' },
  { who: 'Lucas Herrera', what: 'pidió «Tusa» para el DJ', kind: 'cancion' },
  { who: 'Sofía Giménez', what: 'cambió a «No asiste»', kind: 'no' },
  { who: 'Familia Paz', what: 'abrió la invitación', kind: 'visto' },
  { who: 'Abril Navarro', what: 'pidió «Ojitos lindos» para el DJ', kind: 'cancion' },
  { who: 'Familia Ruiz Díaz', what: 'confirmó 2 de 3', kind: 'si' },
  { who: 'Mateo Suárez', what: 'pidió «Provenza» para el DJ', kind: 'cancion' },
  { who: 'Familia Quiroga', what: 'confirmó 5 personas', kind: 'si' },
  { who: 'Germán Pinto', what: 'no va a poder ir', kind: 'no' },
  { who: 'Delfina Ortega', what: 'pidió «Despechá» para el DJ', kind: 'cancion' },
  { who: 'Familia Ledesma', what: 'abrió la invitación', kind: 'visto' },
  { who: 'Bruno Castillo', what: 'pidió «La bachata» para el DJ', kind: 'cancion' },
  { who: 'Familia Acosta', what: 'confirmó 3 personas', kind: 'si' },
  { who: 'Lola Benítez', what: 'pidió «Me porto bonito» para el DJ', kind: 'cancion' },
]
const FILTERS = [
  { id: 'todos', label: 'Todos' },
  { id: 'respuestas', label: 'Respuestas' },
  { id: 'cancion', label: 'Canciones' },
]

let seq = 0
const make = (i, when) => ({ ...POOL[i % POOL.length], id: seq++, when })
const items = ref([make(3, 'hace 2 h'), make(2, 'hace 1 h'), make(1, 'hace 25 min'), make(0, 'hace 3 min')].reverse())
const filter = ref('todos')
let next = 4
let timer = null

const shown = computed(() =>
  items.value
    .filter((m) => filter.value === 'todos' || (filter.value === 'cancion' ? m.kind === 'cancion' : m.kind === 'si' || m.kind === 'no'))
    .slice(0, 5),
)

onMounted(() => {
  timer = setInterval(() => {
    items.value = [make(next++, 'recién'), ...items.value].slice(0, 12)
  }, 2400)
})
onUnmounted(() => clearInterval(timer))
</script>

<template>
  <div class="space-y-3">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <p class="flex items-center gap-1.5 text-xs font-bold tracking-wide text-obsidian/50 uppercase">
        <span class="h-2 w-2 animate-pulse rounded-full bg-go"></span> Movimientos en vivo
      </p>
      <div class="flex gap-1">
        <button
          v-for="f in FILTERS"
          :key="f.id"
          type="button"
          @click="filter = f.id"
          :aria-pressed="filter === f.id"
          class="rounded-full px-2.5 py-1 text-xs font-bold transition-colors"
          :class="filter === f.id ? 'bg-obsidian text-chalk' : 'bg-chalk'"
        >
          {{ f.label }}
        </button>
      </div>
    </div>
    <TransitionGroup name="feed" tag="div" class="relative space-y-2">
      <div v-for="m in shown" :key="m.id" class="flex items-center gap-3 rounded-[1.1rem] bg-chalk px-3 py-2.5">
        <span class="h-2.5 w-2.5 shrink-0 rounded-full" :class="KINDS[m.kind]"></span>
        <span class="min-w-0 flex-1 text-sm"><strong>{{ m.who }}</strong> {{ m.what }}</span>
        <span class="shrink-0 text-xs" :class="m.when === 'recién' ? 'font-bold text-accent' : 'text-obsidian/50'">{{ m.when }}</span>
      </div>
    </TransitionGroup>
  </div>
</template>

<style scoped>
.feed-move,
.feed-enter-active,
.feed-leave-active {
  transition: all 0.4s ease;
}
.feed-enter-from {
  opacity: 0;
  transform: translateY(-10px) scale(0.98);
}
.feed-leave-to {
  opacity: 0;
}
.feed-leave-active {
  position: absolute;
  left: 0;
  right: 0;
}
</style>
