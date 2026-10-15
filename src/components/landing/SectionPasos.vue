<script setup>
import { Sparkles, Palette, Send, PartyPopper } from '@lucide/vue'

// Landing › Cómo funciona: los cuatro pasos, de elegir el plan a la fiesta.
const STEPS = [
  {
    icon: Sparkles,
    title: 'Elegís tu plan',
    text: 'Pagás una sola vez con Mercado Pago, o la probás gratis primero. Sin abonos ni costo por invitado.',
  },
  {
    icon: Palette,
    title: 'Armás tu invitación',
    text: 'Elegís la plantilla, el color y tus fotos, y cargás los datos de la fiesta. Se guarda sola mientras la armás.',
  },
  {
    icon: Send,
    title: 'La mandás por WhatsApp',
    text: 'Un link para cada familia, con su nombre, o uno solo para todos. Confirman en un toque desde el celular.',
  },
  {
    icon: PartyPopper,
    title: 'Seguís todo en vivo',
    text: 'Quién viene, las mesas, la lista de la puerta y, la noche de la fiesta, las llegadas, las fotos y la trivia.',
  },
]
</script>

<template>
  <section id="como-funciona" class="scroll-mt-24 py-14" aria-labelledby="h-pasos">
    <p class="text-sm font-bold tracking-wide text-accent uppercase">Cómo funciona</p>
    <h2 id="h-pasos" class="admin-display mt-2 max-w-3xl text-5xl text-balance sm:text-6xl">
      De la idea a la fiesta, en cuatro pasos
    </h2>
    <ol class="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <li v-for="(s, i) in STEPS" :key="s.title" class="relative flex flex-col gap-3 rounded-[2rem] bg-limestone p-6">
        <div class="flex items-center justify-between">
          <span class="grid h-11 w-11 place-items-center rounded-full bg-chalk text-accent">
            <component :is="s.icon" :size="20" />
          </span>
          <span class="admin-display text-5xl text-obsidian/10" aria-hidden="true">{{ i + 1 }}</span>
        </div>
        <h3 class="text-lg font-bold">
          <span class="sr-only">Paso {{ i + 1 }}: </span>{{ s.title }}
        </h3>
        <p class="text-[0.95rem] text-obsidian/65">{{ s.text }}</p>
      </li>
    </ol>
  </section>
</template>
