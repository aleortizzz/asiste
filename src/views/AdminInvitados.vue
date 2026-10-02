<script setup>
import { ref, onMounted, computed } from 'vue'
import { nanoid } from 'nanoid'
import { Search, UserPlus, X, Link2, Check, Pencil, Trash2, Plus, EyeOff, Eye } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import ExportEntryList from '../components/ExportEntryList.vue'
import { useEvent } from '../composables/useEvent'
import { useWording } from '../composables/useWording'
import { useAuth } from '../composables/useAuth'
import { supabase } from '../lib/supabase'
import { confirmDialog } from '../composables/useConfirm'

// Pantalla única de invitados: crear invitaciones, copiar links, editar
// (solo antes de que respondan), eliminar, y ver/corregir la respuesta de
// cada persona. Antes eran dos pantallas (Invitados + Detalle de invitados).
const { event, loadEvent } = useEvent()
const { w } = useWording()
const { isSuperadmin } = useAuth()
const groups = ref([])
const loading = ref(true)
const error = ref('')
const copiedId = ref(null)
const savingKey = ref(null)

onMounted(async () => {
  if (!event.value) await loadEvent()
  await fetchGroups()
  loading.value = false
})

async function fetchGroups() {
  if (!event.value) return
  // guests completos: nombres, respuesta y orden. invitation_views: cuándo
  // entró cada familia al link por última vez.
  const { data, error: err } = await supabase
    .from('invitation_groups')
    // guests(*): incluye los datos extra al confirmar (empresa, cargo…) si la
    // base ya los tiene (20261002_confirmacion_completa.sql), sin romper si no.
    .select('*, guests(*), invitation_views(viewed_at)')
    .eq('event_id', event.value.id)
  if (!err) groups.value = data.sort((a, b) => a.family_name.localeCompare(b.family_name, 'es'))
}

// --- Cupo -------------------------------------------------------------------
const totalAllowed = computed(() => groups.value.reduce((sum, g) => sum + g.allowed_guests, 0))

// Invitaciones que ya sabemos que no se van a usar (declinadas, o lugares que
// la familia dejó sin reclamar al confirmar con menos nombres). Liberan cupo.
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

// Lo que cuenta contra el tope del evento: repartido menos lo liberado.
const activeAllowed = computed(() => totalAllowed.value - declinedCount.value)

// Datos extra que dejó al confirmar (empresa, cargo, mail, teléfono,
// restricciones), en una línea. Vacío si no dejó ninguno.
function guestInfo(g) {
  const parts = [g.company, g.job_title, g.email, g.phone].map((x) => (x || '').trim()).filter(Boolean)
  if (g.dietary?.trim()) parts.push(`Restricciones: ${g.dietary.trim()}`)
  return parts.join(' · ')
}

// --- Filas por persona --------------------------------------------------------
// Si el grupo tiene invitados con nombre, una fila por persona. Si no tiene
// ninguno (flujo genérico sin responder, o que declinó sin cargar nombres),
// una fila resumen. Las filas resumen pesan `count` invitaciones.
function rowsFor(group) {
  const rows = []
  if (group.guests.length > 0) {
    const guests = [...group.guests].sort((a, b) => (a.created_at < b.created_at ? -1 : 1))
    for (const guest of guests) {
      rows.push({ key: guest.id, id: guest.id, name: guest.full_name, status: guest.rsvp_status, info: guestInfo(guest) })
    }
    const unclaimed = group.allowed_guests - group.guests.length
    if (unclaimed > 0) rows.push({ key: `${group.id}-rest`, id: null, name: null, status: 'not_attending', count: unclaimed })
  } else {
    rows.push({
      key: `${group.id}-all`,
      id: null,
      name: null,
      status: group.status === 'declined' ? 'not_attending' : 'invited',
      count: group.allowed_guests,
    })
  }
  return rows
}

const slotCount = (row) => row.count ?? 1
const allRows = computed(() => groups.value.flatMap((g) => rowsFor(g)))
const counts = computed(() => {
  const sum = (status) => allRows.value.filter((r) => r.status === status).reduce((s, r) => s + slotCount(r), 0)
  return {
    all: allRows.value.reduce((s, r) => s + slotCount(r), 0),
    attending: sum('attending'),
    not_attending: sum('not_attending'),
    invited: sum('invited'),
  }
})

const filter = ref('all')
const search = ref('')
const FILTERS = [
  { id: 'all', label: 'Todos', dot: null },
  { id: 'attending', label: 'Asisten', dot: 'bg-go' },
  { id: 'not_attending', label: 'No asisten', dot: 'bg-nogo' },
  { id: 'invited', label: 'Sin responder', dot: 'bg-chalk ring-1 ring-obsidian/25' },
]

