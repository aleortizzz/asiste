<script setup>
import {
  Mail,
  ListChecks,
  BellRing,
  Table2,
  ClipboardList,
  Music2,
  DoorOpen,
  QrCode,
  Images,
  Trophy,
  History,
  Download,
  Heart,
} from '@lucide/vue'
import { planFor } from '../../lib/plans'

// Landing › Funciones: todo lo que hace Asiste, ordenado por cuándo se usa.
// `feature` es la de lib/plans.js: la etiqueta dice desde qué plan viene
// (sin feature, viene en todos).
const PHASES = [
  {
    id: 'antes',
    label: 'Antes',
    title: 'Invitás y organizás',
    items: [
      { icon: Mail, title: 'Invitación digital', text: 'Con sobre animado, música, fotos, mapa, cuenta regresiva y datos para regalos.' },
      { icon: ListChecks, title: 'Confirmaciones en un panel', text: 'Cada familia responde desde su link y lo ves al instante: quién viene, quién no y quién falta.', feature: 'panel' },
      { icon: BellRing, title: 'Recordatorios', text: 'Sabés a quién falta escribirle y le mandás su link de nuevo en un toque.', feature: 'panel' },
      { icon: Table2, title: 'Mesas', text: 'Armás las mesas arrastrando a cada invitado, con los lugares contados.', feature: 'mesas' },
      { icon: ClipboardList, title: 'Lista para la entrada', text: 'En PDF o Excel, ordenada y con la mesa de cada uno.', feature: 'lista_entrada' },
      { icon: Music2, title: 'Canciones para el DJ', text: 'Los invitados piden sus temas desde la invitación.', feature: 'canciones' },
    ],
  },
  {
    id: 'noche',
    label: 'La noche',
    title: 'La fiesta, en vivo',
    items: [
      { icon: DoorOpen, title: 'Recepción en la puerta', text: 'Tu personal busca a cada invitado, ve su mesa y marca que llegó. Vos lo seguís desde el celular.', feature: 'recepcion' },
      { icon: QrCode, title: 'Un QR en cada mesa', text: 'Los invitados lo escanean para subir fotos y jugar, sin bajarse ninguna app.', feature: 'fotos' },
      { icon: Images, title: 'Álbum compartido', text: 'Todas las fotos de la noche en un mismo lugar, con likes.', feature: 'fotos' },
      { icon: Trophy, title: 'Trivia en vivo', text: 'Preguntas sobre el homenajeado, ranking en la pantalla del salón y festejo al ganador.', feature: 'trivia' },
    ],
  },
  {
    id: 'despues',
    label: 'Después',
    title: 'Te queda todo',
    items: [
      { icon: Download, title: 'Las fotos de todos', text: 'Descargás el álbum completo de una vez, sin pedírselas a nadie.', feature: 'fotos' },
      { icon: History, title: 'Quién vino', text: 'El registro de llegadas y de cada respuesta, con fecha y hora.', feature: 'panel' },
      { icon: Heart, title: 'Un recuerdo', text: 'La invitación y el álbum siguen ahí para volver a verlos.' },
    ],
  },
]

const tag = (feature) => (feature ? `Desde ${planFor(feature)}` : 'En todos los planes')
</script>

<template>
  <section id="funciones" class="scroll-mt-24 py-14" aria-labelledby="h-momentos">
    <p class="text-sm font-bold tracking-wide text-accent uppercase">Funciones</p>
    <h2 id="h-momentos" class="admin-display mt-2 max-w-3xl text-5xl text-balance sm:text-6xl">
      Antes, durante y después de la fiesta
    </h2>
    <p class="mt-3 max-w-2xl text-lg text-obsidian/65">
      Asiste no termina cuando mandás la invitación: te acompaña hasta la última foto.
    </p>

    <div class="mt-8 grid gap-4 lg:grid-cols-3">
      <article
        v-for="(phase, i) in PHASES"
        :key="phase.id"
        class="flex flex-col rounded-[2rem] p-6"
        :class="phase.id === 'noche' ? 'bg-obsidian text-chalk' : 'bg-limestone'"
      >
        <div class="flex items-baseline justify-between gap-3">
          <p class="admin-display text-4xl">{{ phase.label }}</p>
          <span class="text-sm font-bold" :class="phase.id === 'noche' ? 'text-chalk/50' : 'text-obsidian/40'">
            {{ i + 1 }} / 3
          </span>
        </div>
        <p class="mt-1 font-bold" :class="phase.id === 'noche' ? 'text-sulfur' : 'text-accent'">{{ phase.title }}</p>
        <ul class="mt-5 space-y-4">
          <li v-for="item in phase.items" :key="item.title" class="flex gap-3">
            <span
              class="grid h-9 w-9 shrink-0 place-items-center rounded-full"
              :class="phase.id === 'noche' ? 'bg-chalk/10 text-sulfur' : 'bg-chalk text-accent'"
            >
              <component :is="item.icon" :size="17" />
            </span>
            <div class="min-w-0">
              <p class="flex flex-wrap items-center gap-x-2 gap-y-0.5 font-bold">
                {{ item.title }}
                <span
                  class="rounded-full px-2 py-0.5 text-[0.7rem] font-bold"
                  :class="phase.id === 'noche' ? 'bg-chalk/10 text-chalk/70' : 'bg-chalk text-obsidian/55'"
                >
                  {{ tag(item.feature) }}
                </span>
              </p>
              <p class="mt-0.5 text-sm" :class="phase.id === 'noche' ? 'text-chalk/65' : 'text-obsidian/65'">{{ item.text }}</p>
            </div>
          </li>
        </ul>
      </article>
    </div>
  </section>
</template>
