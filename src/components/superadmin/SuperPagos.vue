<script setup>
import { ref, computed, onMounted } from 'vue'
import { RefreshCw } from '@lucide/vue'
import { useSuperadmin } from '../../composables/useSuperadmin'
import { supabase } from '../../lib/supabase'
import { PLANS, formatPrice } from '../../lib/plans'

// Superadmin › Pagos: todos los pagos de Mercado Pago (la policy de `pagos`
// deja leer todo al superadmin). El mail sale del evento o, si pagó antes de
// armar la invitación (pago sin evento), de las cuentas sin evento (useSuperadmin).
//
// «Incompleto» no es un estado de la base: es un 'pendiente' SIN número de MP,
// o sea alguien que abrió Mercado Pago y no pagó (MP nunca avisa nada de esos).
// «Pendiente» queda para pagos que existen en MP y esperan acreditarse
// (efectivo, transferencia o en revisión).
const { rows, pendingAccounts } = useSuperadmin()
const error = ref('')
const pagos = ref([])
const pagosLoading = ref(true)
const pagosFilter = ref('todos')
const PAGO_ESTADOS = {
  aprobado: { label: 'Aprobado', cls: 'bg-go/20' },
  pendiente: { label: 'Pendiente', cls: 'bg-sulfur' },
  incompleto: { label: 'Incompleto', cls: 'bg-pumice text-obsidian/60' },
  rechazado: { label: 'Rechazado', cls: 'bg-nogo/15' },
  cancelado: { label: 'Cancelado', cls: 'bg-pumice text-obsidian/60' },
  devuelto: { label: 'Devuelto', cls: 'bg-nogo/15' },
}
const PAGO_FILTERS = [
  { id: 'todos', label: 'Todos' },
  { id: 'aprobado', label: 'Aprobados' },
  { id: 'pendiente', label: 'Pendientes' },
  { id: 'incompleto', label: 'Incompletos' },
  { id: 'otros', label: 'Rechazados y otros' },
]
const estadoDe = (p) => (p.estado === 'pendiente' && !p.mp_payment_id ? 'incompleto' : p.estado)
const grupoDe = (p) => (['aprobado', 'pendiente', 'incompleto'].includes(estadoDe(p)) ? estadoDe(p) : 'otros')

async function fetchPagos() {
  pagosLoading.value = true
  const { data, error: err } = await supabase
    .from('pagos')
    .select('id, event_id, user_id, plan, monto, estado, mp_payment_id, creado_en, aprobado_en')
    .order('creado_en', { ascending: false })
    .limit(200)
  if (err) error.value = `No se pudieron leer los pagos: ${err.message}`
  else pagos.value = data
  pagosLoading.value = false
}
onMounted(fetchPagos)

const eventById = computed(() => new Map(rows.value.map((r) => [r.event_id, r])))
const accountById = computed(() => new Map(pendingAccounts.value.map((a) => [a.user_id, a])))
const mailDe = (p) => eventById.value.get(p.event_id)?.owner_email ?? accountById.value.get(p.user_id)?.email ?? 'Cuenta eliminada'
const pagosCount = computed(() => {
  const c = { todos: pagos.value.length, aprobado: 0, pendiente: 0, incompleto: 0, otros: 0 }
  for (const p of pagos.value) c[grupoDe(p)]++
  return c
})
// «Rechazados y otros» solo aparece si hay alguno.
const filtrosVisibles = computed(() => PAGO_FILTERS.filter((f) => f.id !== 'otros' || pagosCount.value.otros))
const pagosFiltered = computed(() =>
  pagos.value.filter((p) => pagosFilter.value === 'todos' || grupoDe(p) === pagosFilter.value),
)
const cobrado = computed(() => pagos.value.filter((p) => p.estado === 'aprobado').reduce((t, p) => t + p.monto, 0))
const cobradoMes = computed(() => {
  const d = new Date()
  const desde = new Date(d.getFullYear(), d.getMonth(), 1)
  return pagos.value
    .filter((p) => p.estado === 'aprobado' && new Date(p.aprobado_en ?? p.creado_en) >= desde)
    .reduce((t, p) => t + p.monto, 0)
})
const pagoDate = (iso) =>
  new Date(iso).toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
