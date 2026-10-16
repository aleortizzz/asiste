<script setup>
import { computed } from 'vue'
import { EyeOff, Lock } from '@lucide/vue'
import { FAMILY_COLORS } from '../lib/familyColors'

// Una mesa vista "desde arriba": la mesa redonda al medio y una silla por
// lugar alrededor. Cada persona sentada es un círculo con sus iniciales y el
// color de su familia (así se ve de un vistazo qué familias están juntas).
// Selección y arrastre los maneja AdminMesas: acá solo se avisa con eventos.
const props = defineProps({
  table: { type: Object, required: true },
  seated: { type: Array, required: true },
  reserved: { type: Number, default: 0 }, // invitados sorpresa que esta cuenta no ve
  selected: { type: Set, required: true },
  dragIds: { type: Array, required: true },
  // { [family_id]: color } del evento entero (lib/familyColors.js)
  familyColors: { type: Object, default: () => ({}) },
})
const emit = defineEmits(['toggle', 'dragstart', 'dragend'])

// Color de la familia; si no vino en el mapa, uno fijo según su id.
function familyColor(familyId) {
  if (props.familyColors[familyId]) return props.familyColors[familyId]
  let h = 2166136261
  for (const ch of String(familyId)) h = Math.imul(h ^ ch.charCodeAt(0), 16777619) >>> 0
  return FAMILY_COLORS[h % FAMILY_COLORS.length]
}

// «Lucas Romero» → «LR»; «Mili» → «MI»
function initials(name) {
  const words = name.trim().split(/\s+/)
  const two = words.length > 1 ? words[0][0] + words[1][0] : words[0].slice(0, 2)
  return two.toUpperCase()
}

// Geometría: las sillas se reparten en un círculo. Con muchas sillas el
// círculo crece para que no se pisen; con pocas, se agrandan hasta 40 px.
const SEAT_MAX = 40
const SEAT_MIN = 26
const GAP = 6
const geometry = computed(() => {
  const n = Math.max(props.table.capacity, 1)
  let ring = 92 // radio del círculo de sillas, en px
  let seat = Math.min(SEAT_MAX, (2 * Math.PI * ring) / n - GAP)
  if (seat < SEAT_MIN) {
    seat = SEAT_MIN
    ring = ((seat + GAP) * n) / (2 * Math.PI)
  }
  const size = Math.ceil(2 * ring + seat + 4)
  return { n, ring, seat, size, tableR: ring - seat / 2 - 10 }
})

// Una entrada por silla: primero los sentados, después los reservados y el resto vacías.
const seats = computed(() => {
  const { n, ring, size } = geometry.value
  const list = []
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 - Math.PI / 2
    const pos = { left: size / 2 + Math.cos(a) * ring, top: size / 2 + Math.sin(a) * ring }
    if (i < props.seated.length) list.push({ kind: 'guest', guest: props.seated[i], ...pos })
    else if (i < props.seated.length + props.reserved) list.push({ kind: 'reserved', ...pos })
    else list.push({ kind: 'empty', ...pos })
  }
  // Si hay más gente que lugares (no debería pasar), igual se muestran todos
  for (let i = n; i < props.seated.length; i++) list.push({ kind: 'guest', guest: props.seated[i], extra: true })
  return list
})

// El nombre tiene que entrar en la mesa sin cortar palabras: la letra se
// achica hasta que la palabra más larga entre en un renglón (Anton en
// mayúsculas mide ~0,5 em por letra) y, si hace falta, va en dos renglones.
const nameSize = computed(() => {
  const width = geometry.value.tableR * 1.6
  const name = props.table.name.trim()
  const longest = Math.max(...name.split(/\s+/).map((w) => w.length), 1)
  const oneLine = width / (name.length * 0.5)
  const wordFits = width / (longest * 0.5)
  return Math.round(Math.max(13, Math.min(26, oneLine >= 18 ? oneLine : Math.min(wordFits, 20))))
})

const occupied = computed(() => props.seated.length + props.reserved)
const full = computed(() => occupied.value >= props.table.capacity)
</script>

