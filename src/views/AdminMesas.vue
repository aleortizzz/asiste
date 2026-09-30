<script setup>
import { ref, onMounted, computed } from 'vue'
import { Plus, X, Pencil, Trash2, Search, Armchair, Check, EyeOff } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import ExportEntryList from '../components/ExportEntryList.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'
import { confirmDialog } from '../composables/useConfirm'

// Pantalla única de mesas: crear/editar/eliminar mesas y sentar a los
// confirmados. Antes eran dos pantallas (Mesas + Asignar mesas).
//
// Para sentar gente: se tocan personas (de «Sin mesa» o de otra mesa) para
// seleccionarlas, y después «Sentar acá» en la mesa elegida. Funciona igual
// en celular y en desktop, sin arrastrar.
const { event, loadEvent } = useEvent()
const tables = ref([])
const guests = ref([])
// { [table_id]: cantidad } de invitados sorpresa sentados, que esta cuenta no
// ve (ver migrations/20260930_invitaciones_sorpresa.sql). Para el superadmin
// siempre viene vacío: a esos invitados los ve con nombre.
const reserved = ref({})
const loading = ref(true)
const error = ref('')
const savingKey = ref(null)

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) await Promise.all([fetchTables(), fetchGuests(), fetchReserved()])
  loading.value = false
})

async function fetchTables() {
  const { data, error: err } = await supabase
    .from('tables')
    .select('id, name, capacity, created_at')
    .eq('event_id', event.value.id)
    .order('created_at')
  if (!err) tables.value = data
}

async function fetchGuests() {
  // Solo se sienta a quien confirmó que asiste.
  const { data, error: err } = await supabase
    .from('guests')
    .select('id, full_name, table_id, created_at, invitation_groups!inner(id, family_name, event_id, sorpresa)')
    .eq('invitation_groups.event_id', event.value.id)
    .eq('rsvp_status', 'attending')
  if (!err) {
    guests.value = data.sort(
      (a, b) =>
        a.invitation_groups.family_name.localeCompare(b.invitation_groups.family_name, 'es') ||
        (a.created_at < b.created_at ? -1 : 1),
    )
  }
}

async function fetchReserved() {
  const { data, error: err } = await supabase.rpc('lugares_reservados', { p_event_id: event.value.id })
  if (!err) reserved.value = Object.fromEntries(data.map((r) => [r.table_id, r.cantidad]))
}

// --- Ocupación ---------------------------------------------------------------
const guestsByTable = computed(() => {
  const map = {}
  for (const g of guests.value) {
    if (!g.table_id) continue
    ;(map[g.table_id] ??= []).push(g)
  }
  return map
})

const seatedAt = (table) => guestsByTable.value[table.id] ?? []
const reservedAt = (table) => reserved.value[table.id] ?? 0
const occupied = (table) => seatedAt(table).length + reservedAt(table)
const freeSeats = (table) => table.capacity - occupied(table)

const unseated = computed(() => guests.value.filter((g) => !g.table_id || !tables.value.some((t) => t.id === g.table_id)))
const totalCapacity = computed(() => tables.value.reduce((s, t) => s + t.capacity, 0))
const seatedCount = computed(() => guests.value.length - unseated.value.length)

// «Sin mesa» agrupado por familia, con búsqueda (persona o familia).
const search = ref('')
const unseatedByFamily = computed(() => {
  const q = search.value.trim().toLowerCase()
  const families = []
  const byId = {}
  for (const g of unseated.value) {
    const fam = g.invitation_groups
    const matches = !q || fam.family_name.toLowerCase().includes(q) || g.full_name.toLowerCase().includes(q)
    if (!matches) continue
    if (!byId[fam.id]) {
      byId[fam.id] = { id: fam.id, name: fam.family_name, guests: [] }
      families.push(byId[fam.id])
    }
    byId[fam.id].guests.push(g)
  }
  return families
})

