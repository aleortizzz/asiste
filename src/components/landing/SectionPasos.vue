<script setup>
import { Sparkles, Palette, Send, PartyPopper } from '@lucide/vue'

// Landing › Cómo funciona: los cuatro pasos como un recorrido (una línea los
// une y aparecen de a uno), de elegir el plan a la noche de la fiesta.
const STEPS = [
  {
    icon: Sparkles,
    title: 'Elegís tu plan',
    text: 'Pagás una sola vez con Mercado Pago, o la probás gratis primero.',
  },
  {
    icon: Palette,
    title: 'Armás la invitación',
    text: 'Plantilla, color y tus fotos. Se guarda sola mientras la armás.',
  },
  {
    icon: Send,
    title: 'La mandás por WhatsApp',
    text: 'Un link por familia, con su nombre, o uno solo para todos.',
  },
  {
    icon: PartyPopper,
    title: 'Vivís la fiesta',
    text: 'Confirmaciones, mesas, llegadas, fotos y trivia, todo en vivo.',
  },
]
</script>

<template>
  <section id="como-funciona" class="scroll-mt-24 py-16" aria-labelledby="h-pasos">
    <h2 v-reveal id="h-pasos" class="admin-display max-w-3xl text-5xl text-balance sm:text-6xl">
      De la idea a la fiesta, en cuatro pasos
    </h2>

    <ol class="relative mt-10 grid gap-8 md:grid-cols-4 md:gap-6">
      <!-- La línea que une los pasos (horizontal en desktop, vertical en celular) -->
      <span
        class="absolute top-7 bottom-7 left-7 w-[2px] bg-[repeating-linear-gradient(to_bottom,var(--color-accent)_0_6px,transparent_6px_12px)] opacity-30 md:top-7 md:right-[12%] md:bottom-auto md:left-[12%] md:h-[2px] md:w-auto md:bg-[repeating-linear-gradient(to_right,var(--color-accent)_0_6px,transparent_6px_12px)]"
        aria-hidden="true"
      ></span>
      <li
        v-for="(s, i) in STEPS"
        :key="s.title"
        v-reveal
        :data-delay="i * 110"
        class="relative flex gap-5 md:flex-col md:items-center md:text-center"
      >
        <span
          class="step-dot relative grid h-14 w-14 shrink-0 place-items-center rounded-full bg-accent text-chalk shadow-[0_10px_24px_-10px_rgb(78_31_110/0.8)] ring-[6px] ring-pumice"
        >
          <component :is="s.icon" :size="22" />
          <span class="absolute -top-1 -right-1 grid h-6 w-6 place-items-center rounded-full bg-sulfur text-xs font-bold text-obsidian">
            {{ i + 1 }}
          </span>
        </span>
        <div class="pt-1 md:pt-0">
          <h3 class="text-xl font-bold">{{ s.title }}</h3>
          <p class="mt-1.5 max-w-xs text-obsidian/65">{{ s.text }}</p>
        </div>
      </li>
    </ol>
  </section>
</template>

<style scoped>
@media (hover: hover) {
  .step-dot {
    transition: transform 0.35s cubic-bezier(0.16, 1, 0.3, 1);
  }
  li:hover .step-dot {
    transform: scale(1.08) rotate(-6deg);
  }
}
</style>
