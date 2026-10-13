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
// Las clases que se le pongan (ej. col-span en una grilla) van al envoltorio
// borroso; sin bloqueo, el contenido se muestra tal cual, con las suyas.
defineOptions({ inheritAttrs: false })

const props = defineProps({
  feature: { type: String, required: true },
  action: { type: String, required: true }, // completa «¿Querés …?»
  compact: { type: Boolean, default: false }, // tarjeta (Inicio) en vez de pantalla entera
  title: { type: String, default: '' }, // tarjeta: el nombre de la función, para que se tienten
  hint: { type: String, default: '' }, // tarjeta: qué hace, en el «?»
})

const { event } = useEvent()
// Sin evento cargado todavía no bloqueamos (la pantalla muestra su propio «cargando»).
const locked = computed(() => !!event.value && !hasFeature(event.value.plan, props.feature))
const plan = computed(() => cheapestPlanWith(props.feature))
// Si ya pagó un plan, solo la diferencia (Plus → Premium: $50.000).
const paid = computed(() => PLANS[event.value?.plan]?.price ?? 0)
const isUpgrade = computed(() => paid.value > 0)
const price = computed(() =>
  plan.value ? `$${Math.max(PLANS[plan.value].price - paid.value, 0).toLocaleString('es-AR')}` : '',
)
</script>

<template>
  <slot v-if="!locked" />
  <div v-else v-bind="$attrs" class="relative">
    <!-- h-full en el hijo: en una grilla, la tarjeta borrosa ocupa el mismo alto que sus vecinas -->
    <div
      class="pointer-events-none h-full select-none saturate-50 *:h-full"
      :class="compact ? 'blur-[3px] opacity-70' : 'blur-[6px]'"
      aria-hidden="true"
      inert
    >
      <slot />
    </div>

    <!-- Tarjeta (Inicio): una etiqueta chica, para que se vea la tarjeta borrosa atrás -->
    <div v-if="compact" class="absolute inset-0 flex flex-col items-center justify-center gap-1.5 p-3 text-center">
      <p v-if="title" class="flex items-center gap-1.5 font-bold">
        {{ title }}
        <span v-if="hint" class="group/hint relative">
          <button
            type="button"
            :aria-label="`¿Qué es ${title}?`"
            class="grid h-5 w-5 place-items-center rounded-full bg-obsidian text-[0.7rem] font-bold text-chalk"
          >
            ?
          </button>
          <span
            role="tooltip"
            class="pointer-events-none invisible absolute bottom-full left-1/2 z-10 mb-2 w-60 -translate-x-1/2 rounded-[1rem] bg-obsidian px-3 py-2 text-xs font-medium text-chalk shadow-lg group-focus-within/hint:visible group-hover/hint:visible"
          >
            {{ hint }}
          </span>
        </span>
      </p>
      <span class="flex items-center gap-1.5 rounded-full bg-chalk px-3 py-1.5 text-xs font-bold shadow-md ring-1 ring-obsidian/5">
        <Sparkles :size="13" class="text-accent" />
        Con {{ PLANS[plan]?.label }} · {{ price }}
      </span>
      <router-link
        :to="{ name: 'landing', query: { planes: 1 }, hash: '#planes' }"
        target="_blank"
        :title="`¿Querés ${action}? Pasate al plan ${PLANS[plan]?.label}${isUpgrade ? ' pagando solo la diferencia' : ''}.`"
        class="flex items-center gap-0.5 rounded-full px-2 py-0.5 text-xs font-bold text-accent hover:underline"
      >
        Ver qué incluye <ArrowUpRight :size="12" />
      </router-link>
    </div>

    <!-- Pantalla entera: el cartel con todo -->
    <div v-else class="absolute inset-0 flex items-start justify-center px-4 pt-24">
      <div
        role="dialog"
        :aria-label="`Disponible en el plan ${PLANS[plan]?.label}`"
        class="sticky top-24 w-full max-w-md rounded-[1.75rem] bg-chalk p-7 text-center shadow-xl ring-1 ring-obsidian/5"
      >
        <span class="mx-auto grid h-12 w-12 place-items-center rounded-full bg-accent-soft text-accent">
          <Sparkles :size="22" />
        </span>
        <p class="mt-3 text-xl font-bold">¿Querés {{ action }}?</p>
        <p class="mt-1 text-obsidian/65">
          Pasate al plan <strong class="text-obsidian">{{ PLANS[plan]?.label }}</strong> por
          <strong class="text-obsidian">{{ price }}</strong>.
        </p>
        <p v-if="isUpgrade" class="mt-1 text-xs text-obsidian/50">Pagás solo la diferencia con tu plan.</p>
        <router-link
          :to="{ name: 'landing', query: { planes: 1 }, hash: '#planes' }"
          target="_blank"
          class="admin-btn-primary mt-4 w-full"
        >
          Enterate de todo lo que incluye
          <ArrowUpRight :size="16" />
        </router-link>
      </div>
    </div>
  </div>
</template>
