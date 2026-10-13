<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { DoorOpen, UserPlus, Trash2, ExternalLink, Check, Copy, KeyRound, Clock, RotateCcw, ChevronDown } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import FormField from '../components/FormField.vue'
import PasswordInput from '../components/PasswordInput.vue'
import { useEvent } from '../composables/useEvent'
import { useFormValidation, newPasswordError } from '../composables/useFormValidation'
import { confirmDialog } from '../composables/useConfirm'
import { supabase } from '../lib/supabase'
import { usernameError } from '../lib/staff'

// Recepción, del lado del organizador:
// - Llegadas en vivo (se actualiza cada 15 s): cuántos llegaron, por mesa, y
//   los últimos en entrar. Las sorpresas aparecen con nombre (a diferencia
//   de Mesas): el día del evento esta pantalla la mira la familia.
// - Personal de recepción: usuarios con contraseña para el personal del
//   salón, que entra a /recepcion. Ver migrations/20261012_recepcion.sql.
const { event, loadEvent } = useEvent()
const loading = ref(true)
const tables = ref([])
const guests = ref([])
const staff = ref([])

let timer = null
onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) {
    await Promise.all([fetchArrivals(), fetchStaff()])
    timer = setInterval(() => document.visibilityState === 'visible' && fetchArrivals(), 15000)
  }
  loading.value = false
})
onUnmounted(() => clearInterval(timer))

// La misma lista que usa recepción (recepcion_lista), así las sorpresas
// también aparecen acá con nombre.
async function fetchArrivals() {
  const id = event.value.id
  const [t, l] = await Promise.all([
    supabase.from('tables').select('id, name, created_at').eq('event_id', id).order('created_at'),
    supabase.rpc('recepcion_lista', { p_event_id: id }),
  ])
  if (!t.error) tables.value = t.data
  if (!l.error) guests.value = l.data.guests
}

// --- Llegadas ----------------------------------------------------------------------------
const total = computed(() => guests.value.length)
const arrived = computed(() => guests.value.filter((g) => g.arrived_at).length)

const latest = computed(() =>
  guests.value
    .filter((g) => g.arrived_at)
    .sort((a, b) => (a.arrived_at < b.arrived_at ? 1 : -1))
    .slice(0, 6),
)

// Mesas en el orden en que se crearon; «Sin mesa» al final si hay alguien.
const byTable = computed(() => {
  const rows = tables.value.map((t) => ({ id: t.id, name: t.name, guests: guests.value.filter((g) => g.table_id === t.id) }))
  const known = new Set(tables.value.map((t) => t.id))
  const loose = guests.value.filter((g) => !g.table_id || !known.has(g.table_id))
  if (loose.length) rows.push({ id: 'sin-mesa', name: 'Sin mesa', guests: loose })
  return rows.filter((r) => r.guests.length)
})

const timeOf = (iso) => new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })

// Para después de probar: deja a todos como «no llegó» (sorpresas incluidas).
async function resetArrivals() {
  const ok = await confirmDialog({
    title: '¿Reiniciar las llegadas?',
    message: `Los ${arrived.value} que figuran como llegados vuelven a «no llegó». Sirve para dejar todo limpio después de probar.`,
    confirmText: 'Reiniciar',
    tone: 'danger',
  })
  if (!ok) return
  const { error: err } = await supabase.rpc('reiniciar_llegadas', { p_event_id: event.value.id })
  if (!err) await fetchArrivals()
}

// --- Menú «Marcar llegadas» ----------------------------------------------------------------
const menuOpen = ref(false)

// Lleva al formulario de personal y deja el cursor en «Nombre».
function goToStaffForm() {
  menuOpen.value = false
  const input = document.getElementById('staff-name')
  input?.scrollIntoView({ behavior: 'smooth', block: 'center' })
  input?.focus({ preventScroll: true })
}

// --- Personal ----------------------------------------------------------------------------
async function fetchStaff() {
  const { data, error: err } = await supabase
    .from('event_staff')
    .select('id, username, display_name, created_at')
    .eq('event_id', event.value.id)
    .order('created_at')
  if (!err) staff.value = data
}

const name = ref('')
const username = ref('')
const password = ref('')
const creating = ref(false)
const createError = ref('')
const created = ref(null) // { username, password } recién creado, para pasárselo a la persona

