<script setup>
import { ref, computed } from 'vue'
import { Check, MailQuestion, LayoutGrid, DoorOpen, Trophy, PartyPopper, RotateCcw, ArrowRight, Shuffle, Pipette } from '@lucide/vue'
import { FONDOS, DETALLES, findFondo, findDetalle, applyPalette, currentPalette } from '../lib/paleta'
import PlanPrice from '../components/PlanPrice.vue'
import PromoBadge from '../components/PromoBadge.vue'

// Página de prueba para elegir el fondo y el color de los detalles (ver
// lib/paleta.js). Las piezas son copias de las de la landing, con las mismas
// clases, así que se ven como van a quedar. No está enlazada desde ningún lado.
const sel = ref(currentPalette())
function pick(part, id) {
  sel.value = applyPalette({ ...sel.value, [part]: id })
}
const reset = () => (sel.value = applyPalette({}))
const random = (list) => list[Math.floor(Math.random() * list.length)].id
const surprise = () => (sel.value = applyPalette({ fondo: random(FONDOS), detalle: random(DETALLES) }))
const fondoSel = computed(() => findFondo(sel.value.fondo))
const detalleSel = computed(() => findDetalle(sel.value.detalle))
const ROWS = computed(() => [
  { part: 'fondo', title: 'Fondo', list: FONDOS, current: fondoSel.value, color: (x) => x.pumice },
  { part: 'detalle', title: 'Detalle', list: DETALLES, current: detalleSel.value, color: (x) => x.sulfur },
])

const TABS = [
  { label: 'Quién falta', icon: MailQuestion },
  { label: 'Mesas', icon: LayoutGrid },
  { label: 'Recepción', icon: DoorOpen },
]
const RANKING = [
  { name: 'Lucía Fernández', score: '28/30' },
  { name: 'Tomás Gómez', score: '26/30' },
  { name: 'Martina Ruiz', score: '25/30' },
]
</script>

