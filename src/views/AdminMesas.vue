<script setup>
import { ref, onMounted } from 'vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'

const { event, loadEvent } = useEvent()
const tables = ref([])
const loading = ref(true)
const newTable = ref({ name: '', capacity: 0 })
const error = ref('')

onMounted(async () => {
  if (!event.value) await loadEvent()
  await fetchTables()
  loading.value = false
})

async function fetchTables() {
  if (!event.value) return
  // guests(count) filtrado por rsvp_status='attending': cuántos lugares
  // de esta mesa ya están ocupados por invitados confirmados.
  const { data, error: err } = await supabase
    .from('tables')
    .select('*, guests(count)')
    .eq('event_id', event.value.id)
    .eq('guests.rsvp_status', 'attending')
    .order('created_at')
  if (!err) tables.value = data
}

function occupied(table) {
  return table.guests?.[0]?.count ?? 0
}

async function addTable() {
  error.value = ''
  if (!newTable.value.name) return
  const { error: err } = await supabase
    .from('tables')
    .insert({ event_id: event.value.id, name: newTable.value.name, capacity: newTable.value.capacity })
  if (err) {
    error.value = err.message
    return
  }
  newTable.value = { name: '', capacity: 0 }
  await fetchTables()
}

async function removeTable(id) {
  await supabase.from('tables').delete().eq('id', id)
  await fetchTables()
}
</script>

<template>
  <div>
    <AdminNav />
    <div class="mx-auto max-w-lg p-8">
      <h1 class="text-2xl font-semibold">Mesas</h1>

      <p v-if="!loading && !event" class="mt-4 text-sm text-red-600">
        Primero cargá los datos del salón en la sección "Salón".
      </p>

      <template v-else>
        <router-link :to="{ name: 'admin-asignar-mesas' }" class="mt-2 inline-block text-sm text-blue-600 underline">
          Asignar invitados a mesas →
        </router-link>

        <form @submit.prevent="addTable" class="mt-6 flex gap-2">
          <input
            v-model="newTable.name"
            placeholder="Nombre (ej. Mesa 3)"
            class="flex-1 rounded border border-gray-300 px-3 py-2"
          />
          <input
            v-model.number="newTable.capacity"
            type="number"
            min="0"
            placeholder="Capacidad"
            class="w-28 rounded border border-gray-300 px-3 py-2"
          />
          <button type="submit" class="rounded bg-gray-900 px-4 py-2 text-white">Agregar</button>
        </form>
        <p v-if="error" class="mt-2 text-sm text-red-600">{{ error }}</p>

        <ul class="mt-6 divide-y divide-gray-200">
          <li v-for="table in tables" :key="table.id" class="flex items-center justify-between py-3">
            <span>{{ table.name }} — {{ occupied(table) }}/{{ table.capacity }} lugares</span>
            <button @click="removeTable(table.id)" class="text-sm text-red-600 underline">Eliminar</button>
          </li>
        </ul>
      </template>
    </div>
  </div>
</template>
