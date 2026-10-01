<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Search, ShieldCheck, ArrowRight, CalendarDays } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { useAuth } from '../composables/useAuth'
import { supabase } from '../lib/supabase'

// Lista de todos los eventos (solo superadmin): entrar al panel de un
// cliente para ayudarlo y activarle el plan.
const router = useRouter()
const { viewing, setViewingEvent } = useEvent()
const { user } = useAuth()

const rows = ref([])
const loading = ref(true)
const error = ref('')
const search = ref('')
const filter = ref('todos') // 'todos' | 'plus' | 'basico'
const savingId = ref(null)

onMounted(async () => {
  const { data, error: err } = await supabase.rpc('listar_eventos_superadmin')
  if (err) error.value = err.message
  else rows.value = data ?? []
  loading.value = false
})

function entrar(row) {
  setViewingEvent({ id: row.event_id, name: row.event_name, owner_email: row.owner_email })
  router.push({ name: 'admin-dashboard' })
}

// El plan lo activa TizDigital a mano acá (todavía no hay billing
// automático) — el host no puede subirse de plan solo.
async function setPlan(row, plan) {
  if (row.plan === plan) return
  error.value = ''
  savingId.value = row.event_id
  const { error: err } = await supabase.from('events').update({ plan }).eq('id', row.event_id)
  if (err) error.value = `No se pudo cambiar el plan de «${row.event_name}»: ${err.message}`
  else row.plan = plan
  savingId.value = null
}

// --- Fechas ---------------------------------------------------------------------
// event_date viene como 'YYYY-MM-DD': se arma en hora local para que no se
// corra un día por el huso.
function localDate(ymd) {
  const [y, m, d] = ymd.split('-').map(Number)
  return new Date(y, m - 1, d)
}

function formatDate(ymd) {
  return localDate(ymd).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function daysLabel(ymd) {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const days = Math.round((localDate(ymd) - today) / 86400000)
  if (days === 0) return '¡es hoy!'
  if (days === 1) return 'mañana'
  if (days > 1) return `faltan ${days} días`
  return 'ya pasó'
}

const isPast = (row) => row.event_date && daysLabel(row.event_date) === 'ya pasó'

// --- Filtros ----------------------------------------------------------------------
const counts = computed(() => ({
  todos: rows.value.length,
  plus: rows.value.filter((r) => r.plan === 'plus').length,
  basico: rows.value.filter((r) => r.plan !== 'plus').length,
}))

const FILTERS = [
  { id: 'todos', label: 'Todos' },
  { id: 'plus', label: 'Plus' },
  { id: 'basico', label: 'Básico' },
]

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return rows.value
    .filter((r) => filter.value === 'todos' || (filter.value === 'plus') === (r.plan === 'plus'))
    .filter((r) => !q || r.owner_email?.toLowerCase().includes(q) || r.event_name?.toLowerCase().includes(q))
})