// --- Selección -----------------------------------------------------------------
const selected = ref(new Set())

function toggleGuest(guest) {
  const next = new Set(selected.value)
  next.has(guest.id) ? next.delete(guest.id) : next.add(guest.id)
  selected.value = next
}

// Tocar el nombre de la familia selecciona (o suelta) a todos sus integrantes sin mesa.
function toggleFamily(family) {
  const ids = family.guests.map((g) => g.id)
  const allSelected = ids.every((id) => selected.value.has(id))
  const next = new Set(selected.value)
  for (const id of ids) allSelected ? next.delete(id) : next.add(id)
  selected.value = next
}

const familySelected = (family) => family.guests.every((g) => selected.value.has(g.id))
const clearSelection = () => (selected.value = new Set())

// Cuántos de los seleccionados ocuparían un lugar nuevo en esta mesa
// (los que ya están sentados ahí no suman).
function incomingFor(table) {
  return guests.value.filter((g) => selected.value.has(g.id) && g.table_id !== table.id).length
}

function canSeatAt(table) {
  const incoming = incomingFor(table)
  return incoming > 0 && incoming <= freeSeats(table)
}

// --- Sentar / levantar ---------------------------------------------------------
const seatSelected = (table) => seatGuests(table, [...selected.value])

async function seatGuests(table, guestIds) {
  const wanted = new Set(guestIds)
  const ids = guests.value.filter((g) => wanted.has(g.id) && g.table_id !== table.id).map((g) => g.id)
  if (!ids.length) return
  if (ids.length > freeSeats(table)) {
    error.value = `En ${table.name} quedan ${Math.max(freeSeats(table), 0)} lugares y querés sentar a ${ids.length}.`
    return
  }
  error.value = ''
  savingKey.value = `seat-${table.id}`
  const { error: err } = await supabase.from('guests').update({ table_id: table.id }).in('id', ids)
  if (err) {
    error.value = `No se pudo guardar: ${err.message}`
  } else {
    for (const g of guests.value) if (ids.includes(g.id)) g.table_id = table.id
    clearSelection()
  }
  savingKey.value = null
}

const unseat = (guest) => unseatGuests([guest.id], `guest-${guest.id}`)

async function unseatGuests(guestIds, key = 'unseat') {
  const ids = guests.value.filter((g) => guestIds.includes(g.id) && g.table_id).map((g) => g.id)
  if (!ids.length) return
  error.value = ''
  savingKey.value = key
  const { error: err } = await supabase.from('guests').update({ table_id: null }).in('id', ids)
  if (err) error.value = `No se pudo guardar: ${err.message}`
  else {
    for (const g of guests.value) if (ids.includes(g.id)) g.table_id = null
    const next = new Set(selected.value)
    for (const id of ids) next.delete(id)
    selected.value = next
  }
  savingKey.value = null
}

// --- Arrastrar y soltar (desktop) -------------------------------------------
// Complementa la selección con toques: si arrastrás a alguien que está
// seleccionado, viajan todos los seleccionados; si no, solo esa persona.
// Arrastrando el nombre de una familia viaja la familia entera. En celular
// el arrastre nativo del navegador no funciona con el dedo, así que ahí
// queda el flujo de tocar y «Sentar acá».
const dragIds = ref([])
const dragOver = ref(null) // id de la mesa bajo el cursor, o 'unseated'

function onDragStart(e, ids) {
  dragIds.value = ids
  e.dataTransfer.effectAllowed = 'move'
  e.dataTransfer.setData('text/plain', ids.join(',')) // Firefox no arranca el drag sin datos
}

const dragGuest = (e, guest) => onDragStart(e, selected.value.has(guest.id) ? [...selected.value] : [guest.id])
const dragFamily = (e, family) => onDragStart(e, family.guests.map((g) => g.id))

function onDragEnd() {
  dragIds.value = []
  dragOver.value = null
}