const form = useFormValidation({
  name: { id: 'staff-name', check: () => (name.value.trim() ? '' : 'Escribí el nombre de la persona.') },
  username: { id: 'staff-username', check: () => usernameError(username.value) },
  password: { id: 'staff-password', check: () => newPasswordError(password.value) },
})

async function createStaff() {
  createError.value = ''
  created.value = null
  if (!form.validate()) return
  creating.value = true
  const { error: err } = await supabase.rpc('crear_recepcionista', {
    p_event_id: event.value.id,
    p_username: username.value.trim(),
    p_password: password.value,
    p_display_name: name.value.trim(),
  })
  creating.value = false
  if (err) {
    createError.value = err.message?.includes('ya existe')
      ? 'Ese usuario ya existe. Elegí otro (por ejemplo, agregale el nombre del salón).'
      : 'No se pudo crear el usuario. Probá de nuevo.'
    return
  }
  created.value = { username: username.value.trim().toLowerCase(), password: password.value }
  name.value = username.value = password.value = ''
  form.reset()
  await fetchStaff()
}

// Borra también la cuenta: el usuario queda libre para volver a usarlo.
async function removeStaff(s) {
  const ok = await confirmDialog({
    title: `¿Quitar a ${s.display_name}?`,
    message: 'Se borra su usuario y ya no va a poder entrar a la recepción.',
    confirmText: 'Quitar',
    tone: 'danger',
  })
  if (!ok) return
  const { error: err } = await supabase.rpc('quitar_recepcionista', { p_staff_id: s.id })
  if (err) return
  staff.value = staff.value.filter((x) => x.id !== s.id)
  // Sus datos ya no sirven: no dejamos el cartel para pasárselos.
  if (created.value?.username === s.username) created.value = null
  if (changingId.value === s.id) changingId.value = null
}

// El personal no tiene mail para recuperar la contraseña: se la cambia el
// organizador (y se le cierra la sesión donde la tuviera abierta).
const changingId = ref(null)
const newPassword = ref('')
const changeError = ref('')

function startChange(s) {
  changingId.value = changingId.value === s.id ? null : s.id
  newPassword.value = ''
  changeError.value = ''
}

async function savePassword(s) {
  changeError.value = newPasswordError(newPassword.value)
  if (changeError.value) return
  const { error: err } = await supabase.rpc('cambiar_clave_recepcionista', { p_staff_id: s.id, p_password: newPassword.value })
  if (err) return (changeError.value = 'No se pudo cambiar. Probá de nuevo.')
  created.value = { username: s.username, password: newPassword.value }
  changingId.value = null
}

