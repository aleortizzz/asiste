<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { ChevronLeft, ChevronRight } from '@lucide/vue'

// Carrusel de la plantilla Ejecutiva, pensado para muchas fotos: una foto por
// vez con fundido suave, flechas finas y contador («03 / 24») en vez de una
// fila de puntitos que con 40 fotos no entra. Avanza solo (se pausa con el
// mouse encima o al tocarlo) y se desliza con el dedo.
//
// Solo se cargan la foto actual y la siguiente: con muchas fotos, bajar todas
// de entrada haría lenta la invitación en el celular.
const props = defineProps({
  photos: { type: Array, required: true },
  // Proporción de la caja, para que no salte de alto entre fotos.
  aspect: { type: String, default: '4 / 3' },
  label: { type: String, default: 'Fotos' },
  // Invitación bilingüe en inglés: textos para lectores de pantalla.
  en: { type: Boolean, default: false },
})

const index = ref(0)
const count = computed(() => props.photos.length)
const pad = (n) => String(n).padStart(2, '0')
const next = () => (index.value = (index.value + 1) % count.value)
const prev = () => (index.value = (index.value - 1 + count.value) % count.value)
watch(count, (n) => {
  if (index.value >= n) index.value = 0
})

// Precarga de la siguiente, para que el fundido no muestre un hueco.
const nextUrl = computed(() => (count.value > 1 ? props.photos[(index.value + 1) % count.value] : ''))

// --- Avance automático -----------------------------------------------------------
const reducedMotion = typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
let timer = null
function play() {
  if (reducedMotion || count.value < 2) return
  stop()
  timer = setInterval(next, 4500)
}
function stop() {
  clearInterval(timer)
  timer = null
}
onMounted(play)
onUnmounted(stop)

// Al tocar una flecha, el contador de tiempo arranca de nuevo.
function go(dir) {
  dir > 0 ? next() : prev()
  play()
}

// --- Deslizar con el dedo ----------------------------------------------------------
let x0 = 0
let y0 = 0
function onTouchStart(e) {
  x0 = e.changedTouches[0].clientX
  y0 = e.changedTouches[0].clientY
  stop()
}
function onTouchEnd(e) {
  const dx = e.changedTouches[0].clientX - x0
  const dy = e.changedTouches[0].clientY - y0
  if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy)) dx < 0 ? next() : prev()
  play()
}
</script>

<template>
  <div class="ejc" :aria-label="label" role="region" aria-roledescription="carrusel">
    <div
      class="relative overflow-hidden"
      :style="{ aspectRatio: aspect }"
      @mouseenter="stop"
      @mouseleave="play"
      @touchstart.passive="onTouchStart"
      @touchend.passive="onTouchEnd"
    >
      <!-- La foto va entera (object-contain): nunca se corta. El espacio que
           sobra lo llena la misma foto desenfocada, así no quedan barras vacías. -->
      <Transition name="ejc-fade">
        <div :key="index" class="absolute inset-0">
          <img :src="photos[index]" alt="" aria-hidden="true" class="ejc-fill absolute inset-0 h-full w-full object-cover" />
          <img
            :src="photos[index]"
            :alt="en ? `${label}: photo ${index + 1} of ${count}` : `${label}: foto ${index + 1} de ${count}`"
            decoding="async"
            class="absolute inset-0 h-full w-full object-contain"
          />
        </div>
      </Transition>
      <img v-if="nextUrl" :src="nextUrl" alt="" aria-hidden="true" class="hidden" />
    </div>

    <div v-if="count > 1" class="mt-4 flex items-center justify-between gap-4">
      <button type="button" class="ejc-arrow" :aria-label="en ? 'Previous photo' : 'Foto anterior'" @click="go(-1)">
        <ChevronLeft :size="18" :stroke-width="1.25" />
      </button>
      <div class="flex min-w-0 flex-1 items-center gap-4">
        <span class="ejc-count shrink-0">{{ pad(index + 1) }} / {{ pad(count) }}</span>
        <span class="ejc-track relative flex-1">
          <span class="ejc-progress absolute -top-px left-0" :style="{ width: `${((index + 1) / count) * 100}%` }"></span>
        </span>
      </div>
      <button type="button" class="ejc-arrow" :aria-label="en ? 'Next photo' : 'Foto siguiente'" @click="go(1)">
        <ChevronRight :size="18" :stroke-width="1.25" />
      </button>
    </div>
  </div>
</template>

<style scoped>
/* Usa las variables de color de EjecutivaTemplate (--ink, --muted, --frame, --line). */
.ejc-arrow {
  display: grid;
  place-items: center;
  height: 2.5rem;
  width: 2.5rem;
  flex-shrink: 0;
  border: 1px solid var(--frame);
  border-radius: 999px;
  color: var(--ink);
  transition:
    background-color 150ms ease,
    transform 150ms ease;
}
.ejc-arrow:active {
  transform: scale(0.94);
}
@media (hover: hover) and (pointer: fine) {
  .ejc-arrow:hover {
    background: color-mix(in srgb, var(--ink) 6%, transparent);
  }
}
.ejc-count {
  font: 500 11px 'Inter', sans-serif;
  letter-spacing: 0.25em;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.ejc-track {
  border-top: var(--hair, 1px) solid var(--frame);
}
.ejc-progress {
  border-top: var(--hair, 1px) solid var(--line);
  transition: width 500ms cubic-bezier(0.22, 0.61, 0.36, 1);
}

.ejc-fill {
  filter: blur(24px) saturate(1.1);
  transform: scale(1.15);
  opacity: 0.45;
}

.ejc-fade-enter-active,
.ejc-fade-leave-active {
  transition: opacity 900ms ease;
}
.ejc-fade-enter-from,
.ejc-fade-leave-to {
  opacity: 0;
}
@media (prefers-reduced-motion: reduce) {
  .ejc-fade-enter-active,
  .ejc-fade-leave-active {
    transition-duration: 200ms;
  }
}
</style>