<template>
  <div class="mx-auto" :style="{ width: geometry.size + 'px', height: geometry.size + 'px', position: 'relative' }">
    <!-- Mesa -->
    <div
      class="absolute grid place-items-center rounded-full bg-chalk text-center shadow-[0_10px_30px_rgba(40,10,70,0.08)]"
      :style="{
        width: geometry.tableR * 2 + 'px',
        height: geometry.tableR * 2 + 'px',
        left: geometry.size / 2 - geometry.tableR + 'px',
        top: geometry.size / 2 - geometry.tableR + 'px',
      }"
    >
      <div class="min-w-0" :style="{ maxWidth: geometry.tableR * 1.6 + 'px' }">
        <p class="admin-display line-clamp-2 leading-none text-accent" :title="table.name" :style="{ fontSize: nameSize + 'px' }">{{ table.name }}</p>
        <p
          class="mt-1.5 inline-block rounded-full px-2.5 py-0.5 text-xs font-bold"
          :class="full ? 'bg-go/20 text-[#1f7a4d]' : 'bg-accent-soft text-accent'"
        >
          {{ occupied }}/{{ table.capacity }}
        </p>
      </div>
    </div>

    <!-- Sillas -->
    <template v-for="(s, i) in seats" :key="s.kind === 'guest' ? s.guest.id : `${s.kind}-${i}`">
      <button
        v-if="s.kind === 'guest' && !s.extra"
        type="button"
        draggable="true"
        @dragstart="emit('dragstart', $event, s.guest)"
        @dragend="emit('dragend')"
        @click="emit('toggle', s.guest)"
        :aria-pressed="selected.has(s.guest.id)"
        :aria-label="`${s.guest.full_name} (${s.guest.invitation_groups.family_name})`"
        :title="`${s.guest.full_name} · ${s.guest.invitation_groups.family_name}`"
        class="seat absolute grid cursor-grab place-items-center rounded-full border-[3px] font-bold text-chalk active:cursor-grabbing"
        :class="[
          selected.has(s.guest.id) ? 'z-10 scale-110 border-obsidian ring-2 ring-accent' : 'border-chalk',
          { 'opacity-40': dragIds.includes(s.guest.id) },
        ]"
        :style="{
          width: geometry.seat + 'px',
          height: geometry.seat + 'px',
          left: s.left - geometry.seat / 2 + 'px',
          top: s.top - geometry.seat / 2 + 'px',
          background: familyColor(s.guest.invitation_groups.id),
          fontSize: Math.round(geometry.seat * 0.36) + 'px',
        }"
      >
        {{ initials(s.guest.full_name) }}
        <EyeOff
          v-if="s.guest.invitation_groups.sorpresa"
          :size="11"
          class="absolute -right-1 -bottom-1 rounded-full bg-chalk p-0.5 text-obsidian"
          aria-label="sorpresa"
        />
      </button>
      <span
        v-else-if="s.kind === 'reserved'"
        title="Lugar reservado"
        class="absolute grid place-items-center rounded-full border-2 border-dashed border-accent/50 bg-accent-soft text-accent"
        :style="{
          width: geometry.seat + 'px',
          height: geometry.seat + 'px',
          left: s.left - geometry.seat / 2 + 'px',
          top: s.top - geometry.seat / 2 + 'px',
        }"
      >
        <Lock :size="Math.round(geometry.seat * 0.38)" />
      </span>
      <span
        v-else-if="s.kind === 'empty'"
        class="absolute rounded-full border-2 border-dashed border-obsidian/20 bg-chalk"
        :style="{
          width: geometry.seat + 'px',
          height: geometry.seat + 'px',
          left: s.left - geometry.seat / 2 + 'px',
          top: s.top - geometry.seat / 2 + 'px',
        }"
      ></span>
    </template>
  </div>
</template>

<style scoped>
.seat {
  box-shadow: 0 4px 10px rgba(40, 10, 70, 0.2);
  transition: transform 0.15s ease;
}
@media (hover: hover) {
  .seat:hover {
    transform: scale(1.12);
    z-index: 10;
  }
}
</style>
