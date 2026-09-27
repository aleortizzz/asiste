<script setup>
import { ref, onMounted, computed } from 'vue'
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
  // invitado al confirmar. invitation_views: para saber cuándo entró cada
  // uno al link por última vez (se registra solo, desde obtener_invitacion).
  const { data, error: err } = await supabase
    .from('invitation_groups')
    .select('*, guests(id, full_name, rsvp_status), invitation_views(viewed_at)')
    .eq('event_id', event.value.id)
    .order('created_at')
  if (!err) groups.value = data
}

// Última vez que alguien abrió el link de este grupo, o null si nunca.
function lastOpened(group) {
  const views = group.invitation_views ?? []
  if (!views.length) return null
  return views.reduce((max, v) => (v.viewed_at > max ? v.viewed_at : max), views[0].viewed_at)
}

function formatOpenedAt(iso) {
  const d = new Date(iso)
  const time = d.toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
  const sameDay = d.toDateString() === new Date().toDateString()
  if (sameDay) return `hoy a las ${time}`
  const day = d.toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
  return `el ${day} a las ${time}`
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

const totalAllowed = computed(() => groups.value.reduce((sum, g) => sum + g.allowed_guests, 0))

// Invitaciones que ya sabemos que no se van a usar (declinadas explícitamente,
// o lugares que la familia dejó sin reclamar al confirmar con menos nombres
// que su allowed_guests). Esto libera cupo para volver a repartir.
const declinedCount = computed(() =>
  groups.value.reduce((sum, g) => {
    if (g.guests.length > 0) {
      const explicit = g.guests.filter((x) => x.rsvp_status === 'not_attending').length
      const unclaimed = Math.max(g.allowed_guests - g.guests.length, 0)
      return sum + explicit + unclaimed
    }
    return sum + (g.status === 'declined' ? g.allowed_guests : 0)
  }, 0),
)

// Lo que realmente cuenta contra el tope del evento: total repartido menos
// lo que ya se liberó por cancelaciones.
const activeAllowed = computed(() => totalAllowed.value - declinedCount.value)

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

  const requested = useNames.value ? cleanedNames.length : newGroup.value.allowed_guests
  if (event.value.guest_limit != null && activeAllowed.value + requested > event.value.guest_limit) {
    const remaining = event.value.guest_limit - activeAllowed.value
    error.value = `Superás el tope de invitados del evento (${event.value.guest_limit}). Quedan ${Math.max(remaining, 0)} lugares disponibles.`
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

async function removeGroup(group) {
  const warning =
    group.status === 'pending'
      ? `¿Eliminar la invitación de "${group.family_name}"? El link va a dejar de funcionar.`
      : `"${group.family_name}" ya respondió la invitación. Si la eliminás se pierde su respuesta y su asignación de mesas. ¿Eliminar igual?`
  if (!confirm(warning)) return
  await supabase.from('invitation_groups').delete().eq('id', group.id)
  await fetchGroups()
}

// --- Edición de un grupo ---
// Solo se puede editar mientras la invitación está pendiente: una vez que
// respondieron (confirmaron o declinaron), cambiar nombres o cantidad
// pisaría lo que eligieron ellos.
const editingId = ref(null)
const editForm = ref(null)
const editError = ref('')
const saving = ref(false)

function isLocked(group) {
  return group.status !== 'pending'
}

function lockedReason(group) {
  if (group.status === 'declined') return 'No se puede editar porque ya respondieron que no asisten.'
  return 'No se puede editar porque ya confirmaron su asistencia.'
}

function startEdit(group) {
  if (isLocked(group)) return
  editError.value = ''
  editingId.value = group.id
  editForm.value = {
    family_name: group.family_name,
    allowed_guests: group.allowed_guests,
    useNames: group.named_by_host,
    // id = invitado que ya existe en la base; sin id = nombre nuevo a insertar.
    names: group.guests.length
      ? group.guests.map((g) => ({ key: g.id, id: g.id, full_name: g.full_name }))
      : [{ key: nanoid(), id: null, full_name: '' }],
  }
}

function cancelEdit() {
  editingId.value = null
  editForm.value = null
  editError.value = ''
}

async function saveEdit(group) {
  editError.value = ''
  const f = editForm.value
  const familyName = f.family_name.trim()
  if (!familyName) {
    editError.value = 'El nombre del invitado no puede quedar vacío.'
    return
  }

  const names = f.useNames
    ? f.names.map((n) => ({ ...n, full_name: n.full_name.trim() })).filter((n) => n.full_name)
    : []
  if (f.useNames && names.length === 0) {
    editError.value = 'Cargá al menos un nombre.'
    return
  }

  const requested = f.useNames ? names.length : f.allowed_guests
  if (!Number.isInteger(requested) || requested < 1) {
    editError.value = 'La cantidad de invitaciones tiene que ser al menos 1.'
    return
  }

  // Un grupo pendiente cuenta entero contra el cupo, así que lo descontamos
  // y sumamos la cantidad nueva.
  const othersAllowed = activeAllowed.value - group.allowed_guests
  if (event.value.guest_limit != null && othersAllowed + requested > event.value.guest_limit) {
    const remaining = event.value.guest_limit - othersAllowed
    editError.value = `Superás el tope de invitados del evento (${event.value.guest_limit}). Para este grupo quedan ${Math.max(remaining, 0)} lugares.`
    return
  }

  saving.value = true
  try {
    // .eq('status', 'pending'): si justo respondieron mientras editabas,
    // el update no toca nada y no pisamos su respuesta.
    const { data: updated, error: err } = await supabase
      .from('invitation_groups')
      .update({ family_name: familyName, allowed_guests: requested, named_by_host: f.useNames })
      .eq('id', group.id)
      .eq('status', 'pending')
      .select('id')
    if (err) throw err
    if (!updated.length) {
      editError.value = 'Mientras editabas, respondieron la invitación. No se guardaron los cambios.'
      await fetchGroups()
      return
    }

    // Los invitados solo se tocan si siguen sin responder (rsvp_status 'invited').
    const keptIds = new Set(names.filter((n) => n.id).map((n) => n.id))
    const toDelete = group.guests.filter((g) => !keptIds.has(g.id)).map((g) => g.id)
    if (toDelete.length) {
      const { error: delErr } = await supabase
        .from('guests')
        .delete()
        .in('id', toDelete)
        .eq('rsvp_status', 'invited')
      if (delErr) throw delErr
    }

    const originalNames = new Map(group.guests.map((g) => [g.id, g.full_name]))
    for (const n of names.filter((n) => n.id && originalNames.get(n.id) !== n.full_name)) {
      const { error: updErr } = await supabase
        .from('guests')
        .update({ full_name: n.full_name })
        .eq('id', n.id)
        .eq('rsvp_status', 'invited')
      if (updErr) throw updErr
    }

    const toInsert = names.filter((n) => !n.id)
    if (toInsert.length) {
      const { error: insErr } = await supabase
        .from('guests')
        .insert(toInsert.map((n) => ({ group_id: group.id, full_name: n.full_name, rsvp_status: 'invited' })))
      if (insErr) throw insErr
    }

    cancelEdit()
    await fetchGroups()
  } catch (err) {
    editError.value = err.message
    await fetchGroups()
  } finally {
    saving.value = false
  }
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
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-2xl p-8">
      <h1 class="text-2xl font-semibold">Grupos de invitados</h1>

      <p v-if="!loading && !event" class="mt-4 text-sm text-red-600">
        Primero cargá los datos del salón en la sección "Creá tu invitación".
      </p>

      <template v-else>
        <p class="mt-2 text-sm text-gray-500">
          Cupo:
          <strong>{{ activeAllowed }}{{ event.guest_limit != null ? ` / ${event.guest_limit}` : '' }}</strong>
          {{ event.guest_limit == null ? 'invitados (ilimitado)' : 'invitados' }}
          <span v-if="declinedCount > 0">
            ({{ declinedCount }} liberados por cancelaciones)
          </span>
        </p>

        <form @submit.prevent="addGroup" class="mt-6 space-y-3 rounded border border-gray-200 p-4">
          <input
            v-model="newGroup.family_name"
            placeholder="Nombre del invitado — ej. Familia Pérez, Juan y Ana, o un solo nombre"
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
                <p v-if="group.status === 'pending'" class="text-xs text-gray-400">
                  <template v-if="lastOpened(group)">
                    Entró por última vez {{ formatOpenedAt(lastOpened(group)) }}, pero no respondió.
                  </template>
                  <template v-else> Todavía no abrió el link. </template>
                </p>
              </div>
              <div class="flex items-center gap-3">
                <button @click="copyLink(group)" class="text-sm text-blue-600 underline">
                  {{ copiedId === group.id ? 'Copiado ✅' : 'Copiar link' }}
                </button>
                <span class="group relative">
                  <button
                    type="button"
                    @click="startEdit(group)"
                    :aria-disabled="isLocked(group)"
                    :class="isLocked(group) ? 'cursor-not-allowed text-gray-400' : 'text-gray-900'"
                    class="text-sm underline"
                  >
                    Editar
                  </button>
                  <span
                    v-if="isLocked(group)"
                    role="tooltip"
                    class="invisible absolute right-0 bottom-full z-10 mb-2 w-56 rounded bg-gray-900 px-3 py-2 text-xs text-white shadow group-focus-within:visible group-hover:visible"
                  >
                    {{ lockedReason(group) }}
                  </span>
                </span>
                <button @click="removeGroup(group)" class="text-sm text-red-600 underline">Eliminar</button>
              </div>
            </div>

            <form
              v-if="editingId === group.id && editForm"
              @submit.prevent="saveEdit(group)"
              class="mt-3 space-y-3 rounded border border-gray-200 p-4"
            >
              <input
                v-model="editForm.family_name"
                placeholder="Nombre del invitado"
                class="w-full rounded border border-gray-300 px-3 py-2"
              />

              <label class="flex items-center gap-2 text-sm text-gray-700">
                <input type="checkbox" v-model="editForm.useNames" />
                Cargar los nombres de los invitados
              </label>

              <input
                v-if="!editForm.useNames"
                v-model.number="editForm.allowed_guests"
                type="number"
                min="1"
                placeholder="Cantidad de invitaciones"
                class="w-48 rounded border border-gray-300 px-3 py-2"
              />

              <div v-else class="space-y-2">
                <div v-for="(name, i) in editForm.names" :key="name.key" class="flex gap-2">
                  <input
                    v-model="name.full_name"
                    placeholder="Nombre y apellido"
                    class="flex-1 rounded border border-gray-300 px-3 py-2"
                  />
                  <button
                    v-if="editForm.names.length > 1"
                    type="button"
                    @click="editForm.names.splice(i, 1)"
                    class="text-red-600"
                  >
                    ✕
                  </button>
                </div>
                <button
                  type="button"
                  @click="editForm.names.push({ key: nanoid(), id: null, full_name: '' })"
                  class="text-sm text-blue-600 underline"
                >
                  + Agregar nombre
                </button>
              </div>

              <p v-if="editError" class="text-sm text-red-600">{{ editError }}</p>

              <div class="flex gap-3">
                <button type="submit" :disabled="saving" class="rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50">
                  {{ saving ? 'Guardando…' : 'Guardar cambios' }}
                </button>
                <button type="button" @click="cancelEdit" class="text-sm text-gray-600 underline">Cancelar</button>
              </div>
            </form>

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
