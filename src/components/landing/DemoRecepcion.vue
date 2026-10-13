<script setup>
import { ref, computed } from 'vue'
import { Check, Search, X } from '@lucide/vue'

// Demo de la portada: buscar a alguien y marcar que llegó (como en /recepcion).
const TOTAL = 103
const ALREADY = 61 // los que «ya llegaron» antes de que la persona toque algo

const guests = ref([
  { name: 'Familia Benítez', table: 'Mesa 3', at: '21:58' },
  { name: 'Camila Ferreyra', table: 'Mesa 2', at: '22:03' },
  { name: 'Tomás Aguirre', table: 'Mesa 8', at: null },
  { name: 'Ana Lucía Pereyra', table: 'Mesa 5', at: null },
  { name: 'Joaquín Molina', table: 'Mesa 1', at: null },
  { name: 'Mariana Ortega', table: 'Mesa 4', at: null },
  { name: 'Familia Acuña', table: 'Mesa 6', at: null },
  { name: 'Santiago Ríos', table: 'Mesa 2', at: null },
])

const search = ref('')
const normalize = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
const shown = computed(() => {
  const q = normalize(search.value.trim())
  return guests.value.filter((g) => !q || normalize(g.name).includes(q)).slice(0, 4)
})

const arrived = computed(() => ALREADY + guests.value.filter((g) => g.at).length)
let minute = 14
function toggle(g) {
  g.at = g.at ? null : `22:${String(minute++ % 60).padStart(2, '0')}`
}
</script>

<template>
  <div class="space-y-3">
    <div class="flex items-baseline justify-between text-xs font-bold tracking-wide text-obsidian/50 uppercase">
      <span>Recepción · en vivo</span><span>Probá: buscá «ana»</span>
    </div>
    <p class="text-5xl font-bold tabular-nums">
      {{ arrived }} <span class="text-xl font-medium text-obsidian/50">de {{ TOTAL }} llegaron</span>
    </p>
    <div class="h-3 overflow-hidden rounded-full bg-chalk">
      <div class="h-full rounded-full bg-go transition-[width] duration-500" :style="{ width: `${(arrived / TOTAL) * 100}%` }"></div>
    </div>
    <div class="relative">
      <Search :size="16" class="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-obsidian/40" />
      <input
        v-model="search"
        type="search"
        aria-label="Buscar invitado"
        placeholder="Buscar por nombre o familia"
        class="w-full rounded-full border-[1.5px] border-transparent bg-chalk py-2.5 pr-10 pl-10 text-sm font-medium outline-none focus:border-accent"
      />
      <button v-if="search" type="button" @click="search = ''" aria-label="Borrar búsqueda" class="absolute top-1/2 right-2 grid h-7 w-7 -translate-y-1/2 place-items-center rounded-full hover:bg-limestone">
        <X :size="15" />
      </button>
    </div>
    <TransitionGroup name="row" tag="div" class="space-y-2">
      <div v-for="g in shown" :key="g.name" class="flex items-center gap-3 rounded-[1.1rem] p-2 pl-3 transition-colors" :class="g.at ? 'bg-go/15' : 'bg-chalk'">
        <span class="min-w-0 flex-1">
          <span class="block truncate font-bold">{{ g.name }}</span>
          <span v-if="g.at" class="block text-xs text-obsidian/55">Llegó {{ g.at }}</span>
        </span>
        <span class="shrink-0 rounded-full bg-accent-soft px-2.5 py-1 text-xs font-bold text-accent">{{ g.table }}</span>
        <button
          type="button"
          @click="toggle(g)"
          :aria-label="g.at ? `Desmarcar a ${g.name}` : `Marcar que llegó ${g.name}`"
          class="flex h-9 shrink-0 items-center justify-center gap-1 rounded-full font-bold transition-colors"
          :class="g.at ? 'w-9 bg-go' : 'bg-accent px-3 text-sm text-chalk'"
        >
          <Check :size="g.at ? 17 : 15" />
          <span v-if="!g.at">Llegó</span>
        </button>
      </div>
    </TransitionGroup>
    <p v-if="!shown.length" class="rounded-[1.1rem] bg-chalk p-3 text-center text-sm text-obsidian/55">No hay nadie con «{{ search }}».</p>
  </div>
</template>

<style scoped>
.row-enter-active,
.row-leave-active {
  transition: all 0.25s ease;
}
.row-enter-from,
.row-leave-to {
  opacity: 0;
  transform: translateY(6px);
}
.row-leave-active {
  position: absolute;
  visibility: hidden;
}
</style>