const isMine = (row) => row.owner_email && row.owner_email === user.value?.email
const isViewing = (row) => viewing.value?.id === row.event_id
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-3xl px-4 pt-4 pb-16 lg:px-8 lg:pt-8">
      <p class="inline-flex items-center gap-1.5 rounded-full bg-obsidian px-3 py-1 text-xs font-bold text-chalk">
        <ShieldCheck :size="13" /> Superadmin
      </p>
      <h1 class="admin-display mt-3 text-5xl sm:text-6xl">Clientes</h1>
      <p class="mt-3 max-w-lg text-obsidian/60">
        Entrá al panel de cualquier cliente para ayudarlo. Mientras estés adentro vas a ver un aviso arriba de todo, con
        un botón para salir.
      </p>

      <!-- Filtros + buscador -->
      <div class="mt-6 flex flex-wrap items-center gap-2">
        <button
          v-for="f in FILTERS"
          :key="f.id"
          type="button"
          @click="filter = f.id"
          :class="filter === f.id ? 'bg-accent text-chalk' : 'bg-limestone hover:bg-chalk'"
          class="flex items-center gap-2 rounded-full px-4 py-2 text-sm font-bold transition-colors"
        >
          {{ f.label }}
          <span :class="filter === f.id ? 'text-chalk/70' : 'text-obsidian/45'">{{ counts[f.id] }}</span>
        </button>
        <label class="relative ml-auto w-full sm:w-64">
          <Search :size="16" class="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 text-obsidian/40" />
          <input v-model="search" type="search" placeholder="Buscar mail o evento" class="admin-input !py-2 !pl-10 text-sm" />
        </label>
      </div>

      <p v-if="error" class="mt-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ error }}</p>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>

      <div v-else-if="!rows.length && !error" class="mt-6 rounded-[2rem] bg-limestone p-8 text-center text-obsidian/60">
        Todavía no hay ningún evento creado.
      </div>

      <div v-else-if="!filtered.length && rows.length" class="mt-6 rounded-[2rem] bg-limestone p-8 text-center text-obsidian/60">
        <template v-if="search.trim()">No hay clientes que coincidan con «{{ search.trim() }}».</template>
        <template v-else>No hay clientes en esta categoría.</template>
      </div>

      <ul v-else class="mt-4 space-y-3">
        <li
          v-for="row in filtered"
          :key="row.event_id"
          :class="{ 'ring-2 ring-accent': isViewing(row), 'opacity-70': isPast(row) }"
          class="rounded-[1.75rem] bg-limestone p-5 sm:p-6"
        >
          <div class="flex flex-wrap items-start justify-between gap-x-4 gap-y-4">
            <div class="min-w-0">
              <h2 class="flex min-w-0 flex-wrap items-center gap-2 text-lg font-bold">
                <span class="truncate">{{ row.event_name }}</span>
                <span v-if="isMine(row)" class="shrink-0 rounded-full bg-chalk px-2.5 py-0.5 text-xs">Tu cuenta</span>
                <span v-if="isViewing(row)" class="shrink-0 rounded-full bg-accent px-2.5 py-0.5 text-xs text-chalk">
                  Estás viendo este
                </span>
              </h2>
              <p class="truncate text-sm text-obsidian/60">{{ row.owner_email }}</p>
              <p class="mt-2 flex items-center gap-1.5 text-xs font-bold text-obsidian/45">
                <CalendarDays :size="13" />
                <template v-if="row.event_date">{{ formatDate(row.event_date) }} · {{ daysLabel(row.event_date) }}</template>
                <template v-else>Sin fecha cargada</template>
              </p>
            </div>

            <div class="flex shrink-0 flex-wrap items-center gap-2">
              <!-- Plan -->
              <div
                class="flex rounded-full bg-pumice/70 p-0.5 text-sm font-bold"
                :class="{ 'opacity-50': savingId === row.event_id }"
                role="group"
                :aria-label="`Plan de ${row.event_name}`"
              >
                <button
                  type="button"
                  :disabled="savingId === row.event_id"
                  @click="setPlan(row, 'basico')"
                  :class="row.plan !== 'plus' ? 'bg-chalk' : 'text-obsidian/55 hover:text-obsidian'"
                  class="rounded-full px-3 py-1.5 transition-colors"
                >
                  Básico
                </button>
                <button
                  type="button"
                  :disabled="savingId === row.event_id"
                  @click="setPlan(row, 'plus')"
                  :class="row.plan === 'plus' ? 'bg-accent text-chalk' : 'text-obsidian/55 hover:text-obsidian'"
                  class="rounded-full px-3 py-1.5 transition-colors"
                >
                  Plus
                </button>
              </div>

              <button type="button" @click="entrar(row)" class="admin-btn-primary !px-5 !py-2.5 text-sm">
                Entrar
                <ArrowRight :size="16" />
              </button>
            </div>
          </div>
        </li>
      </ul>

      <p v-if="!loading && rows.length" class="mt-6 text-center text-xs text-obsidian/45">
        Ordenados por fecha de creación, del más nuevo al más viejo.
      </p>
    </div>
  </div>
</template>
