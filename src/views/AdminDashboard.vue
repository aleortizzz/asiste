<script setup>
import { ref, onMounted, computed } from 'vue'
import { RefreshCw, ArrowRight, Link2, Check, PenSquare, Music2, Camera, Eye, ExternalLink, CalendarClock, Circle, CheckCircle2, Armchair } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { useWording } from '../composables/useWording'
import { supabase } from '../lib/supabase'
import { timeAgo } from '../lib/timeAgo'

const { event, loadEvent } = useEvent()
const { w } = useWording()
const groups = ref([])
const tables = ref([])
// Lugares de invitados sorpresa por mesa (ver fetchReserved en AdminMesas.vue).
const reserved = ref({})
const loading = ref(true)
const refreshing = ref(false)
const updatedAt = ref(null)
const copiedId = ref(null)

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) await fetchAll()
  loading.value = false
})

async function fetchAll() {
  await Promise.all([fetchGroups(), fetchTables(), fetchReserved(), fetchSongs(), fetchPhotos(), fetchActivity()])
  updatedAt.value = new Date()
}

// Los números no se actualizan solos: este botón vuelve a pedirlos sin
// recargar la página (útil mientras la gente va confirmando).
async function refresh() {
  if (!event.value || refreshing.value) return
  refreshing.value = true
  try {
    await fetchAll()
  } finally {
    refreshing.value = false
  }
}

const updatedAtText = computed(() =>
  updatedAt.value?.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }),
)

const eventTitle = computed(() => event.value?.hero_title || event.value?.name || 'Tu evento')

// Cuenta regresiva a la fecha del evento. event_date viene como 'YYYY-MM-DD':
// se arma la fecha en hora local para que no se corra un día por el huso.
const eventDate = computed(() => {
  const raw = event.value?.event_date
  if (!raw) return null
  const [y, m, d] = raw.split('-').map(Number)
  return new Date(y, m - 1, d)
})
const daysLeft = computed(() => {
  if (!eventDate.value) return null
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return Math.round((eventDate.value - today) / 86400000)
})
const countdownText = computed(() => {
  if (daysLeft.value == null) return 'Todavía no cargaste la fecha del evento'
  const date = eventDate.value.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
  if (daysLeft.value === 0) return `¡Es hoy! · ${date}`
  if (daysLeft.value < 0) return `Fue el ${date}`
  return `Faltan ${daysLeft.value} ${daysLeft.value === 1 ? 'día' : 'días'} · ${date}`
})

async function fetchGroups() {
  // Traemos el rsvp_status de cada invitado (no solo un count) porque un
  // grupo genérico que todavía no respondió (o que declinó sin llegar a
  // escribir nombres) no tiene filas en guests — hay que completar esos
  // "huecos" con allowed_guests para que los totales por invitado cierren.
  const { data, error } = await supabase
    .from('invitation_groups')
    .select('id, family_name, slug, status, allowed_guests, guests(rsvp_status, table_id), invitation_views(count)')
    .eq('event_id', event.value.id)
  if (!error) groups.value = data
}

async function fetchTables() {
  const { data, error } = await supabase
    .from('tables')
    .select('id, name, capacity, guests(count)')
    .eq('event_id', event.value.id)
    .eq('guests.rsvp_status', 'attending')
    .order('created_at')
  if (!error) tables.value = data
}

async function fetchReserved() {
  const { data, error } = await supabase.rpc('lugares_reservados', { p_event_id: event.value.id })
  reserved.value = error ? {} : Object.fromEntries(data.map((r) => [r.table_id, r.cantidad]))
}

// Canciones y fotos: solo el total y las últimas, para las tarjetas de
// actividad. Si la consulta falla (ej. la tabla todavía no existe en la base)
// la tarjeta queda en "—" en vez de romper el resto del panel.
const songs = ref({ count: null, latest: [] })
const photos = ref({ count: null, latest: [] })

async function fetchSongs() {
  const { data, count, error } = await supabase
    .from('song_requests')
    .select('id, song_title, artist', { count: 'exact' })
    .eq('event_id', event.value.id)
    .order('created_at', { ascending: false })
    .limit(3)
  songs.value = error ? { count: null, latest: [] } : { count, latest: data }
}

