<script setup>
// Esquinero con el cartel de la promo (Superadmin › Precios): una banda en
// diagonal sobre la esquina de arriba a la derecha de la tarjeta de un plan.
// Se recorta sola con el mismo radio que la tarjeta (rounded-[2rem]), así
// queda igual en las claras y en las oscuras (.night recorta lo que sale).
// La tarjeta tiene que ser `relative` y dejarle lugar al título (pr-24).
// Ver promoBadge() en lib/plans.js.
defineProps({ text: { type: String, required: true } })
</script>

<template>
  <div class="pointer-events-none absolute top-0 right-0 z-10 h-32 w-32 overflow-hidden rounded-tr-[2rem]" role="note">
    <span class="esquinero absolute block w-48 bg-sulfur py-1.5 text-center text-[0.66rem] font-bold tracking-wider whitespace-nowrap text-obsidian uppercase">
      {{ text }}
    </span>
  </div>
</template>

<style scoped>
/* El centro de la banda a 4,6rem de la esquina, sobre la diagonal. */
.esquinero {
  left: 4.75rem;
  top: 3.25rem;
  translate: -50% -50%;
  rotate: 45deg;
  box-shadow:
    0 3px 0 rgb(0 0 0 / 0.12),
    inset 0 1px 0 rgb(255 255 255 / 0.35);
}
@media (prefers-reduced-motion: no-preference) {
  .esquinero {
    animation: esquinero-in 0.5s cubic-bezier(0.16, 1, 0.3, 1) both;
  }
}
@keyframes esquinero-in {
  from {
    translate: 0 -150%;
  }
}
</style>
