<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { compressImage } from '../lib/compressImage'
import { lighten, contrastText, isDark } from '../lib/color'
import { Camera, Heart, Clock, Flame, UserRound, Check, X, AlertCircle, ArrowUp, ImagePlus, Pencil } from '@lucide/vue'
import PhotoFeed from '../components/guest-photos/PhotoFeed.vue'

// Galería pública para los invitados (la abren escaneando el QR de las mesas).
// Sin login. Pensada como Instagram: perfil del evento arriba, pestañas
// (más votadas / recientes / mis fotos), grilla, y al tocar una foto un feed
// vertical donde el doble tap da like. Toma el estilo de la invitación.
const route = useRoute()
const eventId = route.params.eventId

const info = ref(null) // info_fotos_evento(): nombre, plantilla y colores
const cover = ref(null) // foto del evento para el "avatar" (vista_previa_fotos)
const photos = ref([])
const loading = ref(true)

// --- Estilo según la plantilla de la invitación ---------------------------------
// Las fuentes ya las carga index.html (son las mismas de las invitaciones).
const THEMES = {
  clasico: {
    display: "'Dancing Script', cursive",
    displayWeight: 700,
    displaySize: '2.6rem',
    body: "'Playfair Display', serif",
  },
  partiful: {
    display: "'Space Grotesk', ui-sans-serif, sans-serif",
    displayWeight: 700,
    displaySize: '2.1rem',
    body: "'Inter', ui-sans-serif, sans-serif",
    bg: '#ffffff',
  },
  craft: {
    display: "'DM Serif Text', ui-serif, Georgia, serif",
    displayWeight: 400,
    displaySize: '2.3rem',
    body: "'Inter', ui-sans-serif, sans-serif",
    bg: '#f7f3ea',
  },
}

const theme = computed(() => {
  const t = THEMES[info.value?.template] ?? THEMES.clasico
  const accent = /^#[0-9a-f]{6}$/i.test(info.value?.primary_color || '') ? info.value.primary_color : '#9f1239'
  const bg = t.bg ?? info.value?.bg_color ?? '#fdf7f1'
  const dark = isDark(bg)
  return {
    ...t,
    vars: {
      '--accent': accent,
      '--accent-on': contrastText(accent),
      // Sobre fondo oscuro el color principal puede no leerse: lo aclaramos.
      '--accent-text': dark ? lighten(accent, 0.45) : accent,
      '--tint': dark ? 'rgba(255,255,255,0.08)' : lighten(accent, 0.86),
      '--page-bg': bg,
      '--ink': dark ? '#f5f3f0' : '#2b2527',
      '--muted': dark ? 'rgba(245,243,240,0.6)' : 'rgba(43,37,39,0.58)',
      '--line': dark ? 'rgba(255,255,255,0.12)' : 'rgba(43,37,39,0.1)',
      '--field': dark ? 'rgba(255,255,255,0.08)' : '#ffffff',
      '--heart': '#ff3040',
    },
  }
})

const pageStyle = computed(() => ({
  ...theme.value.vars,
  background: 'var(--page-bg)',
  color: 'var(--ink)',
  fontFamily: theme.value.body,
}))

const eventTitle = computed(() => info.value?.hero_title || info.value?.event_name || 'Fotos de la fiesta')

// --- Datos ------------------------------------------------------------------------
async function loadInfo() {
  // Si alguna falla, la página sigue con el estilo Clásica y sin avatar.
  const [a, b] = await Promise.all([
    supabase.rpc('info_fotos_evento', { p_event_id: eventId }),
    supabase.rpc('vista_previa_fotos', { p_event_id: eventId }),
  ])
  if (!a.error && a.data) info.value = a.data
  if (!b.error && b.data?.image) cover.value = b.data.image
}

async function fetchPhotos() {
  const { data, error } = await supabase.rpc('listar_fotos_invitados', { p_event_id: eventId })
  return error ? null : (data ?? [])
}

