<script setup>
// Logo de Asiste: la lista de invitados con la insignia de confirmado + «ASISTE»
// en Anton. Toma el color del texto (currentColor) y el tamaño de la letra del
// que lo contiene, así que se usa como un texto: <a class="text-4xl"><BrandLogo /></a>.
// El ícono mide lo mismo que las mayúsculas de Anton (0,86 em): arriba queda a
// la altura de las letras y abajo apoyado en la base, como una letra más.
// El dibujo sale de branding/generador/final_logo.py (no cambiarlo a mano).
import { useId } from 'vue'

defineProps({
  // false = solo el ícono (para lugares chicos)
  text: { type: Boolean, default: true },
})

// La máscara necesita un id único por cada logo de la página.
const maskId = 'asiste-logo-' + useId().replace(/[^\w-]/g, '')
</script>

<template>
  <span class="inline-flex items-center gap-[0.26em] whitespace-nowrap" :aria-label="text ? undefined : 'Asiste'">
    <svg
      viewBox="0 0 100 100"
      class="h-[0.86em] w-[0.86em] shrink-0"
      :aria-hidden="text ? 'true' : undefined"
      :role="text ? undefined : 'img'"
    >
      <defs>
        <mask :id="maskId" maskUnits="userSpaceOnUse" x="-10" y="-10" width="120" height="120">
          <rect x="-10" y="-10" width="120" height="120" fill="#fff" />
          <g fill="#000" stroke="#000" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="16" cy="20" r="5" />
            <circle cx="16" cy="39" r="5" />
            <circle cx="16" cy="58" r="5" />
            <path d="M28,20 H60 M28,39 H60 M28,58 H44" fill="none" stroke-width="6" />
            <circle cx="78" cy="78" r="27.5" />
          </g>
          <circle cx="78" cy="78" r="22" fill="#fff" />
          <path d="M67.5,78 L74.5,85 L88.5,71" fill="none" stroke="#000" stroke-width="8.5" stroke-linecap="round" stroke-linejoin="round" />
        </mask>
      </defs>
      <g fill="currentColor" :mask="`url(#${maskId})`">
        <rect x="0" y="0" width="76" height="90" rx="12" />
        <circle cx="78" cy="78" r="22" />
      </g>
    </svg>
    <span v-if="text" class="admin-display">Asiste</span>
  </span>
</template>
