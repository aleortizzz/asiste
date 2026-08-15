<script setup>
import { ref, onMounted } from 'vue'
import { nanoid } from 'nanoid'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'

const { event, loadEvent } = useEvent()
const groups = ref([])
const loading = ref(true)
const error = ref('')
const copiedId = ref(null)

const newGroup = ref({ family_name: '', allowed_guests: 1 })
const useNames = ref(false)
const newNames = ref([''])
const expandedId = ref(null)

onMounted(async () => {
  if (!event.value) await loadEvent()
  await fetchGroups()
  loading.value = false
})

async function fetchGroups() {
  if (!event.value) return
  // Traemos los guests completos (no solo el count) para poder mostrar
  // los nombres, tanto si los cargó el anfitrión como si los tipeó el
  // invitado al confirmar.
  const { data, error: err } = await supabase
    .from('invitation_groups')
    .select('*, guests(id, full_name, rsvp_status)')
    .eq('event_id', event.value.id)
    .order('created_at')
  if (!err) groups.value = data
}

function confirmedCount(group) {
  return group.guests?.filter((g) => g.rsvp_status === 'attending').length ?? 0
}

function statusText(group) {
  const count = confirmedCount(group)
  if (group.status === 'declined') return 'No asiste'
  if (group.status === 'pending') return `Pendiente (${count}/${group.allowed_guests})`
  return `Confirmados ${count}/${group.allowed_guests}`
}

function guestStatusLabel(status) {
  if (status === 'attending') return 'Asiste ✅'
  if (status === 'not_attending') return 'No asiste ❌'
  return 'Pendiente ⏳'
}

function toggleExpand(id) {
  expandedId.value = expandedId.value === id ? null : id
}

function addNewName() {
  newNames.value.push('')
}

function removeNewName(i) {
  newNames.value.splice(i, 1)
}

async function addGroup() {
  error.value = ''
  if (!newGroup.value.family_name) return

  const cleanedNames = useNames.value ? newNames.value.map((n) => n.trim()).filter(Boolean) : []
  if (useNames.value && cleanedNames.length === 0) {
    error.value = 'Cargá al menos un nombre.'
    return
  }

  const { data, error: err } = await supabase
    .from('invitation_groups')
    .insert({
      event_id: event.value.id,
      family_name: newGroup.value.family_name,
      allowed_guests: useNames.value ? cleanedNames.length : newGroup.value.allowed_guests,
      named_by_host: useNames.value,
      slug: nanoid(10),
    })
    .select()
    .single()

  if (err) {
    error.value = err.message
    return
  }

  if (useNames.value) {
    const { error: guestsErr } = await supabase
      .from('guests')
      .insert(cleanedNames.map((full_name) => ({ group_id: data.id, full_name, rsvp_status: 'invited' })))
    if (guestsErr) {
      error.value = guestsErr.message
      return
    }
  }

  newGroup.value = { family_name: '', allowed_guests: 1 }
  newNames.value = ['']
  useNames.value = false
  await fetchGroups()
}

async function removeGroup(id) {
  await supabase.from('invitation_groups').delete().eq('id', id)
  await fetchGroups()
}

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
    <div class="mx-auto max-w-2xl p-8">
      <h1 class="text-2xl font-semibold">Grupos de invitados</h1>

      <p v-if="!loading && !event" class="mt-4 text-sm text-red-600">
        Primero cargá los datos del salón en la sección "Salón".
      </p>

      <template v-else>
        <form @submit.prevent="addGroup" class="mt-6 space-y-3 rounded border border-gray-200 p-4">
          <input
            v-model="newGroup.family_name"
            placeholder="Familia (ej. Familia Pérez)"
            class="w-full rounded border border-gray-300 px-3 py-2"
          />

          <label class="flex items-center gap-2 text-sm text-gray-700">
            <input type="checkbox" v-model="useNames" />
            Cargar los nombres de los invitados ahora
          </label>

          <input
            v-if="!useNames"
            v-model.number="newGroup.allowed_guests"
            type="number"
            min="1"
            placeholder="Cantidad de invitaciones"
            class="w-48 rounded border border-gray-300 px-3 py-2"
          />

          <div v-else class="space-y-2">
            <div v-for="(name, i) in newNames" :key="i" class="flex gap-2">
              <input
                v-model="newNames[i]"
                placeholder="Nombre y apellido"
                class="flex-1 rounded border border-gray-300 px-3 py-2"
              />
              <button v-if="newNames.length > 1" type="button" @click="removeNewName(i)" class="text-red-600">
                ✕
              </button>
            </div>
            <button type="button" @click="addNewName" class="text-sm text-blue-600 underline">
              + Agregar nombre
            </button>
          </div>

          <button type="submit" class="rounded bg-gray-900 px-4 py-2 text-white">Agregar</button>
        </form>
        <p v-if="error" class="mt-2 text-sm text-red-600">{{ error }}</p>

        <ul class="mt-6 divide-y divide-gray-200">
          <li v-for="group in groups" :key="group.id" class="py-3">
            <div class="flex items-center justify-between">
              <div>
                <p class="font-medium">{{ group.family_name }}</p>
                <p class="text-sm text-gray-500">
                  {{ statusText(group) }}
                  <button
                    v-if="group.guests?.length"
                    type="button"
                    @click="toggleExpand(group.id)"
                    class="ml-1 text-blue-600 underline"
                  >
                    {{ expandedId === group.id ? 'ocultar' : 'ver nombres' }}
                  </button>
                </p>
              </div>
              <div class="flex items-center gap-3">
                <button @click="copyLink(group)" class="text-sm text-blue-600 underline">
                  {{ copiedId === group.id ? 'Copiado ✅' : 'Copiar link' }}
                </button>
                <button @click="removeGroup(group.id)" class="text-sm text-red-600 underline">Eliminar</button>
              </div>
            </div>

            <ul v-if="expandedId === group.id" class="mt-2 ml-4 space-y-1">
              <li v-for="guest in group.guests" :key="guest.id" class="text-sm text-gray-600">
                {{ guest.full_name }} — {{ guestStatusLabel(guest.rsvp_status) }}
              </li>
            </ul>
          </li>
        </ul>
      </template>
    </div>
  </div>
</template>