// "Más votadas" se ordena al cargar y no cada vez que alguien da like: así las
// fotos no saltan de lugar mientras mirás (Instagram hace lo mismo).
const rankOrder = ref([])
function rerank() {
  rankOrder.value = [...photos.value]
    .sort((a, b) => b.likes_count - a.likes_count || (a.created_at < b.created_at ? 1 : -1))
    .map((p) => p.id)
}

async function loadPhotos() {
  const data = await fetchPhotos()
  if (data) {
    photos.value = data
    rerank()
  }
}

onMounted(async () => {
  await Promise.all([loadInfo(), loadPhotos()])
  loading.value = false
})

// --- Fotos nuevas de otros ------------------------------------------------------------
// Cada 20 s miramos si hay fotos nuevas. Los likes se actualizan solos; las
// fotos nuevas esperan en un botón «N fotos nuevas» para no mover la grilla.
const pending = ref([])
let pollTimer = null
onMounted(() => {
  pollTimer = setInterval(async () => {
    if (document.visibilityState !== 'visible' || uploading.value) return
    const data = await fetchPhotos()
    if (!data) return
    const known = new Map(photos.value.map((p) => [p.id, p]))
    const fresh = []
    for (const p of data) {
      const mine = known.get(p.id)
      if (mine) {
        // No pisamos el conteo de algo que este navegador acaba de tocar.
        if (!touched.has(p.id)) mine.likes_count = p.likes_count
      } else fresh.push(p)
    }
    pending.value = fresh
  }, 20000)
})
onUnmounted(() => clearInterval(pollTimer))

function showPending() {
  photos.value = [...pending.value, ...photos.value]
  pending.value = []
  rerank()
  tab.value = 'recent'
  window.scrollTo({ top: document.getElementById('tabs')?.offsetTop - 8 || 0, behavior: 'smooth' })
}

// --- Pestañas ---------------------------------------------------------------------------
const TABS = [
  { id: 'top', label: 'Más votadas', icon: Flame },
  { id: 'recent', label: 'Recientes', icon: Clock },
  { id: 'mine', label: 'Mis fotos', icon: UserRound },
]
const tab = ref('top')

const byId = computed(() => new Map(photos.value.map((p) => [p.id, p])))
const visible = computed(() => {
  if (tab.value === 'top') return rankOrder.value.map((id) => byId.value.get(id)).filter(Boolean)
  const recent = [...photos.value].sort((a, b) => (a.created_at < b.created_at ? 1 : -1))
  return tab.value === 'mine' ? recent.filter((p) => mineUrls.value.has(p.url)) : recent
})

const stats = computed(() => ({
  photos: photos.value.length,
  likes: photos.value.reduce((s, p) => s + (p.likes_count || 0), 0),
  people: new Set(photos.value.map((p) => p.uploader_name?.trim().toLowerCase()).filter(Boolean)).size,
}))

const MEDALS = ['🥇', '🥈', '🥉']

// --- Guardado en este navegador (sin login) --------------------------------------------
function readSet(key) {
  try {
    return new Set(JSON.parse(localStorage.getItem(key) || '[]'))
  } catch {
    return new Set()
  }
}
function writeSet(key, set) {
  try {
    localStorage.setItem(key, JSON.stringify([...set]))
  } catch {
    /* modo privado */
  }
}

// Likes: uno por foto por navegador (no hay forma real de impedir dos likes
// desde dos dispositivos sin login — no vale la pena más que esto).
const LIKED_KEY = 'liked-photo-ids'
const likedIds = ref(readSet(LIKED_KEY))
const touched = new Set() // fotos que likeaste en esta visita (ver el refresco)

// Fotos subidas desde este navegador (por URL: es única y la tenemos al subir).
const MINE_KEY = `my-photos-${eventId}`
const mineUrls = ref(readSet(MINE_KEY))

async function like(photo) {
  if (likedIds.value.has(photo.id)) return
  const next = new Set(likedIds.value).add(photo.id)
  likedIds.value = next
  writeSet(LIKED_KEY, next)
  touched.add(photo.id)
  photo.likes_count = (photo.likes_count || 0) + 1
  try {
    await supabase.rpc('dar_like_foto', { p_photo_id: photo.id })
  } catch {
    /* no vale la pena revertir el like si falla la red */
  }
}