<template>
  <div class="landing font-ui min-h-dvh bg-pumice pb-20 text-obsidian transition-colors duration-500">
    <!-- Selector, fijo arriba -->
    <div class="sticky top-0 z-30 border-b border-obsidian/10 bg-chalk/85 backdrop-blur">
      <div class="mx-auto max-w-6xl space-y-3 px-4 py-3 sm:px-6">
        <div v-for="row in ROWS" :key="row.part" class="flex flex-wrap items-center gap-x-1.5 gap-y-1.5">
          <span class="w-full text-xs font-bold tracking-wide text-obsidian/50 uppercase sm:w-auto sm:min-w-44">
            {{ row.title }} · <span class="text-obsidian normal-case">{{ row.current.label }}</span>
            <span class="font-normal tracking-normal normal-case">{{ row.color(row.current) }}</span>
          </span>
          <button
            v-for="x in row.list"
            :key="x.id"
            type="button"
            @click="pick(row.part, x.id)"
            :title="x.label"
            :aria-label="x.label"
            :aria-pressed="row.current.id === x.id"
            class="h-8 w-8 rounded-full ring-1 ring-obsidian/15 transition-transform hover:scale-110"
            :class="row.current.id === x.id ? 'scale-110 !ring-[2.5px] !ring-obsidian ring-offset-2' : ''"
            :style="{ background: row.color(x) }"
          ></button>
          <!-- Cualquier otro color -->
          <label
            :title="`Otro ${row.title.toLowerCase()}`"
            class="relative grid h-8 w-8 place-items-center overflow-hidden rounded-full bg-chalk ring-1 ring-obsidian/15 hover:scale-110"
            :class="row.current.label === 'Otro' ? '!ring-[2.5px] !ring-obsidian ring-offset-2' : ''"
          >
            <Pipette :size="15" />
            <input
              type="color"
              :value="row.color(row.current)"
              @input="pick(row.part, $event.target.value)"
              :aria-label="`Otro color de ${row.title.toLowerCase()}`"
              class="absolute inset-0 cursor-pointer opacity-0"
            />
          </label>
        </div>
        <div class="flex flex-wrap items-center gap-3 pt-1">
          <router-link :to="{ name: 'landing' }" class="admin-btn-primary !py-2 text-sm">
            Ver la landing entera así <ArrowRight :size="16" />
          </router-link>
          <button type="button" @click="surprise" class="admin-btn-secondary !py-2 text-sm"><Shuffle :size="15" /> Sorpresa</button>
          <button type="button" @click="reset" class="flex items-center gap-1.5 text-sm font-bold text-obsidian/55 hover:text-obsidian">
            <RotateCcw :size="14" /> Volver a los actuales
          </button>
          <span class="text-xs text-obsidian/45">La elección queda mientras no cierres la pestaña.</span>
        </div>
      </div>
    </div>

    <main class="mx-auto max-w-6xl space-y-10 px-4 pt-8 sm:px-6">
      <!-- Encabezado -->
      <div class="flex flex-wrap items-center justify-between gap-4">
        <span class="admin-display text-4xl text-accent">Asiste</span>
        <div class="flex flex-wrap gap-2">
          <span class="admin-btn-secondary !py-2">Ver planes</span>
          <span class="admin-btn-primary !py-2">Creá tu invitación gratis</span>
        </div>
      </div>

      <!-- Panel de noche (hero) -->
      <section class="night grid gap-8 rounded-[2.5rem] p-8 sm:p-12 lg:grid-cols-[1fr_auto] lg:items-center">
        <div>
          <h1 class="admin-display text-5xl text-balance sm:text-6xl">Tu fiesta, organizada de punta a punta</h1>
          <p class="mt-4 max-w-lg text-chalk/75">Invitación, confirmaciones, mesas, recepción, fotos y trivia en un solo lugar.</p>
          <div class="mt-6 flex flex-wrap gap-3">
            <span class="admin-btn-primary !bg-sulfur !text-obsidian">Ver planes</span>
            <span class="admin-btn-secondary !border-chalk">Creá tu invitación gratis</span>
          </div>
        </div>
        <div class="space-y-2.5 lg:w-72">
          <div v-for="n in [{ icon: DoorOpen, t: 'Llegó Martina Gómez', s: 'Mesa 3' }, { icon: Trophy, t: 'Lucía ganó la trivia', s: '28 de 30 correctas' }]" :key="n.t" class="flex items-center gap-3 rounded-2xl bg-chalk p-3 text-obsidian">
            <span class="grid h-10 w-10 place-items-center rounded-xl bg-sulfur"><component :is="n.icon" :size="18" /></span>
            <span><strong class="block text-sm">{{ n.t }}</strong><span class="text-xs text-obsidian/55">{{ n.s }}</span></span>
          </div>
          <p class="pt-1 font-bold text-sulfur">La noche · todo en vivo</p>
        </div>
      </section>

      <!-- Tocalo vos -->
      <section class="grid gap-6 lg:grid-cols-[1fr_1.1fr]">
        <div>
          <h2 class="admin-display text-5xl">Tocalo vos</h2>
          <ul class="mt-4 space-y-1.5">
            <li v-for="(t, i) in TABS" :key="t.label">
              <span
                class="relative flex items-center gap-3 overflow-hidden rounded-2xl px-4 py-3 font-bold"
                :class="i === 0 ? 'bg-obsidian text-chalk' : ''"
              >
                <span class="grid h-9 w-9 place-items-center rounded-xl" :class="i === 0 ? 'bg-sulfur text-obsidian' : 'bg-limestone text-accent'">
                  <component :is="t.icon" :size="17" />
                </span>
                {{ t.label }}
                <span v-if="i === 0" class="absolute bottom-0 left-0 h-[3px] w-3/5 bg-sulfur"></span>
              </span>
            </li>
          </ul>
        </div>
        <div class="space-y-3 rounded-[2rem] bg-limestone p-5">
          <div class="grid grid-cols-3 gap-2 text-center">
            <div class="rounded-[1.1rem] bg-chalk p-3"><p class="text-2xl font-bold">94</p><p class="text-xs text-obsidian/55">vienen</p></div>
            <div class="rounded-[1.1rem] bg-chalk p-3"><p class="text-2xl font-bold">10</p><p class="text-xs text-obsidian/55">no vienen</p></div>
            <div class="rounded-[1.1rem] bg-sulfur/70 p-3"><p class="text-2xl font-bold">6</p><p class="text-xs">falta que respondan</p></div>
          </div>
          <div
            v-for="(r, i) in RANKING"
            :key="r.name"
            class="flex items-center gap-3 rounded-[1.1rem] p-2 pl-3"
            :class="i === 0 ? 'bg-sulfur' : 'bg-chalk'"
          >
            <span class="grid h-8 w-8 place-items-center rounded-full font-bold" :class="i === 0 ? 'bg-obsidian text-sulfur' : 'bg-pumice'">
              <Trophy v-if="i === 0" :size="16" /><template v-else>{{ i + 1 }}</template>
            </span>
            <span class="flex-1 font-bold">{{ r.name }}</span>
            <strong class="text-sm tabular-nums">{{ r.score }}</strong>
          </div>
        </div>
      </section>

      <!-- Planes -->
      <section class="space-y-4">
        <h2 class="admin-display text-5xl">Planes</h2>
        <div class="flex flex-wrap items-center gap-4 rounded-[2rem] border-[1.5px] border-dashed border-accent/35 bg-chalk p-5">
          <span class="rounded-full bg-sulfur px-2.5 py-1 text-xs font-bold tracking-wide uppercase">Prueba gratis</span>
          <span class="font-bold">Probá el Premium completo, gratis.</span>
        </div>
        <div class="grid gap-4 pt-3 md:grid-cols-3">
          <article class="lift relative flex flex-col gap-4 rounded-[2rem] bg-limestone p-6">
            <h3 class="text-lg font-bold">Invitación</h3>
            <PlanPrice id="invitacion" unit="por evento" />
            <ul class="space-y-2 text-[0.95rem]">
              <li class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-go" />Un solo link para todos</li>
            </ul>
            <span class="admin-btn-secondary w-full">Comprar Invitación</span>
          </article>
          <article class="lift night relative flex flex-col gap-4 rounded-[2rem] p-6 md:-my-3 md:py-9">
            <span class="self-start rounded-full bg-sulfur px-2.5 py-1 text-xs font-bold tracking-wide text-obsidian uppercase">El más elegido</span>
            <h3 class="text-lg font-bold">Plus</h3>
            <PlanPrice id="plus" unit="por evento" dark />
            <ul class="space-y-2 text-[0.95rem]">
              <li class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-sulfur" />Todo lo de Invitación</li>
              <li class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-sulfur" />Mesas y lista de la entrada</li>
            </ul>
            <span class="admin-btn-primary w-full !bg-sulfur !text-obsidian">Comprar Plus</span>
          </article>
          <article class="lift relative flex flex-col gap-4 rounded-[2rem] bg-limestone p-6">
            <PromoBadge text="Precio lanzamiento" />
            <h3 class="pr-24 text-lg font-bold">Premium</h3>
            <PlanPrice id="premium" unit="por evento" />
            <ul class="space-y-2 text-[0.95rem]">
              <li class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-go" />Trivia en vivo el día de la fiesta</li>
            </ul>
            <span class="admin-btn-secondary w-full">Comprar Premium</span>
          </article>
        </div>
      </section>

      <!-- Tipos de fiesta -->
      <section class="grid gap-3 sm:grid-cols-3">
        <div class="flex items-center gap-3 rounded-[1.5rem] bg-sulfur p-5 font-bold"><PartyPopper :size="20" /> Casamientos</div>
        <div class="flex items-center gap-3 rounded-[1.5rem] bg-obsidian p-5 font-bold text-chalk"><PartyPopper :size="20" class="text-sulfur" /> Quinces</div>
        <div class="flex items-center gap-3 rounded-[1.5rem] bg-limestone p-5 font-bold"><PartyPopper :size="20" class="text-accent" /> Cumpleaños</div>
      </section>
    </main>
  </div>
</template>
