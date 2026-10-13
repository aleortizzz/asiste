<script setup>
import { computed } from 'vue'
import { Sparkles, ArrowUpRight } from '@lucide/vue'
import { useEvent } from '../composables/useEvent'
import { hasFeature, cheapestPlanWith, PLANS } from '../lib/plans'

// Envuelve una pantalla o una tarjeta del panel. Si el plan del evento no
// incluye `feature`, muestra el contenido borroso (sin poder tocarlo) y un
// cartel para pasarse al plan que lo trae. Es solo la vitrina: lo que importa
// se bloquea en la base (ver migrations/20261013_planes_funciones.sql).
//
//   <PlanGate feature="mesas" action="armar las mesas"> …pantalla… </PlanGate>
//   <PlanGate feature="canciones" action="recibir pedidos de canciones" compact> …tarjeta… </PlanGate>
const props = defineProps({
  feature: { type: String, required: true },
  action: { type: String, required: true }, // completa «¿Querés …?»
  compact: { type: Boolean, default: false }, // tarjeta (Inicio) en vez de pantalla entera
})

const { event } = useEvent()
// Sin evento cargado todavía no bloqueamos (la pantalla muestra su propio «cargando»).
const locked = computed(() => !!event.value && !hasFeature(event.value.plan, props.feature))
const plan = computed(() => cheapestPlanWith(props.feature))
const price = computed(() => (plan.value ? `$${PLANS[plan.value].price.toLocaleString('es-AR')}` : ''))
</script>

<template>
  <slot v-if="!locked" />
  <div v-else class="relative">
    <div class="pointer-events-none select-none blur-[6px] saturate-50" aria-hidden="true" inert>
      <slot />
    </div>

    <!-- Cartel -->
    <div class="absolute inset-0 flex justify-center" :class="compact ? 'items-center p-3' : 'items-start px-4 pt-24'">
      <div
        role="dialog"
        :aria-label="`Disponible en el plan ${PLANS[plan]?.label}`"
        class="w-full rounded-[1.75rem] bg-chalk text-center shadow-xl ring-1 ring-obsidian/5"
        :class="compact ? 'max-w-xs p-4' : 'sticky top-24 max-w-md p-7'"
      >
        <span class="mx-auto grid place-items-center rounded-full bg-accent-soft text-accent" :class="compact ? 'h-9 w-9' : 'h-12 w-12'">
          <Sparkles :size="compact ? 17 : 22" />
        </span>
        <p class="mt-3 font-bold" :class="compact ? 'text-base' : 'text-xl'">¿Querés {{ action }}?</p>
        <p class="mt-1 text-obsidian/65" :class="compact ? 'text-sm' : ''">
          Pasate al plan <strong class="text-obsidian">{{ PLANS[plan]?.label }}</strong> por
          <strong class="text-obsidian">{{ price }}</strong>.
        </p>
        <router-link
          :to="{ name: 'landing', query: { planes: 1 }, hash: '#planes' }"
          target="_blank"
          class="admin-btn-primary mt-4 w-full"
          :class="compact ? '!py-2 text-sm' : ''"
        >
          Enterate de todo lo que incluye
          <ArrowUpRight :size="16" />
        </router-link>
      </div>
    </div>
  </div>
</template>