async function unlike(photo) {
  if (!likedIds.value.has(photo.id)) return
  const next = new Set(likedIds.value)
  next.delete(photo.id)
  likedIds.value = next
  writeSet(LIKED_KEY, next)
  touched.add(photo.id)
  photo.likes_count = Math.max((photo.likes_count || 1) - 1, 0)
  try {
    await supabase.rpc('quitar_like_foto', { p_photo_id: photo.id })
  } catch {
    /* ídem */
  }
}

// --- Nombre de quien sube -----------------------------------------------------------------
// Se pide una sola vez (hoja de abajo) y se recuerda. Se puede saltear.
const NAME_KEY = 'guest-photo-name'
const ASKED_KEY = 'guest-photo-name-asked'
const uploaderName = ref('')
const nameAsked = ref(false)
try {
  uploaderName.value = localStorage.getItem(NAME_KEY) || ''
  // Quien ya había escrito su nombre en la versión anterior no lo vuelve a ver.
  nameAsked.value = localStorage.getItem(ASKED_KEY) === '1' || !!uploaderName.value
} catch {
  /* modo privado */
}
const nameSheet = ref(false)
const nameDraft = ref('')

function saveName(name) {
  uploaderName.value = name.trim()
  nameAsked.value = true
  try {
    localStorage.setItem(NAME_KEY, uploaderName.value)
    localStorage.setItem(ASKED_KEY, '1')
  } catch {
    /* modo privado */
  }
}

function openNameSheet() {
  nameDraft.value = uploaderName.value
  nameSheet.value = true
}

// Desde la hoja: guardar y (si venía del botón de subir) abrir la cámara/galería.
// Tiene que ser dentro del mismo toque para que el navegador deje abrir el selector.
const pickAfterName = ref(false)
function confirmName(skip = false) {
  saveName(skip ? '' : nameDraft.value)
  nameSheet.value = false
  if (pickAfterName.value) {
    pickAfterName.value = false
    fileInput.value?.click()
  }
}

function closeNameSheet() {
  nameSheet.value = false
  pickAfterName.value = false
}

// --- Subir --------------------------------------------------------------------------------
const fileInput = ref(null)
const uploads = ref([]) // { key, file, preview, status: 'waiting'|'uploading'|'done'|'error', error }
const uploading = computed(() => uploads.value.some((u) => u.status === 'waiting' || u.status === 'uploading'))
const full = ref(false)
const toast = ref(null) // { text, action? }
let toastTimer = null

function showToast(text, action = null, ms = 5000) {
  toast.value = { text, action }
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => (toast.value = null), ms)
}

function onUploadButton() {
  if (uploading.value || full.value) return
  if (!nameAsked.value) {
    pickAfterName.value = true
    openNameSheet()
    return
  }
  fileInput.value?.click()
}

