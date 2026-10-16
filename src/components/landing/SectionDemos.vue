<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { DoorOpen, MailQuestion, History, Images, Trophy, Table2, Hand } from '@lucide/vue'
import DemoRecepcion from './DemoRecepcion.vue'
import DemoRespuestas from './DemoRespuestas.vue'
import DemoMovimientos from './DemoMovimientos.vue'
import DemoAlbum from './DemoAlbum.vue'
import DemoTrivia from './DemoTrivia.vue'
import DemoMesas from './DemoMesas.vue'

// Landing › Probalo: las demos que se pueden tocar (antes estaban en la
// portada; la invitación ahora vive en «Plantillas»). Pasan solas a la
// siguiente después de `ms` mientras la sección está en pantalla, con una
// barrita que muestra cuánto falta; cuando la persona toca algo, se quedan
// en la que eligió.
const features = [
  { id: 'respuestas', label: 'Quién falta', icon: MailQuestion, demo: DemoRespuestas, ms: 9000, caption: 'Las respuestas llegan solas: sabés quién confirmó, quién no va y quién todavía ni abrió el link.' },
  { id: 'mesas', label: 'Mesas', icon: Table2, demo: DemoMesas, ms: 8000, caption: 'Armás las mesas arrastrando a cada invitado, con los lugares contados.' },
  { id: 'recepcion', label: 'Recepción', icon: DoorOpen, demo: DemoRecepcion, ms: 7000, caption: 'El personal busca a cada invitado, ve su mesa y marca que llegó. Vos lo ves en vivo.' },
  { id: 'album', label: 'Álbum', icon: Images, demo: DemoAlbum, ms: 8000, caption: 'Los invitados escanean el QR de la mesa y suben sus fotos a un mismo álbum.' },
  { id: 'trivia', label: 'Trivia', icon: Trophy, demo: DemoTrivia, ms: 12000, caption: 'Trivia en vivo: juegan desde el celular, el ranking sale en la pantalla del salón y al final se festeja al ganador.' },
  { id: 'movimientos', label: 'Movimientos', icon: History, demo: DemoMovimientos, ms: 8000, caption: 'Cada respuesta, cambio o canción pedida, en el momento.' },
]
const active = ref(0)
const autoplay = ref(true)
const paused = ref(false)
const onScreen = ref(false)
let timer = null
let io = null
const root = ref(null)

function schedule() {
  clearTimeout(timer)
  if (!autoplay.value) return
  timer = setTimeout(() => {
    if (paused.value || !onScreen.value || document.visibilityState !== 'visible') return schedule()
    active.value = (active.value + 1) % features.length
    schedule()
  }, features[active.value].ms)
}
function select(i) {
  active.value = i
  stopAutoplay()
}
function stopAutoplay() {
  autoplay.value = false
  clearTimeout(timer)
}

onMounted(() => {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) autoplay.value = false
  io = new IntersectionObserver(
    ([e]) => {
      const was = onScreen.value
      onScreen.value = e.isIntersecting
      // Recién al llegar a la sección arranca el reloj de la primera demo.
      if (e.isIntersecting && !was) schedule()
    },
    { threshold: 0.3 },
  )
  io.observe(root.value)
})
onUnmounted(() => {
  clearTimeout(timer)
  io?.disconnect()
})
</script>

<template>
  <section ref="root" id="probalo" class="scroll-mt-24 py-16" aria-labelledby="h-demos">
    <div class="grid grid-cols-1 gap-10 lg:grid-cols-[0.85fr_1.15fr] lg:items-start">
      <div v-reveal class="lg:sticky lg:top-28">
        <h2 id="h-demos" class="admin-display text-5xl text-balance sm:text-6xl">Tocalo vos</h2>
        <p class="mt-3 max-w-md text-lg text-obsidian/65">
          Así se ve tu panel mientras la gente responde y la noche de la fiesta. Elegí una función y probala.
        </p>

        <ul class="mt-7 space-y-1.5" role="tablist" aria-label="Funciones de Asiste" aria-orientation="vertical">
          <li v-for="(f, i) in features" :key="f.id">
            <button
              type="button"
              role="tab"
              :id="`feat-tab-${f.id}`"
              :aria-selected="active === i"
              aria-controls="feat-panel"
              @click="select(i)"
              class="group relative flex w-full items-center gap-3 overflow-hidden rounded-2xl px-4 py-3 text-left transition-colors duration-300"
              :class="active === i ? 'bg-obsidian text-chalk' : 'hover:bg-limestone'"
            >
              <span
                class="grid h-9 w-9 shrink-0 place-items-center rounded-xl transition-colors duration-300"
                :class="active === i ? 'bg-sulfur text-obsidian' : 'bg-limestone text-accent group-hover:bg-chalk'"
              >
                <component :is="f.icon" :size="17" />
              </span>
              <span class="font-bold">{{ f.label }}</span>
              <!-- Cuánto falta para pasar a la siguiente -->
              <span
                v-if="active === i && autoplay"
                :key="`bar-${f.id}`"
                class="bar absolute bottom-0 left-0 h-[3px] bg-sulfur"
                :style="{ animationDuration: `${f.ms}ms`, animationPlayState: paused || !onScreen ? 'paused' : 'running' }"
              ></span>
            </button>
          </li>
        </ul>
      </div>

      <div
        v-reveal="'right'"
        @mouseenter="paused = true"
        @mouseleave="paused = false"
        @focusin="paused = true"
        @focusout="paused = false"
      >
        <div id="feat-panel" role="tabpanel" :aria-labelledby="`feat-tab-${features[active].id}`" class="relative rounded-[2.25rem] bg-limestone p-4 shadow-[0_30px_70px_-40px_rgb(78_31_110/0.55)] ring-1 ring-obsidian/5 sm:p-6">
          <!-- Todas apiladas en la misma celda: las invisibles le dan el alto de la más grande -->
          <div class="grid grid-cols-1" @pointerdown="stopAutoplay" @keydown="stopAutoplay">
            <div v-for="f in features" :key="`medida-${f.id}`" class="invisible col-start-1 row-start-1" aria-hidden="true" inert>
              <component :is="f.demo" paused />
            </div>
            <component :is="features[active].demo" :key="features[active].id" class="feat-in col-start-1 row-start-1 self-start" />
          </div>
          <div class="mt-4 grid grid-cols-1 border-t-[1.5px] border-dotted border-obsidian/20 pt-4 text-obsidian/70">
            <p v-for="f in features" :key="`texto-${f.id}`" class="invisible col-start-1 row-start-1 pr-24" aria-hidden="true">{{ f.caption }}</p>
            <p class="col-start-1 row-start-1 flex items-start gap-2">
              <span class="min-w-0 flex-1">{{ features[active].caption }}</span>
              <span class="flex shrink-0 items-center gap-1 rounded-full bg-accent-soft px-2.5 py-1 text-xs font-bold text-accent">
                <Hand :size="13" /> Probalo
              </span>
            </p>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.bar {
  width: 100%;
  transform-origin: left;
  animation: fill linear both;
}
@keyframes fill {
  from {
    transform: scaleX(0);
  }
}
@media (prefers-reduced-motion: no-preference) {
  .feat-in {
    animation: feat-in 0.45s cubic-bezier(0.16, 1, 0.3, 1);
  }
}
@keyframes feat-in {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
}
</style>
