<script setup>
import { ref, computed, watch, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Search, Check, LogOut, Users, X, ChevronRight, CalendarDays } from '@lucide/vue'
import { supabase } from '../lib/supabase'
import { useAuth } from '../composables/useAuth'
import { confirmDialog } from '../composables/useConfirm'

// Pantalla del personal del salón en la entrada (tablet o celular): busca al
// invitado, le dice su mesa y lo marca como llegado. Varias personas pueden
// usarla a la vez: se refresca cada 10 s. Todo pasa por las RPC de
// migrations/20261012_recepcion.sql.
const route = useRoute()
const router = useRouter()
const { user, logout } = useAuth()

const eventId = computed(() => route.params.eventId || null)
const staffName = computed(() => user.value?.user_metadata?.display_name || '')

// --- Sin evento elegido: lista de mis eventos -----------------------------------------
const myEvents = ref(null)

async function loadMyEvents() {
  const { data, error: err } = await supabase.rpc('mis_eventos_recepcion')
  if (err) return (error.value = 'No se pudieron cargar tus eventos.')
  myEvents.value = data
  if (data.length === 1) router.replace({ name: 'recepcion', params: { eventId: data[0].id } })
}

const formatDate = (d) =>
  d ? new Date(`${d}T12:00:00`).toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' }) : ''

// --- Evento elegido: la lista -----------------------------------------------------------
const event = ref(null)
const guests = ref([])
const loading = ref(true)
const error = ref('')
// Ids que se están guardando ahora (ver mark()).
const pending = new Set()

async function fetchList() {
  const { data, error: err } = await supabase.rpc('recepcion_lista', { p_event_id: eventId.value })
  if (err) {
    error.value = err.message?.includes('No autorizado')
      ? 'Tu usuario no tiene acceso a este evento.'
      : 'No se pudo cargar la lista. Revisá la conexión.'
    return
  }
  error.value = ''
  event.value = data.event
  // Lo que se está guardando ahora no lo pisa un refresco que salió antes.
  guests.value = data.guests.map((g) => (pending.has(g.id) ? guests.value.find((o) => o.id === g.id) ?? g : g))
}

let timer = null
watch(
  eventId,
  async (id) => {
    clearInterval(timer)
    loading.value = true
    event.value = null
    if (id) {
      await fetchList()
      timer = setInterval(() => document.visibilityState === 'visible' && fetchList(), 10000)
    } else {
      await loadMyEvents()
    }
    loading.value = false
  },
  { immediate: true },
)
onUnmounted(() => clearInterval(timer))

// --- Búsqueda y filtro ------------------------------------------------------------------
const search = ref('')
const filter = ref('todos') // 'todos' | 'faltan' | 'llegaron'

// Sin acentos ni mayúsculas: «sofia» encuentra a «Sofía».
const normalize = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

const arrivedCount = computed(() => guests.value.filter((g) => g.arrived_at).length)

const families = computed(() => {
  const q = normalize(search.value.trim())
  const out = []
  const byId = {}
  for (const g of guests.value) {
    if (filter.value === 'faltan' && g.arrived_at) continue
    if (filter.value === 'llegaron' && !g.arrived_at) continue
    // Si coincide la familia, se muestra entera; si no, solo quien coincide.
    if (q && !normalize(g.family_name).includes(q) && !normalize(g.full_name).includes(q)) continue
    if (!byId[g.group_id]) {
      byId[g.group_id] = { id: g.group_id, name: g.family_name, guests: [] }
      out.push(byId[g.group_id])
    }
    byId[g.group_id].guests.push(g)
  }
  return out
})

// Total de la familia (no solo los que pasan el filtro), para «2 de 4».
const familyTotals = computed(() => {
  const map = {}
  for (const g of guests.value) {
    const t = (map[g.group_id] ??= { total: 0, arrived: 0 })
    t.total++
    if (g.arrived_at) t.arrived++
  }
  return map
})

// --- Marcar llegadas --------------------------------------------------------------------
const saving = ref(new Set())