async function fetchPhotos() {
  const { data, count, error } = await supabase
    .from('event_photos')
    .select('id, url', { count: 'exact' })
    .eq('event_id', event.value.id)
    .order('created_at', { ascending: false })
    .limit(4)
  photos.value = error ? { count: null, latest: [] } : { count, latest: data }
}

const isPlus = computed(() => event.value?.plan === 'plus')

// --- Actividad reciente -----------------------------------------------------
// Dos fuentes: la hora de respuesta de cada familia (responded_at, columna
// nueva — ver migrations/20260927_respondido_en.sql) y las visitas al link.
// Van en consultas aparte para que, si la migración todavía no se corrió, el
// resto del panel funcione igual y solo falten las respuestas en el listado.
const responses = ref([]) // [{ id, responded_at }]
const views = ref([]) // [{ group_id, viewed_at }]

async function fetchActivity() {
  const [resp, vw] = await Promise.all([
    supabase
      .from('invitation_groups')
      .select('id, responded_at')
      .eq('event_id', event.value.id)
      .not('responded_at', 'is', null)
      .order('responded_at', { ascending: false })
      .limit(20),
    supabase
      .from('invitation_views')
      .select('group_id, viewed_at, invitation_groups!inner(event_id)')
      .eq('invitation_groups.event_id', event.value.id)
      .order('viewed_at', { ascending: false })
      .limit(60),
  ])
  responses.value = resp.error ? [] : resp.data
  views.value = vw.error ? [] : vw.data
}

const ACTIVITY_LIMIT = 6
const activity = computed(() => {
  const byId = new Map(groups.value.map((g) => [g.id, g]))
  const items = []

  for (const r of responses.value) {
    const g = byId.get(r.id)
    if (!g || g.status === 'pending') continue
    const going = g.guests.filter((x) => x.rsvp_status === 'attending').length
    items.push({
      key: `r-${g.id}`,
      kind: g.status === 'declined' ? 'declined' : 'confirmed',
      name: g.family_name,
      text: g.status === 'declined' ? 'respondió que no va' : `confirmó · ${going} ${going === 1 ? 'va' : 'van'}`,
      at: r.responded_at,
    })
  }

  // De las visitas, solo la última de cada familia que todavía no respondió
  // (de las que respondieron, lo que importa es la respuesta).
  const seen = new Set()
  for (const v of views.value) {
    if (seen.has(v.group_id)) continue
    seen.add(v.group_id)
    const g = byId.get(v.group_id)
    if (!g || g.status !== 'pending') continue
    items.push({ key: `v-${g.id}`, kind: 'view', name: g.family_name, text: 'abrió la invitación', at: v.viewed_at })
  }

  return items.sort((a, b) => (a.at < b.at ? 1 : -1)).slice(0, ACTIVITY_LIMIT)
})

// --- Confirmados sin mesa ---------------------------------------------------
const unseatedGuests = computed(() =>
  groups.value.reduce(
    (sum, g) => sum + g.guests.filter((x) => x.rsvp_status === 'attending' && !x.table_id).length,
    0,
  ),
)

// --- Fecha límite para confirmar -------------------------------------------
function parseLocalDate(raw) {
  if (!raw) return null
  const [y, m, d] = raw.split('-').map(Number)
  return new Date(y, m - 1, d)
}
function daysUntil(date) {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return Math.round((date - today) / 86400000)
}
const deadline = computed(() => {
  const date = parseLocalDate(event.value?.rsvp_deadline)
  if (!date) return null
  const days = daysUntil(date)
  const label = date.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
  // Solo se avisa cuando la fecha cambia algo: si cierra las confirmaciones.
  // Si la fecha es orientativa (solo de referencia), en el panel no se muestra.
  if (!event.value.rsvp_deadline_strict) return null
  let text
  if (days < 0) text = `Las confirmaciones cerraron el ${label} · ya no se aceptan respuestas`
  else if (days === 0) text = 'Las confirmaciones cierran hoy'
  else text = `Las confirmaciones cierran en ${days} ${days === 1 ? 'día' : 'días'} · ${label}`
  // Amarillo cuando falta una semana o menos y todavía hay gente sin responder.
  return { text, urgent: days <= 7 && days >= 0 && pendingReminders.value.length > 0 }
})

