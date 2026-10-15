<script setup>
// Landing › Cierre: el último empujón antes del pie.
</script>

<template>
  <section class="py-14" aria-labelledby="h-cierre">
    <div class="relative overflow-hidden rounded-[2.5rem] bg-accent px-6 py-14 text-center text-chalk sm:px-10 sm:py-20">
      <!-- Dos círculos de color de fondo, solo decoración -->
      <span class="pointer-events-none absolute -top-24 -left-20 h-64 w-64 rounded-full bg-plasma/40 blur-3xl" aria-hidden="true"></span>
      <span class="pointer-events-none absolute -right-16 -bottom-28 h-72 w-72 rounded-full bg-sulfur/25 blur-3xl" aria-hidden="true"></span>
      <div class="relative">
        <h2 id="h-cierre" class="admin-display mx-auto max-w-3xl text-5xl text-balance sm:text-7xl">Tu fiesta empieza hoy</h2>
        <p class="mx-auto mt-4 max-w-xl text-lg text-chalk/75">
          Armá la invitación en minutos y mandala por WhatsApp. Del resto nos ocupamos nosotros.
        </p>
        <div class="mt-8 flex flex-wrap justify-center gap-3">
          <a href="#planes" class="admin-btn-primary !bg-chalk !text-obsidian">Ver planes</a>
          <router-link :to="{ name: 'admin-signup' }" class="admin-btn-secondary !border-chalk">Probar gratis</router-link>
        </div>
      </div>
    </div>
  </section>
</template>
