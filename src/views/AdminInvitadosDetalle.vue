<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'

const router = useRouter()
const { event, loadEvent } = useEvent()
const rows = ref([])
const loading = ref(true)
const filter = ref('all')

const statusMeta = {
  attending: { label: 'Asiste', badge: 'bg-green-100 text-green-800' },
  not_attending: { label: 'No asiste', badge: 'bg-red-100 text-red-800' },
  invited: { label: 'Pendiente', badge: 'bg-gray-100 text-gray-600' },
}

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) await fetchData()
  loading.value = false
})

async function fetchData() {
  const { data, error } = await supabase
    .from('invitation_groups')
    .select('family_name, allowed_guests, status, guests(id, full_name, rsvp_status)')
    .eq('event_id', event.value.id)
    .order('family_name')
  if (!error) rows.value = buildRows(data)
}

// Si el grupo ya tiene invitados con nombre (precargados por el
// anfitrión, o tipeados por la familia al confirmar), mostramos uno
// por uno. Si el grupo todavía no tiene ningún nombre —porque es el
// flujo genérico y nadie escribió nada todavía, sea porque no
// respondió o porque declinó sin cargar nombres— mostramos una sola
// fila resumen para esa familia, para no "perderla" de la tabla.
function buildRows(groups) {
  const result = []
  for (const group of groups) {
    if (group.guests.length > 0) {
      for (const guest of group.guests) {
        result.push({
          name: guest.full_name,
          family: group.family_name,
          status: guest.rsvp_status,
        })
      }
      // Flujo genérico: si confirmaron con menos nombres que allowed_guests,
      // los lugares no usados ya son respuesta final — cuentan "no asiste".
      const unclaimed = group.allowed_guests - group.guests.length
      if (unclaimed > 0) {
        result.push({
          name: null,
          family: group.family_name,
          status: 'not_attending',
          count: unclaimed,
        })
      }
    } else {
      result.push({
        name: null,
        family: group.family_name,
        status: group.status === 'declined' ? 'not_attending' : 'invited',
        count: group.allowed_guests,
      })
    }
  }
  return result
}

const filteredRows = computed(() => {
  if (filter.value === 'all') return rows.value
  return rows.value.filter((r) => r.status === filter.value)
})

// Una fila resumen (sin nombre) representa "count" invitaciones, no 1 sola
// persona. Para que los totales de acá coincidan con el dashboard (que suma
// allowed_guests de todas las familias), estos contadores pesan cada fila
// por su "count" en vez de contarla como 1.
function slotCount(row) {
  return row.count ?? 1
}

const totalSlots = computed(() => rows.value.reduce((sum, r) => sum + slotCount(r), 0))

const counts = computed(() => ({
  attending: rows.value.filter((r) => r.status === 'attending').reduce((sum, r) => sum + slotCount(r), 0),
  not_attending: rows.value
    .filter((r) => r.status === 'not_attending')
    .reduce((sum, r) => sum + slotCount(r), 0),
  invited: rows.value.filter((r) => r.status === 'invited').reduce((sum, r) => sum + slotCount(r), 0),
}))
</script>

<template>
  <div>
    <AdminNav />
    <div class="mx-auto max-w-2xl p-8">
      <button type="button" @click="router.push({ name: 'admin-dashboard' })" class="text-sm text-blue-600 underline">
        ← Volver al dashboard
      </button>
      <h1 class="mt-2 text-2xl font-semibold">Detalle de invitados</h1>

      <p v-if="!loading && !event" class="mt-4 text-sm text-red-600">
        Primero cargá los datos del salón en la sección "Salón".
      </p>

      <template v-else-if="!loading">
        <div class="mt-4 flex flex-wrap gap-2 text-sm">
          <button
            type="button"
            @click="filter = 'all'"
            :class="filter === 'all' ? 'bg-gray-900 text-white' : 'bg-gray-100 text-gray-700'"
            class="rounded px-3 py-1"
          >
            Todos ({{ totalSlots }})
          </button>
          <button
            type="button"
            @click="filter = 'attending'"
            :class="filter === 'attending' ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-700'"
            class="rounded px-3 py-1"
          >
            Asisten ({{ counts.attending }})
          </button>
          <button
            type="button"
            @click="filter = 'not_attending'"
            :class="filter === 'not_attending' ? 'bg-red-600 text-white' : 'bg-gray-100 text-gray-700'"
            class="rounded px-3 py-1"
          >
            No asisten ({{ counts.not_attending }})
          </button>
          <button
            type="button"
            @click="filter = 'invited'"
            :class="filter === 'invited' ? 'bg-gray-500 text-white' : 'bg-gray-100 text-gray-700'"
            class="rounded px-3 py-1"
          >
            Pendientes ({{ counts.invited }})
          </button>
        </div>

        <table class="mt-6 w-full text-left text-sm">
          <thead>
            <tr class="border-b border-gray-200 text-gray-500">
              <th class="py-2">Nombre</th>
              <th class="py-2">Familia</th>
              <th class="py-2">Estado</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr v-for="(row, i) in filteredRows" :key="i">
              <td class="py-2" :class="{ 'italic text-gray-400': !row.name }">
                {{ row.name ?? `${row.count} invitación(es) sin nombre cargado` }}
              </td>
              <td class="py-2 text-gray-500">{{ row.family }}</td>
              <td class="py-2">
                <span class="rounded px-2 py-0.5 text-xs" :class="statusMeta[row.status].badge">
                  {{ statusMeta[row.status].label }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>

        <p v-if="filteredRows.length === 0" class="mt-6 text-sm text-gray-500">
          No hay invitados en esta categoría todavía.
        </p>
      </template>
    </div>
  </div>
</template>