// --- Checklist de invitación completa ---------------------------------------
// `to`: a dónde lleva cada ítem pendiente (el editor abre directo en ese paso).
const checklist = computed(() => {
  const e = event.value
  if (!e) return []
  const salon = (paso) => ({ name: 'admin-salon', query: { paso } })
  return [
    { label: 'Fecha del evento', done: !!e.event_date, to: salon('portada') },
    { label: 'Lugar y dirección', done: !!(e.venue_name && e.venue_address), to: salon('fiesta') },
    { label: 'Link de Maps', done: !!e.maps_url, to: salon('fiesta') },
    { label: 'Foto de portada', done: !!e.banner?.length, to: salon('fotos') },
    { label: 'Música', done: !!e.music_url, to: salon('portada') },
    { label: 'Fecha límite', done: !!e.rsvp_deadline, to: salon('confirmacion') },
    { label: 'Invitados', done: groups.value.length > 0, to: { name: 'admin-invitados' } },
  ]
})
const checklistDone = computed(() => checklist.value.filter((i) => i.done).length)
const checklistComplete = computed(() => checklistDone.value === checklist.value.length)

// Aperturas del link (invitation_views las registra solo cada vez que
// alguien abre /i/:slug).
function wasOpened(group) {
  return (group.invitation_views?.[0]?.count ?? 0) > 0
}
const openedGroups = computed(() => groups.value.filter(wasOpened).length)
const openedNotAnswered = computed(() => groups.value.filter((g) => g.status === 'pending' && wasOpened(g)).length)

const totalGuests = computed(() => groups.value.reduce((sum, g) => sum + g.allowed_guests, 0))

const confirmedGuests = computed(() =>
  groups.value.reduce((sum, g) => sum + g.guests.filter((x) => x.rsvp_status === 'attending').length, 0),
)

const declinedGuests = computed(() =>
  groups.value.reduce((sum, g) => {
    if (g.guests.length > 0) {
      // El flujo genérico puede confirmar con menos nombres que allowed_guests
      // (ej. tenían 10 invitaciones, mandaron 6 nombres) — como ya es su
      // respuesta final, los lugares no usados cuentan como "no asisten".
      const explicit = g.guests.filter((x) => x.rsvp_status === 'not_attending').length
      const unclaimed = Math.max(g.allowed_guests - g.guests.length, 0)
      return sum + explicit + unclaimed
    }
    return sum + (g.status === 'declined' ? g.allowed_guests : 0)
  }, 0),
)

const pendingGuests = computed(() =>
  groups.value.reduce((sum, g) => {
    if (g.guests.length > 0) {
      return sum + g.guests.filter((x) => x.rsvp_status === 'invited').length
    }
    return sum + (g.status === 'pending' ? g.allowed_guests : 0)
  }, 0),
)

// Porcentajes para la barra de RSVP general (sobre el total de invitaciones
// repartidas, no sobre el tope del evento).
const rsvpBar = computed(() => {
  if (totalGuests.value === 0) return { confirmed: 0, pending: 0, declined: 0 }
  return {
    confirmed: (confirmedGuests.value / totalGuests.value) * 100,
    pending: (pendingGuests.value / totalGuests.value) * 100,
    declined: (declinedGuests.value / totalGuests.value) * 100,
  }
})

const confirmedPct = computed(() =>
  totalGuests.value === 0 ? 0 : Math.round((confirmedGuests.value / totalGuests.value) * 100),
)
const respondedGroups = computed(() => groups.value.filter((g) => g.status !== 'pending').length)

function tableOccupancy(table) {
  return (table.guests?.[0]?.count ?? 0) + (reserved.value[table.id] ?? 0)
}

function tableOccupancyPct(table) {
  if (table.capacity === 0) return 0
  return Math.min((tableOccupancy(table) / table.capacity) * 100, 100)
}

// Familias que todavía no respondieron, ordenadas por cuántas invitaciones
// tienen (a las que más gente involucran conviene recordarles primero).
const pendingReminders = computed(() =>
  groups.value
    .filter((g) => g.status === 'pending')
    .sort((a, b) => b.allowed_guests - a.allowed_guests),
)

