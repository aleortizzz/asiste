<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { ChevronDown, Hand } from '@lucide/vue'

// La invitación real del evento de ejemplo (la de Antonella, con su permiso)
// dentro de un celular. Es /demo/invitacion en un <iframe> dibujado a ancho
// de teléfono y achicado para entrar en la pantalla, así se ve igual que en
// un celular de verdad y se puede deslizar.
//
// Con `auto-open` (sección «Plantillas»): cuando el celular aparece en
// pantalla le pide a la invitación que abra el sobre sola (postMessage, ver
// InvitacionDemo.vue, sin música) y, ya abierta, la desliza un poco hacia
// abajo y vuelve, con un cartel de «Deslizá», para que se note que es una
// invitación de verdad y no una foto.
const props = defineProps({
  paused: Boolean, // copia invisible para medir el alto: sin iframe
  template: { type: String, default: '' }, // otra plantilla (sección «Plantillas»)
  autoOpen: Boolean,
  big: Boolean, // más grande (sección «Plantillas»)
})
const query = new URLSearchParams()
if (props.template) query.set('plantilla', props.template)
if (props.autoOpen) query.set('auto', '1')
const src = `/demo/invitacion${query.size ? `?${query}` : ''}`

// Pantalla del dibujo (px) y ancho real al que se dibuja la invitación.
const SCREEN_W = props.big ? 236 : 184
const SCREEN_H = props.big ? 492 : 384
const PAGE_W = 390
const SCALE = SCREEN_W / PAGE_W

const reduced = typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches
const loaded = ref(false)
const scrolled = ref(false) // la persona ya deslizó: se va el cartel
const peeking = ref(false)
const frame = ref(null)
const root = ref(null)
let io = null
let onScreen = false
let requested = false
const timers = []

// Mismo origen: podemos escuchar el scroll de adentro y moverlo nosotros.
function onLoad(e) {
  loaded.value = true
  try {
    // Solo cuenta si de verdad bajó: al cerrarse el sobre la invitación
    // también dispara un scroll (vuelve arriba) y eso no es la persona.
    const win = e.target.contentWindow
    win.addEventListener(
      'scroll',
      () => {
        if (!peeking.value && win.scrollY > 40) scrolled.value = true
      },
      { passive: true },
    )
  } catch {
    /* si no se puede, el cartel se va al pasar el mouse */
  }
  requestOpen()
}

function requestOpen() {
  if (!props.autoOpen || requested || !loaded.value || !onScreen) return
  requested = true
  frame.value?.contentWindow?.postMessage('asiste:abrir-sobre', window.location.origin)
}

// La invitación avisa que el sobre ya se abrió: la deslizamos un poco y la
// devolvemos arriba (dos veces, separadas, si nadie la tocó).
function onMessage(e) {
  if (e.origin !== window.location.origin || e.data !== 'asiste:sobre-abierto') return
  if (e.source !== frame.value?.contentWindow) return
  peek(500)
  timers.push(setTimeout(() => !scrolled.value && peek(0), 7000))
}
function peek(delay) {
  if (reduced) return
  timers.push(
    setTimeout(() => {
      const win = frame.value?.contentWindow
      if (!win || scrolled.value) return
      peeking.value = true
      win.scrollTo({ top: 520, behavior: 'smooth' })
      timers.push(
        setTimeout(() => {
          win.scrollTo({ top: 0, behavior: 'smooth' })
          timers.push(setTimeout(() => (peeking.value = false), 900))
        }, 1300),
      )
    }, delay),
  )
}

onMounted(() => {
  if (!props.autoOpen) return
  window.addEventListener('message', onMessage)
  io = new IntersectionObserver(
    ([e]) => {
      onScreen = e.isIntersecting
      requestOpen()
    },
    { threshold: 0.6 },
  )
  io.observe(root.value)
})
onUnmounted(() => {
  window.removeEventListener('message', onMessage)
  io?.disconnect()
  timers.forEach(clearTimeout)
})
</script>

<template>
  <div ref="root" class="flex justify-center py-1">
    <!-- Celular: marco, isla y pantalla con las proporciones de un teléfono -->
    <div class="relative rounded-[2.6rem] bg-obsidian p-2 shadow-xl ring-1 ring-obsidian/10" @pointerenter="scrolled = true">
      <div class="absolute top-4 left-1/2 z-20 h-[1.1rem] w-16 -translate-x-1/2 rounded-full bg-obsidian"></div>
      <div class="relative overflow-hidden rounded-[2.1rem] bg-limestone" :style="{ width: `${SCREEN_W}px`, height: `${SCREEN_H}px` }">
        <iframe
          v-if="!props.paused"
          ref="frame"
          :src="src"
          title="Invitación de ejemplo"
          allow="autoplay; encrypted-media"
          loading="lazy"
          @load="onLoad"
          class="absolute top-0 left-0 origin-top-left border-0 transition-opacity duration-500"
          :class="loaded ? 'opacity-100' : 'opacity-0'"
          :style="{ width: `${PAGE_W}px`, height: `${SCREEN_H / SCALE}px`, transform: `scale(${SCALE})` }"
        ></iframe>
        <div v-if="!loaded" class="absolute inset-0 grid place-items-center text-xs text-obsidian/40">Cargando invitación…</div>
        <Transition name="fade">
          <p
            v-if="loaded && !scrolled"
            class="hint pointer-events-none absolute bottom-4 left-1/2 z-10 flex -translate-x-1/2 items-center gap-1 rounded-full bg-chalk/95 px-3 py-1 text-[0.7rem] font-bold whitespace-nowrap text-obsidian shadow"
          >
            <template v-if="props.autoOpen"><Hand :size="12" /> Deslizá para verla</template>
            <template v-else>Deslizá <ChevronDown :size="13" /></template>
          </p>
        </Transition>
      </div>
    </div>
  </div>
</template>

<style scoped>
@media (prefers-reduced-motion: no-preference) {
  .hint {
    animation: nudge 1.4s ease-in-out infinite;
  }
}
/* El centrado lo hace -translate-x-1/2 (propiedad `translate`): acá solo `transform`. */
@keyframes nudge {
  50% {
    transform: translateY(4px);
  }
}
.fade-leave-active {
  transition: opacity 0.3s ease;
}
.fade-leave-to {
  opacity: 0;
}
</style>
