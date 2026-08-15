<script setup>
import { ref, onMounted, computed } from 'vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'

const { event, loadEvent } = useEvent()
const tables = ref([])
const guests = ref([])
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) {
    await Promise.all([fetchTables(), fetchGuests()])
  }
  loading.value = false
})

async function fetchTables() {
  const { data, error: err } = await supabase
    .from('tables')
    .select('id, name, capacity')
    .eq('event_id', event.value.id)
    .order('created_at')
  if (!err) tables.value = data
}

async function fetchGuests() {
  // Solo tiene sentido asignar mesa a quien ya confirmó que asiste.
  const { data, error: err } = await supabase
    .from('guests')
    .select('id, full_name, table_id, invitation_groups!inner(family_name, event_id)')
    .eq('invitation_groups.event_id', event.value.id)
    .eq('rsvp_status', 'attending')
    .order('full_name')
  if (!err) guests.value = data
}

const occupancy = computed(() => {
  const counts = {}
  for (const guest of guests.value) {
    if (guest.table_id) counts[guest.table_id] = (counts[guest.table_id] ?? 0) + 1
  }
  return counts
})

function tableLabel(table) {
  const used = occupancy.value[table.id] ?? 0
  return `${table.name} (${used}/${table.capacity})`
}

function isFull(tableId, forGuest) {
  if (forGuest.table_id === tableId) return false // ya está ahí, no suma un lugar nuevo
  const table = tables.value.find((t) => t.id === tableId)
  const used = occupancy.value[tableId] ?? 0
  return table ? used >= table.capacity : false
}

async function assignTable(event, guest, tableId) {
  error.value = ''

  if (tableId && isFull(tableId, guest)) {
    const table = tables.value.find((t) => t.id === tableId)
    error.value = `${table.name} ya está completa (${table.capacity}/${table.capacity}).`
    event.target.value = guest.table_id ?? '' // revierte el <select> visualmente
    return
  }

  const { error: err } = await supabase
    .from('guests')
    .update({ table_id: tableId || null })
    .eq('id', guest.id)
  if (err) {
    error.value = err.message
    event.target.value = guest.table_id ?? ''
    return
  }
  guest.table_id = tableId || null
}

const groupedByFamily = computed(() => {
  const groups = {}
  for (const guest of guests.value) {
    const family = guest.invitation_groups.family_name
    if (!groups[family]) groups[family] = []
    groups[family].push(guest)
  }
  return groups
})
</script>

<template>
  <div>
    <AdminNav />
    <div class="mx-auto max-w-2xl p-8">
      <h1 class="text-2xl font-semibold">Asignar mesas</h1>

      <p v-if="!loading && !event" class="mt-4 text-sm text-red-600">
        Primero cargá los datos del salón en la sección "Salón".
      </p>
      <p v-else-if="!loading && tables.length === 0" class="mt-4 text-sm text-red-600">
        Primero cargá mesas en la sección "Mesas".
      </p>
      <p v-else-if="!loading && guests.length === 0" class="mt-4 text-sm text-gray-500">
        Todavía no hay invitados confirmados para asignar.
      </p>

      <template v-else-if="!loading">
        <p v-if="error" class="mt-2 text-sm text-red-600">{{ error }}</p>

        <div v-for="(familyGuests, family) in groupedByFamily" :key="family" class="mt-6">
          <h2 class="font-medium text-gray-800">{{ family }}</h2>
          <ul class="mt-2 divide-y divide-gray-100 rounded border border-gray-200">
            <li v-for="guest in familyGuests" :key="guest.id" class="flex items-center justify-between px-3 py-2">
              <span class="text-sm">{{ guest.full_name }}</span>
              <select
                :value="guest.table_id ?? ''"
                @change="assignTable($event, guest, $event.target.value)"
                class="rounded border border-gray-300 px-2 py-1 text-sm"
              >
                <option value="">Sin asignar</option>
                <option
                  v-for="table in tables"
                  :key="table.id"
                  :value="table.id"
                  :disabled="isFull(table.id, guest)"
                >
                  {{ tableLabel(table) }}{{ isFull(table.id, guest) ? ' — completa' : '' }}
                </option>
              </select>
            </li>
          </ul>
        </div>
      </template>
    </div>
  </div>
</template>
