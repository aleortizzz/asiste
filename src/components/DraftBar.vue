<script setup>
import { ArrowLeft } from '@lucide/vue'
import BrandLogo from './BrandLogo.vue'

// Barra de arriba del editor en modo borrador (/crear, sin cuenta), en lugar
// del menú del panel. Recuerda que lo armado queda en este navegador y lleva
// a crear la cuenta: ahí el borrador pasa a la base (ver lib/draft.js).
</script>

<template>
  <header class="font-ui fixed inset-x-0 top-0 z-50 border-b border-obsidian/5 bg-pumice/90 backdrop-blur-md">
    <div class="mx-auto flex h-16 max-w-[1200px] items-center justify-between gap-3 px-4 lg:px-8">
      <div class="flex min-w-0 items-center gap-3">
        <router-link :to="{ name: 'landing' }" class="hidden text-3xl text-accent sm:block" aria-label="Volver al inicio">
          <BrandLogo />
        </router-link>
        <router-link :to="{ name: 'landing' }" class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-limestone sm:hidden" aria-label="Volver al inicio">
          <ArrowLeft :size="18" />
        </router-link>
        <p class="min-w-0 text-sm leading-tight">
          <span class="block font-bold">Estás probando</span>
          <span class="block truncate text-obsidian/55">Se guarda en este navegador</span>
        </p>
      </div>
      <div class="flex shrink-0 items-center gap-1 sm:gap-2">
        <router-link :to="{ name: 'admin-login', query: { desde: 'crear' } }" class="hidden rounded-full px-3 py-2 text-sm font-bold sm:block">
          Ya tengo cuenta
        </router-link>
        <router-link :to="{ name: 'admin-signup', query: { desde: 'crear' } }" class="admin-btn-primary !px-4 !py-2 text-sm">
          <span class="sm:hidden">Guardarla</span>
          <span class="hidden sm:inline">Crear cuenta y guardarla</span>
        </router-link>
      </div>
    </div>
  </header>
</template>
