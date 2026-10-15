<script setup>
import { Crown, Heart, Cake, Briefcase, Baby, GraduationCap } from '@lucide/vue'

// Landing › Para cada fiesta: qué le sirve más a cada tipo de evento.
// Más adelante cada tarjeta puede llevar a su página (/xv, /casamientos…).
const EVENTS = [
  {
    icon: Crown,
    title: 'XV años',
    text: 'La invitación con sus fotos, la trivia «¿Cuánto conocés a…?» y todas las fotos de la noche en un álbum.',
    tags: ['Trivia', 'Álbum', 'Canciones'],
  },
  {
    icon: Heart,
    title: 'Casamientos',
    text: 'Confirmaciones con acompañantes, mesas sin planillas, datos para regalos y recepción en la puerta.',
    tags: ['Mesas', 'Regalos', 'Recepción'],
  },
  {
    icon: Cake,
    title: 'Cumpleaños',
    text: 'Un link para todos que confirman por WhatsApp, o uno por familia si querés saber exactamente quién viene.',
    tags: ['Un solo link', 'WhatsApp'],
  },
  {
    icon: Briefcase,
    title: 'Eventos de empresa',
    text: 'Plantilla Ejecutiva con tu logo, programa, acreditación con empresa y cargo, los logos de tus sponsors y versión en inglés.',
    tags: ['Bilingüe', 'Acreditación', 'Programa', 'Sponsors'],
  },
  {
    icon: Baby,
    title: 'Bautismos y comuniones',
    text: 'Una invitación delicada con los datos de la iglesia y de la fiesta, y la lista de quién confirmó.',
    tags: ['Mapa', 'Confirmaciones'],
  },
  {
    icon: GraduationCap,
    title: 'Egresos y aniversarios',
    text: 'Mucha gente, muchas mesas: las confirmaciones ordenadas y la lista de la entrada lista para imprimir.',
    tags: ['Lista de entrada', 'Mesas'],
  },
]
</script>

<template>
  <section id="eventos" class="scroll-mt-24 py-14" aria-labelledby="h-eventos">
    <p class="text-sm font-bold tracking-wide text-accent uppercase">Para cada fiesta</p>
    <h2 id="h-eventos" class="admin-display mt-2 max-w-3xl text-5xl text-balance sm:text-6xl">
      Sea la fiesta que sea
    </h2>
    <ul class="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <li v-for="e in EVENTS" :key="e.title" class="flex flex-col gap-3 rounded-[2rem] bg-limestone p-6">
        <span class="grid h-11 w-11 place-items-center rounded-full bg-chalk text-accent">
          <component :is="e.icon" :size="20" />
        </span>
        <h3 class="text-lg font-bold">{{ e.title }}</h3>
        <p class="flex-1 text-[0.95rem] text-obsidian/65">{{ e.text }}</p>
        <div class="flex flex-wrap gap-1.5">
          <span v-for="t in e.tags" :key="t" class="rounded-full bg-chalk px-2.5 py-1 text-xs font-bold text-obsidian/60">
            {{ t }}
          </span>
        </div>
      </li>
    </ul>
  </section>
</template>
