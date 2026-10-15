<script setup>
import { waLink } from '../../lib/contact'

// Botón flotante de WhatsApp (abajo a la derecha) de la landing.
</script>

<template>
  <a
    :href="waLink()"
    target="_blank"
    rel="noopener"
    aria-label="Escribinos por WhatsApp"
    title="Escribinos por WhatsApp"
    class="wa fixed right-4 bottom-4 z-40 grid h-14 w-14 place-items-center rounded-full bg-[#25d366] text-chalk shadow-lg ring-1 ring-obsidian/10 transition-transform hover:scale-105 active:scale-95 sm:right-6 sm:bottom-6"
    style="margin-bottom: env(safe-area-inset-bottom)"
  >
    <!-- Logo de WhatsApp -->
    <svg viewBox="0 0 24 24" width="28" height="28" fill="currentColor" aria-hidden="true">
      <path
        d="M17.47 14.38c-.3-.15-1.76-.87-2.03-.97-.27-.1-.47-.15-.67.15-.2.3-.77.97-.94 1.17-.17.2-.35.22-.64.07-.3-.15-1.26-.46-2.4-1.48-.89-.79-1.49-1.77-1.66-2.07-.17-.3-.02-.46.13-.6.13-.14.3-.35.45-.52.15-.17.2-.3.3-.5.1-.2.05-.37-.03-.52-.07-.15-.67-1.61-.91-2.2-.24-.58-.49-.5-.67-.51h-.57c-.2 0-.52.07-.79.37-.27.3-1.04 1.02-1.04 2.48s1.07 2.88 1.21 3.08c.15.2 2.1 3.2 5.08 4.49.71.31 1.26.49 1.69.63.71.22 1.36.19 1.87.12.57-.09 1.76-.72 2.01-1.41.25-.69.25-1.29.17-1.41-.07-.12-.27-.2-.57-.35M12.05 21.5h-.01a9.4 9.4 0 0 1-4.79-1.31l-.34-.2-3.56.93.95-3.47-.22-.36a9.4 9.4 0 0 1-1.44-5.02c0-5.2 4.23-9.43 9.44-9.43a9.4 9.4 0 0 1 9.43 9.44c0 5.2-4.23 9.42-9.43 9.42m8.02-17.45A11.27 11.27 0 0 0 12.05.72 11.33 11.33 0 0 0 2.24 17.7L.64 23.5l5.94-1.56a11.3 11.3 0 0 0 5.46 1.39h.01A11.33 11.33 0 0 0 23.37 12a11.26 11.26 0 0 0-3.3-7.96"
      />
    </svg>
  </a>
</template>

<style scoped>
@media (prefers-reduced-motion: no-preference) {
  .wa {
    animation: wa-in 0.5s 1s cubic-bezier(0.32, 0.72, 0, 1) both;
  }
}
@keyframes wa-in {
  from {
    opacity: 0;
    transform: translateY(12px) scale(0.9);
  }
}
</style>
