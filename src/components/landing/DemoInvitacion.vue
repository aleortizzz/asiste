<script setup>
import { ref } from 'vue'
import { ChevronDown } from '@lucide/vue'

// Demo de la portada: la invitación real del evento de ejemplo (la de
// Antonella, con su permiso) dentro de un celular. Es /demo/invitacion en un
// <iframe> dibujado a ancho de teléfono y achicado para entrar en la pantalla,
// así se ve igual que en un celular de verdad y se puede deslizar.
const props = defineProps({
  paused: Boolean, // copia invisible para medir el alto: sin iframe
  template: { type: String, default: '' }, // otra plantilla (sección «Plantillas»)
})
const src = props.template ? `/demo/invitacion?plantilla=${props.template}` : '/demo/invitacion'

// Pantalla del dibujo (px) y ancho real al que se dibuja la invitación.
const SCREEN_W = 184
const SCREEN_H = 384
const PAGE_W = 390
const SCALE = SCREEN_W / PAGE_W

const loaded = ref(false)
const scrolled = ref(false)

// Mismo origen: podemos escuchar el scroll de adentro para sacar el «Deslizá».
function onLoad(e) {
  loaded.value = true
  try {
    e.target.contentWindow.addEventListener('scroll', () => (scrolled.value = true), { passive: true, once: true })
  } catch {
    /* si no se puede, el cartel se va al pasar el mouse */
  }
}
</script>

<template>
  <div class="flex justify-center py-1">
    <!-- Celular: marco, isla y pantalla con las proporciones de un teléfono -->
    <div class="relative rounded-[2.6rem] bg-obsidian p-2 shadow-xl ring-1 ring-obsidian/10" @pointerenter="scrolled = true">
      <div class="absolute top-4 left-1/2 z-20 h-[1.1rem] w-16 -translate-x-1/2 rounded-full bg-obsidian"></div>
      <div class="relative overflow-hidden rounded-[2.1rem] bg-limestone" :style="{ width: `${SCREEN_W}px`, height: `${SCREEN_H}px` }">
        <iframe
          v-if="!props.paused"
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
            class="hint pointer-events-none absolute bottom-4 left-1/2 z-10 flex -translate-x-1/2 items-center gap-1 rounded-full bg-chalk/95 px-3 py-1 text-[0.7rem] font-bold text-obsidian shadow"
          >
            Deslizá <ChevronDown :size="13" />
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