async function onFilesPicked(e) {
  const files = Array.from(e.target.files || [])
  e.target.value = ''
  if (!files.length) return

  // Limpia la bandeja anterior y arma la nueva con las miniaturas.
  for (const u of uploads.value) URL.revokeObjectURL(u.preview)
  toast.value = null
  uploads.value = files.map((file) => ({ key: crypto.randomUUID(), file, preview: URL.createObjectURL(file), status: 'waiting', error: '' }))

  let ok = 0
  for (const item of uploads.value) {
    item.status = 'uploading'
    try {
      const blob = await compressImage(item.file)
      const path = `${eventId}/${crypto.randomUUID()}.jpg`
      const { error: upErr } = await supabase.storage
        .from('guest-uploads')
        .upload(path, blob, { contentType: 'image/jpeg', cacheControl: '3600' })
      if (upErr) throw upErr

      const { data: pub } = supabase.storage.from('guest-uploads').getPublicUrl(path)
      const { error: rpcErr } = await supabase.rpc('agregar_foto_invitados', {
        p_event_id: eventId,
        p_url: pub.publicUrl,
        p_path: path,
        p_uploader_name: uploaderName.value,
      })
      if (rpcErr) {
        if (rpcErr.message?.includes('máximo')) full.value = true
        throw rpcErr
      }
      const mine = new Set(mineUrls.value).add(pub.publicUrl)
      mineUrls.value = mine
      writeSet(MINE_KEY, mine)
      item.status = 'done'
      ok++
    } catch (err) {
      item.status = 'error'
      item.error = full.value ? 'La galería llegó al máximo de fotos.' : 'Una foto no se pudo subir. Probá de nuevo.'
      if (full.value) break
    }
  }
  // Si cortamos por el tope, las que quedaron esperando no se suben.
  for (const u of uploads.value) if (u.status === 'waiting') u.status = 'error'

  // Traemos la lista real (con los ids de verdad, para poder dar like).
  await loadPhotos()
  pending.value = []

  const failed = uploads.value.filter((u) => u.status === 'error').length
  if (ok > 0) {
    tab.value = 'mine'
    setTimeout(() => {
      clearTray()
      showToast(
        ok === 1 ? '¡Listo! Tu foto ya está en la galería 🎉' : `¡Listo! Tus ${ok} fotos ya están en la galería 🎉`,
        { label: 'Ver', run: () => openFeed(0) },
        6000,
      )
    }, failed ? 4000 : 1200)
  }
}

function clearTray() {
  if (uploading.value) return
  for (const u of uploads.value) URL.revokeObjectURL(u.preview)
  uploads.value = []
}

const doneCount = computed(() => uploads.value.filter((u) => u.status === 'done').length)
const trayError = computed(() => uploads.value.find((u) => u.status === 'error')?.error ?? '')

// --- Feed ------------------------------------------------------------------------------------
const feedIndex = ref(-1)
const feedPhotos = ref([])
function openFeed(i) {
  feedPhotos.value = visible.value // foto fija: si llega algo nuevo no se mueve el feed
  feedIndex.value = i
}
const feedTitle = computed(() => TABS.find((t) => t.id === tab.value)?.label ?? '')

// Al cambiar de pestaña, si estabas muy abajo, volvés al principio de la grilla.
watch(tab, () => {
  const top = (document.getElementById('tabs')?.offsetTop ?? 0) - 8
  if (window.scrollY > top) window.scrollTo({ top })
})
</script>