async function mark(ids, arrived) {
  const before = new Map(guests.value.map((g) => [g.id, g.arrived_at]))
  const now = new Date().toISOString()
  ids.forEach((id) => pending.add(id))
  saving.value = new Set([...saving.value, ...ids])
  guests.value = guests.value.map((g) => (ids.includes(g.id) ? { ...g, arrived_at: arrived ? g.arrived_at || now : null } : g))

  const { data, error: err } = await supabase.rpc('recepcion_marcar', {
    p_event_id: eventId.value,
    p_guest_ids: ids,
    p_llego: arrived,
  })
  ids.forEach((id) => pending.delete(id))
  saving.value = new Set([...saving.value].filter((id) => !ids.includes(id)))

  if (err) {
    guests.value = guests.value.map((g) => (ids.includes(g.id) ? { ...g, arrived_at: before.get(g.id) } : g))
    error.value = 'No se pudo guardar. Revisá la conexión y probá de nuevo.'
    return
  }
  error.value = ''
  // La hora que quedó en la base (si otra persona ya lo había marcado, la suya).
  guests.value = guests.value.map((g) => (g.id in data ? { ...g, arrived_at: data[g.id] } : g))
}

async function toggleGuest(g) {
  if (!g.arrived_at) return mark([g.id], true)
  const ok = await confirmDialog({
    title: `¿Desmarcar a ${g.full_name}?`,
    message: 'Va a figurar como que todavía no llegó.',
    confirmText: 'Desmarcar',
  })
  if (ok) mark([g.id], false)
}

function markFamily(family) {
  const ids = guests.value.filter((g) => g.group_id === family.id && !g.arrived_at).map((g) => g.id)
  if (ids.length) mark(ids, true)
}

const timeOf = (iso) => new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })

async function onLogout() {
  await logout()
  router.push({ name: 'admin-login' })
}
</script>

