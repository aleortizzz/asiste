<script setup>
import { ref, computed, nextTick, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Search, ShieldCheck, ArrowRight, CalendarDays, Trash2, TriangleAlert } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { useAuth } from '../composables/useAuth'
import { supabase } from '../lib/supabase'
import { confirmDialog } from '../composables/useConfirm'
import { PHOTO_SLOTS } from '../composables/useEventPhotos'
import { PLANS, PLAN_IDS } from '../lib/plans'

// Lista de todos los eventos (solo superadmin): entrar al panel de un
// cliente para ayudarlo y activarle el plan.
const router = useRouter()
const { viewing, setViewingEvent } = useEvent()
const { user } = useAuth()

const rows = ref([])
const loading = ref(true)
const error = ref('')
const search = ref('')
const filter = ref('todos') // 'todos' | un plan (ver lib/plans.js)
const savingId = ref(null)

onMounted(async () => {
  const { data, error: err } = await supabase.rpc('listar_eventos_superadmin')
  if (err) error.value = err.message
  else rows.value = data ?? []
  loading.value = false
})

function entrar(row) {
  setViewingEvent({ id: row.event_id, name: row.event_name, owner_email: row.owner_email })
  router.push({ name: 'admin-dashboard' })
}

// El plan lo activa TizDigital a mano acá (todavía no hay billing
// automático) — el host no puede subirse de plan solo.
async function setPlan(row, plan) {
  if (row.plan === plan) return
  error.value = ''
  savingId.value = row.event_id
  const { error: err } = await supabase.from('events').update({ plan }).eq('id', row.event_id)
  if (err) error.value = `No se pudo cambiar el plan de «${row.event_name}»: ${err.message}`
  else row.plan = plan
  savingId.value = null
}

// --- Fechas ---------------------------------------------------------------------
// event_date viene como 'YYYY-MM-DD': se arma en hora local para que no se
// corra un día por el huso.
function localDate(ymd) {
  const [y, m, d] = ymd.split('-').map(Number)
  return new Date(y, m - 1, d)
}

function formatDate(ymd) {
  return localDate(ymd).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
}

function daysLabel(ymd) {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const days = Math.round((localDate(ymd) - today) / 86400000)
  if (days === 0) return '¡es hoy!'
  if (days === 1) return 'mañana'
  if (days > 1) return `faltan ${days} días`
  return 'ya pasó'
}

const isPast = (row) => row.event_date && daysLabel(row.event_date) === 'ya pasó'

// --- Filtros ----------------------------------------------------------------------
const counts = computed(() => ({
  todos: rows.value.length,
  ...Object.fromEntries(PLAN_IDS.map((p) => [p, rows.value.filter((r) => r.plan === p).length])),
}))

const FILTERS = [{ id: 'todos', label: 'Todos' }, ...PLAN_IDS.map((p) => ({ id: p, label: PLANS[p].label }))]

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return rows.value
    .filter((r) => filter.value === 'todos' || r.plan === filter.value)
    .filter((r) => !q || r.owner_email?.toLowerCase().includes(q) || r.event_name?.toLowerCase().includes(q))
})

const isMine = (row) => row.owner_email && row.owner_email === user.value?.email
const isViewing = (row) => viewing.value?.id === row.event_id

// --- Eliminar un evento ---------------------------------------------------------------
// Dos pasos para no borrar sin querer: un aviso con todo lo que se pierde y
// después hay que escribir ELIMINAR (el diálogo común confirma con Enter).
// La base borra en cascada (mesas, invitaciones, invitados, canciones, fotos,
// juego…); los archivos de Storage los borramos acá. La cuenta del cliente
// no se toca: puede volver a entrar y crear otro evento.
const DELETE_WORD = 'ELIMINAR'
const toDelete = ref(null) // fila en el paso 2
const deleteText = ref('')
const deleteBusy = ref(false)
const deleteError = ref('')
const canDelete = computed(() => deleteText.value.trim().toUpperCase() === DELETE_WORD)

