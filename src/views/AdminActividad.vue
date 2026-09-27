<script setup>
import { ref, computed, onMounted } from 'vue'
import { ArrowLeft, Check, Eye, Search } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'
import { timeAgo } from '../lib/timeAgo'

// Registro completo de movimientos: cada vez que alguien abrió su link
// (invitation_views) y cada respuesta (rsvp_log, ver fetchResponses).
const { event, loadEvent } = useEvent()
const loading = ref(true)
const responses = ref([])
const views = ref([])
const hasMoreViews = ref(false)
const loadingMore = ref(false)
const VIEWS_PAGE = 200

const filter = ref('todos') // todos | respuestas | visitas
const search = ref('')

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) await Promise.all([fetchResponses(), fetchViews()])
  loading.value = false
})

// Respuestas normalizadas a { key, groupId, name, status, going, at }.
// Fuente preferida: rsvp_log (cada respuesta, incluidos los cambios de
// opinión — migrations/20260927_historial_respuestas.sql). Si esa tabla
// todavía no existe, cae a responded_at (solo la última respuesta).
async function fetchResponses() {
  const log = await supabase
    .from('rsvp_log')
    .select('id, status, attending_count, created_at, invitation_groups!inner(id, family_name, event_id)')
    .eq('invitation_groups.event_id', event.value.id)
  if (!log.error) {
    responses.value = log.data.map((r) => ({
      key: `l-${r.id}`,
      groupId: r.invitation_groups.id,
      name: r.invitation_groups.family_name,
      status: r.status,
      going: r.attending_count,
      at: r.created_at,
    }))
    return
  }

  const { data, error } = await supabase
    .from('invitation_groups')
    .select('id, family_name, status, responded_at, guests(rsvp_status)')
    .eq('event_id', event.value.id)
    .not('responded_at', 'is', null)
  responses.value = error
    ? []
    : data
        .filter((g) => g.status !== 'pending')
        .map((g) => ({
          key: `r-${g.id}`,
          groupId: g.id,
          name: g.family_name,
          status: g.status,
          going: g.guests.filter((x) => x.rsvp_status === 'attending').length,
          at: g.responded_at,
        }))
}

// Textos de cada respuesta; la segunda en adelante de una misma familia se
// muestra como cambio de respuesta.
const responseItems = computed(() => {
  const count = new Map()
  return [...responses.value]
    .sort((a, b) => (a.at < b.at ? -1 : 1))
    .map((r) => {
      const n = (count.get(r.groupId) ?? 0) + 1
      count.set(r.groupId, n)
      const answer =
        r.status === 'declined' ? 'no va' : `${r.going} ${r.going === 1 ? 'va' : 'van'}`
      let text
      if (n > 1) text = `cambió su respuesta · ahora ${answer}`
      else text = r.status === 'declined' ? 'respondió que no va' : `confirmó · ${answer}`
      return { key: r.key, kind: r.status === 'declined' ? 'declined' : 'confirmed', name: r.name, text, at: r.at }
    })
})

async function fetchViews() {
  const from = views.value.length
  const { data, error } = await supabase
    .from('invitation_views')
    .select('id, viewed_at, invitation_groups!inner(id, family_name, event_id)')
    .eq('invitation_groups.event_id', event.value.id)
    .order('viewed_at', { ascending: false })
    .range(from, from + VIEWS_PAGE - 1)
  if (error) return
  views.value = [...views.value, ...data]
  hasMoreViews.value = data.length === VIEWS_PAGE
}

async function loadMore() {
  loadingMore.value = true
  try {
    await fetchViews()
  } finally {
    loadingMore.value = false
  }
}

const items = computed(() => {
  const list = []
  if (filter.value !== 'visitas') list.push(...responseItems.value)
  if (filter.value !== 'respuestas') {
    for (const v of views.value) {
      list.push({
        key: `v-${v.id}`,
        kind: 'view',
        name: v.invitation_groups.family_name,
        text: 'abrió la invitación',
        at: v.viewed_at,
      })
    }
  }

  // Las visitas vienen de a páginas: mientras queden más por cargar, no
  // mostramos respuestas más viejas que la última visita cargada (si no,
  // aparecerían fuera de orden al tocar «Cargar más»).
  const oldestView = views.value.at(-1)?.viewed_at
  const cutoff = hasMoreViews.value && filter.value !== 'respuestas' ? oldestView : null

  const q = search.value.trim().toLowerCase()
  return list
    .filter((i) => !cutoff || i.at >= cutoff)
    .filter((i) => !q || i.name.toLowerCase().includes(q))
    .sort((a, b) => (a.at < b.at ? 1 : -1))
})

