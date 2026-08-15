<script setup>
import { ref, onMounted, computed } from 'vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'

const { event, loadEvent } = useEvent()
const groups = ref([])
const tables = ref([])
const loading = ref(true)

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
    .select('status, allowed_guests, guests(rsvp_status)')
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
      return sum + g.guests.filter((x) => x.rsvp_status === 'not_attending').length
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

function tableOccupancy(table) {
  return table.guests?.[0]?.count ?? 0
}
</script>

<template>
  <div>
    <AdminNav />
    <div class="mx-auto max-w-3xl p-8">
      <h1 class="text-2xl font-semibold">Panel admin</h1>

      <p v-if="!loading && !event" class="mt-4 text-sm text-red-600">
        Primero cargá los datos del salón en la sección "Salón".
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

        <router-link :to="{ name: 'admin-invitados-detalle' }" class="mt-4 inline-block text-sm text-blue-600 underline">
          ver detalle
        </router-link>

        <div class="mt-8 flex items-center justify-between">
          <h2 class="text-lg font-semibold">Ocupación de mesas</h2>
          <router-link :to="{ name: 'admin-asignar-mesas' }" class="text-sm text-blue-600 underline">
            asignar
          </router-link>
        </div>
        <p v-if="tables.length === 0" class="mt-2 text-sm text-gray-500">Todavía no cargaste mesas.</p>
        <ul v-else class="mt-4 divide-y divide-gray-200">
          <li v-for="table in tables" :key="table.id" class="flex items-center justify-between py-3">
            <span>{{ table.name }}</span>
            <span class="text-sm text-gray-500">{{ tableOccupancy(table) }} / {{ table.capacity }}</span>
          </li>
        </ul>
      </template>
    </div>
  </div>
</template>
