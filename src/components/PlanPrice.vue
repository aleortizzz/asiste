<script setup>
import { computed } from 'vue'
import { priceOf, priceBefore, discountPercent, formatPrice } from '../lib/plans'

// El precio grande de un plan (id de precios_planes) con el de antes tachado
// y el % de descuento arriba, si hay promo cargada en Superadmin › Precios.
// Siempre en pesos: lleva «ARS» al lado.
const props = defineProps({
  id: { type: String, required: true },
  unit: { type: String, default: '' },
  dark: { type: Boolean, default: false },
})
const before = computed(() => priceBefore(props.id))
</script>

<template>
  <div>
    <p v-if="before" class="mb-1 flex items-center gap-2 text-sm font-bold tabular-nums">
      <s :class="dark ? 'text-chalk/55' : 'text-obsidian/45'" :aria-label="`Antes ${formatPrice(before)}`">{{ formatPrice(before) }}</s>
      <span class="rounded-full px-2 py-0.5 text-xs" :class="dark ? 'bg-chalk text-obsidian' : 'bg-sulfur text-obsidian'">
        −{{ discountPercent(id) }}%
      </span>
    </p>
    <p class="admin-display text-5xl">
      {{ formatPrice(priceOf(id)) }}<span class="ml-1 font-ui text-sm tracking-normal normal-case" :class="dark ? 'text-chalk/60' : 'text-obsidian/55'">
        <abbr title="Pesos argentinos" class="font-bold no-underline">ARS</abbr> {{ unit }}
      </span>
    </p>
  </div>
</template>
