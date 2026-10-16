<script setup>
// Landing › Cierre: el último empujón antes del pie.
</script>

<template>
  <section class="py-14" aria-labelledby="h-cierre">
    <div v-reveal="'scale'" class="night rounded-[2.5rem] px-6 py-14 text-center sm:px-10 sm:py-20">
      <div>
        <h2 id="h-cierre" class="admin-display mx-auto max-w-3xl text-5xl text-balance sm:text-7xl">Tu fiesta empieza hoy</h2>
        <p class="mx-auto mt-4 max-w-xl text-lg text-chalk/75">
          Armá la invitación en minutos y mandala por WhatsApp. Del resto nos ocupamos nosotros.
        </p>
        <div class="mt-8 flex flex-wrap justify-center gap-3">
          <a href="#planes" class="admin-btn-primary !bg-chalk !text-obsidian">Ver planes</a>
          <router-link :to="{ name: 'crear' }" class="admin-btn-secondary !border-chalk hover:!bg-chalk/10">Creá tu invitación gratis</router-link>
        </div>
      </div>
    </div>
  </section>
</template>