// Familias con las filas que pasan el filtro y la búsqueda (persona o familia).
const visibleGroups = computed(() => {
  const q = search.value.trim().toLowerCase()
  return groups.value
    .map((g) => {
      const familyMatch = !q || g.family_name.toLowerCase().includes(q)
      const rows = rowsFor(g)
        .filter((r) => filter.value === 'all' || r.status === filter.value)
        .filter((r) => familyMatch || (r.name && r.name.toLowerCase().includes(q)))
      return { group: g, rows }
    })
    .filter((x) => x.rows.length > 0)
})

function groupSummary(group) {
  const going = group.guests.filter((g) => g.rsvp_status === 'attending').length
  if (group.status === 'pending') return 'Sin responder'
  if (group.status === 'declined') return 'No asisten'
  return `${going} de ${group.allowed_guests} ${group.allowed_guests === 1 ? 'asiste' : 'asisten'}`
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
  if (d.toDateString() === new Date().toDateString()) return `hoy a las ${time}`
  return `el ${d.toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })} a las ${time}`
}

// --- Links -------------------------------------------------------------------
async function copyLink(group) {
  await navigator.clipboard.writeText(`${window.location.origin}/i/${group.slug}`)
  copiedId.value = group.id
  setTimeout(() => {
    if (copiedId.value === group.id) copiedId.value = null
  }, 1500)
}

// --- Agregar -----------------------------------------------------------------
// Dos formas: una invitación nueva con link (familia/grupo), o una persona
// sin link cargada directo con su respuesta (ej. un abuelo o abuela).
const addPanel = ref(null) // null | 'invitacion' | 'persona'
const addError = ref('')

const newGroup = ref({ family_name: '', allowed_guests: 1, sorpresa: false })
const useNames = ref(false)
const newNames = ref([''])

async function addGroup() {
  addError.value = ''
  const familyName = newGroup.value.family_name.trim()
  if (!familyName) {
    addError.value = 'Escribí el nombre de la invitación.'
    return
  }

  const cleanedNames = useNames.value ? newNames.value.map((n) => n.trim()).filter(Boolean) : []
  if (useNames.value && cleanedNames.length === 0) {
    addError.value = 'Cargá al menos un nombre.'
    return
  }

  const requested = useNames.value ? cleanedNames.length : newGroup.value.allowed_guests
  if (!Number.isInteger(requested) || requested < 1) {
    addError.value = 'La cantidad de invitaciones tiene que ser al menos 1.'
    return
  }
  if (event.value.guest_limit != null && activeAllowed.value + requested > event.value.guest_limit) {
    const remaining = event.value.guest_limit - activeAllowed.value
    addError.value = `Superás el tope de invitados del evento (${event.value.guest_limit}). Quedan ${Math.max(remaining, 0)} lugares disponibles.`
    return
  }

  savingKey.value = 'add'
  try {
    const { data, error: err } = await supabase
      .from('invitation_groups')
      .insert({
        event_id: event.value.id,
        family_name: familyName,
        allowed_guests: requested,
        named_by_host: useNames.value,
        slug: nanoid(10),
        // Solo el superadmin la puede crear así (la base se lo impide a la cuenta del evento).
        sorpresa: isSuperadmin.value && newGroup.value.sorpresa,
      })
      .select()
      .single()
    if (err) throw err

    if (useNames.value) {
      const { error: guestsErr } = await supabase
        .from('guests')
        .insert(cleanedNames.map((full_name) => ({ group_id: data.id, full_name, rsvp_status: 'invited' })))
      if (guestsErr) throw guestsErr
    }

    newGroup.value = { family_name: '', allowed_guests: 1, sorpresa: false }
    newNames.value = ['']
    useNames.value = false
    addPanel.value = null
  } catch (err) {
    addError.value = err.message
  } finally {
    await fetchGroups()
    savingKey.value = null
  }
}

const manualGroupId = ref('')
const manualName = ref('')

