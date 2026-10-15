<script setup>
// Landing › Para cada fiesta: un mosaico de fotos, una por tipo de evento,
// con lo que más le sirve a cada uno. Fotos de Unsplash (public/fondos y
// public/landing); con el tiempo, cambiarlas por fotos de fiestas reales.
// Más adelante cada tarjeta puede llevar a su página (/xv, /casamientos…).
const EVENTS = [
  {
    title: 'XV años',
    text: 'Sus fotos en la invitación, la trivia «¿Cuánto conocés a…?» y todas las fotos de la noche en un álbum.',
    tags: ['Trivia', 'Álbum', 'Canciones'],
    photo: '/fondos/cel-4.jpg',
    pos: '50% 55%',
    alt: 'Una quinceañera entrando a su fiesta',
    span: 'lg:col-span-5 lg:row-span-2',
  },
  {
    title: 'Casamientos',
    text: 'Confirmaciones con acompañantes, mesas sin planillas, datos para regalos y recepción en la puerta.',
    tags: ['Mesas', 'Regalos', 'Recepción'],
    photo: '/landing/boda.jpg',
    pos: '50% 30%',
    alt: 'Una novia bailando con sus invitados',
    span: 'lg:col-span-7',
  },
  {
    title: 'Cumpleaños',
    text: 'Un link para todos que confirman por WhatsApp, o uno por familia para saber exactamente quién viene.',
    tags: ['Un solo link', 'WhatsApp'],
    photo: '/landing/confeti.jpg',
    pos: '50% 40%',
    alt: 'Papel picado cayendo sobre una fiesta',
    span: 'lg:col-span-4',
  },
  {
    title: 'Bautismos y comuniones',
    text: 'Una invitación delicada con los datos de la iglesia y de la fiesta.',
    tags: ['Mapa', 'Confirmaciones'],
    span: 'lg:col-span-3',
    solid: true,
  },
  {
    title: 'Eventos de empresa',
    text: 'Plantilla Ejecutiva con tu logo, programa, acreditación con empresa y cargo, los logos de tus sponsors y versión en inglés.',
    tags: ['Bilingüe', 'Acreditación', 'Programa', 'Sponsors'],
    photo: '/landing/empresa.jpg',
    pos: '50% 60%',
    alt: 'Un salón de conferencias armado con mesas redondas',
    span: 'lg:col-span-7',
  },
  {
    title: 'Egresos y aniversarios',
    text: 'Mucha gente, muchas mesas: las confirmaciones ordenadas y la lista de la entrada lista para imprimir.',
    tags: ['Lista de entrada', 'Mesas'],
    photo: '/fondos/pc-3.jpg',
    pos: '50% 50%',
    alt: 'Gente bailando con las manos arriba',
    span: 'lg:col-span-5',
  },
]
</script>

<template>
  <section id="eventos" class="scroll-mt-24 py-16" aria-labelledby="h-eventos">
    <h2 v-reveal id="h-eventos" class="admin-display max-w-3xl text-5xl text-balance sm:text-6xl">Sea la fiesta que sea</h2>

    <ul class="mt-10 grid auto-rows-[17rem] gap-4 lg:grid-cols-12 lg:auto-rows-[16rem]">
      <li
        v-for="(e, i) in EVENTS"
        :key="e.title"
        v-reveal
        :data-delay="(i % 3) * 90"
        class="tile group relative overflow-hidden rounded-[2rem]"
        :class="[e.span, e.solid ? 'bg-sulfur text-obsidian' : 'bg-obsidian text-chalk']"
      >
        <img
          v-if="e.photo"
          :src="e.photo"
          :alt="e.alt"
          loading="lazy"
          class="absolute inset-0 h-full w-full object-cover transition-transform duration-[900ms] ease-[cubic-bezier(0.16,1,0.3,1)]"
          :style="{ objectPosition: e.pos }"
        />
        <!-- Degradé para que el texto se lea sobre cualquier foto -->
        <span
          v-if="e.photo"
          class="absolute inset-0 bg-linear-to-t from-obsidian/90 via-obsidian/35 to-obsidian/0 transition-opacity duration-500 group-hover:opacity-95"
          aria-hidden="true"
        ></span>
        <div class="relative flex h-full flex-col justify-end p-6">
          <h3 class="admin-display text-4xl">{{ e.title }}</h3>
          <p class="text mt-2 max-w-md text-[0.95rem]" :class="e.solid ? 'text-obsidian/70' : 'text-chalk/80'">{{ e.text }}</p>
          <div class="mt-3 flex flex-wrap gap-1.5">
            <span
              v-for="t in e.tags"
              :key="t"
              class="rounded-full px-2.5 py-1 text-xs font-bold"
              :class="e.solid ? 'bg-obsidian/10' : 'bg-chalk/15 backdrop-blur-sm'"
            >
              {{ t }}
            </span>
          </div>
        </div>
      </li>
    </ul>
  </section>
</template>

<style scoped>
@media (hover: hover) {
  .tile:hover img {
    transform: scale(1.07);
  }
  .tile {
    transition: box-shadow 0.4s ease;
  }
  .tile:hover {
    box-shadow: 0 26px 50px -28px rgb(7 6 7 / 0.7);
  }
}
</style>
