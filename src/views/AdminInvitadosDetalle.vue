<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { nanoid } from 'nanoid'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'

const router = useRouter()
const { event, loadEvent } = useEvent()
const groups = ref([])
const rows = ref([])
const loading = ref(true)
const filter = ref('all')
const error = ref('')

const manualGroupId = ref('')
const manualName = ref('')

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
  const { data, error: err } = await supabase
    .from('invitation_groups')
    .select('id, family_name, allowed_guests, status, guests(id, full_name, rsvp_status)')
    .eq('event_id', event.value.id)
    .order('family_name')
  if (!err) {
    groups.value = data
    rows.value = buildRows(data)
  }
}

// Si el grupo ya tiene invitados con nombre (precargados por el
// anfitrión, o tipeados por la familia al confirmar), mostramos uno
// por uno. Si el grupo todavía no tiene ningún nombre —porque es el
// flujo genérico y nadie escribió nada todavía, sea porque no
// respondió o porque declinó sin cargar nombres— mostramos una sola
// fila resumen para esa familia, para no "perderla" de la tabla.
function buildRows(groupsData) {
  const result = []
  for (const group of groupsData) {
    if (group.guests.length > 0) {
      for (const guest of group.guests) {
        result.push({
          id: guest.id,
          groupId: group.id,
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
          id: null,
          groupId: group.id,
          name: null,
          family: group.family_name,
          status: 'not_attending',
          count: unclaimed,
        })
      }
    } else {
      result.push({
        id: null,
        groupId: group.id,
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

// Recalcula el status del grupo con la misma regla que usan las funciones
// RPC del RSVP público: si hay al menos un invitado "attending", el grupo
// queda "confirmed"; si no, "declined". Así admin y familia quedan consistentes.
async function recomputeGroupStatus(groupId) {
  const { data } = await supabase.from('guests').select('rsvp_status').eq('group_id', groupId)
  const attendingCount = data?.filter((g) => g.rsvp_status === 'attending').length ?? 0
  const status = attendingCount > 0 ? 'confirmed' : 'declined'
  await supabase.from('invitation_groups').update({ status }).eq('id', groupId)
}

// Para cargar a alguien que no puede confirmar por su cuenta (ej. un
// abuelo/a) — el admin lo agrega directo con el estado que corresponda.
// Si no se elige familia, se crea un grupo individual (de 1 invitación)
// con el nombre de la persona — no todo invitado tiene que pertenecer
// a una familia armada de antemano.
async function addManualGuest(status) {
  error.value = ''
  const name = manualName.value.trim()
  if (!name) return

  let groupId = manualGroupId.value

  if (!groupId) {
    const { data: newGroup, error: groupErr } = await supabase
      .from('invitation_groups')
      .insert({
        event_id: event.value.id,
        family_name: name,
        allowed_guests: 1,
        named_by_host: true,
        slug: nanoid(10),
      })
      .select()
      .single()
    if (groupErr) {
      error.value = groupErr.message
      return
    }
    groupId = newGroup.id
  }

  const { error: err } = await supabase.from('guests').insert({ group_id: groupId, full_name: name, rsvp_status: status })
  if (err) {
    error.value = err.message
    return
  }

  manualName.value = ''
  await recomputeGroupStatus(groupId)
  await fetchData()
}

// Para cuando alguien ya está precargado (named_by_host) pero no puede
// responder por su cuenta — el admin marca la respuesta en su nombre.
async function setGuestStatus(row, status) {
  const { error: err } = await supabase.from('guests').update({ rsvp_status: status }).eq('id', row.id)
  if (err) {
    error.value = err.message
    return
  }
  await recomputeGroupStatus(row.groupId)
  await fetchData()
}
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
        Primero cargá los datos del salón en la sección "Creá tu invitación".
      </p>

      <template v-else-if="!loading">
        <!-- Agregar invitado manualmente: para quien no puede confirmar por su cuenta -->
        <div class="mt-4 rounded border border-gray-200 p-3">
          <p class="text-sm font-medium text-gray-700">Agregar invitado manualmente</p>
          <p class="text-xs text-gray-500">Para alguien que no puede confirmar por su cuenta (ej. un abuelo/a).</p>
          <div class="mt-2 flex flex-wrap gap-2">
            <select v-model="manualGroupId" class="rounded border border-gray-300 px-2 py-1 text-sm">
              <option value="">Invitado individual (sin familia)</option>
              <option v-for="group in groups" :key="group.id" :value="group.id">{{ group.family_name }}</option>
            </select>
            <input
              v-model="manualName"
              placeholder="Nombre (ej. Abuela Rosa)"
              class="flex-1 rounded border border-gray-300 px-2 py-1 text-sm"
            />
            <button
              type="button"
              @click="addManualGuest('attending')"
              class="rounded bg-green-600 px-2 py-1 text-xs text-white"
            >
              Agregar (asiste)
            </button>
            <button
              type="button"
              @click="addManualGuest('not_attending')"
              class="rounded bg-gray-500 px-2 py-1 text-xs text-white"
            >
              Agregar (no asiste)
            </button>
          </div>
          <p v-if="error" class="mt-2 text-sm text-red-600">{{ error }}</p>
        </div>

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
              <th class="py-2"></th>
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
              <td class="py-2">
                <span v-if="row.status === 'invited' && row.id" class="flex gap-1">
                  <button
                    type="button"
                    @click="setGuestStatus(row, 'attending')"
                    class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-700 hover:bg-green-100"
                  >
                    Marcar asiste
                  </button>
                  <button
                    type="button"
                    @click="setGuestStatus(row, 'not_attending')"
                    class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-700 hover:bg-red-100"
                  >
                    Marcar no asiste
                  </button>
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
