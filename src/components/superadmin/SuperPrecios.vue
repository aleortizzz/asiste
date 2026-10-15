<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { supabase } from '../../lib/supabase'
import { confirmDialog } from '../../composables/useConfirm'
import { PLANS, SALON_PRICES, loadPlanPrices, formatPrice } from '../../lib/plans'

// Superadmin › Precios.
// Tabla precios_planes (migrations/20261015_precios_planes.sql). Los de
// particulares son los que cobra Mercado Pago; los de salón solo se muestran
// en la landing. Un cambio no toca los pagos ya iniciados (guardan su monto).
const PRICE_ROWS = [
  { id: 'invitacion', label: 'Invitación', hint: 'Particulares · Mercado Pago' },
  { id: 'plus', label: 'Plus', hint: 'Particulares · Mercado Pago' },
  { id: 'premium', label: 'Premium', hint: 'Particulares · Mercado Pago' },
  { id: 'salon_fiesta', label: 'Salón por fiesta', hint: 'Solo se muestra en la landing' },
  { id: 'salon_abono', label: 'Salón abono mensual', hint: 'Solo se muestra en la landing' },
]
const currentPrice = (id) =>
  id === 'salon_fiesta' ? SALON_PRICES.fiesta : id === 'salon_abono' ? SALON_PRICES.abono : PLANS[id].price
const priceDraft = reactive({})
const pricesSaving = ref(false)
const pricesMsg = ref('')

function resetPriceDraft() {
  for (const r of PRICE_ROWS) priceDraft[r.id] = currentPrice(r.id)
}
resetPriceDraft()
onMounted(async () => {
  await loadPlanPrices(true)
  resetPriceDraft()
})

const priceChanges = computed(() => PRICE_ROWS.filter((r) => priceDraft[r.id] !== currentPrice(r.id)))
// Enteros positivos, y los de particulares en orden: si Plus costara menos
// que Invitación, «pasarse pagando la diferencia» no tendría sentido.
const priceProblem = computed(() => {
  if (PRICE_ROWS.some((r) => !Number.isInteger(priceDraft[r.id]) || priceDraft[r.id] <= 0))
    return 'Cada precio tiene que ser un número entero mayor a 0.'
  if (!(priceDraft.invitacion < priceDraft.plus && priceDraft.plus < priceDraft.premium))
    return 'Tiene que ser Invitación < Plus < Premium (pasarse de plan cobra la diferencia).'
  return ''
})

async function savePrices() {
  const changes = priceChanges.value
  if (!changes.length || priceProblem.value) return
  const ok = await confirmDialog({
    title: '¿Cambiar los precios?',
    message:
      changes.map((r) => `${r.label}: ${formatPrice(currentPrice(r.id))} → ${formatPrice(priceDraft[r.id])}`).join(' · ') +
      '. Se ven al instante en la landing y en el panel, y los próximos pagos se cobran así.',
    confirmText: 'Cambiar precios',
  })
  if (!ok) return
  pricesSaving.value = true
  pricesMsg.value = ''
  const now = new Date().toISOString()
  const results = await Promise.all(
    changes.map((r) =>
      supabase.from('precios_planes').update({ precio: priceDraft[r.id], actualizado_en: now }).eq('plan', r.id).select(),
    ),
  )
  const failed = results.find((r) => r.error || !r.data?.length)
  await loadPlanPrices(true)
  resetPriceDraft()
  pricesMsg.value = failed
    ? `No se pudieron guardar todos: ${failed.error?.message ?? 'sin permiso'}.`
    : 'Listo, precios actualizados.'
  pricesSaving.value = false
}
</script>

<template>
  <div>
    <p class="max-w-lg text-obsidian/60">
      Se ven al instante en la landing y en «Tu plan». Los pagos ya iniciados se cobran con el precio que tenían.
    </p>
    <form @submit.prevent="savePrices" class="mt-4 rounded-[1.75rem] bg-limestone p-5 sm:p-6">
      <ul class="space-y-3">
        <li v-for="r in PRICE_ROWS" :key="r.id" class="flex flex-wrap items-center justify-between gap-x-4 gap-y-2">
          <label :for="`precio-${r.id}`" class="min-w-0">
            <span class="block font-bold">{{ r.label }}</span>
            <span class="block text-xs text-obsidian/55">{{ r.hint }}</span>
          </label>
          <span class="relative w-full sm:w-44">
            <span class="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 font-bold text-obsidian/45">$</span>
            <input
              :id="`precio-${r.id}`"
              v-model.number="priceDraft[r.id]"
              type="number"
              inputmode="numeric"
              min="1"
              step="1"
              class="admin-input !py-2 !pl-8 text-right tabular-nums"
              :class="priceDraft[r.id] !== currentPrice(r.id) ? '!border-accent' : ''"
            />
          </span>
        </li>
      </ul>
      <p v-if="priceProblem" role="alert" class="mt-4 text-sm font-bold text-nogo">{{ priceProblem }}</p>
      <div class="mt-5 flex flex-wrap items-center gap-3">
        <button type="submit" class="admin-btn-primary" :disabled="!priceChanges.length || !!priceProblem || pricesSaving">
          {{ pricesSaving ? 'Guardando…' : 'Guardar precios' }}
        </button>
        <button
          v-if="priceChanges.length && !pricesSaving"
          type="button"
          @click="resetPriceDraft"
          class="text-sm font-bold text-obsidian/55 hover:text-obsidian"
        >
          Descartar cambios
        </button>
        <p v-if="pricesMsg" role="status" class="text-sm font-bold">{{ pricesMsg }}</p>
      </div>
    </form>
  </div>
</template>
