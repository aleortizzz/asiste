<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { supabase } from '../../lib/supabase'
import { confirmDialog } from '../../composables/useConfirm'
import { PRICE_PROMO, priceOf, loadPlanPrices, formatPrice } from '../../lib/plans'

// Superadmin › Precios.
// Tabla precios_planes (migrations/20261015_precios_planes.sql). Los de
// particulares son los que cobra Mercado Pago; los de salón solo se muestran
// en la landing. Un cambio no toca los pagos ya iniciados (guardan su monto).
// «Antes» y el cartel (migrations/20261016_precios_promo.sql) solo se
// muestran: el de antes va tachado al lado del precio, simulando el descuento.
const PRICE_ROWS = [
  { id: 'invitacion', label: 'Invitación', hint: 'Particulares · Mercado Pago' },
  { id: 'plus', label: 'Plus', hint: 'Particulares · Mercado Pago' },
  { id: 'premium', label: 'Premium', hint: 'Particulares · Mercado Pago' },
  { id: 'salon_fiesta', label: 'Salón por fiesta', hint: 'Solo se muestra en la landing' },
  { id: 'salon_abono', label: 'Salón abono mensual', hint: 'Solo se muestra en la landing' },
]
// Corto: va en una línea en el esquinero de la tarjeta.
const CARTEL_IDEAS = ['Precio lanzamiento', 'Promoción', 'Descuento', 'Por tiempo limitado']
const CARTEL_MAX = 20

const currentBefore = (id) => PRICE_PROMO.before[id] ?? null
const priceDraft = reactive({})
const beforeDraft = reactive({})
const percentDraft = reactive({})
const cartelDraft = ref('')
const pricesSaving = ref(false)
const pricesMsg = ref('')

// El input vacío de «Antes» da '' con v-model.number: es «sin precio de antes».
const beforeValue = (id) => (beforeDraft[id] === '' || beforeDraft[id] == null ? null : beforeDraft[id])
const discount = (id) => {
  const before = beforeValue(id)
  return before && priceDraft[id] > 0 && before > priceDraft[id] ? Math.round((1 - priceDraft[id] / before) * 100) : null
}

// El % es un atajo: al cargarlo, lo de antes es el precio sin descuento y el
// precio se calcula (redondeado a $100). Si se toca el precio o el de antes a
// mano, el % se recalcula. Vaciarlo saca la promo y vuelve al precio de antes.
const roundPrice = (n) => (n >= 1000 ? Math.round(n / 100) * 100 : Math.round(n))
function onPercent(id) {
  const p = percentDraft[id]
  if (p === '' || p == null) {
    if (beforeValue(id)) priceDraft[id] = beforeValue(id)
    beforeDraft[id] = null
    return
  }
  if (!Number.isInteger(p) || p < 1 || p > 99) return
  const base = beforeValue(id) ?? priceDraft[id]
  if (!Number.isInteger(base) || base <= 0) return
  beforeDraft[id] = base
  priceDraft[id] = roundPrice(base * (1 - p / 100))
}
const syncPercent = (id) => (percentDraft[id] = discount(id) ?? '')

function resetPriceDraft() {
  for (const r of PRICE_ROWS) {
    priceDraft[r.id] = priceOf(r.id)
    beforeDraft[r.id] = currentBefore(r.id)
    syncPercent(r.id)
  }
  cartelDraft.value = PRICE_PROMO.cartel
}
resetPriceDraft()
onMounted(async () => {
  await loadPlanPrices(true)
  resetPriceDraft()
})

const rowChanged = (id) => priceDraft[id] !== priceOf(id) || beforeValue(id) !== currentBefore(id)
const priceChanges = computed(() => PRICE_ROWS.filter((r) => rowChanged(r.id)))
const cartelChanged = computed(() => cartelDraft.value.trim() !== PRICE_PROMO.cartel)
const hasChanges = computed(() => priceChanges.value.length > 0 || cartelChanged.value)

// Enteros positivos, y los de particulares en orden: si Plus costara menos
// que Invitación, «pasarse pagando la diferencia» no tendría sentido.
const priceProblem = computed(() => {
  if (PRICE_ROWS.some((r) => !Number.isInteger(priceDraft[r.id]) || priceDraft[r.id] <= 0))
    return 'Cada precio tiene que ser un número entero mayor a 0.'
  if (!(priceDraft.invitacion < priceDraft.plus && priceDraft.plus < priceDraft.premium))
    return 'Tiene que ser Invitación < Plus < Premium (pasarse de plan cobra la diferencia).'
  const badBefore = PRICE_ROWS.find((r) => {
    const b = beforeValue(r.id)
    return b !== null && (!Number.isInteger(b) || b <= priceDraft[r.id])
  })
  if (badBefore) return `El precio de antes de ${badBefore.label} tiene que ser mayor al precio (o dejalo vacío).`
  return ''
})

function describeRow(r) {
  const parts = []
  if (priceDraft[r.id] !== priceOf(r.id)) parts.push(`${formatPrice(priceOf(r.id))} → ${formatPrice(priceDraft[r.id])}`)
  if (beforeValue(r.id) !== currentBefore(r.id))
    parts.push(beforeValue(r.id) ? `antes ${formatPrice(beforeValue(r.id))}` : 'sin precio de antes')
  return `${r.label}: ${parts.join(', ')}`
}

