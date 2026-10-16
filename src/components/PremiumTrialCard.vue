<script setup>
import { ref } from 'vue'
import { Users, Table2, DoorOpen, Trophy, Camera, Music2, X, ArrowRight } from '@lucide/vue'
import { FREE_LIMITS } from '../lib/plans'

// Inicio del panel, mientras el evento está en la prueba gratis: la prueba es
// el Premium completo con límites (ver lib/plans.js), pero si nadie lo dice
// la gente arma la invitación y no prueba el resto. Accesos directos a cada
// función. Se puede cerrar (queda cerrado en este navegador).
const KEY = 'asiste-prueba-bienvenida-cerrada'
const closed = ref(false)
try {
  closed.value = localStorage.getItem(KEY) === '1'
} catch {
  /* modo privado */
}
function close() {
  closed.value = true
  try {
    localStorage.setItem(KEY, '1')
  } catch {
    /* modo privado */
  }
}

const LINKS = [
  { to: 'admin-invitados', icon: Users, label: 'Invitados', hint: `Cargá hasta ${FREE_LIMITS.invitations} familias` },
  { to: 'admin-mesas', icon: Table2, label: 'Mesas', hint: 'Armalas arrastrando' },
  { to: 'admin-recepcion', icon: DoorOpen, label: 'Recepción', hint: 'Marcá quién llegó' },
  { to: 'admin-juego', icon: Trophy, label: 'Trivia', hint: 'Armá las preguntas' },
  { to: 'admin-fotos-evento', icon: Camera, label: 'Fotos', hint: 'El álbum de la fiesta' },
  { to: 'admin-canciones', icon: Music2, label: 'Canciones', hint: 'Pedidos para el DJ' },
]
</script>

<template>
  <section v-if="!closed" class="night relative mt-8 rounded-[2rem] p-6 sm:p-8" aria-labelledby="h-prueba">
    <button
      type="button"
      @click="close"
      aria-label="Cerrar"
      class="absolute top-4 right-4 grid h-9 w-9 place-items-center rounded-full bg-chalk/10 transition-colors hover:bg-chalk/20"
    >
      <X :size="17" />
    </button>
    <h2 id="h-prueba" class="admin-display pr-10 text-4xl">Estás probando el Premium completo, gratis</h2>
    <p class="mt-2 max-w-xl text-chalk/75">
      Recorré todo antes de pagar. Cuando elijas un plan se levantan los límites y no perdés nada de lo que armaste.
    </p>
    <ul class="mt-6 grid grid-cols-2 gap-2 sm:grid-cols-3">
      <li v-for="l in LINKS" :key="l.to">
        <router-link
          :to="{ name: l.to }"
          class="flex h-full items-center gap-3 rounded-2xl bg-chalk/10 p-3 transition-colors hover:bg-chalk/20"
        >
          <span class="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-chalk/15 text-sulfur">
            <component :is="l.icon" :size="17" />
          </span>
          <span class="min-w-0">
            <span class="block font-bold">{{ l.label }}</span>
            <span class="block truncate text-xs text-chalk/60">{{ l.hint }}</span>
          </span>
        </router-link>
      </li>
    </ul>
    <router-link :to="{ name: 'admin-plan' }" class="admin-btn-primary mt-6 !bg-sulfur !text-obsidian">
      Elegir un plan <ArrowRight :size="16" />
    </router-link>
  </section>
</template>