<template>
  <div class="guest-page min-h-screen pb-32" :style="pageStyle">
    <!-- ============ PERFIL DEL EVENTO ============ -->
    <header class="mx-auto max-w-xl px-5 pt-10 pb-5">
      <div class="flex items-center gap-5">
        <div class="ring-avatar shrink-0 rounded-full p-[3px]">
          <div class="avatar-img overflow-hidden rounded-full border-[3px]">
            <img v-if="cover" :src="cover" alt="" class="h-full w-full object-cover" />
            <div v-else class="grid h-full w-full place-items-center" style="color: var(--accent-text)"><Camera :size="30" /></div>
          </div>
        </div>
        <div class="grid flex-1 grid-cols-3 text-center">
          <div>
            <p class="text-lg font-bold">{{ stats.photos }}</p>
            <p class="text-xs" style="color: var(--muted)">{{ stats.photos === 1 ? 'foto' : 'fotos' }}</p>
          </div>
          <div>
            <p class="text-lg font-bold">{{ stats.likes }}</p>
            <p class="text-xs" style="color: var(--muted)">me gusta</p>
          </div>
          <div>
            <p class="text-lg font-bold">{{ stats.people }}</p>
            <p class="text-xs" style="color: var(--muted)">{{ stats.people === 1 ? 'persona' : 'personas' }}</p>
          </div>
        </div>
      </div>

      <h1
        class="mt-4 leading-none"
        :style="{ fontFamily: theme.display, fontWeight: theme.displayWeight, fontSize: theme.displaySize, color: 'var(--accent-text)' }"
      >
        {{ eventTitle }}
      </h1>
      <p class="mt-2 text-sm" style="color: var(--muted)">
        Compartí las fotos que saques en la fiesta. Tocá dos veces una foto para darle me gusta ❤️
      </p>
      <button
        v-if="nameAsked"
        type="button"
        @click="openNameSheet"
        class="mt-3 inline-flex items-center gap-1.5 text-xs font-semibold"
        style="color: var(--muted)"
      >
        {{ uploaderName ? `Subís como ${uploaderName}` : 'Subís sin nombre' }}
        <Pencil :size="12" />
      </button>
    </header>

    <!-- ============ PESTAÑAS ============ -->
    <nav id="tabs" class="tabs sticky top-0 z-20 mx-auto flex max-w-xl">
      <button
        v-for="t in TABS"
        :key="t.id"
        type="button"
        @click="tab = t.id"
        :aria-pressed="tab === t.id"
        class="tab flex flex-1 items-center justify-center gap-1.5 py-3 text-xs font-semibold"
        :class="{ active: tab === t.id }"
      >
        <component :is="t.icon" :size="16" />
        {{ t.label }}
      </button>
    </nav>

    <!-- ============ GRILLA ============ -->
    <main class="mx-auto max-w-xl">
      <div v-if="loading" class="grid grid-cols-3 gap-0.5">
        <div v-for="n in 9" :key="n" class="skeleton aspect-square"></div>
      </div>

      <div v-else-if="!visible.length" class="px-8 py-16 text-center">
        <div class="mx-auto grid h-16 w-16 place-items-center rounded-full" style="background: var(--tint); color: var(--accent-text)">
          <ImagePlus :size="28" />
        </div>
        <p class="mt-4 font-semibold">
          {{ tab === 'mine' ? 'Todavía no subiste fotos' : 'Todavía no hay fotos' }}
        </p>
        <p class="mt-1 text-sm" style="color: var(--muted)">
          {{ tab === 'mine' ? 'Las que subas desde este celular van a aparecer acá.' : '¡Subí la primera y arrancá la galería!' }}
        </p>
      </div>

      <div v-else class="grid grid-cols-3 gap-0.5">
        <button
          v-for="(photo, i) in visible"
          :key="photo.id"
          type="button"
          @click="openFeed(i)"
          class="tile relative aspect-square overflow-hidden"
        >
          <img
            :src="photo.url"
            alt=""
            loading="lazy"
            decoding="async"
            class="h-full w-full object-cover opacity-0 transition-opacity duration-300"
            @load="$event.target.classList.remove('opacity-0')"
          />
          <span v-if="tab === 'top' && i < 3 && photo.likes_count > 0" class="medal absolute top-1 left-1 text-lg leading-none">
            {{ MEDALS[i] }}
          </span>
          <span
            v-if="mineUrls.has(photo.url) && tab !== 'mine'"
            class="mine-chip absolute top-1.5 right-1.5 rounded-full px-1.5 py-0.5 text-[10px] font-bold"
          >
            Tuya
          </span>
          <span
            v-if="photo.likes_count"
            class="absolute bottom-1 left-1.5 flex items-center gap-1 text-xs font-bold text-white"
            style="text-shadow: 0 1px 4px rgb(0 0 0 / 0.6)"
          >
            <Heart :size="13" fill="currentColor" :class="{ 'liked-small': likedIds.has(photo.id) }" />
            {{ photo.likes_count }}
          </span>
        </button>
      </div>
    </main>

    <!-- «N fotos nuevas» -->
    <transition name="drop">
      <button
        v-if="pending.length && feedIndex < 0"
        type="button"
        @click="showPending"
        class="pill fixed top-4 left-1/2 z-30 flex -translate-x-1/2 items-center gap-1.5 rounded-full px-4 py-2 text-sm font-semibold shadow-lg"
      >
        <ArrowUp :size="15" />
        {{ pending.length === 1 ? '1 foto nueva' : `${pending.length} fotos nuevas` }}
      </button>
    </transition>

    <!-- ============ BANDEJA DE SUBIDA ============ -->
    <transition name="rise">
      <div v-if="uploads.length" class="tray fixed inset-x-3 bottom-24 z-30 mx-auto max-w-md rounded-3xl p-3 shadow-xl">
        <div class="flex items-center justify-between px-1 pb-2 text-sm font-semibold">
          <span v-if="uploading">Subiendo {{ Math.min(doneCount + 1, uploads.length) }} de {{ uploads.length }}…</span>
          <span v-else-if="doneCount === uploads.length" class="flex items-center gap-1.5">
            <Check :size="16" style="color: #16a34a" /> ¡{{ uploads.length === 1 ? 'Subida' : 'Todas subidas' }}!
          </span>
          <span v-else>Se subieron {{ doneCount }} de {{ uploads.length }}</span>
          <button v-if="!uploading" type="button" @click="clearTray" aria-label="Cerrar" class="grid h-7 w-7 place-items-center rounded-full" style="background: var(--tint)">
            <X :size="14" />
          </button>
        </div>
        <div class="flex gap-2 overflow-x-auto pb-1">
          <div v-for="u in uploads" :key="u.key" class="relative h-16 w-16 shrink-0 overflow-hidden rounded-2xl" style="background: var(--tint)">
            <img :src="u.preview" alt="" class="h-full w-full object-cover" :class="{ 'opacity-50': u.status !== 'done' }" />
            <div class="absolute inset-0 grid place-items-center">
              <span v-if="u.status === 'uploading'" class="spinner"></span>
              <span v-else-if="u.status === 'done'" class="pop-in grid h-7 w-7 place-items-center rounded-full bg-white/95" style="color: #16a34a">
                <Check :size="17" :stroke-width="3" />
              </span>
              <span v-else-if="u.status === 'error'" class="grid h-7 w-7 place-items-center rounded-full bg-white/95" style="color: #dc2626">
                <AlertCircle :size="17" />
              </span>
            </div>
          </div>
        </div>
        <p v-if="trayError" class="px-1 pt-1 text-xs" style="color: #dc2626">{{ trayError }}</p>
      </div>
    </transition>

    <!-- Aviso -->
    <transition name="rise">
      <div
        v-if="toast && !uploads.length"
        role="status"
        class="toast fixed inset-x-3 bottom-24 z-30 mx-auto flex max-w-md items-center gap-3 rounded-full py-2 pr-2 pl-5 text-sm font-semibold shadow-xl"
      >
        <span class="flex-1">{{ toast.text }}</span>
        <button
          v-if="toast.action"
          type="button"
          @click="(toast.action.run(), (toast = null))"
          class="rounded-full px-4 py-1.5 font-bold"
          style="background: var(--accent); color: var(--accent-on)"
        >
          {{ toast.action.label }}
        </button>
      </div>
    </transition>

    <!-- ============ BOTÓN SUBIR ============ -->
    <div class="fab-wrap pointer-events-none fixed inset-x-0 bottom-0 z-30 flex justify-center px-5 pt-8">
      <button
        type="button"
        @click="onUploadButton"
        :disabled="uploading || full"
        class="fab pointer-events-auto flex items-center gap-2 rounded-full px-7 py-4 text-base font-bold shadow-xl transition active:scale-95 disabled:opacity-60"
      >
        <Camera :size="21" />
        {{ full ? 'Galería completa' : uploading ? 'Subiendo…' : 'Subir fotos' }}
      </button>
    </div>
    <input ref="fileInput" type="file" accept="image/*" multiple class="hidden" @change="onFilesPicked" />

    <!-- ============ HOJA: TU NOMBRE ============ -->
    <transition name="fade">
      <div v-if="nameSheet" class="fixed inset-0 z-40 bg-black/40" @click="closeNameSheet"></div>
    </transition>
    <transition name="sheet">
      <form v-if="nameSheet" @submit.prevent="confirmName(false)" class="sheet fixed inset-x-0 bottom-0 z-50 mx-auto max-w-xl rounded-t-3xl px-6 pt-3 shadow-2xl">
        <div class="mx-auto h-1.5 w-10 rounded-full" style="background: var(--line)"></div>
        <h2 class="mt-5 text-lg font-bold">¿Cómo te llamás?</h2>
        <p class="mt-1 text-sm" style="color: var(--muted)">Así todos saben quién compartió cada foto.</p>
        <input
          v-model="nameDraft"
          type="text"
          autocomplete="given-name"
          placeholder="Tu nombre"
          maxlength="40"
          class="field mt-4 w-full rounded-full px-5 py-3.5 text-base"
        />
        <button type="submit" class="fab mt-4 w-full rounded-full py-3.5 text-base font-bold">
          {{ pickAfterName ? 'Elegir fotos' : 'Guardar' }}
        </button>
        <button type="button" @click="confirmName(true)" class="mt-2 w-full py-2 text-sm font-semibold" style="color: var(--muted)">
          Prefiero no poner mi nombre
        </button>
      </form>
    </transition>

    <!-- ============ FEED ============ -->
    <PhotoFeed
      v-if="feedIndex >= 0"
      :photos="feedPhotos"
      :start-index="feedIndex"
      :title="feedTitle"
      :liked-ids="likedIds"
      :mine-urls="mineUrls"
      :show-rank="tab === 'top'"
      @close="feedIndex = -1"
      @like="like"
      @unlike="unlike"
    />
  </div>