async function savePrices() {
  const changes = priceChanges.value
  if (!hasChanges.value || priceProblem.value) return
  const cartel = cartelDraft.value.trim()
  const lines = changes.map(describeRow)
  if (cartelChanged.value) lines.push(cartel ? `Cartel: «${cartel}»` : 'Sin cartel')
  const ok = await confirmDialog({
    title: '¿Cambiar los precios?',
    message: lines.join(' · ') + '. Se ven al instante en la landing y en el panel, y los próximos pagos se cobran así.',
    confirmText: 'Cambiar precios',
  })
  if (!ok) return
  pricesSaving.value = true
  pricesMsg.value = ''
  const now = new Date().toISOString()
  const results = await Promise.all([
    ...changes.map((r) =>
      supabase
        .from('precios_planes')
        .update({ precio: priceDraft[r.id], precio_antes: beforeValue(r.id), actualizado_en: now })
        .eq('plan', r.id)
        .select(),
    ),
    ...(cartelChanged.value
      ? [supabase.from('precios_cartel').update({ texto: cartel || null, actualizado_en: now }).eq('id', true).select()]
      : []),
  ])
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
      <!-- Cartel -->
      <div class="border-b border-pumice pb-5">
        <label for="precio-cartel" class="block font-bold">Esquinero de la promo</label>
        <span class="block text-xs text-obsidian/55">Banda en la esquina de las tarjetas de los planes con descuento (en todas, si ninguno tiene). Vacío, no se muestra.</span>
        <div class="mt-2 flex flex-wrap items-center gap-2">
          <input
            id="precio-cartel"
            v-model="cartelDraft"
            type="text"
            :maxlength="CARTEL_MAX"
            placeholder="Ej.: Precio lanzamiento"
            class="admin-input !py-2 sm:max-w-xs"
            :class="cartelChanged ? '!border-accent' : ''"
          />
          <button
            v-for="t in CARTEL_IDEAS"
            :key="t"
            type="button"
            @click="cartelDraft = t"
            class="rounded-full bg-chalk px-3 py-1.5 text-xs font-bold text-obsidian/70 transition-colors hover:bg-accent-soft hover:text-accent"
          >
            {{ t }}
          </button>
        </div>
      </div>

      <!-- Precios -->
      <div class="mt-5 hidden justify-end gap-3 text-xs font-bold tracking-wide text-obsidian/45 uppercase sm:flex">
        <span class="w-32 text-center">Antes (tachado)</span>
        <span class="w-20 text-center">Descuento</span>
        <span class="w-36 text-center">Precio (ARS)</span>
      </div>
      <ul class="mt-3 space-y-3 sm:mt-2">
        <li v-for="r in PRICE_ROWS" :key="r.id" class="flex flex-wrap items-center justify-between gap-x-4 gap-y-2">
          <label :for="`precio-${r.id}`" class="min-w-0">
            <span class="flex items-center gap-2 font-bold">
              {{ r.label }}
              <span v-if="discount(r.id)" class="rounded-full bg-sulfur px-2 py-0.5 text-[0.7rem] text-obsidian">
                −{{ discount(r.id) }}%
              </span>
            </span>
            <span class="block text-xs text-obsidian/55">{{ r.hint }}</span>
          </label>
          <span class="flex w-full gap-3 sm:w-auto">
            <span class="relative flex-1 sm:w-32 sm:flex-none">
              <span class="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 font-bold text-obsidian/35">$</span>
              <input
                :id="`precio-antes-${r.id}`"
                v-model.number="beforeDraft[r.id]"
                @input="syncPercent(r.id)"
                type="number"
                inputmode="numeric"
                min="1"
                step="1"
                placeholder="—"
                :aria-label="`${r.label}: precio de antes (tachado)`"
                class="admin-input !py-2 !pl-8 text-right text-obsidian/55 tabular-nums line-through"
                :class="beforeValue(r.id) !== currentBefore(r.id) ? '!border-accent' : ''"
              />
            </span>
            <span class="relative w-20 shrink-0">
              <input
                :id="`precio-descuento-${r.id}`"
                v-model.number="percentDraft[r.id]"
                @input="onPercent(r.id)"
                @blur="syncPercent(r.id)"
                type="number"
                inputmode="numeric"
                min="1"
                max="99"
                step="1"
                placeholder="—"
                :aria-label="`${r.label}: descuento en %`"
                class="admin-input !py-2 !pr-7 text-right tabular-nums"
              />
              <span class="pointer-events-none absolute top-1/2 right-3 -translate-y-1/2 font-bold text-obsidian/45">%</span>
            </span>
            <span class="relative flex-1 sm:w-36 sm:flex-none">
              <span class="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 font-bold text-obsidian/45">$</span>
              <input
                :id="`precio-${r.id}`"
                v-model.number="priceDraft[r.id]"
                @input="syncPercent(r.id)"
                type="number"
                inputmode="numeric"
                min="1"
                step="1"
                class="admin-input !py-2 !pl-8 text-right tabular-nums"
                :class="priceDraft[r.id] !== priceOf(r.id) ? '!border-accent' : ''"
              />
            </span>
          </span>
        </li>
      </ul>
      <p v-if="priceProblem" role="alert" class="mt-4 text-sm font-bold text-nogo">{{ priceProblem }}</p>
      <div class="mt-5 flex flex-wrap items-center gap-3">
        <button type="submit" class="admin-btn-primary" :disabled="!hasChanges || !!priceProblem || pricesSaving">
          {{ pricesSaving ? 'Guardando…' : 'Guardar precios' }}
        </button>
        <button
          v-if="hasChanges && !pricesSaving"
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