async function addManualGuest(status) {
  if (eventClosed()) return void (addError.value = CLOSED_MSG)
  addError.value = ''
  const name = manualName.value.trim()
  if (!name) {
    addError.value = 'Escribí el nombre del invitado.'
    return
  }
  savingKey.value = 'manual'
  try {
    let groupId = manualGroupId.value
    if (!groupId) {
      const { data: newG, error: groupErr } = await supabase
        .from('invitation_groups')
        .insert({ event_id: event.value.id, family_name: name, allowed_guests: 1, named_by_host: true, slug: nanoid(10) })
        .select()
        .single()
      if (groupErr) throw groupErr
      groupId = newG.id
    } else {
      // Se suma a una familia existente: +1 a allowed_guests, si no queda con
      // más invitados reales que su tope y los totales dejan de cerrar.
      const group = groups.value.find((g) => g.id === groupId)
      if (group) {
        const { error: upErr } = await supabase
          .from('invitation_groups')
          .update({ allowed_guests: group.allowed_guests + 1 })
          .eq('id', groupId)
        if (upErr) throw upErr
      }
    }
    const { error: err } = await supabase.from('guests').insert({ group_id: groupId, full_name: name, rsvp_status: status })
    if (err) throw err
    await recomputeGroupStatus(groupId)
    manualName.value = ''
    manualGroupId.value = ''
    addPanel.value = null
  } catch (err) {
    addError.value = friendlyError(err)
  } finally {
    await fetchGroups()
    savingKey.value = null
  }
}

// --- Eliminar ----------------------------------------------------------------
async function removeGroup(group) {
  const ok = await confirmDialog({
    title: `¿Eliminar a ${group.family_name}?`,
    message:
      group.status === 'pending'
        ? 'Se borra la invitación y el link va a dejar de funcionar.'
        : 'Ya respondieron la invitación: si la eliminás se pierde su respuesta y su asignación de mesas. No se puede deshacer.',
    confirmText: 'Eliminar',
    tone: 'danger',
  })
  if (!ok) return
  error.value = ''
  const { error: err } = await supabase.from('invitation_groups').delete().eq('id', group.id)
  if (err) error.value = `No se pudo eliminar: ${err.message}`
  await fetchGroups()
}

// --- Sorpresa (solo superadmin) ------------------------------------------------
// Una invitación sorpresa desaparece del panel de la cuenta del evento: no la
// ve en Invitados, ni en la actividad, ni en las canciones; en Mesas sus
// lugares figuran como «reservados». Lo resuelve la base (RLS), acá solo se
// prende o apaga la marca.
async function toggleSorpresa(group) {
  const ok = await confirmDialog(
    group.sorpresa
      ? {
          title: `¿Revelar a ${group.family_name}?`,
          message: 'Va a aparecer en el panel de la cuenta del evento, con sus respuestas y su mesa.',
          confirmText: 'Revelar',
        }
      : {
          title: `¿Ocultar a ${group.family_name}?`,
          message:
            'Deja de aparecer en el panel de la cuenta del evento (invitados, actividad, canciones, lista de la entrada). El link sigue funcionando igual. Solo la ves vos como superadmin.',
          confirmText: 'Ocultar',
        },
  )
  if (!ok) return
  error.value = ''
  savingKey.value = `sorpresa-${group.id}`
  const { error: err } = await supabase.from('invitation_groups').update({ sorpresa: !group.sorpresa }).eq('id', group.id)
  if (err) error.value = `No se pudo guardar: ${err.message}`
  await fetchGroups()
  savingKey.value = null
}

// --- Editar la invitación ------------------------------------------------------
// Solo mientras está pendiente: una vez que respondieron, cambiar nombres o
// cantidad pisaría lo que eligieron ellos (las respuestas se corrigen persona
// por persona, más abajo).
const editingId = ref(null)
const editForm = ref(null)
const editError = ref('')

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
    editError.value = 'El nombre no puede quedar vacío.'
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

  // Un grupo pendiente cuenta entero contra el cupo: lo descontamos y sumamos la cantidad nueva.
  const othersAllowed = activeAllowed.value - group.allowed_guests
  if (event.value.guest_limit != null && othersAllowed + requested > event.value.guest_limit) {
    const remaining = event.value.guest_limit - othersAllowed
    editError.value = `Superás el tope de invitados del evento (${event.value.guest_limit}). Para este grupo quedan ${Math.max(remaining, 0)} lugares.`
    return
  }

  savingKey.value = `edit-${group.id}`
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
      return
    }

    // Los invitados solo se tocan si siguen sin responder (rsvp_status 'invited').
    const keptIds = new Set(names.filter((n) => n.id).map((n) => n.id))
    const toDelete = group.guests.filter((g) => !keptIds.has(g.id)).map((g) => g.id)
    if (toDelete.length) {
      const { error: delErr } = await supabase.from('guests').delete().in('id', toDelete).eq('rsvp_status', 'invited')
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
  } catch (err) {
    editError.value = err.message
  } finally {
    await fetchGroups()
    savingKey.value = null
  }
}

// --- Corregir respuestas -------------------------------------------------------