const loginUrl = `${window.location.origin}/admin/login`
const copied = ref(false)
async function copyCredentials() {
  const c = created.value
  await navigator.clipboard.writeText(`Recepción · ${event.value.name}\nEntrá en ${loginUrl}\nUsuario: ${c.username}\nContraseña: ${c.password}`)
  copied.value = true
  setTimeout(() => (copied.value = false), 1500)
}
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-4xl px-4 pt-4 pb-16 lg:px-8 lg:pt-8">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 class="admin-display text-5xl sm:text-6xl">Recepción</h1>
          <p class="mt-3 max-w-lg text-obsidian/60">
            El personal del salón marca quién llega y le dice su mesa. Acá ves las llegadas en vivo.
          </p>
        </div>
        <div v-if="event" class="relative">
          <button type="button" @click="menuOpen = !menuOpen" :aria-expanded="menuOpen" class="admin-btn-secondary">
            <DoorOpen :size="18" />
            Marcar llegadas
            <ChevronDown :size="16" class="transition-transform" :class="{ 'rotate-180': menuOpen }" />
          </button>

          <!-- Click afuera cierra el menú -->
          <div v-if="menuOpen" @click="menuOpen = false" class="fixed inset-0 z-30"></div>

          <div
            v-if="menuOpen"
            class="absolute right-0 z-40 mt-2 w-[min(20rem,calc(100vw-2rem))] space-y-1 rounded-[1.5rem] bg-chalk p-3 shadow-xl ring-1 ring-obsidian/5"
          >
            <button
              type="button"
              @click="goToStaffForm"
              class="flex w-full items-center gap-3 rounded-[1.1rem] px-2 py-2 text-left transition-colors hover:bg-limestone"
            >
              <span class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-accent-soft text-accent"><UserPlus :size="17" /></span>
              <span>
                <span class="block text-sm font-bold">Agregar personal de recepción</span>
                <span class="block text-xs text-obsidian/55">Usuarios para el personal del salón</span>
              </span>
            </button>
            <router-link
              :to="{ name: 'recepcion', params: { eventId: event.id } }"
              target="_blank"
              @click="menuOpen = false"
              class="flex w-full items-center gap-3 rounded-[1.1rem] px-2 py-2 text-left transition-colors hover:bg-limestone"
            >
              <span class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-go/20 text-obsidian"><ExternalLink :size="17" /></span>
              <span>
                <span class="block text-sm font-bold">Marcar llegadas yo mismo</span>
                <span class="block text-xs text-obsidian/55">Con tu cuenta, sin personal. Se abre en otra pestaña</span>
              </span>
            </router-link>
          </div>
        </div>
      </div>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>

      <div v-else-if="!event" class="mt-8 rounded-[2rem] bg-limestone p-8">
        <p class="text-obsidian/60">Primero creá tu invitación, después vas a poder armar la recepción.</p>
        <router-link :to="{ name: 'admin-salon' }" class="admin-btn-primary mt-5">Creá tu invitación</router-link>
      </div>

      <template v-else>
        <!-- Llegadas -->
        <section class="mt-8 rounded-[2rem] bg-limestone p-5 sm:p-7">
          <div class="flex flex-wrap items-end justify-between gap-3">
            <div>
              <p class="text-sm font-bold text-obsidian/55">Llegadas</p>
              <p class="mt-1 text-4xl font-bold">
                {{ arrived }} <span class="text-xl font-medium text-obsidian/50">de {{ total }}</span>
              </p>
            </div>
            <button
              v-if="arrived"
              type="button"
              @click="resetArrivals"
              class="inline-flex items-center gap-1.5 text-sm font-bold text-obsidian/60 hover:text-obsidian"
            >
              <RotateCcw :size="14" /> Reiniciar llegadas
            </button>
          </div>
          <div class="mt-4 h-3 overflow-hidden rounded-full bg-chalk">
            <div class="h-full rounded-full bg-go transition-[width] duration-500" :style="{ width: `${total ? (arrived / total) * 100 : 0}%` }"></div>
          </div>

          <div v-if="latest.length" class="mt-6">
            <p class="flex items-center gap-1.5 text-sm font-bold text-obsidian/55"><Clock :size="15" /> Últimos en llegar</p>
            <ul class="mt-2 flex flex-wrap gap-2">
              <li v-for="g in latest" :key="g.id" class="rounded-full bg-chalk px-3 py-1.5 text-sm">
                <strong>{{ g.full_name }}</strong> <span class="text-obsidian/50">{{ timeOf(g.arrived_at) }}</span>
              </li>
            </ul>
          </div>

          <p v-if="!guests.length" class="mt-6 text-obsidian/60">
            Cuando haya invitados confirmados, los vas a ver acá por mesa.
          </p>
          <div v-else class="mt-6 grid gap-3 sm:grid-cols-2">
            <div v-for="t in byTable" :key="t.id" class="rounded-[1.5rem] bg-chalk p-4">
              <div class="flex items-center justify-between gap-2">
                <p class="font-bold">{{ t.name }}</p>
                <p class="text-sm text-obsidian/55">
                  {{ t.guests.filter((g) => g.arrived_at).length }} de {{ t.guests.length }}
                </p>
              </div>
              <ul class="mt-2 space-y-1">
                <li v-for="g in t.guests" :key="g.id" class="flex items-center gap-2 text-sm">
                  <span
                    class="grid h-5 w-5 shrink-0 place-items-center rounded-full"
                    :class="g.arrived_at ? 'bg-go text-obsidian' : 'border-[1.5px] border-obsidian/20'"
                  >
                    <Check v-if="g.arrived_at" :size="12" />
                  </span>
                  <span :class="g.arrived_at ? 'font-bold' : 'text-obsidian/60'" class="truncate">{{ g.full_name }}</span>
                </li>
              </ul>
            </div>
          </div>
        </section>

        <!-- Personal -->
        <section class="mt-6 rounded-[2rem] bg-limestone p-5 sm:p-7">
          <div class="flex items-start gap-4">
            <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-accent-soft text-accent">
              <DoorOpen :size="20" />
            </span>
            <div>
              <h2 class="text-xl font-bold">Personal de recepción</h2>
              <p class="mt-1 text-sm text-obsidian/60">
                Cada persona entra en <strong>{{ loginUrl.replace(/^https?:\/\//, '') }}</strong> con su usuario y
                contraseña, y va directo a la lista de la entrada. Solo puede marcar llegadas de este evento.
              </p>
            </div>
          </div>

          <ul v-if="staff.length" class="mt-5 space-y-2">
            <li v-for="s in staff" :key="s.id" class="rounded-[1.25rem] bg-chalk py-2 pr-2 pl-4">
              <div class="flex items-center gap-1">
                <div class="min-w-0 flex-1">
                  <p class="truncate font-bold">{{ s.display_name }}</p>
                  <p class="truncate text-sm text-obsidian/55">Usuario: {{ s.username }}</p>
                </div>
                <button
                  type="button"
                  @click="startChange(s)"
                  :aria-label="`Cambiar la contraseña de ${s.display_name}`"
                  :aria-expanded="changingId === s.id"
                  class="grid h-10 w-10 shrink-0 place-items-center rounded-full hover:bg-limestone"
                >
                  <KeyRound :size="17" />
                </button>
                <button
                  type="button"
                  @click="removeStaff(s)"
                  :aria-label="`Quitar a ${s.display_name}`"
                  class="grid h-10 w-10 shrink-0 place-items-center rounded-full hover:bg-nogo/15"
                >
                  <Trash2 :size="17" />
                </button>
              </div>
              <form v-if="changingId === s.id" @submit.prevent="savePassword(s)" novalidate class="mt-2 mb-1 flex flex-wrap items-start gap-2">
                <div class="min-w-48 flex-1">
                  <PasswordInput
                    v-model="newPassword"
                    autocomplete="new-password"
                    placeholder="Contraseña nueva"
                    class="bg-limestone"
                    :aria-invalid="!!changeError"
                    :aria-label="`Contraseña nueva para ${s.display_name}`"
                  />
                  <p v-if="changeError" class="mt-1 px-2 text-sm font-bold text-nogo-ink">{{ changeError }}</p>
                </div>
                <button type="submit" class="admin-btn-primary px-5">Guardar</button>
              </form>
            </li>
          </ul>

          <!-- Recién creado: los datos para pasarle a la persona -->
          <div v-if="created" class="mt-5 rounded-[1.5rem] bg-go/20 p-4">
            <p class="flex items-center gap-2 font-bold"><KeyRound :size="17" /> Listo. Pasale estos datos:</p>
            <p class="mt-2 text-sm">Usuario: <strong>{{ created.username }}</strong></p>
            <p class="text-sm">Contraseña: <strong>{{ created.password }}</strong></p>
            <p class="mt-1 text-xs text-obsidian/60">La contraseña no se vuelve a mostrar: anotala o copiala ahora.</p>
            <button type="button" @click="copyCredentials" class="admin-btn-secondary mt-3 px-4 py-2 text-sm">
              <Check v-if="copied" :size="16" />
              <Copy v-else :size="16" />
              {{ copied ? '¡Copiado!' : 'Copiar para WhatsApp' }}
            </button>
          </div>

          <form @submit.prevent="createStaff" novalidate class="mt-5 rounded-[1.5rem] bg-chalk/60 p-4 sm:p-5">
            <p class="flex items-center gap-2 font-bold"><UserPlus :size="17" /> Agregar a alguien</p>
            <div class="mt-4 grid gap-4 sm:grid-cols-3">
              <FormField id="staff-name" label="Nombre" :error="form.errorFor('name')" v-slot="{ a11y }">
                <input v-bind="a11y" v-model="name" placeholder="Ej. Laura" @blur="form.touch('name', name)" class="admin-input" />
              </FormField>
              <FormField id="staff-username" label="Usuario" :error="form.errorFor('username')" v-slot="{ a11y }">
                <input
                  v-bind="a11y"
                  v-model="username"
                  autocomplete="off"
                  autocapitalize="none"
                  spellcheck="false"
                  placeholder="Ej. laura.salon"
                  @blur="form.touch('username', username)"
                  class="admin-input"
                />
              </FormField>
              <FormField id="staff-password" label="Contraseña" :error="form.errorFor('password')" v-slot="{ a11y }">
                <PasswordInput v-bind="a11y" v-model="password" autocomplete="new-password" @blur="form.touch('password', password)" />
              </FormField>
            </div>
            <p v-if="createError" class="mt-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold" role="alert">{{ createError }}</p>
            <button type="submit" :disabled="creating" class="admin-btn-primary mt-4">
              {{ creating ? 'Creando…' : 'Crear usuario' }}
            </button>
          </form>
        </section>
      </template>
    </div>
  </div>
</template>