async function askDelete(row) {
  error.value = ''
  const [groups, photos] = await Promise.all([
    supabase.from('invitation_groups').select('id', { count: 'exact', head: true }).eq('event_id', row.event_id),
    supabase.from('event_photos').select('id', { count: 'exact', head: true }).eq('event_id', row.event_id),
  ])
  const n = groups.count ?? 0
  const f = photos.count ?? 0
  const ok = await confirmDialog({
    title: '¿Eliminar este evento?',
    message:
      `Se borra «${row.event_name}» (${row.owner_email}) con todo lo que tiene: ` +
      `${n} ${n === 1 ? 'invitación' : 'invitaciones'} con sus respuestas, mesas, canciones, ` +
      `${f} ${f === 1 ? 'foto' : 'fotos'} de invitados, el juego y las fotos de la invitación. ` +
      'No se puede deshacer.',
    confirmText: 'Continuar',
    tone: 'danger',
  })
  if (!ok) return
  deleteText.value = ''
  deleteError.value = ''
  toDelete.value = row
  await nextTick()
  deleteInput.value?.focus()
}
const deleteInput = ref(null)

function cancelDelete() {
  if (deleteBusy.value) return
  toDelete.value = null
}

// Las fotos de la invitación están en event-photos/<dueño>/<sección>/… (un
// evento por cuenta, así que esa carpeta es solo de este evento).
async function listInvitationPhotos(ownerId) {
  const paths = []
  for (const slot of PHOTO_SLOTS) {
    const { data } = await supabase.storage.from('event-photos').list(`${ownerId}/${slot}`, { limit: 1000 })
    for (const file of data ?? []) if (file.id) paths.push(`${ownerId}/${slot}/${file.name}`)
  }
  return paths
}

// Devuelve cuántos archivos no se pudieron borrar.
async function removeFiles(bucket, paths) {
  let failed = 0
  for (let i = 0; i < paths.length; i += 100) {
    const chunk = paths.slice(i, i + 100)
    const { error: err } = await supabase.storage.from(bucket).remove(chunk)
    if (err) failed += chunk.length
  }
  return failed
}