</template>

<style scoped>
.ring-avatar {
  background: conic-gradient(from 200deg, var(--accent), var(--heart), #ffb347, var(--accent));
}
.avatar-img {
  width: 5.5rem;
  height: 5.5rem;
  border-color: var(--page-bg);
  background: var(--tint);
}

.tabs {
  background: var(--page-bg);
  border-top: 1px solid var(--line);
}
.tab {
  color: var(--muted);
  border-top: 1.5px solid transparent;
  margin-top: -1px;
  transition: color 150ms ease;
}
.tab.active {
  color: var(--ink);
  border-top-color: var(--ink);
}

.tile {
  background: var(--tint);
  -webkit-tap-highlight-color: transparent;
}
.tile:active img {
  filter: brightness(0.85);
}
.medal {
  filter: drop-shadow(0 1px 3px rgb(0 0 0 / 0.4));
}
.mine-chip {
  background: var(--accent);
  color: var(--accent-on);
}
.liked-small {
  color: var(--heart);
}
.skeleton {
  background: var(--tint);
  animation: pulse 1.4s ease-in-out infinite;
}
@keyframes pulse {
  50% {
    opacity: 0.55;
  }
}

.pill,
.fab {
  background: var(--accent);
  color: var(--accent-on);
}
.fab-wrap {
  background: linear-gradient(to top, var(--page-bg) 35%, transparent);
  padding-bottom: max(1.25rem, env(safe-area-inset-bottom));
}
.tray,
.toast {
  background: var(--field);
  color: var(--ink);
  border: 1px solid var(--line);
}
.sheet {
  background: var(--page-bg);
  color: var(--ink);
  padding-bottom: max(2rem, env(safe-area-inset-bottom));
}
.field {
  background: var(--field);
  color: var(--ink);
  border: 1.5px solid var(--line);
  outline: none;
}
.field:focus {
  border-color: var(--accent);
}

.spinner {
  width: 1.6rem;
  height: 1.6rem;
  border-radius: 999px;
  border: 3px solid rgb(255 255 255 / 0.5);
  border-top-color: #fff;
  animation: spin 0.8s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
.pop-in {
  animation: pop-in 0.35s cubic-bezier(0.17, 0.89, 0.32, 1.4);
}
@keyframes pop-in {
  from {
    transform: scale(0);
  }
}

.rise-enter-active,
.rise-leave-active,
.drop-enter-active,
.drop-leave-active,
.fade-enter-active,
.fade-leave-active,
.sheet-enter-active,
.sheet-leave-active {
  transition:
    transform 0.3s cubic-bezier(0.32, 0.72, 0, 1),
    opacity 0.25s ease;
}
.rise-enter-from,
.rise-leave-to {
  transform: translateY(1rem);
  opacity: 0;
}
.drop-enter-from,
.drop-leave-to {
  /* El centrado es la propiedad `translate` de Tailwind: acá solo el desplazamiento. */
  transform: translateY(-1rem);
  opacity: 0;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
.sheet-enter-from,
.sheet-leave-to {
  transform: translateY(100%);
}
</style>