// Lugares nuevos que ocuparía lo que se está arrastrando en esta mesa.
function dragIncoming(table) {
  const ids = new Set(dragIds.value)
  return guests.value.filter((g) => ids.has(g.id) && g.table_id !== table.id).length
}
const dragFits = (table) => dragIncoming(table) <= freeSeats(table)

function onTableDragOver(e, table) {
  if (!dragIds.value.length || dragIncoming(table) === 0) return
  e.preventDefault() // sin esto el navegador no permite soltar
  e.dataTransfer.dropEffect = dragFits(table) ? 'move' : 'none'
  dragOver.value = table.id
}

function onUnseatedDragOver(e) {
  if (!guests.value.some((g) => dragIds.value.includes(g.id) && g.table_id)) return
  e.preventDefault()
  dragOver.value = 'unseated'
}

// dragleave también salta al pasar sobre un hijo: solo limpiamos si el
// cursor salió de verdad del contenedor.
function onDragLeave(e, key) {
  if (dragOver.value === key && !e.currentTarget.contains(e.relatedTarget)) dragOver.value = null
}

async function onTableDrop(table) {
  const ids = dragIds.value
  onDragEnd()
  await seatGuests(table, ids)
}

async function onUnseatedDrop() {
  const ids = dragIds.value
  onDragEnd()
  await unseatGuests(ids)
}

// --- Agregar mesas -------------------------------------------------------------
// Una o varias de una: con varias se numeran solas («Mesa 4», «Mesa 5»…)
// siguiendo el número más alto que ya exista.
const addOpen = ref(false)
const addError = ref('')
const newTables = ref({ count: 1, capacity: 10, name: '' })

const nextNumber = computed(() => {
  const nums = tables.value.map((t) => Number(t.name.match(/^mesa\s+(\d+)$/i)?.[1])).filter(Number.isFinite)
  return nums.length ? Math.max(...nums) + 1 : tables.value.length + 1
})

async function addTables() {
  addError.value = ''
  const { count, capacity } = newTables.value
  if (!Number.isInteger(count) || count < 1 || count > 100) {
    addError.value = 'La cantidad de mesas tiene que ser entre 1 y 100.'
    return
  }
  if (!Number.isInteger(capacity) || capacity < 1) {
    addError.value = 'Cada mesa tiene que tener al menos 1 lugar.'
    return
  }
  const rows =
    count === 1
      ? [{ event_id: event.value.id, name: newTables.value.name.trim() || `Mesa ${nextNumber.value}`, capacity }]
      : Array.from({ length: count }, (_, i) => ({ event_id: event.value.id, name: `Mesa ${nextNumber.value + i}`, capacity }))

  savingKey.value = 'add'
  const { error: err } = await supabase.from('tables').insert(rows)
  if (err) addError.value = `No se pudo crear: ${err.message}`
  else {
    newTables.value = { count: 1, capacity, name: '' }
    addOpen.value = false
    await fetchTables()
  }
  savingKey.value = null
}

// --- Editar / eliminar ---------------------------------------------------------
const editingId = ref(null)
const editForm = ref(null)
const editError = ref('')

function startEdit(table) {
  editError.value = ''
  editingId.value = table.id
  editForm.value = { name: table.name, capacity: table.capacity }
}

function cancelEdit() {
  editingId.value = null
  editForm.value = null
  editError.value = ''
}

async function saveEdit(table) {
  editError.value = ''
  const name = editForm.value.name.trim()
  const capacity = editForm.value.capacity
  if (!name) return void (editError.value = 'El nombre no puede quedar vacío.')
  if (!Number.isInteger(capacity) || capacity < 1) return void (editError.value = 'Tiene que tener al menos 1 lugar.')
  const seated = occupied(table)
  if (capacity < seated) {
    editError.value = `Ya hay ${seated} personas sentadas. Levantá a alguien antes de achicar la mesa.`
    return
  }
  savingKey.value = `edit-${table.id}`
  const { error: err } = await supabase.from('tables').update({ name, capacity }).eq('id', table.id)
  if (err) editError.value = `No se pudo guardar: ${err.message}`
  else {
    Object.assign(table, { name, capacity })
    cancelEdit()
  }
  savingKey.value = null
}