<template>
  <div class="font-ui min-h-dvh bg-pumice text-obsidian">
    <!-- Elegir evento -->
    <div v-if="!eventId" class="mx-auto max-w-xl px-4 pt-10 pb-16">
      <div class="flex items-start justify-between gap-4">
        <div>
          <h1 class="admin-display text-5xl">Recepción</h1>
          <p v-if="staffName" class="mt-2 text-obsidian/60">Hola, {{ staffName }}</p>
        </div>
        <button type="button" @click="onLogout" class="admin-btn-secondary shrink-0 px-4 py-2 text-sm">
          <LogOut :size="16" /> Salir
        </button>
      </div>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>
      <p v-else-if="error" class="mt-8 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ error }}</p>
      <div v-else-if="!myEvents?.length" class="mt-8 rounded-[2rem] bg-limestone p-8 text-obsidian/60">
        Tu usuario todavía no está asignado a ningún evento. Pedile al organizador que te agregue.
      </div>
      <ul v-else class="mt-8 space-y-2">
        <li v-for="e in myEvents" :key="e.id">
          <router-link
            :to="{ name: 'recepcion', params: { eventId: e.id } }"
            class="flex items-center gap-4 rounded-[1.5rem] bg-limestone p-4 transition-colors hover:bg-chalk"
          >
            <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-accent-soft text-accent">
              <CalendarDays :size="20" />
            </span>
            <span class="min-w-0 flex-1">
              <span class="block truncate font-bold">{{ e.name }}</span>
              <span class="block text-sm text-obsidian/55 first-letter:uppercase">{{ formatDate(e.event_date) }}</span>
            </span>
            <ChevronRight :size="18" class="shrink-0 text-obsidian/40" />
          </router-link>
        </li>
      </ul>
    </div>

    <!-- Lista de la entrada -->
    <template v-else>
      <header class="sticky top-0 z-20 bg-pumice/95 px-4 pt-4 pb-3 backdrop-blur">
        <div class="mx-auto max-w-3xl">
          <div class="flex items-center justify-between gap-3">
            <div class="min-w-0">
              <!-- Con qué cuenta se está marcando: el personal o el organizador (que también puede). -->
              <p class="truncate text-xs font-bold tracking-wide text-obsidian/50 uppercase">
                Recepción · {{ staffName || `${user?.email} (organizador)` }}
              </p>
              <h1 class="truncate text-2xl font-bold">{{ event?.name ?? '…' }}</h1>
            </div>
            <button type="button" @click="onLogout" aria-label="Salir" class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-limestone">
              <LogOut :size="18" />
            </button>
          </div>

          <div v-if="event" class="mt-3 flex items-center gap-3">
            <div class="h-2.5 flex-1 overflow-hidden rounded-full bg-chalk">
              <div class="h-full rounded-full bg-go transition-[width] duration-500" :style="{ width: `${guests.length ? (arrivedCount / guests.length) * 100 : 0}%` }"></div>
            </div>
            <p class="shrink-0 text-sm"><strong class="text-base">{{ arrivedCount }}</strong> de {{ guests.length }} llegaron</p>
          </div>

          <div class="relative mt-3">
            <Search :size="20" class="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 text-obsidian/40" />
            <input
              v-model="search"
              type="search"
              autocomplete="off"
              autocapitalize="none"
              spellcheck="false"
              placeholder="Buscar por nombre o familia"
              class="admin-input py-3.5 pr-12 pl-12 text-lg"
            />
            <button
              v-if="search"
              type="button"
              @click="search = ''"
              aria-label="Borrar búsqueda"
              class="absolute top-1/2 right-2 grid h-9 w-9 -translate-y-1/2 place-items-center rounded-full hover:bg-limestone"
            >
              <X :size="18" />
            </button>
          </div>

          <div class="mt-3 flex gap-2">
            <button
              v-for="f in [
                { id: 'todos', label: 'Todos' },
                { id: 'faltan', label: `Faltan ${guests.length - arrivedCount}` },
                { id: 'llegaron', label: `Llegaron ${arrivedCount}` },
              ]"
              :key="f.id"
              type="button"
              @click="filter = f.id"
              class="rounded-full px-4 py-1.5 text-sm font-bold transition-colors"
              :class="filter === f.id ? 'bg-obsidian text-chalk' : 'bg-limestone'"
            >
              {{ f.label }}
            </button>
          </div>
        </div>
      </header>

      <main class="mx-auto max-w-3xl px-4 pt-2 pb-16">
        <p v-if="error" class="mb-3 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold" role="alert">{{ error }}</p>
        <p v-if="loading" class="mt-8 text-obsidian/55">Cargando…</p>

        <p v-else-if="!families.length" class="mt-8 rounded-[2rem] bg-limestone p-8 text-center text-obsidian/60">
          <template v-if="search">No hay nadie con «{{ search }}» en la lista.</template>
          <template v-else-if="filter === 'faltan'">¡Llegaron todos!</template>
          <template v-else>Todavía no hay nadie en la lista.</template>
        </p>

        <ul v-else class="space-y-3">
          <li v-for="fam in families" :key="fam.id" class="rounded-[1.75rem] bg-limestone p-3">
            <div class="flex items-center justify-between gap-3 px-2 pt-1 pb-2">
              <p class="min-w-0 truncate text-sm font-bold text-obsidian/60">
                <Users :size="14" class="mr-1 inline -translate-y-px" />{{ fam.name }}
                <span class="font-medium">· {{ familyTotals[fam.id].arrived }} de {{ familyTotals[fam.id].total }}</span>
              </p>
              <button
                v-if="familyTotals[fam.id].total > 1 && familyTotals[fam.id].arrived < familyTotals[fam.id].total"
                type="button"
                @click="markFamily(fam)"
                class="shrink-0 rounded-full bg-chalk px-3 py-1.5 text-xs font-bold text-accent"
              >
                Llegaron todos
              </button>
            </div>

            <ul class="space-y-1.5">
              <li
                v-for="g in fam.guests"
                :key="g.id"
                class="flex items-center gap-3 rounded-[1.25rem] p-2 pl-4 transition-colors"
                :class="g.arrived_at ? 'bg-go/15' : 'bg-chalk'"
              >
                <div class="min-w-0 flex-1">
                  <p class="truncate text-lg font-bold">{{ g.full_name }}</p>
                  <p v-if="g.arrived_at || g.is_minor" class="text-xs text-obsidian/55">
                    <template v-if="g.is_minor"><strong class="text-accent">Menor de {{ event?.minor_age ?? 3 }}</strong></template>
                    <template v-if="g.is_minor && g.arrived_at"> · </template>
                    <template v-if="g.arrived_at">Llegó {{ timeOf(g.arrived_at) }}</template>
                  </p>
                </div>
                <span
                  class="shrink-0 rounded-full px-3 py-1.5 text-sm font-bold"
                  :class="g.table_name ? 'bg-accent-soft text-accent' : 'bg-pumice text-obsidian/50'"
                >
                  {{ g.table_name ?? 'Sin mesa' }}
                </span>
                <button
                  type="button"
                  @click="toggleGuest(g)"
                  :disabled="saving.has(g.id)"
                  :aria-label="g.arrived_at ? `Desmarcar a ${g.full_name}` : `Marcar que llegó ${g.full_name}`"
                  class="flex h-12 shrink-0 items-center justify-center gap-1.5 rounded-full px-4 font-bold transition-colors disabled:opacity-60"
                  :class="g.arrived_at ? 'w-12 bg-go text-obsidian' : 'bg-accent text-chalk'"
                >
                  <Check :size="20" />
                  <span v-if="!g.arrived_at">Llegó</span>
                </button>
              </li>
            </ul>
          </li>
        </ul>
      </main>
    </template>
  </div>
</template>