// Con muchas familias sin responder la lista se hacía eterna: mostramos las
// primeras (las más grandes, por el orden de arriba) y el resto con "ver más".
const REMINDERS_PREVIEW = 5
const showAllReminders = ref(false)
const visibleReminders = computed(() =>
  showAllReminders.value ? pendingReminders.value : pendingReminders.value.slice(0, REMINDERS_PREVIEW),
)

function linkFor(slug) {
  return `${window.location.origin}/i/${slug}`
}

async function copyLink(group) {
  await navigator.clipboard.writeText(linkFor(group.slug))
  copiedId.value = group.id
  setTimeout(() => {
    if (copiedId.value === group.id) copiedId.value = null
  }, 1500)
}
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-5xl px-4 pt-4 pb-16 lg:px-8 lg:pt-8">
      <!-- Encabezado -->
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div class="min-w-0">
          <p class="text-xs font-bold tracking-[0.2em] text-obsidian/45 uppercase">Inicio</p>
          <h1 class="admin-display mt-2 truncate text-5xl sm:text-6xl">{{ eventTitle }}</h1>
          <p v-if="event" class="mt-3 text-obsidian/60 first-letter:uppercase">{{ countdownText }}</p>
        </div>
        <div v-if="event && !loading" class="flex flex-wrap items-center gap-2">
        <router-link
          :to="{ name: 'admin-salon-preview', query: { guardada: 1 } }"
          target="_blank"
          class="flex items-center gap-2 rounded-full border-[1.5px] border-obsidian py-1.5 pr-4 pl-3 text-sm font-bold transition-colors hover:bg-obsidian/5"
        >
          <ExternalLink :size="15" />
          Ver mi invitación
        </router-link>
        <button
          type="button"
          @click="refresh"
          :disabled="refreshing"
          class="flex items-center gap-2 rounded-full bg-limestone py-2 pr-4 pl-3 text-sm font-bold transition-colors hover:bg-chalk disabled:opacity-60"
        >
          <RefreshCw :size="15" :class="{ 'animate-spin': refreshing }" />
          <span>Actualizar</span>
          <span v-if="updatedAtText" class="font-medium text-obsidian/45">· {{ updatedAtText }}</span>
        </button>
        </div>
      </div>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>

      <!-- Sin evento todavía -->
      <div v-else-if="!event" class="mt-8 rounded-[2rem] bg-limestone p-8 sm:rounded-[2.5rem] sm:p-10">
        <h2 class="admin-display text-4xl">Empezá por tu invitación</h2>
        <p class="mt-3 max-w-md text-obsidian/60">
          Cargá los datos de tu evento y guardalos. Después vas a poder sumar invitados y ver acá
          quién confirma.
        </p>
        <router-link :to="{ name: 'admin-salon' }" class="admin-btn-primary mt-6">
          <PenSquare :size="18" />
          Creá tu invitación
        </router-link>
      </div>

      <template v-else>
        <!-- ============ FECHA LÍMITE ============ -->
        <div
          v-if="deadline"
          :class="deadline.urgent ? 'bg-accent text-chalk' : 'bg-limestone'"
          class="mt-8 flex flex-wrap items-center justify-between gap-x-4 gap-y-2 rounded-full py-2.5 pr-2.5 pl-5"
        >
          <p class="flex items-center gap-2 text-sm font-bold first-letter:uppercase">
            <CalendarClock :size="17" class="shrink-0" />
            {{ deadline.text }}
            <span v-if="pendingReminders.length" class="font-medium opacity-70">
              · {{ pendingReminders.length }} {{ pendingReminders.length === 1 ? w.unit : w.units }} sin responder
            </span>
          </p>
          <a
            v-if="deadline.urgent"
            href="#falta-que-respondan"
            class="rounded-full bg-chalk px-4 py-1.5 text-sm font-bold text-accent"
          >
            Recordarles
          </a>
        </div>

        <!-- ============ CHECKLIST ============ -->
        <section v-if="!checklistComplete" class="mt-3 rounded-[1.75rem] bg-limestone p-5">
          <div class="flex items-center gap-4">
            <h2 class="shrink-0 text-sm font-bold">Completá tu invitación</h2>
            <div class="h-1.5 flex-1 overflow-hidden rounded-full bg-chalk">
              <div
                class="h-full rounded-full bg-accent transition-[width] duration-500"
                :style="{ width: (checklistDone / checklist.length) * 100 + '%' }"
              ></div>
            </div>
            <p class="shrink-0 text-xs font-bold text-obsidian/55">{{ checklistDone }} de {{ checklist.length }}</p>
          </div>
          <ul class="mt-3 grid grid-cols-2 gap-1.5 sm:grid-cols-3 lg:grid-cols-4">
            <li v-for="item in checklist" :key="item.label">
              <p v-if="item.done" class="flex items-center gap-1.5 px-2 py-1.5 text-[0.8125rem] text-obsidian/40">
                <CheckCircle2 :size="15" class="shrink-0 text-accent" />
                <span class="truncate line-through">{{ item.label }}</span>
              </p>
              <router-link
                v-else
                :to="item.to"
                class="group flex items-center gap-1.5 rounded-full bg-chalk px-2.5 py-1.5 text-[0.8125rem] font-bold transition-colors hover:bg-accent hover:text-chalk"
              >
                <Circle :size="15" class="shrink-0 text-obsidian/30 group-hover:text-chalk" />
                <span class="truncate">{{ item.label }}</span>
              </router-link>
            </li>
          </ul>
        </section>

        <!-- Todo cargado: queda solo una línea de confirmación. -->
        <div
          v-else
          :class="deadline ? 'mt-3' : 'mt-8'"
          class="flex items-center justify-between gap-3 rounded-full bg-limestone py-2.5 pr-2.5 pl-4"
        >
          <p class="flex items-center gap-2 text-sm font-bold">
            <span class="grid h-6 w-6 shrink-0 place-items-center rounded-full bg-go text-obsidian">
              <Check :size="14" :stroke-width="3" />
            </span>
            Tu invitación está completa
          </p>
          <router-link
            :to="{ name: 'admin-salon' }"
            class="shrink-0 rounded-full px-3 py-1 text-sm font-bold text-obsidian/55 transition-colors hover:bg-chalk hover:text-obsidian"
          >
            Editar
          </router-link>
        </div>

        <!-- ============ MÉTRICAS ============ -->
        <div class="mt-3 grid grid-cols-2 gap-3 lg:grid-cols-4">
          <!-- Principal: confirmados -->
          <div class="col-span-2 flex flex-col justify-between rounded-[2rem] bg-accent p-6 text-chalk sm:p-8 lg:row-span-2">
            <div>
              <p class="flex items-center gap-2 text-sm font-bold text-chalk/70">
                <span class="h-2 w-2 rounded-full bg-go"></span>
                Confirmaron que van
              </p>
              <p class="admin-display mt-3 text-[5.5rem] leading-[0.9] sm:text-[7rem]">{{ confirmedGuests }}</p>
              <p class="mt-2 text-chalk/70">
                de {{ totalGuests }} invitados
                <template v-if="totalGuests > 0"> · {{ confirmedPct }}%</template>
              </p>
            </div>

            <div class="mt-8">
              <div v-if="totalGuests > 0" class="flex h-3 gap-0.5 overflow-hidden rounded-full">
                <div v-if="rsvpBar.confirmed" class="rounded-full bg-go" :style="{ width: rsvpBar.confirmed + '%' }"></div>
                <div v-if="rsvpBar.pending" class="rounded-full bg-chalk/50" :style="{ width: rsvpBar.pending + '%' }"></div>
                <div v-if="rsvpBar.declined" class="rounded-full bg-nogo" :style="{ width: rsvpBar.declined + '%' }"></div>
              </div>
              <div class="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-chalk/80">
                <span class="flex items-center gap-1.5"><span class="h-2 w-2 rounded-full bg-go"></span>Van</span>
                <span class="flex items-center gap-1.5"><span class="h-2 w-2 rounded-full bg-chalk/50"></span>Sin responder</span>
                <span class="flex items-center gap-1.5"><span class="h-2 w-2 rounded-full bg-nogo"></span>No van</span>
              </div>
              <router-link
                :to="{ name: 'admin-invitados' }"
                class="mt-6 inline-flex items-center gap-1.5 text-sm font-bold underline-offset-4 hover:underline"
              >
                Ver la lista completa
                <ArrowRight :size="15" />
              </router-link>
            </div>
          </div>

          <div class="rounded-[1.75rem] bg-limestone p-5">
            <p class="flex items-center gap-2 text-sm font-bold text-obsidian/55">
              <span class="h-2 w-2 rounded-full bg-chalk ring-1 ring-obsidian/25"></span>
              Sin responder
            </p>
            <p class="admin-display mt-3 text-5xl">{{ pendingGuests }}</p>
          </div>
          <div class="rounded-[1.75rem] bg-limestone p-5">
            <p class="flex items-center gap-2 text-sm font-bold text-obsidian/55">
              <span class="h-2 w-2 rounded-full bg-nogo"></span>
              No van
            </p>
            <p class="admin-display mt-3 text-5xl">{{ declinedGuests }}</p>
          </div>
          <div class="rounded-[1.75rem] bg-limestone p-5">
            <p class="text-sm font-bold text-obsidian/55">Invitaciones enviadas</p>
            <p class="admin-display mt-3 text-5xl">
              {{ totalGuests
              }}<span v-if="event.guest_limit != null" class="text-2xl text-obsidian/35"> / {{ event.guest_limit }}</span>
            </p>
          </div>
          <div class="rounded-[1.75rem] bg-limestone p-5">
            <p class="text-sm font-bold text-obsidian/55">{{ w.Units }} que respondieron</p>
            <p class="admin-display mt-3 text-5xl">
              {{ respondedGroups }}<span class="text-2xl text-obsidian/35"> / {{ groups.length }}</span>
            </p>
          </div>
        </div>

        <!-- ============ ACTIVIDAD ============ -->
        <div class="mt-3 grid gap-3 sm:grid-cols-3">
          <!-- Canciones -->
          <router-link
            :to="{ name: 'admin-canciones' }"
            class="group flex flex-col rounded-[1.75rem] bg-limestone p-5 transition-colors hover:bg-chalk"
          >
            <div class="flex items-center justify-between">
              <span class="grid h-9 w-9 place-items-center rounded-full bg-chalk transition-colors group-hover:bg-accent group-hover:text-chalk">
                <Music2 :size="17" />
              </span>
              <ArrowRight :size="17" class="text-obsidian/35 transition-transform group-hover:translate-x-0.5 group-hover:text-obsidian" />
            </div>
            <p class="mt-4 text-sm font-bold text-obsidian/55">Canciones pedidas</p>
            <template v-if="isPlus">
              <p class="admin-display mt-1 text-5xl">{{ songs.count ?? '—' }}</p>
              <ul v-if="songs.latest.length" class="mt-3 space-y-1 text-sm">
                <li v-for="s in songs.latest" :key="s.id" class="truncate">
                  <span class="font-bold">{{ s.song_title }}</span>
                  <span v-if="s.artist" class="text-obsidian/55"> · {{ s.artist }}</span>
                </li>
              </ul>
              <p v-else-if="songs.count === 0" class="mt-3 text-sm text-obsidian/55">Todavía nadie pidió canciones.</p>
            </template>
            <p v-else class="mt-2 text-sm text-obsidian/55">
              Tus invitados pueden sugerir canciones para la fiesta. Viene con el
              <span class="rounded-full bg-accent-soft px-2 py-0.5 text-xs font-bold text-accent">Plan Plus</span>
            </p>
          </router-link>

          <!-- Fotos de invitados -->
          <router-link
            :to="{ name: 'admin-fotos-evento' }"
            class="group flex flex-col rounded-[1.75rem] bg-limestone p-5 transition-colors hover:bg-chalk"
          >
            <div class="flex items-center justify-between">
              <span class="grid h-9 w-9 place-items-center rounded-full bg-chalk transition-colors group-hover:bg-accent group-hover:text-chalk">
                <Camera :size="17" />
              </span>
              <ArrowRight :size="17" class="text-obsidian/35 transition-transform group-hover:translate-x-0.5 group-hover:text-obsidian" />
            </div>
            <p class="mt-4 text-sm font-bold text-obsidian/55">Fotos de invitados</p>
            <p class="admin-display mt-1 text-5xl">{{ photos.count ?? '—' }}</p>
            <div v-if="photos.latest.length" class="mt-3 flex gap-1.5">
              <img
                v-for="p in photos.latest"
                :key="p.id"
                :src="p.url"
                alt=""
                loading="lazy"
                class="h-12 w-12 rounded-[0.75rem] bg-pumice object-cover"
              />
            </div>
            <p v-else-if="photos.count === 0" class="mt-3 text-sm text-obsidian/55">
              Aparecen acá cuando las suban el día de la fiesta.
            </p>
          </router-link>

          <!-- Aperturas del link -->
          <router-link
            :to="{ name: 'admin-invitados' }"
            class="group flex flex-col rounded-[1.75rem] bg-limestone p-5 transition-colors hover:bg-chalk"
          >
            <div class="flex items-center justify-between">
              <span class="grid h-9 w-9 place-items-center rounded-full bg-chalk transition-colors group-hover:bg-accent group-hover:text-chalk">
                <Eye :size="17" />
              </span>
              <ArrowRight :size="17" class="text-obsidian/35 transition-transform group-hover:translate-x-0.5 group-hover:text-obsidian" />
            </div>
            <p class="mt-4 text-sm font-bold text-obsidian/55">Abrieron la invitación</p>
            <p class="admin-display mt-1 text-5xl">
              {{ openedGroups }}<span class="text-2xl text-obsidian/35"> / {{ groups.length }}</span>
            </p>
            <p class="mt-3 text-sm text-obsidian/55">
              <template v-if="openedNotAnswered > 0">
                <span class="font-bold text-obsidian">{{ openedNotAnswered }}</span>
                {{ openedNotAnswered === 1 ? w.openedOne : w.openedMany }} pero todavía no
                {{ openedNotAnswered === 1 ? 'respondió' : 'respondieron' }}.
              </template>
              <template v-else>{{ w.enteredLink }}</template>
            </p>
          </router-link>
        </div>

        <!-- ============ RECORDATORIOS + MESAS ============ -->
        <div class="mt-3 grid gap-3 lg:grid-cols-5">
          <!-- Recordatorios -->
          <section id="falta-que-respondan" class="scroll-mt-24 rounded-[2rem] bg-limestone p-6 sm:p-8 lg:col-span-3">
            <div class="flex items-center justify-between gap-3">
              <h2 class="admin-display text-3xl">Falta que respondan</h2>
              <span v-if="pendingReminders.length" class="shrink-0 rounded-full bg-accent-soft px-3 py-1 text-xs font-bold text-accent">
                {{ pendingReminders.length }} {{ pendingReminders.length === 1 ? w.unit : w.units }}
              </span>
            </div>
            <p class="mt-2 text-sm text-obsidian/55">Copiá el link y mandáselo de nuevo para recordarles.</p>

            <p v-if="pendingReminders.length === 0" class="mt-6 rounded-[1.25rem] bg-chalk px-4 py-5 text-center font-bold">
              Todas las {{ w.units }} ya respondieron 🎉
            </p>
            <ul v-else class="mt-5 space-y-2">
              <li
                v-for="group in visibleReminders"
                :key="group.id"
                class="flex items-center justify-between gap-3 rounded-[1.25rem] bg-chalk py-3 pr-3 pl-4"
              >
                <div class="min-w-0">
                  <p class="truncate font-bold">{{ group.family_name }}</p>
                  <p class="flex flex-wrap items-center gap-x-2 text-sm text-obsidian/55">
                    {{ group.allowed_guests }} {{ group.allowed_guests === 1 ? 'invitación' : 'invitaciones' }}
                    <span
                      v-if="wasOpened(group)"
                      class="rounded-full bg-accent-soft px-2 py-0.5 text-[0.7rem] font-bold text-accent"
                    >
                      Abrió el link
                    </span>
                    <span v-else class="text-xs">· No lo abrió</span>
                  </p>
                </div>
                <button
                  type="button"
                  @click="copyLink(group)"
                  :class="copiedId === group.id ? 'border-accent bg-accent text-chalk' : 'border-obsidian'"
                  class="flex shrink-0 items-center gap-1.5 rounded-full border-[1.5px] px-3 py-1.5 text-sm font-bold transition-colors"
                >
                  <Check v-if="copiedId === group.id" :size="15" />
                  <Link2 v-else :size="15" />
                  {{ copiedId === group.id ? 'Copiado' : 'Copiar link' }}
                </button>
              </li>
            </ul>
            <button
              v-if="pendingReminders.length > REMINDERS_PREVIEW"
              type="button"
              @click="showAllReminders = !showAllReminders"
              class="mt-4 text-sm font-bold underline underline-offset-4"
            >
              {{ showAllReminders ? 'Ver menos' : `Ver ${pendingReminders.length - REMINDERS_PREVIEW} más` }}
            </button>
          </section>

          <div class="flex flex-col gap-3 lg:col-span-2">
          <!-- Actividad reciente -->
          <section class="rounded-[2rem] bg-limestone p-6 sm:p-8">
            <div class="flex items-center justify-between gap-3">
              <h2 class="admin-display text-3xl">Últimos movimientos</h2>
              <router-link
                :to="{ name: 'admin-actividad' }"
                class="flex shrink-0 items-center gap-1 rounded-full border-[1.5px] border-obsidian px-3 py-1.5 text-sm font-bold"
              >
                Ver todos
                <ArrowRight :size="14" />
              </router-link>
            </div>
            <p v-if="activity.length === 0" class="mt-4 text-sm text-obsidian/55">
              Cuando tus invitados abran el link o respondan, lo vas a ver acá.
            </p>
            <ul v-else class="mt-5 space-y-3">
              <li v-for="item in activity" :key="item.key" class="flex items-start gap-3">
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
                  <span v-else class="text-sm font-bold leading-none">✕</span>
                </span>
                <p class="min-w-0 text-sm leading-snug">
                  <span class="font-bold">{{ item.name }}</span>
                  {{ item.text }}
                  <span class="block text-xs text-obsidian/45">{{ timeAgo(item.at) }}</span>
                </p>
              </li>
            </ul>
          </section>

          <!-- Mesas -->
          <section class="rounded-[2rem] bg-limestone p-6 sm:p-8">
            <div class="flex items-center justify-between gap-3">
              <h2 class="admin-display text-3xl">Mesas</h2>
              <router-link
                :to="{ name: 'admin-mesas' }"
                class="flex shrink-0 items-center gap-1 rounded-full border-[1.5px] border-obsidian px-3 py-1.5 text-sm font-bold"
              >
                Asignar
                <ArrowRight :size="14" />
              </router-link>
            </div>

            <router-link
              v-if="unseatedGuests > 0"
              :to="{ name: 'admin-mesas' }"
              class="mt-5 flex items-center gap-3 rounded-[1.25rem] bg-accent-soft px-4 py-3 text-sm text-accent"
            >
              <Armchair :size="18" class="shrink-0" />
              <span>
                <strong>{{ unseatedGuests }}</strong>
                {{ unseatedGuests === 1 ? 'confirmado todavía sin mesa' : 'confirmados todavía sin mesa' }}
              </span>
              <ArrowRight :size="15" class="ml-auto shrink-0" />
            </router-link>

            <div v-if="tables.length === 0" class="mt-6 rounded-[1.25rem] bg-chalk px-4 py-5 text-sm">
              Todavía no cargaste mesas.
              <router-link :to="{ name: 'admin-mesas' }" class="font-bold underline underline-offset-4">Crear mesas</router-link>
            </div>
            <ul v-else class="mt-6 space-y-4">
              <li v-for="table in tables" :key="table.id">
                <div class="flex items-center justify-between gap-2 text-sm">
                  <span class="truncate font-bold">{{ table.name }}</span>
                  <span class="flex shrink-0 items-center gap-2 text-obsidian/55">
                    <span
                      v-if="tableOccupancy(table) >= table.capacity"
                      class="rounded-full bg-accent-soft px-2 py-0.5 text-[0.7rem] font-bold text-accent"
                    >
                      Llena
                    </span>
                    {{ tableOccupancy(table) }} / {{ table.capacity }}
                  </span>
                </div>
                <div class="mt-1.5 h-2 overflow-hidden rounded-full bg-chalk">
                  <div class="h-full rounded-full bg-accent" :style="{ width: tableOccupancyPct(table) + '%' }"></div>
                </div>
              </li>
            </ul>
          </section>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
