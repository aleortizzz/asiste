<script setup>
import { ref } from 'vue'
import { Check } from '@lucide/vue'
import DemoInvitacion from './DemoInvitacion.vue'

// Landing › Plantillas: la misma invitación de ejemplo con cada una de las
// cuatro plantillas (/demo/invitacion?plantilla=…), dentro de un celular.
const TEMPLATES = [
  {
    id: 'clasico',
    label: 'Clásica',
    title: 'Romántica y elegante',
    text: 'Sobre animado, letra cursiva y tonos cálidos. La de siempre, para XV, casamientos y bautismos.',
  },
  {
    id: 'partiful',
    label: 'Partiful',
    title: 'Moderna y descontracturada',
    text: 'Blanco y negro con degradés de colores suaves. Para cumpleaños y fiestas con onda.',
  },
  {
    id: 'craft',
    label: 'Craft',
    title: 'Natural, como papel',
    text: 'Textura de papel crema y detalles botánicos. Para fiestas al aire libre o con estilo rústico.',
  },
  {
    id: 'ejecutiva',
    label: 'Ejecutiva',
    title: 'Para eventos de empresa',
    text: 'Tarjeta sobria con tu logo, programa del evento, acceso y estacionamiento, los logos de tus sponsors y versión en inglés.',
  },
]
const COMMON = [
  'El color principal lo elegís vos',
  'Tus fotos en portada, saludo y galería',
  'Prendés y apagás cada sección',
  'Se ve perfecta en el celular',
]

const active = ref(TEMPLATES[0].id)
</script>

<template>
  <section id="plantillas" class="scroll-mt-24 py-14" aria-labelledby="h-plantillas">
    <div class="night grid items-center gap-10 rounded-[2.5rem] p-6 sm:p-10 lg:grid-cols-[1.1fr_0.9fr] lg:p-14">
      <div v-reveal>
        <h2 id="h-plantillas" class="admin-display text-5xl text-balance sm:text-6xl">Una invitación con tu estilo</h2>
        <p class="mt-3 text-lg text-chalk/75">
          Cuatro diseños para elegir. Tocá cada uno y mirá cómo queda la misma invitación.
        </p>

        <div class="mt-6 flex flex-wrap gap-1.5" role="tablist" aria-label="Plantillas">
          <button
            v-for="t in TEMPLATES"
            :key="t.id"
            type="button"
            role="tab"
            :aria-selected="active === t.id"
            aria-controls="plantilla-panel"
            @click="active = t.id"
            class="rounded-full px-4 py-2 text-sm font-bold transition-colors"
            :class="active === t.id ? 'bg-sulfur text-obsidian' : 'bg-chalk/10 text-chalk hover:bg-chalk/20'"
          >
            {{ t.label }}
          </button>
        </div>

        <div id="plantilla-panel" role="tabpanel" class="mt-5 grid">
          <!-- Las cuatro apiladas: el bloque toma el alto del texto más largo y no salta -->
          <div
            v-for="t in TEMPLATES"
            :key="t.id"
            class="col-start-1 row-start-1 transition-opacity duration-300"
            :class="active === t.id ? 'opacity-100' : 'pointer-events-none opacity-0'"
            :aria-hidden="active !== t.id"
          >
            <p class="text-xl font-bold">{{ t.title }}</p>
            <p class="mt-1 text-chalk/70">{{ t.text }}</p>
          </div>
        </div>

        <ul class="mt-6 grid gap-2 sm:grid-cols-2">
          <li v-for="c in COMMON" :key="c" class="flex gap-2 text-[0.95rem]">
            <Check :size="17" class="mt-0.5 shrink-0 text-sulfur" />{{ c }}
          </li>
        </ul>
      </div>

      <!-- :key recarga el iframe con la plantilla elegida -->
      <div v-reveal="'scale'" class="relative">
        <!-- Halo detrás del celular -->
        <span class="absolute inset-x-[15%] top-[10%] bottom-[10%] rounded-full bg-accent-light/60 blur-3xl" aria-hidden="true"></span>
        <DemoInvitacion :key="active" :template="active" auto-open big class="relative" />
      </div>
    </div>
  </section>
</template>