// Agrupado por día: "Hoy", "Ayer", "sábado 27 de septiembre".
const days = computed(() => {
  const out = []
  let current = null
  for (const item of items.value) {
    const d = new Date(item.at)
    const key = d.toDateString()
    if (!current || current.key !== key) {
      current = { key, label: dayLabel(d), items: [] }
      out.push(current)
    }
    current.items.push(item)
  }
  return out
})

function dayLabel(d) {
  const today = new Date()
  const yesterday = new Date()
  yesterday.setDate(today.getDate() - 1)
  if (d.toDateString() === today.toDateString()) return 'Hoy'
  if (d.toDateString() === yesterday.toDateString()) return 'Ayer'
  return d.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
}

function timeOfDay(iso) {
  return new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

const FILTERS = [
  { id: 'todos', label: 'Todo' },
  { id: 'respuestas', label: 'Respuestas' },
  { id: 'visitas', label: 'Visitas al link' },
]
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-3xl px-4 pt-4 pb-16 lg:px-8 lg:pt-8">
      <router-link
        :to="{ name: 'admin-dashboard' }"
        class="inline-flex items-center gap-1.5 text-sm font-bold text-obsidian/55 hover:text-obsidian"
      >
        <ArrowLeft :size="15" />
        Inicio
      </router-link>
      <h1 class="admin-display mt-3 text-5xl sm:text-6xl">Movimientos</h1>
      <p class="mt-3 max-w-lg text-obsidian/60">
        Todo lo que pasó con tus invitaciones: quién abrió el link y quién respondió.
      </p>

      <!-- Filtros + buscador -->
      <div class="mt-6 flex flex-wrap items-center gap-2">
        <button
          v-for="f in FILTERS"
          :key="f.id"
          type="button"
          @click="filter = f.id"
          :class="filter === f.id ? 'bg-accent text-chalk' : 'bg-limestone hover:bg-chalk'"
          class="rounded-full px-4 py-2 text-sm font-bold transition-colors"
        >
          {{ f.label }}
        </button>
        <label class="relative ml-auto w-full sm:w-64">
          <Search :size="16" class="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 text-obsidian/40" />
          <input v-model="search" type="search" placeholder="Buscar familia" class="admin-input !py-2 !pl-10 text-sm" />
        </label>
      </div>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>

      <p v-else-if="!event" class="mt-8 rounded-[2rem] bg-limestone p-8 text-obsidian/60">
        Todavía no creaste tu invitación.
      </p>

      <div v-else-if="days.length === 0" class="mt-6 rounded-[2rem] bg-limestone p-8 text-center text-obsidian/60">
        <template v-if="search.trim()">No hay movimientos de «{{ search.trim() }}».</template>
        <template v-else>Cuando tus invitados abran el link o respondan, lo vas a ver acá.</template>
      </div>

      <template v-else>
        <section v-for="day in days" :key="day.key" class="mt-6 rounded-[2rem] bg-limestone p-6 sm:p-8">
          <h2 class="text-xs font-bold tracking-[0.2em] text-obsidian/45 uppercase">{{ day.label }}</h2>
          <ul class="mt-4 space-y-3">
            <li v-for="item in day.items" :key="item.key" class="flex items-start gap-3">
              <span
                :class="{
                  'bg-accent text-chalk': item.kind === 'confirmed',
                  'bg-obsidian/10': item.kind === 'declined',
                  'bg-accent-soft text-accent': item.kind === 'view',
                }"
                class="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-full"
              >
                <Check v-if="item.kind === 'confirmed'" :size="15" />
                <Eye v-else-if="item.kind === 'view'" :size="15" />
                <span v-else class="text-sm leading-none font-bold">✕</span>
              </span>
              <p class="min-w-0 flex-1 text-sm leading-snug">
                <span class="font-bold">{{ item.name }}</span>
                {{ item.text }}
                <span class="block text-xs text-obsidian/45">{{ timeOfDay(item.at) }} · {{ timeAgo(item.at) }}</span>
              </p>
            </li>
          </ul>
        </section>

        <div v-if="hasMoreViews && filter !== 'respuestas'" class="mt-6 text-center">
          <button type="button" @click="loadMore" :disabled="loadingMore" class="admin-btn-secondary">
            {{ loadingMore ? 'Cargando…' : 'Cargar más' }}
          </button>
        </div>

        <p class="mt-8 text-center text-xs text-obsidian/45">
          Las respuestas anteriores al 27 de septiembre de 2026 pueden no tener hora registrada.
        </p>
      </template>
    </div>
  </div>
</template>