</script>

<template>
  <div>
    <div class="flex flex-wrap items-center justify-between gap-2">
      <p class="max-w-lg text-obsidian/60">Los pagos con Mercado Pago. Un pago aprobado ya subió el plan solo.</p>
      <button
        type="button"
        @click="fetchPagos"
        :disabled="pagosLoading"
        class="flex items-center gap-1.5 rounded-full bg-limestone px-3 py-1.5 text-sm font-bold hover:bg-chalk"
      >
        <RefreshCw :size="14" :class="pagosLoading ? 'animate-spin' : ''" /> Actualizar
      </button>
    </div>
    <p v-if="error" class="mt-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ error }}</p>

    <div class="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3">
      <div class="rounded-[1.5rem] bg-limestone p-4">
        <p class="text-xs font-bold text-obsidian/55">Cobrado este mes</p>
        <p class="mt-1 text-2xl font-bold tabular-nums">{{ formatPrice(cobradoMes) }}</p>
      </div>
      <div class="rounded-[1.5rem] bg-limestone p-4">
        <p class="text-xs font-bold text-obsidian/55">Cobrado en total</p>
        <p class="mt-1 text-2xl font-bold tabular-nums">{{ formatPrice(cobrado) }}</p>
      </div>
      <div class="col-span-2 rounded-[1.5rem] bg-limestone p-4 sm:col-span-1">
        <p class="text-xs font-bold text-obsidian/55">Pagos aprobados</p>
        <p class="mt-1 text-2xl font-bold tabular-nums">{{ pagosCount.aprobado }}</p>
      </div>
    </div>

    <div class="mt-4 flex flex-wrap gap-2">
      <button
        v-for="f in filtrosVisibles"
        :key="f.id"
        type="button"
        @click="pagosFilter = f.id"
        :class="pagosFilter === f.id ? 'bg-accent text-chalk' : 'bg-limestone hover:bg-chalk'"
        class="flex items-center gap-2 rounded-full px-4 py-2 text-sm font-bold transition-colors"
      >
        {{ f.label }}
        <span :class="pagosFilter === f.id ? 'text-chalk/70' : 'text-obsidian/45'">{{ pagosCount[f.id] }}</span>
      </button>
    </div>

    <p v-if="!pagosFiltered.length" class="mt-4 rounded-[1.5rem] bg-limestone p-6 text-center text-sm text-obsidian/60">
      {{ pagos.length ? 'No hay pagos en esta categoría.' : 'Todavía no hay pagos.' }}
    </p>
    <ul v-else class="mt-4 space-y-2">
      <li
        v-for="p in pagosFiltered"
        :key="p.id"
        class="flex flex-wrap items-start justify-between gap-x-4 gap-y-2 rounded-[1.5rem] bg-limestone px-5 py-4"
      >
        <div class="min-w-0">
          <p class="truncate font-bold">{{ mailDe(p) }}</p>
          <p class="text-sm text-obsidian/60">
            Plan {{ PLANS[p.plan]?.label ?? p.plan }} · {{ pagoDate(p.creado_en) }}
            <template v-if="p.mp_payment_id"> · <span class="select-all" title="Número de pago en Mercado Pago">MP {{ p.mp_payment_id }}</span></template>
          </p>
        </div>
        <div class="flex shrink-0 items-center gap-2">
          <span class="font-bold tabular-nums">{{ formatPrice(p.monto) }}</span>
          <span class="rounded-full px-2.5 py-1 text-xs font-bold" :class="PAGO_ESTADOS[estadoDe(p)]?.cls">
            {{ PAGO_ESTADOS[estadoDe(p)]?.label ?? p.estado }}
          </span>
        </div>
      </li>
    </ul>
    <p class="mt-3 text-xs text-obsidian/45">
      <strong>Pendiente:</strong> el pago está en Mercado Pago y espera acreditarse (efectivo, transferencia o en revisión).
      <strong>Incompleto:</strong> abrió Mercado Pago y no terminó de pagar; no hay plata en juego.
    </p>
  </div>
</template>