async function confirmDelete() {
  const row = toDelete.value
  if (!row || !canDelete.value || deleteBusy.value) return
  deleteBusy.value = true
  deleteError.value = ''
  try {
    // 1) Antes de borrar juntamos los archivos: después ya no está el catálogo.
    const [{ data: ev }, { data: guestPhotos }] = await Promise.all([
      supabase.from('events').select('owner_user_id').eq('id', row.event_id).single(),
      supabase.from('event_photos').select('path').eq('event_id', row.event_id),
    ])
    const invitationPaths = ev?.owner_user_id ? await listInvitationPhotos(ev.owner_user_id) : []

    // 2) El evento (y todo lo de la base, en cascada).
    const { data: gone, error: err } = await supabase.from('events').delete().eq('id', row.event_id).select('id')
    if (err) throw err
    if (!gone?.length) throw new Error('la base no lo borró (¿permisos?)')

    // 3) Los archivos. Si alguno falla, el evento ya no está: solo avisamos.
    const failed =
      (await removeFiles('guest-uploads', (guestPhotos ?? []).map((p) => p.path))) +
      (await removeFiles('event-photos', invitationPaths))
    if (failed) {
      error.value = `Se eliminó «${row.event_name}», pero ${failed} archivos de fotos no se pudieron borrar del almacenamiento.`
    }

    rows.value = rows.value.filter((r) => r.event_id !== row.event_id)
    // Si era el que estaba viendo (o el mío), que el panel no lo siga mostrando.
    if (isViewing(row) || isMine(row)) setViewingEvent(null)
    toDelete.value = null
  } catch (err) {
    deleteError.value = `No se pudo eliminar: ${err.message}`
  } finally {
    deleteBusy.value = false
  }
}
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-3xl px-4 pt-4 pb-16 lg:px-8 lg:pt-8">
      <p class="inline-flex items-center gap-1.5 rounded-full bg-obsidian px-3 py-1 text-xs font-bold text-chalk">
        <ShieldCheck :size="13" /> Superadmin
      </p>
      <h1 class="admin-display mt-3 text-5xl sm:text-6xl">Clientes</h1>
      <p class="mt-3 max-w-lg text-obsidian/60">
        Entrá al panel de cualquier cliente para ayudarlo. Mientras estés adentro vas a ver un aviso arriba de todo, con
        un botón para salir.
      </p>

      <!-- Filtros + buscador -->
      <div class="mt-6 flex flex-wrap items-center gap-2">
        <button
          v-for="f in FILTERS"
          :key="f.id"
          type="button"
          @click="filter = f.id"
          :class="filter === f.id ? 'bg-accent text-chalk' : 'bg-limestone hover:bg-chalk'"
          class="flex items-center gap-2 rounded-full px-4 py-2 text-sm font-bold transition-colors"
        >
          {{ f.label }}
          <span :class="filter === f.id ? 'text-chalk/70' : 'text-obsidian/45'">{{ counts[f.id] }}</span>
        </button>
        <label class="relative ml-auto w-full sm:w-64">
          <Search :size="16" class="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 text-obsidian/40" />
          <input v-model="search" type="search" placeholder="Buscar mail o evento" class="admin-input !py-2 !pl-10 text-sm" />
        </label>
      </div>

      <p v-if="error" class="mt-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ error }}</p>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>

      <div v-else-if="!rows.length && !error" class="mt-6 rounded-[2rem] bg-limestone p-8 text-center text-obsidian/60">
        Todavía no hay ningún evento creado.
      </div>

      <div v-else-if="!filtered.length && rows.length" class="mt-6 rounded-[2rem] bg-limestone p-8 text-center text-obsidian/60">
        <template v-if="search.trim()">No hay clientes que coincidan con «{{ search.trim() }}».</template>
        <template v-else>No hay clientes en esta categoría.</template>
      </div>

      <ul v-else class="mt-4 space-y-3">
        <li
          v-for="row in filtered"
          :key="row.event_id"
          :class="{ 'ring-2 ring-accent': isViewing(row), 'opacity-70': isPast(row) }"
          class="rounded-[1.75rem] bg-limestone p-5 sm:p-6"
        >
          <div class="flex flex-wrap items-start justify-between gap-x-4 gap-y-4">
            <div class="min-w-0">
              <h2 class="flex min-w-0 flex-wrap items-center gap-2 text-lg font-bold">
                <span class="truncate">{{ row.event_name }}</span>
                <span v-if="isMine(row)" class="shrink-0 rounded-full bg-chalk px-2.5 py-0.5 text-xs">Tu cuenta</span>
                <span v-if="isViewing(row)" class="shrink-0 rounded-full bg-accent px-2.5 py-0.5 text-xs text-chalk">
                  Estás viendo este
                </span>
              </h2>
              <p class="truncate text-sm text-obsidian/60">{{ row.owner_email }}</p>
              <p class="mt-2 flex items-center gap-1.5 text-xs font-bold text-obsidian/45">
                <CalendarDays :size="13" />
                <template v-if="row.event_date">{{ formatDate(row.event_date) }} · {{ daysLabel(row.event_date) }}</template>
                <template v-else>Sin fecha cargada</template>
              </p>
            </div>

            <div class="flex shrink-0 flex-wrap items-center gap-2">
              <!-- Plan -->
              <div
                class="flex rounded-full bg-pumice/70 p-0.5 text-sm font-bold"
                :class="{ 'opacity-50': savingId === row.event_id }"
                role="group"
                :aria-label="`Plan de ${row.event_name}`"
              >
                <button
                  v-for="p in PLAN_IDS"
                  :key="p"
                  type="button"
                  :disabled="savingId === row.event_id"
                  @click="setPlan(row, p)"
                  :aria-pressed="row.plan === p"
                  :class="
                    row.plan === p
                      ? p === 'gratis'
                        ? 'bg-chalk'
                        : 'bg-accent text-chalk'
                      : 'text-obsidian/55 hover:text-obsidian'
                  "
                  class="rounded-full px-3 py-1.5 transition-colors"
                >
                  {{ p === 'gratis' ? 'Gratis' : PLANS[p].label }}
                </button>
              </div>

              <button type="button" @click="entrar(row)" class="admin-btn-primary !px-5 !py-2.5 text-sm">
                Entrar
                <ArrowRight :size="16" />
              </button>
              <button
                type="button"
                @click="askDelete(row)"
                :aria-label="`Eliminar ${row.event_name}`"
                title="Eliminar evento"
                class="grid h-10 w-10 place-items-center rounded-full text-obsidian/45 transition-colors hover:bg-nogo/15 hover:text-nogo"
              >
                <Trash2 :size="17" />
              </button>
            </div>
          </div>
        </li>
      </ul>

      <p v-if="!loading && rows.length" class="mt-6 text-center text-xs text-obsidian/45">
        Ordenados por fecha de creación, del más nuevo al más viejo.
      </p>
    </div>

    <!-- Paso 2 del borrado: escribir ELIMINAR -->
    <Transition name="del">
      <div
        v-if="toDelete"
        class="fixed inset-0 z-[80] flex items-end justify-center bg-obsidian/40 p-4 backdrop-blur-[2px] sm:items-center"
        @click.self="cancelDelete"
        @keydown.esc="cancelDelete"
      >
        <form
          @submit.prevent="confirmDelete"
          role="alertdialog"
          aria-modal="true"
          aria-label="Confirmar eliminación"
          class="del-card w-full max-w-sm rounded-[2rem] bg-limestone p-6 text-obsidian sm:p-7"
        >
          <span class="grid h-11 w-11 place-items-center rounded-full bg-nogo/15 text-nogo">
            <TriangleAlert :size="20" />
          </span>
          <h2 class="admin-display mt-4 text-3xl">Última confirmación</h2>
          <p class="mt-3 text-[0.95rem] leading-relaxed text-obsidian/65">
            Vas a eliminar <strong class="text-obsidian">«{{ toDelete.event_name }}»</strong> de
            {{ toDelete.owner_email }} para siempre. Para confirmar, escribí
            <strong class="text-obsidian">{{ DELETE_WORD }}</strong>.
          </p>
          <input
            ref="deleteInput"
            v-model="deleteText"
            type="text"
            autocomplete="off"
            autocapitalize="characters"
            spellcheck="false"
            :placeholder="DELETE_WORD"
            class="admin-input mt-4 text-center font-bold tracking-widest"
          />
          <p v-if="deleteError" class="mt-3 rounded-[1rem] bg-nogo/15 px-3 py-2 text-sm font-bold">{{ deleteError }}</p>
          <div class="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <button type="button" @click="cancelDelete" :disabled="deleteBusy" class="admin-btn-secondary">Cancelar</button>
            <button type="submit" :disabled="!canDelete || deleteBusy" class="admin-btn-primary !bg-nogo !text-chalk">
              <Trash2 :size="16" /> {{ deleteBusy ? 'Eliminando…' : 'Eliminar para siempre' }}
            </button>
          </div>
        </form>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.del-enter-active,
.del-leave-active {
  transition: opacity 0.2s ease;
}
.del-enter-active .del-card,
.del-leave-active .del-card {
  transition: transform 0.25s cubic-bezier(0.32, 0.72, 0, 1);
}
.del-enter-from,
.del-leave-to {
  opacity: 0;
}
.del-enter-from .del-card,
.del-leave-to .del-card {
  transform: translateY(1rem);
}
</style>