// Evento con «fecha de cierre» ya vencida: el servidor bloquea el cambio del
// grupo pero no el del invitado, así que lo frenamos ANTES de tocar nada
// para no dejar a la persona y a su familia con respuestas distintas.
const CLOSED_MSG = 'Las confirmaciones de este evento ya cerraron (fecha de cierre vencida), así que no se pueden cambiar respuestas.'
function eventClosed() {
  const e = event.value
  if (!e?.rsvp_deadline_strict || !e.rsvp_deadline) return false
  const today = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Argentina/Buenos_Aires' })
  return today > e.rsvp_deadline
}

function friendlyError(err) {
  const msg = err?.message || ''
  if (/ya cerraron/i.test(msg)) return CLOSED_MSG
  return `No se pudo guardar: ${msg}`
}

// Recalcula el status del grupo con la misma regla que las funciones de RSVP
// públicas: con al menos un "attending" queda "confirmed", si no "declined".
// Excepción: si todavía hay invitados sin responder y el grupo seguía
// pendiente, queda pendiente (no desaparece de «Falta que respondan» solo
// porque se cargó la respuesta de una persona).
async function recomputeGroupStatus(groupId) {
  const [{ data: guests, error: gErr }, { data: group, error: grErr }] = await Promise.all([
    supabase.from('guests').select('rsvp_status').eq('group_id', groupId),
    supabase.from('invitation_groups').select('status').eq('id', groupId).single(),
  ])
  if (gErr) throw gErr
  if (grErr) throw grErr
  const stillInvited = guests.some((g) => g.rsvp_status === 'invited')
  if (stillInvited && group.status === 'pending') return
  const status = guests.some((g) => g.rsvp_status === 'attending') ? 'confirmed' : 'declined'
  if (status === group.status) return
  const { error: err } = await supabase.from('invitation_groups').update({ status }).eq('id', groupId)
  if (err) throw err
}

// Cambiar la respuesta de una persona con nombre (o cargarla si no respondió).
async function setGuestStatus(group, row, status) {
  if (row.status === status) return
  if (eventClosed()) return void (error.value = CLOSED_MSG)
  const label = status === 'attending' ? 'Asiste' : 'No asiste'
  if (row.status !== 'invited') {
    const ok = await confirmDialog({
      title: 'Cambiar respuesta',
      message: `${row.name} había respondido «${row.status === 'attending' ? 'Asiste' : 'No asiste'}». ¿La cambiamos a «${label}»?`,
      confirmText: `Sí, ${label.toLowerCase()}`,
    })
    if (!ok) return
  }
  error.value = ''
  savingKey.value = row.key
  try {
    const { error: err } = await supabase.from('guests').update({ rsvp_status: status }).eq('id', row.id)
    if (err) throw err
    await recomputeGroupStatus(group.id)
  } catch (err) {
    error.value = friendlyError(err)
  } finally {
    await fetchGroups()
    savingKey.value = null
  }
}

// Filas sin nombre: para marcar que alguien sí va hay que decir quién.
const addingKey = ref(null)
const addingNames = ref([])

function startAdding(group, row) {
  error.value = ''
  addingKey.value = row.key
  // Invitación de una sola persona: el nombre del grupo suele ser el suyo.
  addingNames.value = [row.count === 1 && group.guests.length === 0 ? group.family_name : '']
}

function cancelAdding() {
  addingKey.value = null
  addingNames.value = []
}

