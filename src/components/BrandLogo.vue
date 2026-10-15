<script setup>
// Logo de Asiste: la lista de invitados con la insignia de confirmado + «ASISTE»
// en Anton. Toma el color del texto (currentColor) y el tamaño de la letra del
// que lo contiene, así que se usa como un texto: <a class="text-4xl"><BrandLogo /></a>.
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
  <span class="inline-flex items-center gap-[0.3em] whitespace-nowrap" :aria-label="text ? undefined : 'Asiste'">
    <svg
      viewBox="2 0 100 100"
      class="h-[1.05em] w-[1.05em] shrink-0"
      :aria-hidden="text ? 'true' : undefined"
      :role="text ? undefined : 'img'"
    >
      <defs>
        <mask :id="maskId" maskUnits="userSpaceOnUse" x="-10" y="-10" width="120" height="120">
          <rect x="-10" y="-10" width="120" height="120" fill="#fff" />
          <g fill="#000" stroke="#000" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="20" cy="22" r="5.5" />
            <circle cx="20" cy="41" r="5.5" />
            <circle cx="20" cy="60" r="5.5" />
            <path d="M33,22 H62 M33,41 H62 M33,60 H42" fill="none" stroke-width="6.5" />
            <circle cx="74" cy="72" r="32.5" />
          </g>
          <circle cx="74" cy="72" r="26" fill="#fff" />
          <path d="M61.5,72 L70,80.5 L86.5,63.5" fill="none" stroke="#000" stroke-width="9.5" stroke-linecap="round" stroke-linejoin="round" />
        </mask>
      </defs>
      <g fill="currentColor" :mask="`url(#${maskId})`">
        <rect x="4" y="2" width="72" height="86" rx="12" />
        <circle cx="74" cy="72" r="26" />
      </g>
    </svg>
    <span v-if="text" class="admin-display">Asiste</span>
  </span>
</template>
