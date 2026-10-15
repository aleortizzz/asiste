<script setup>
import { DoorOpen, BadgeCheck, Users, TrendingUp, MessageCircle, ArrowDown } from '@lucide/vue'
import { SALON_PRICES, formatPrice } from '../../lib/plans'
import { waLink } from '../../lib/contact'

// Landing › Salones (B2B): por qué a un salón le conviene ofrecer Asiste.
// «Ver precios» abre la pestaña de salones en Planes (la maneja Landing.vue).
const emit = defineEmits(['ver-precios'])

const BENEFITS = [
  { icon: DoorOpen, title: 'Recepción con tu personal', text: 'Tus empleados entran con su usuario, buscan a cada invitado y marcan que llegó.' },
  { icon: BadgeCheck, title: 'Tu logo en cada invitación', text: 'Cada fiesta que hacés es publicidad para tu salón.' },
  { icon: Users, title: 'El cliente arma todo', text: 'La familia carga la invitación y los invitados; vos no sumás trabajo.' },
  { icon: TrendingUp, title: 'Un diferencial para vender', text: 'Lo regalás, lo sumás a tus paquetes o lo cobrás aparte: vos decidís.' },
]
</script>

<template>
  <section id="salones" class="scroll-mt-24 py-14" aria-labelledby="h-salones">
    <div class="rounded-[2.5rem] bg-obsidian p-6 text-chalk sm:p-10">
      <p class="text-sm font-bold tracking-wide text-sulfur uppercase">Para salones</p>
      <h2 id="h-salones" class="admin-display mt-2 max-w-3xl text-5xl text-balance sm:text-6xl">
        ¿Tenés un salón? Sumá Asiste a cada fiesta
      </h2>
      <p class="mt-3 max-w-2xl text-lg text-chalk/65">
        Todo lo del Premium en cada evento, con tu marca y usuarios para tu personal. Desde
        {{ formatPrice(SALON_PRICES.fiesta) }} por fiesta, o fiestas ilimitadas con el abono mensual, sin permanencia.
      </p>

      <ul class="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <li v-for="b in BENEFITS" :key="b.title" class="rounded-[1.75rem] bg-chalk/[0.06] p-5 ring-1 ring-chalk/10">
          <span class="grid h-10 w-10 place-items-center rounded-full bg-chalk/10 text-sulfur">
            <component :is="b.icon" :size="18" />
          </span>
          <h3 class="mt-3 font-bold">{{ b.title }}</h3>
          <p class="mt-1 text-sm text-chalk/65">{{ b.text }}</p>
        </li>
      </ul>

      <div class="mt-8 flex flex-wrap gap-3">
        <button type="button" @click="emit('ver-precios')" class="admin-btn-primary !bg-sulfur !text-obsidian">
          Ver precios para salones <ArrowDown :size="16" />
        </button>
        <a
          :href="waLink('Hola! Tengo un salón y quiero saber más sobre Asiste.')"
          target="_blank"
          rel="noopener"
          class="admin-btn-secondary !border-chalk"
        >
          <MessageCircle :size="17" /> Hablemos por WhatsApp
        </a>
      </div>
    </div>
  </section>
</template>