async function removeTable(table) {
  const seated = occupied(table)
  const ok = await confirmDialog({
    title: `¿Eliminar ${table.name}?`,
    message: seated
      ? `Tiene ${seated} ${seated === 1 ? 'persona sentada, que vuelve' : 'personas sentadas, que vuelven'} a «Sin mesa».`
      : 'La mesa está vacía.',
    confirmText: 'Eliminar',
    tone: 'danger',
  })
  if (!ok) return
  error.value = ''
  // guests.table_id es "on delete set null": los sentados quedan sin mesa solos.
  const { error: err } = await supabase.from('tables').delete().eq('id', table.id)
  if (err) error.value = `No se pudo eliminar: ${err.message}`
  if (editingId.value === table.id) cancelEdit()
  await Promise.all([fetchTables(), fetchGuests(), fetchReserved()])
}
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-6xl px-4 pt-4 pb-32 lg:px-8 lg:pt-8">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 class="admin-display text-5xl sm:text-6xl">Mesas</h1>
          <p v-if="event && !loading" class="mt-3 text-obsidian/60">
            <strong class="text-obsidian">{{ seatedCount }} de {{ guests.length }}</strong>
            confirmados con mesa · {{ totalCapacity }} lugares en {{ tables.length }}
            {{ tables.length === 1 ? 'mesa' : 'mesas' }}
          </p>
        </div>
        <div v-if="event && !loading" class="flex flex-wrap gap-2">
          <ExportEntryList />
          <button type="button" @click="addOpen = !addOpen" class="admin-btn-primary">
            <Plus :size="18" />
            Agregar mesas
          </button>
        </div>
      </div>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>

      <div v-else-if="!event" class="mt-8 rounded-[2rem] bg-limestone p-8">
        <p class="text-obsidian/60">Primero creá tu invitación, después vas a poder armar las mesas.</p>
        <router-link :to="{ name: 'admin-salon' }" class="admin-btn-primary mt-5">Creá tu invitación</router-link>
      </div>

      <template v-else>
        <!-- ============ AGREGAR ============ -->
        <form v-if="addOpen" @submit.prevent="addTables" class="mt-6 rounded-[2rem] bg-limestone p-6 sm:p-8">
          <div class="flex items-center justify-between gap-3">
            <h2 class="text-lg font-bold">Agregar mesas</h2>
            <button type="button" @click="addOpen = false" aria-label="Cerrar" class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-chalk">
              <X :size="16" />
            </button>
          </div>
          <div class="mt-5 grid gap-4 sm:grid-cols-3">
            <div>
              <label class="admin-label" for="t-count">Cuántas mesas</label>
              <input id="t-count" v-model.number="newTables.count" type="number" min="1" max="100" class="admin-input" />
            </div>
            <div>
              <label class="admin-label" for="t-capacity">Lugares por mesa</label>
              <input id="t-capacity" v-model.number="newTables.capacity" type="number" min="1" class="admin-input" />
            </div>
            <div v-if="newTables.count === 1">
              <label class="admin-label" for="t-name">Nombre</label>
              <input id="t-name" v-model="newTables.name" :placeholder="`Mesa ${nextNumber}`" class="admin-input" />
            </div>
            <p v-else class="self-end pb-3 text-sm text-obsidian/55">
              Se llaman «Mesa {{ nextNumber }}» a «Mesa {{ nextNumber + (newTables.count || 1) - 1 }}». Después las podés renombrar.
            </p>
          </div>
          <p v-if="addError" class="mt-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ addError }}</p>
          <button type="submit" :disabled="savingKey === 'add'" class="admin-btn-primary mt-5">
            {{ savingKey === 'add' ? 'Creando…' : newTables.count > 1 ? `Crear ${newTables.count} mesas` : 'Crear mesa' }}
          </button>
        </form>

        <p v-if="error" class="mt-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ error }}</p>

        <div class="mt-6 grid items-start gap-4 lg:grid-cols-[18rem_1fr]">
          <!-- ============ SIN MESA ============ -->
          <aside
            @dragover="onUnseatedDragOver"
            @dragleave="onDragLeave($event, 'unseated')"
            @drop.prevent="onUnseatedDrop"
            :class="{ 'ring-2 ring-accent': dragOver === 'unseated' }"
            class="rounded-[1.75rem] bg-limestone p-5 transition-shadow lg:sticky lg:top-[calc(1rem+var(--banner-h,0px))] lg:max-h-[calc(100dvh-2rem-var(--banner-h,0px))] lg:overflow-y-auto">
            <h2 class="flex items-center justify-between gap-2 text-lg font-bold">
              Sin mesa
              <span class="rounded-full bg-chalk px-2.5 py-0.5 text-sm">{{ unseated.length }}</span>
            </h2>
            <p class="mt-1 text-xs text-obsidian/50">
              Confirmados que asisten. Arrastralos a una mesa, o tocalos y elegí la mesa. El nombre de la familia mueve a todos.
            </p>

            <label v-if="unseated.length > 6" class="relative mt-4 block">
              <Search :size="15" class="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 text-obsidian/40" />
              <input v-model="search" type="search" placeholder="Buscar" class="admin-input !py-2 !pl-10 text-sm" />
            </label>

            <p v-if="guests.length === 0" class="mt-4 rounded-[1.25rem] bg-chalk px-4 py-3 text-sm text-obsidian/60">
              Todavía nadie confirmó que asiste.
            </p>
            <p v-else-if="unseated.length === 0" class="mt-4 flex items-center gap-2 rounded-[1.25rem] bg-chalk px-4 py-3 text-sm font-bold">
              <Check :size="16" class="text-go" /> Todos tienen mesa.
            </p>
            <p v-else-if="unseatedByFamily.length === 0" class="mt-4 text-sm text-obsidian/55">Nadie coincide con «{{ search.trim() }}».</p>

            <div v-for="family in unseatedByFamily" :key="family.id" class="mt-4">
              <button
                type="button"
                draggable="true"
                @dragstart="dragFamily($event, family)"
                @dragend="onDragEnd"
                @click="toggleFamily(family)"
                class="flex w-full cursor-grab active:cursor-grabbing items-center gap-2 text-left text-xs font-bold tracking-wide text-obsidian/55 uppercase hover:text-obsidian"
              >
                <span
                  class="grid h-4 w-4 shrink-0 place-items-center rounded-full border-[1.5px]"
                  :class="familySelected(family) ? 'border-accent bg-accent text-chalk' : 'border-obsidian/30'"
                >
                  <Check v-if="familySelected(family)" :size="10" :stroke-width="3" />
                </span>
                <span class="truncate">{{ family.name }}</span>
              </button>
              <div class="mt-2 flex flex-wrap gap-1.5">
                <button
                  v-for="guest in family.guests"
                  :key="guest.id"
                  type="button"
                  draggable="true"
                  @dragstart="dragGuest($event, guest)"
                  @dragend="onDragEnd"
                  @click="toggleGuest(guest)"
                  :aria-pressed="selected.has(guest.id)"
                  :class="[
                    selected.has(guest.id) ? 'bg-accent text-chalk' : 'bg-chalk hover:bg-accent-soft',
                    { 'opacity-40': dragIds.includes(guest.id) },
                  ]"
                  class="cursor-grab rounded-full px-3 py-1.5 text-sm font-bold transition-colors active:cursor-grabbing"
                >
                  {{ guest.full_name }}
                </button>
              </div>
            </div>
          </aside>

          <!-- ============ MESAS ============ -->
          <div>
            <div v-if="tables.length === 0" class="rounded-[1.75rem] bg-limestone p-8 text-center text-obsidian/60">
              Todavía no hay mesas. Tocá «Agregar mesas» para crear las del salón.
            </div>

            <div v-else class="grid gap-3 sm:grid-cols-2">
              <section
                v-for="table in tables"
                :key="table.id"
                @dragover="onTableDragOver($event, table)"
                @dragleave="onDragLeave($event, table.id)"
                @drop.prevent="onTableDrop(table)"
                class="flex flex-col rounded-[1.75rem] bg-limestone p-5 transition-[box-shadow,background-color]"
                :class="
                  dragOver === table.id
                    ? dragFits(table)
                      ? 'bg-accent-soft ring-2 ring-accent'
                      : 'bg-nogo/10 ring-2 ring-nogo'
                    : { 'ring-2 ring-accent': selected.size && canSeatAt(table) }
                "
              >
                <p v-if="dragOver === table.id" class="mb-3 rounded-full px-3 py-1 text-center text-sm font-bold" :class="dragFits(table) ? 'bg-accent text-chalk' : 'bg-nogo text-chalk'">
                  <template v-if="dragFits(table)">Soltá para sentar {{ dragIncoming(table) === 1 ? '1 persona' : `${dragIncoming(table)} personas` }}</template>
                  <template v-else>No entran: {{ freeSeats(table) <= 0 ? 'está llena' : `quedan ${freeSeats(table)}` }}</template>
                </p>
                <!-- Edición -->
                <form v-if="editingId === table.id && editForm" @submit.prevent="saveEdit(table)" class="space-y-3">
                  <div class="grid grid-cols-[1fr_6rem] gap-2">
                    <div>
                      <label class="admin-label" :for="`e-name-${table.id}`">Nombre</label>
                      <input :id="`e-name-${table.id}`" v-model="editForm.name" class="admin-input !py-2" />
                    </div>
                    <div>
                      <label class="admin-label" :for="`e-cap-${table.id}`">Lugares</label>
                      <input :id="`e-cap-${table.id}`" v-model.number="editForm.capacity" type="number" min="1" class="admin-input !py-2" />
                    </div>
                  </div>
                  <p v-if="editError" class="rounded-[1rem] bg-nogo/15 px-3 py-2 text-sm font-bold">{{ editError }}</p>
                  <div class="flex gap-2">
                    <button type="submit" :disabled="savingKey === `edit-${table.id}`" class="admin-btn-primary !px-4 !py-2 text-sm">Guardar</button>
                    <button type="button" @click="cancelEdit" class="rounded-full px-3 py-2 text-sm font-bold text-obsidian/55">Cancelar</button>
                  </div>
                </form>

                <!-- Encabezado -->
                <div v-else class="flex items-start justify-between gap-2">
                  <div class="min-w-0">
                    <h3 class="truncate text-lg font-bold">{{ table.name }}</h3>
                    <p class="text-xs font-bold text-obsidian/45">
                      {{ occupied(table) }} / {{ table.capacity }}
                      <template v-if="freeSeats(table) <= 0"> · llena</template>
                      <template v-else> · {{ freeSeats(table) === 1 ? 'queda 1 lugar' : `quedan ${freeSeats(table)} lugares` }}</template>
                    </p>
                  </div>
                  <div class="flex shrink-0 items-center">
                    <button type="button" @click="startEdit(table)" :aria-label="`Editar ${table.name}`" class="grid h-9 w-9 place-items-center rounded-full transition-colors hover:bg-chalk">
                      <Pencil :size="15" />
                    </button>
                    <button
                      type="button"
                      @click="removeTable(table)"
                      :aria-label="`Eliminar ${table.name}`"
                      class="grid h-9 w-9 place-items-center rounded-full text-obsidian/55 transition-colors hover:bg-nogo/15 hover:text-nogo"
                    >
                      <Trash2 :size="15" />
                    </button>
                  </div>
                </div>

                <div class="mt-3 h-2 overflow-hidden rounded-full bg-chalk">
                  <div
                    class="h-full rounded-full bg-accent transition-[width]"
                    :style="{ width: Math.min(100, table.capacity ? (occupied(table) / table.capacity) * 100 : 0) + '%' }"
                  ></div>
                </div>

                <!-- Sentados -->
                <ul v-if="occupied(table)" class="mt-4 flex flex-wrap gap-1.5">
                  <li
                    v-for="guest in seatedAt(table)"
                    :key="guest.id"
                    draggable="true"
                    @dragstart="dragGuest($event, guest)"
                    @dragend="onDragEnd"
                    :class="[selected.has(guest.id) ? 'bg-accent text-chalk' : 'bg-chalk', { 'opacity-40': dragIds.includes(guest.id) }]"
                    class="flex cursor-grab items-center rounded-full text-sm font-bold transition-colors active:cursor-grabbing"
                  >
                    <button
                      type="button"
                      @click="toggleGuest(guest)"
                      :aria-pressed="selected.has(guest.id)"
                      :title="`${guest.invitation_groups.family_name} · arrastralo o tocalo para moverlo a otra mesa`"
                      class="cursor-grab py-1.5 pl-3 active:cursor-grabbing"
                    >
                      {{ guest.full_name }}
                      <EyeOff v-if="guest.invitation_groups.sorpresa" :size="12" class="ml-1 inline align-[-1px] opacity-60" aria-label="sorpresa" />
                    </button>
                    <button
                      type="button"
                      @click="unseat(guest)"
                      :disabled="savingKey === `guest-${guest.id}`"
                      :aria-label="`Sacar a ${guest.full_name} de ${table.name}`"
                      class="grid h-8 w-8 place-items-center rounded-full opacity-50 hover:opacity-100"
                    >
                      <X :size="13" />
                    </button>
                  </li>
                  <!-- Invitados que esta cuenta no ve: ocupan lugar, sin nombre. -->
                  <li v-if="reservedAt(table)" class="rounded-full border-[1.5px] border-dashed border-obsidian/25 px-3 py-1.5 text-sm font-bold text-obsidian/50">
                    {{ reservedAt(table) === 1 ? '1 lugar reservado' : `${reservedAt(table)} lugares reservados` }}
                  </li>
                </ul>
                <p v-else class="mt-4 text-sm text-obsidian/45">Mesa vacía.</p>

                <!-- Sentar a los seleccionados -->
                <div v-if="selected.size" class="mt-auto pt-4">
                  <button
                    v-if="incomingFor(table) > 0"
                    type="button"
                    @click="seatSelected(table)"
                    :disabled="!canSeatAt(table) || savingKey === `seat-${table.id}`"
                    class="admin-btn-primary w-full !py-2 text-sm"
                  >
                    <Armchair :size="16" />
                    <template v-if="canSeatAt(table)">Sentar acá ({{ incomingFor(table) }})</template>
                    <template v-else>No entran: {{ freeSeats(table) <= 0 ? 'está llena' : `quedan ${freeSeats(table)}` }}</template>
                  </button>
                </div>
              </section>
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- Barra de selección -->
    <div
      v-if="selected.size"
      class="font-ui fixed inset-x-0 bottom-4 z-30 flex justify-center px-4 lg:left-[16.5rem]"
    >
      <div class="flex items-center gap-3 rounded-full bg-obsidian py-2 pr-2 pl-5 text-sm text-chalk shadow-lg">
        <span>
          <strong>{{ selected.size }}</strong> {{ selected.size === 1 ? 'seleccionado' : 'seleccionados' }} · elegí una mesa
        </span>
        <button type="button" @click="clearSelection" class="rounded-full bg-chalk/15 px-3 py-1.5 font-bold hover:bg-chalk/25">
          Cancelar
        </button>
      </div>
    </div>
  </div>
</template>
