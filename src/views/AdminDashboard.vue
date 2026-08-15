<script setup>
import { ref, onMounted, computed } from 'vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'

const { event, loadEvent } = useEvent()
const groups = ref([])
const tables = ref([])
const loading = ref(true)
const copiedId = ref(null)

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) {
    await Promise.all([fetchGroups(), fetchTables()])
  }
  loading.value = false
})

async function fetchGroups() {
  // Traemos el rsvp_status de cada invitado (no solo un count) porque un
  // grupo genérico que todavía no respondió (o que declinó sin llegar a
  // escribir nombres) no tiene filas en guests — hay que completar esos
  // "huecos" con allowed_guests para que los totales por invitado cierren.
  const { data, error } = await supabase
    .from('invitation_groups')
    .select('id, family_name, slug, status, allowed_guests, guests(rsvp_status)')
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

function tableOccupancy(table) {
  return table.guests?.[0]?.count ?? 0
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
  <div>
    <AdminNav />
    <div class="mx-auto max-w-3xl p-8">
      <h1 class="text-2xl font-semibold">Panel admin</h1>

      <p v-if="!loading && !event" class="mt-4 text-sm text-red-600">
        Primero cargá los datos del salón en la sección "Creá tu invitación".
      </p>

      <template v-else-if="!loading">
        <div class="mt-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
          <div class="rounded-lg border border-gray-200 p-4">
            <p class="text-2xl font-semibold">
              {{ totalGuests }}<span v-if="event.guest_limit != null" class="text-gray-400"> / {{ event.guest_limit }}</span>
            </p>
            <p class="text-sm text-gray-500">Invitados totales</p>
          </div>
          <div class="rounded-lg border border-gray-200 p-4">
            <p class="text-2xl font-semibold text-green-700">{{ confirmedGuests }}</p>
            <p class="text-sm text-gray-500">Asisten</p>
          </div>
          <div class="rounded-lg border border-gray-200 p-4">
            <p class="text-2xl font-semibold text-gray-500">{{ pendingGuests }}</p>
            <p class="text-sm text-gray-500">Pendientes</p>
          </div>
          <div class="rounded-lg border border-gray-200 p-4">
            <p class="text-2xl font-semibold text-red-600">{{ declinedGuests }}</p>
            <p class="text-sm text-gray-500">No asisten</p>
          </div>
        </div>

        <!-- Barra de progreso del RSVP general -->
        <div v-if="totalGuests > 0" class="mt-4 flex h-3 overflow-hidden rounded-full bg-gray-100">
          <div class="bg-green-600" :style="{ width: rsvpBar.confirmed + '%' }"></div>
          <div class="bg-gray-300" :style="{ width: rsvpBar.pending + '%' }"></div>
          <div class="bg-red-500" :style="{ width: rsvpBar.declined + '%' }"></div>
        </div>

        <router-link :to="{ name: 'admin-invitados-detalle' }" class="mt-4 inline-block text-sm text-blue-600 underline">
          ver detalle
        </router-link>

        <!-- Recordatorios: familias sin responder -->
        <div class="mt-8">
          <h2 class="text-lg font-semibold">Recordatorios pendientes</h2>
          <p v-if="pendingReminders.length === 0" class="mt-2 text-sm text-gray-500">
            Todas las familias ya respondieron 🎉
          </p>
          <ul v-else class="mt-4 divide-y divide-gray-200">
            <li v-for="group in pendingReminders" :key="group.id" class="flex items-center justify-between py-3">
              <div>
                <p class="font-medium">{{ group.family_name }}</p>
                <p class="text-sm text-gray-500">{{ group.allowed_guests }} invitaciones sin responder</p>
              </div>
              <button @click="copyLink(group)" class="text-sm text-blue-600 underline">
                {{ copiedId === group.id ? 'Copiado ✅' : 'Copiar link' }}
              </button>
            </li>
          </ul>
        </div>

        <div class="mt-8 flex items-center justify-between">
          <h2 class="text-lg font-semibold">Ocupación de mesas</h2>
          <router-link :to="{ name: 'admin-asignar-mesas' }" class="text-sm text-blue-600 underline">
            asignar
          </router-link>
        </div>
        <p v-if="tables.length === 0" class="mt-2 text-sm text-gray-500">Todavía no cargaste mesas.</p>
        <ul v-else class="mt-4 space-y-3">
          <li v-for="table in tables" :key="table.id">
            <div class="flex items-center justify-between text-sm">
              <span>{{ table.name }}</span>
              <span class="text-gray-500">{{ tableOccupancy(table) }} / {{ table.capacity }}</span>
            </div>
            <div class="mt-1 h-2 overflow-hidden rounded-full bg-gray-100">
              <div
                class="h-full"
                :class="tableOccupancy(table) >= table.capacity ? 'bg-red-500' : 'bg-gray-900'"
                :style="{ width: tableOccupancyPct(table) + '%' }"
              ></div>
            </div>
          </li>
        </ul>
      </template>
    </div>
  </div>
</template>
