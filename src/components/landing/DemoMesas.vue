<script setup>
import { ref, computed } from 'vue'
import { RotateCcw, Hand, FileText, FileSpreadsheet, X } from '@lucide/vue'

// Demo de la portada: sentar invitados arrastrándolos a una mesa (como en
// Mesas del panel). En el celular: tocar la persona y después la mesa.
// «Lista de la entrada» muestra cómo queda la lista que se exporta (PDF/Excel).
const START_TABLES = () => [
  { id: 1, name: 'Mesa 1', cap: 6, guests: ['Abuela Rosa', 'Tío Carlos', 'Tía Marta'] },
  { id: 2, name: 'Mesa 2', cap: 5, guests: ['Camila', 'Agustina', 'Delfina', 'Morena'] },
  { id: 3, name: 'Principal', cap: 4, guests: ['Valentina', 'Mamá'] },
]
const START_LOOSE = () => ['Papá', 'Nicolás', 'Lola', 'Joaquín', 'Pilar', 'Nona']

const tables = ref(START_TABLES())
const loose = ref(START_LOOSE())
const selected = ref(null) // { name, from: 'loose' | table id }
const dragOver = ref(null)
const full = ref(null) // id de la mesa que se intentó llenar de más (para sacudirla)

const done = computed(() => !loose.value.length)

function pick(name, from) {
  selected.value = selected.value?.name === name ? null : { name, from }
}

function removeFrom(from, name) {
  if (from === 'loose') loose.value = loose.value.filter((n) => n !== name)
  else {
    const t = tables.value.find((x) => x.id === from)
    t.guests = t.guests.filter((n) => n !== name)
  }
}

function seat(table) {
  const s = selected.value
  if (!s || s.from === table.id) return (selected.value = null)
  if (table.guests.length >= table.cap) {
    full.value = table.id
    setTimeout(() => (full.value = null), 500)
    return
  }
  removeFrom(s.from, s.name)
  table.guests.push(s.name)
  selected.value = null
}

function unseat() {
  const s = selected.value
  if (!s || s.from === 'loose') return (selected.value = null)
  removeFrom(s.from, s.name)
  loose.value.push(s.name)
  selected.value = null
}

// Arrastrar (compu): reusa la misma selección.
function onDragStart(e, name, from) {
  selected.value = { name, from }
  e.dataTransfer.effectAllowed = 'move'
  e.dataTransfer.setData('text/plain', name)
}
function onDrop(target) {
  dragOver.value = null
  if (target === 'loose') unseat()
  else seat(target)
}

// Vista previa de la lista de la entrada: todos por nombre, con su mesa.
const showList = ref(false)
const exported = ref(null) // 'PDF' | 'Excel', para el aviso
const entryList = computed(() =>
  [
    ...tables.value.flatMap((t) => t.guests.map((name) => ({ name, table: t.name }))),
    ...loose.value.map((name) => ({ name, table: 'Sin mesa' })),
  ].sort((a, b) => a.name.localeCompare(b.name, 'es')),
)
function fakeExport(kind) {
  exported.value = kind
  setTimeout(() => exported.value === kind && (exported.value = null), 1800)
}

function restart() {
  tables.value = START_TABLES()
  loose.value = START_LOOSE()
  selected.value = null
}
</script>