async function saveAdding(group, row) {
  if (eventClosed()) return void (error.value = CLOSED_MSG)
  const names = addingNames.value.map((n) => n.trim()).filter(Boolean)
  if (names.length === 0) {
    error.value = 'Escribí al menos un nombre.'
    return
  }
  if (names.length > row.count) {
    error.value = `${w.value.thisGroupHas} ${row.count} ${row.count === 1 ? 'lugar' : 'lugares'} sin nombre.`
    return
  }
  error.value = ''
  savingKey.value = row.key
  try {
    const { error: err } = await supabase
      .from('guests')
      .insert(names.map((full_name) => ({ group_id: group.id, full_name, rsvp_status: 'attending' })))
    if (err) throw err
    await recomputeGroupStatus(group.id)
    cancelAdding()
  } catch (err) {
    error.value = friendlyError(err)
  } finally {
    await fetchGroups()
    savingKey.value = null
  }
}
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-3xl px-4 pt-4 pb-16 lg:px-8 lg:pt-8">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 class="admin-display text-5xl sm:text-6xl">Invitados</h1>
          <p v-if="event" class="mt-3 text-obsidian/60">
            Cupo: <strong class="text-obsidian">{{ activeAllowed }}{{ event.guest_limit != null ? ` / ${event.guest_limit}` : '' }}</strong>
            {{ event.guest_limit == null ? 'invitados (sin tope)' : 'invitados' }}
            <span v-if="declinedCount > 0"> · {{ declinedCount }} liberados por cancelaciones</span>
          </p>
        </div>
        <div v-if="event && !loading" class="flex flex-wrap gap-2">
          <ExportEntryList />
          <button type="button" @click="addPanel = addPanel ? null : 'invitacion'" class="admin-btn-primary">
            <UserPlus :size="18" />
            Agregar invitados
          </button>
        </div>
      </div>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>

      <div v-else-if="!event" class="mt-8 rounded-[2rem] bg-limestone p-8">
        <p class="text-obsidian/60">Primero creá tu invitación, después vas a poder sumar invitados.</p>
        <router-link :to="{ name: 'admin-salon' }" class="admin-btn-primary mt-5">Creá tu invitación</router-link>
      </div>

      <template v-else>
        <!-- ============ AGREGAR ============ -->
        <section v-if="addPanel" class="mt-6 rounded-[2rem] bg-limestone p-6 sm:p-8">
          <div class="flex items-center justify-between gap-3">
            <div class="flex rounded-full bg-pumice/70 p-1 text-sm font-bold">
              <button
                type="button"
                @click="(addPanel = 'invitacion'), (addError = '')"
                :class="addPanel === 'invitacion' ? 'bg-chalk' : 'text-obsidian/55'"
                class="rounded-full px-4 py-1.5 transition-colors"
              >
                Nueva invitación
              </button>
              <button
                type="button"
                @click="(addPanel = 'persona'), (addError = '')"
                :class="addPanel === 'persona' ? 'bg-chalk' : 'text-obsidian/55'"
                class="rounded-full px-4 py-1.5 transition-colors"
              >
                Persona sin link
              </button>
            </div>
            <button type="button" @click="addPanel = null" aria-label="Cerrar" class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-chalk">
              <X :size="16" />
            </button>
          </div>

          <!-- Nueva invitación (con link) -->
          <form v-if="addPanel === 'invitacion'" @submit.prevent="addGroup" class="mt-6 space-y-5">
            <p class="text-sm text-obsidian/55">{{ w.linkFor }}</p>
            <div>
              <label class="admin-label" for="n-family">Nombre de la invitación</label>
              <input id="n-family" v-model="newGroup.family_name" :placeholder="w.namePlaceholder" class="admin-input" />
            </div>

            <div class="grid grid-cols-2 gap-3">
              <button
                v-for="opt in [
                  { value: false, label: 'Cantidad', help: 'Ellos escriben sus nombres al confirmar.' },
                  { value: true, label: 'Con nombres', help: 'Vos cargás quiénes son; ellos marcan si van.' },
                ]"
                :key="opt.label"
                type="button"
                @click="useNames = opt.value"
                :class="useNames === opt.value ? 'border-obsidian bg-chalk' : 'border-transparent bg-chalk/60 hover:bg-chalk'"
                class="rounded-[1.5rem] border-2 p-4 text-left transition-colors"
              >
                <span class="block font-bold">{{ opt.label }}</span>
                <span class="mt-0.5 block text-sm leading-snug text-obsidian/55">{{ opt.help }}</span>
              </button>
            </div>

            <label v-if="isSuperadmin" class="flex items-start gap-2 rounded-[1.25rem] bg-chalk/60 px-4 py-3 text-sm">
              <input type="checkbox" v-model="newGroup.sorpresa" class="mt-0.5 h-4 w-4 shrink-0 accent-[var(--color-accent)]" />
              <span>
                <span class="font-bold">Invitación sorpresa</span>
                <span class="block text-obsidian/55">La cuenta del evento no la ve. Solo vos, como superadmin.</span>
              </span>
            </label>

            <div v-if="!useNames">
              <label class="admin-label" for="n-count">Cantidad de invitaciones</label>
              <input id="n-count" v-model.number="newGroup.allowed_guests" type="number" min="1" class="admin-input !w-40" />
            </div>
            <div v-else class="space-y-2">
              <p class="admin-label">Nombres</p>
              <div v-for="(name, i) in newNames" :key="i" class="flex gap-2">
                <input v-model="newNames[i]" placeholder="Nombre y apellido" class="admin-input" />
                <button
                  v-if="newNames.length > 1"
                  type="button"
                  @click="newNames.splice(i, 1)"
                  aria-label="Quitar"
                  class="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-chalk"
                >
                  <X :size="16" />
                </button>
              </div>
              <button type="button" @click="newNames.push('')" class="flex items-center gap-1 text-sm font-bold underline underline-offset-4">
                <Plus :size="15" /> Otro nombre
              </button>
            </div>

            <p v-if="addError" class="rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ addError }}</p>
            <button type="submit" :disabled="savingKey === 'add'" class="admin-btn-primary">
              {{ savingKey === 'add' ? 'Creando…' : 'Crear invitación' }}
            </button>
          </form>

          <!-- Persona sin link -->
          <div v-else class="mt-6 space-y-5">
            <p class="text-sm text-obsidian/55">
              Para alguien que no va a usar el link (ej. un abuelo o abuela): lo cargás directo con su respuesta.
            </p>
            <div class="grid gap-3 sm:grid-cols-2">
              <div>
                <label class="admin-label" for="m-name">Nombre</label>
                <input id="m-name" v-model="manualName" placeholder="Ej. Abuela Rosa" class="admin-input" />
              </div>
              <div>
                <label class="admin-label" for="m-group">{{ w.groupLabel }}</label>
                <select id="m-group" v-model="manualGroupId" class="admin-input appearance-none">
                  <option value="">{{ w.noGroup }}</option>
                  <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.family_name }}</option>
                </select>
              </div>
            </div>
            <p v-if="addError" class="rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ addError }}</p>
            <div class="flex flex-wrap gap-2">
              <button type="button" @click="addManualGuest('attending')" :disabled="savingKey === 'manual'" class="admin-btn-primary">
                Agregar: asiste
              </button>
              <button type="button" @click="addManualGuest('not_attending')" :disabled="savingKey === 'manual'" class="admin-btn-secondary">
                Agregar: no asiste
              </button>
            </div>
          </div>
        </section>

        <!-- ============ FILTROS ============ -->
        <div class="mt-6 flex flex-wrap items-center gap-2">
          <button
            v-for="f in FILTERS"
            :key="f.id"
            type="button"
            @click="filter = f.id"
            :class="filter === f.id ? 'bg-accent text-chalk' : 'bg-limestone hover:bg-chalk'"
            class="flex items-center gap-2 rounded-full px-4 py-2 text-sm font-bold transition-colors"
          >
            <span v-if="f.dot" class="h-2 w-2 rounded-full" :class="f.dot"></span>
            {{ f.label }}
            <span :class="filter === f.id ? 'text-chalk/70' : 'text-obsidian/45'">{{ counts[f.id] }}</span>
          </button>
          <label class="relative ml-auto w-full sm:w-64">
            <Search :size="16" class="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 text-obsidian/40" />
            <input v-model="search" type="search" :placeholder="w.searchPeople" class="admin-input !py-2 !pl-10 text-sm" />
          </label>
        </div>

        <p v-if="error" class="mt-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ error }}</p>

        <div v-if="groups.length === 0" class="mt-6 rounded-[2rem] bg-limestone p-8 text-center text-obsidian/60">
          Todavía no agregaste invitados. Tocá «Agregar invitados» para crear la primera invitación.
        </div>
        <div v-else-if="visibleGroups.length === 0" class="mt-6 rounded-[2rem] bg-limestone p-8 text-center text-obsidian/60">
          <template v-if="search.trim()">No hay invitados que coincidan con «{{ search.trim() }}».</template>
          <template v-else>No hay invitados en esta categoría.</template>
        </div>

        <!-- ============ FAMILIAS ============ -->
        <div class="mt-4 space-y-3">
          <section v-for="{ group, rows } in visibleGroups" :key="group.id" class="rounded-[1.75rem] bg-limestone p-5 sm:p-6">
            <!-- Encabezado de la familia -->
            <div class="flex flex-wrap items-start justify-between gap-x-4 gap-y-3">
              <div class="min-w-0">
                <h2 class="flex min-w-0 items-center gap-2 text-lg font-bold">
                  <span class="truncate">{{ group.family_name }}</span>
                  <span v-if="group.sorpresa" class="flex shrink-0 items-center gap-1 rounded-full bg-obsidian px-2.5 py-0.5 text-xs text-chalk">
                    <EyeOff :size="12" /> Sorpresa
                  </span>
                </h2>
                <p class="text-xs font-bold text-obsidian/45">
                  {{ groupSummary(group) }}
                  <template v-if="group.status === 'pending'">
                    ·
                    <template v-if="lastOpened(group)">entró {{ formatOpenedAt(lastOpened(group)) }}</template>
                    <template v-else>todavía no abrió el link</template>
                  </template>
                </p>
              </div>
              <div class="flex shrink-0 items-center gap-1.5">
                <button
                  type="button"
                  @click="copyLink(group)"
                  :class="copiedId === group.id ? 'border-accent bg-accent text-chalk' : 'border-obsidian'"
                  class="flex items-center gap-1.5 rounded-full border-[1.5px] px-3 py-1.5 text-sm font-bold transition-colors"
                >
                  <Check v-if="copiedId === group.id" :size="15" />
                  <Link2 v-else :size="15" />
                  {{ copiedId === group.id ? 'Copiado' : 'Copiar link' }}
                </button>
                <button
                  v-if="isSuperadmin"
                  type="button"
                  @click="toggleSorpresa(group)"
                  :disabled="savingKey === `sorpresa-${group.id}`"
                  :aria-label="group.sorpresa ? `Revelar a ${group.family_name}` : `Ocultar a ${group.family_name} (sorpresa)`"
                  :title="group.sorpresa ? 'Revelar: que la vea la cuenta del evento' : 'Sorpresa: ocultarla de la cuenta del evento'"
                  class="grid h-9 w-9 place-items-center rounded-full transition-colors hover:bg-chalk"
                >
                  <Eye v-if="group.sorpresa" :size="16" />
                  <EyeOff v-else :size="16" />
                </button>
                <span class="group/lock relative">
                  <button
                    type="button"
                    @click="editingId === group.id ? cancelEdit() : startEdit(group)"
                    :aria-disabled="isLocked(group)"
                    :aria-label="`Editar ${group.family_name}`"
                    :class="isLocked(group) ? 'cursor-not-allowed text-obsidian/25' : 'hover:bg-chalk'"
                    class="grid h-9 w-9 place-items-center rounded-full transition-colors"
                  >
                    <Pencil :size="16" />
                  </button>
                  <span
                    role="tooltip"
                    class="pointer-events-none invisible absolute right-0 bottom-full z-10 mb-2 w-56 rounded-[1rem] bg-obsidian px-3 py-2 text-xs text-chalk group-focus-within/lock:visible group-hover/lock:visible"
                  >
                    {{ isLocked(group) ? lockedReason(group) : 'Editar nombre y cantidad' }}
                  </span>
                </span>
                <button
                  type="button"
                  @click="removeGroup(group)"
                  :aria-label="`Eliminar ${group.family_name}`"
                  class="grid h-9 w-9 place-items-center rounded-full text-obsidian/55 transition-colors hover:bg-nogo/15 hover:text-nogo"
                >
                  <Trash2 :size="16" />
                </button>
              </div>
            </div>

            <!-- Edición de la invitación -->
            <form v-if="editingId === group.id && editForm" @submit.prevent="saveEdit(group)" class="mt-4 space-y-4 rounded-[1.25rem] bg-chalk p-4 sm:p-5">
              <div>
                <label class="admin-label" :for="`e-name-${group.id}`">Nombre de la invitación</label>
                <input :id="`e-name-${group.id}`" v-model="editForm.family_name" class="admin-input !bg-limestone" />
              </div>
              <label class="flex items-center gap-2 text-sm font-bold">
                <input type="checkbox" v-model="editForm.useNames" class="h-4 w-4 accent-[var(--color-accent)]" />
                Con nombres cargados
              </label>
              <div v-if="!editForm.useNames">
                <label class="admin-label" :for="`e-count-${group.id}`">Cantidad de invitaciones</label>
                <input :id="`e-count-${group.id}`" v-model.number="editForm.allowed_guests" type="number" min="1" class="admin-input !w-40 !bg-limestone" />
              </div>
              <div v-else class="space-y-2">
                <div v-for="(name, i) in editForm.names" :key="name.key" class="flex gap-2">
                  <input v-model="name.full_name" placeholder="Nombre y apellido" class="admin-input !bg-limestone" />
                  <button
                    v-if="editForm.names.length > 1"
                    type="button"
                    @click="editForm.names.splice(i, 1)"
                    aria-label="Quitar"
                    class="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-limestone"
                  >
                    <X :size="16" />
                  </button>
                </div>
                <button
                  type="button"
                  @click="editForm.names.push({ key: nanoid(), id: null, full_name: '' })"
                  class="flex items-center gap-1 text-sm font-bold underline underline-offset-4"
                >
                  <Plus :size="15" /> Otro nombre
                </button>
              </div>
              <p v-if="editError" class="rounded-[1rem] bg-nogo/15 px-3 py-2 text-sm font-bold">{{ editError }}</p>
              <div class="flex flex-wrap gap-2">
                <button type="submit" :disabled="savingKey === `edit-${group.id}`" class="admin-btn-primary !px-5 !py-2.5">
                  {{ savingKey === `edit-${group.id}` ? 'Guardando…' : 'Guardar cambios' }}
                </button>
                <button type="button" @click="cancelEdit" class="rounded-full px-4 py-2 text-sm font-bold text-obsidian/55">Cancelar</button>
              </div>
            </form>

            <!-- Personas -->
            <ul v-else class="mt-4 space-y-2">
              <li v-for="row in rows" :key="row.key" class="rounded-[1.25rem] bg-chalk px-4 py-3">
                <div class="flex flex-wrap items-center justify-between gap-x-3 gap-y-2">
                  <p class="flex min-w-0 items-center gap-2.5">
                    <span
                      class="h-2.5 w-2.5 shrink-0 rounded-full"
                      :class="{
                        'bg-go': row.status === 'attending',
                        'bg-nogo': row.status === 'not_attending',
                        'bg-chalk ring-1 ring-obsidian/25': row.status === 'invited',
                      }"
                    ></span>
                    <span v-if="row.name" class="min-w-0">
                      <span class="block truncate font-bold">{{ row.name }}</span>
                      <span v-if="row.info" class="block text-xs leading-snug break-words text-obsidian/55">{{ row.info }}</span>
                    </span>
                    <span v-else class="text-sm text-obsidian/55">
                      {{ row.count }} {{ row.count === 1 ? 'lugar' : 'lugares' }} sin nombre ·
                      {{ row.status === 'invited' ? 'sin responder' : 'no asiste' }}
                    </span>
                  </p>

                  <!-- Persona con nombre: Asiste / No asiste -->
                  <div v-if="row.id" class="flex shrink-0 rounded-full bg-pumice/70 p-0.5 text-sm font-bold" :class="{ 'opacity-50': savingKey === row.key }">
                    <button
                      type="button"
                      :disabled="savingKey === row.key"
                      @click="setGuestStatus(group, row, 'attending')"
                      :class="row.status === 'attending' ? 'bg-go text-obsidian' : 'text-obsidian/55 hover:text-obsidian'"
                      class="rounded-full px-3 py-1 transition-colors"
                    >
                      Asiste
                    </button>
                    <button
                      type="button"
                      :disabled="savingKey === row.key"
                      @click="setGuestStatus(group, row, 'not_attending')"
                      :class="row.status === 'not_attending' ? 'bg-nogo text-chalk' : 'text-obsidian/55 hover:text-obsidian'"
                      class="rounded-full px-3 py-1 transition-colors"
                    >
                      No asiste
                    </button>
                  </div>

                  <!-- Sin nombre: cargar quién sí va -->
                  <button
                    v-else-if="addingKey !== row.key"
                    type="button"
                    @click="startAdding(group, row)"
                    class="shrink-0 rounded-full border-[1.5px] border-obsidian px-3 py-1 text-sm font-bold"
                  >
                    Marcar que asiste
                  </button>
                </div>

                <div v-if="addingKey === row.key" class="mt-3 border-t-[1.5px] border-dotted border-obsidian/20 pt-3">
                  <p class="text-sm text-obsidian/60">¿Quién asiste? Hasta {{ row.count }} {{ row.count === 1 ? 'persona' : 'personas' }}.</p>
                  <div class="mt-2 space-y-2">
                    <div v-for="(n, i) in addingNames" :key="i" class="flex gap-2">
                      <input v-model="addingNames[i]" placeholder="Nombre y apellido" class="admin-input !bg-limestone !py-2 text-sm" />
                      <button
                        v-if="addingNames.length > 1"
                        type="button"
                        @click="addingNames.splice(i, 1)"
                        aria-label="Quitar"
                        class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-pumice/70"
                      >
                        <X :size="15" />
                      </button>
                    </div>
                  </div>
                  <div class="mt-3 flex flex-wrap items-center gap-2">
                    <button
                      v-if="addingNames.length < row.count"
                      type="button"
                      @click="addingNames.push('')"
                      class="text-sm font-bold underline underline-offset-4"
                    >
                      + Otra persona
                    </button>
                    <span class="flex-1"></span>
                    <button type="button" @click="cancelAdding" class="rounded-full px-3 py-1.5 text-sm font-bold text-obsidian/55">Cancelar</button>
                    <button type="button" @click="saveAdding(group, row)" :disabled="savingKey === row.key" class="admin-btn-primary !px-4 !py-2 text-sm">
                      Guardar
                    </button>
                  </div>
                </div>
              </li>
            </ul>
          </section>
        </div>
      </template>
    </div>
  </div>
</template>