<template>
  <div class="relative grid gap-3 sm:grid-cols-[0.8fr_1.2fr]">
    <!-- Sin mesa -->
    <div
      @dragover.prevent="dragOver = 'loose'"
      @dragleave="dragOver === 'loose' && (dragOver = null)"
      @drop.prevent="onDrop('loose')"
      @click.self="unseat"
      class="rounded-[1.1rem] border-[1.5px] border-dashed p-3 transition-colors"
      :class="dragOver === 'loose' ? 'border-accent bg-accent-soft' : 'border-obsidian/20'"
    >
      <p class="flex items-center justify-between text-xs font-bold tracking-wide text-obsidian/50 uppercase">
        Sin mesa <span class="tabular-nums">{{ loose.length }}</span>
      </p>
      <div class="mt-2 flex flex-wrap gap-1.5">
        <button
          v-for="n in loose"
          :key="n"
          type="button"
          draggable="true"
          @dragstart="onDragStart($event, n, 'loose')"
          @click="pick(n, 'loose')"
          class="cursor-grab rounded-full px-2.5 py-1 text-sm font-bold transition-colors active:cursor-grabbing"
          :class="selected?.name === n ? 'bg-accent text-chalk' : 'bg-chalk'"
        >
          {{ n }}
        </button>
      </div>
      <p v-if="done" class="mt-2 text-sm font-bold text-accent">¡Sentaste a todos!</p>
      <p v-else class="mt-3 flex items-start gap-1.5 text-xs text-obsidian/55">
        <Hand :size="13" class="mt-0.5 shrink-0" /> Arrastrá a alguien a una mesa, o tocalo y después tocá la mesa.
      </p>
    </div>

    <!-- Mesas -->
    <div class="space-y-2">
      <div
        v-for="t in tables"
        :key="t.id"
        @dragover.prevent="dragOver = t.id"
        @dragleave="dragOver === t.id && (dragOver = null)"
        @drop.prevent="onDrop(t)"
        @click.self="seat(t)"
        class="rounded-[1.1rem] p-3 transition-colors"
        :class="[
          dragOver === t.id || (selected && selected.from !== t.id && t.guests.length < t.cap) ? 'bg-accent-soft ring-2 ring-accent/40' : 'bg-chalk',
          full === t.id ? 'shake' : '',
          selected ? 'cursor-pointer' : '',
        ]"
      >
        <div class="pointer-events-none flex items-center justify-between">
          <p class="font-bold">{{ t.name }}</p>
          <p class="text-xs font-bold tabular-nums" :class="t.guests.length === t.cap ? 'text-accent' : 'text-obsidian/55'">
            {{ t.guests.length }}/{{ t.cap }}{{ t.guests.length === t.cap ? ' · llena' : '' }}
          </p>
        </div>
        <div class="mt-2 flex flex-wrap gap-1" @click.self="seat(t)">
          <button
            v-for="g in t.guests"
            :key="g"
            type="button"
            draggable="true"
            @dragstart="onDragStart($event, g, t.id)"
            @click.stop="pick(g, t.id)"
            class="cursor-grab rounded-full px-2 py-0.5 text-xs transition-colors"
            :class="selected?.name === g ? 'bg-accent font-bold text-chalk' : 'bg-limestone'"
          >
            {{ g }}
          </button>
          <span
            v-for="n in t.cap - t.guests.length"
            :key="`libre-${n}`"
            @click="seat(t)"
            class="rounded-full border-[1.5px] border-dashed border-obsidian/20 px-2 py-0.5 text-xs text-obsidian/40"
          >
            libre
          </span>
        </div>
      </div>
      <div class="flex flex-wrap items-center justify-between gap-2 px-1">
        <button type="button" @click="restart" class="flex items-center gap-1 text-xs font-bold text-obsidian/55 hover:text-obsidian">
          <RotateCcw :size="12" /> Volver a empezar
        </button>
        <button type="button" @click="showList = true" class="flex items-center gap-1.5 rounded-full border-[1.5px] border-obsidian px-3 py-1 text-xs font-bold">
          <FileText :size="13" /> Lista de la entrada
        </button>
      </div>
    </div>

    <!-- Vista previa de la lista que se exporta -->
    <Transition name="sheet">
      <div v-if="showList" class="absolute inset-0 z-10 flex flex-col rounded-[1.1rem] bg-chalk p-3 shadow-xl ring-1 ring-obsidian/5">
        <div class="flex items-start justify-between gap-2">
          <div>
            <p class="font-bold">Lista para la entrada</p>
            <p class="text-xs text-obsidian/55">{{ entryList.length }} invitados · ordenados por nombre</p>
          </div>
          <button type="button" @click="showList = false" aria-label="Cerrar" class="grid h-8 w-8 shrink-0 place-items-center rounded-full hover:bg-limestone"><X :size="16" /></button>
        </div>
        <div class="mt-2 min-h-0 flex-1 overflow-y-auto rounded-[0.8rem] border border-pumice">
          <table class="w-full text-xs">
            <thead class="sticky top-0 bg-accent text-left text-chalk">
              <tr><th class="w-7 p-1.5"></th><th class="p-1.5">Nombre</th><th class="p-1.5">Mesa</th></tr>
            </thead>
            <tbody>
              <tr v-for="(r, i) in entryList" :key="r.name" :class="i % 2 ? 'bg-limestone' : ''">
                <td class="p-1.5"><span class="block h-3.5 w-3.5 rounded-sm border border-obsidian/30"></span></td>
                <td class="p-1.5 font-bold">{{ r.name }}</td>
                <td class="p-1.5" :class="r.table === 'Sin mesa' ? 'text-obsidian/40' : ''">{{ r.table }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="mt-2 flex flex-wrap items-center gap-2">
          <button type="button" @click="fakeExport('PDF')" class="flex items-center gap-1.5 rounded-full bg-accent px-3 py-1.5 text-xs font-bold text-chalk"><FileText :size="13" /> PDF</button>
          <button type="button" @click="fakeExport('Excel')" class="flex items-center gap-1.5 rounded-full border-[1.5px] border-obsidian px-3 py-1 text-xs font-bold"><FileSpreadsheet :size="13" /> Excel</button>
          <span v-if="exported" class="text-xs text-obsidian/60">En tu panel, el {{ exported }} se descarga con un toque.</span>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.sheet-enter-active,
.sheet-leave-active {
  transition: all 0.25s ease;
}
.sheet-enter-from,
.sheet-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
@media (prefers-reduced-motion: no-preference) {
  .shake {
    animation: shake 0.4s ease;
  }
}
@keyframes shake {
  20%,
  60% {
    transform: translateX(-4px);
  }
  40%,
  80% {
    transform: translateX(4px);
  }
}
</style>
