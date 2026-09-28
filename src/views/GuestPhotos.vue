<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { compressImage } from '../lib/compressImage'
import { lighten, contrastText, isDark } from '../lib/color'
import { Camera, Heart, Download, X, ChevronLeft, ChevronRight } from '@lucide/vue'

// Página pública sin login: la abre quien escanea el QR de las mesas.
// Toma el estilo de la invitación (plantilla, color, nombre).
const route = useRoute()
const eventId = route.params.eventId

const info = ref(null) // info_fotos_evento(): nombre, plantilla y colores
const photos = ref([])
const loading = ref(true)
const uploading = ref(false)
const uploadedCount = ref(0)
const totalToUpload = ref(0)
const error = ref('')
const full = ref(false)
const fileInput = ref(null)

// --- Estilo según la plantilla de la invitación ---------------------------------
// Las fuentes ya las carga index.html (son las mismas de las invitaciones).
const THEMES = {
  clasico: {
    display: "'Dancing Script', cursive",
    displayWeight: 700,
    displaySize: '3.1rem',
    kicker: "'Playfair Display', serif",
    body: "'Playfair Display', serif",
    radius: '1rem',
  },
  partiful: {
    display: "'Space Grotesk', ui-sans-serif, sans-serif",
    displayWeight: 700,
    displaySize: '2.6rem',
    kicker: "'Inter', ui-sans-serif, sans-serif",
    body: "'Inter', ui-sans-serif, sans-serif",
    radius: '1.25rem',
    bg: '#ffffff',
  },
  craft: {
    display: "'DM Serif Text', ui-serif, Georgia, serif",
    displayWeight: 400,
    displaySize: '2.8rem',
    kicker: "'Bodoni Moda', ui-serif, Georgia, serif",
    body: "'Inter', ui-sans-serif, sans-serif",
    radius: '0.5rem',
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
    accent,
    accentOn: contrastText(accent),
    // Sobre fondo oscuro el color principal puede no leerse: lo aclaramos.
    accentText: dark ? lighten(accent, 0.45) : accent,
    tint: dark ? 'rgba(255,255,255,0.08)' : lighten(accent, 0.88),
    bg,
    ink: dark ? '#f5f3f0' : '#3a3431',
    muted: dark ? 'rgba(245,243,240,0.6)' : 'rgba(58,52,49,0.6)',
    field: dark ? 'rgba(255,255,255,0.08)' : '#ffffff',
  }
})

const pageStyle = computed(() => ({
  '--accent': theme.value.accent,
  '--accent-on': theme.value.accentOn,
  '--accent-text': theme.value.accentText,
  '--tint': theme.value.tint,
  '--ink': theme.value.ink,
  '--muted': theme.value.muted,
  '--field': theme.value.field,
  '--radius': theme.value.radius,
  background: theme.value.bg,
  color: theme.value.ink,
  fontFamily: theme.value.body,
}))

// Corazón "likeado" sobre las fotos (fondo oscuro): el color principal, aclarado.
const lightenForPhoto = computed(() => lighten(theme.value.accent, 0.35))

const eventTitle = computed(() => info.value?.hero_title || info.value?.event_name || '')

// Si la función no está en la base o falla, la página usa el estilo Clásica.
async function loadInfo() {
  const { data, error: err } = await supabase.rpc('info_fotos_evento', { p_event_id: eventId })
  if (!err && data) info.value = data
}

// Nombre de quien sube: se recuerda en este navegador para no re-tipearlo.
const NAME_KEY = 'guest-photo-name'
const uploaderName = ref('')
try {
  uploaderName.value = localStorage.getItem(NAME_KEY) || ''
} catch {
  /* modo privado */
}
watch(uploaderName, (v) => {
  try {
    localStorage.setItem(NAME_KEY, v)
  } catch {
    /* modo privado */
  }
})

// Un like por foto por navegador (no hay login, así que no hay forma real de
// impedir dos likes desde dos dispositivos — no vale la pena más que esto).
const LIKED_KEY = 'liked-photo-ids'
function readLiked() {
  try {
    return new Set(JSON.parse(localStorage.getItem(LIKED_KEY) || '[]'))
  } catch {
    return new Set()
  }
}
const likedIds = ref(readLiked())
function persistLiked() {
  try {
    localStorage.setItem(LIKED_KEY, JSON.stringify([...likedIds.value]))
  } catch {
    /* modo privado */
  }
}

function sortPhotos(list) {
  return [...list].sort((a, b) => {
    if (b.likes_count !== a.likes_count) return b.likes_count - a.likes_count
    return new Date(b.created_at) - new Date(a.created_at)
  })
}

async function loadPhotos() {
  const { data, error: err } = await supabase.rpc('listar_fotos_invitados', {
    p_event_id: eventId,
  })
  if (!err) photos.value = data ?? []
}

onMounted(async () => {
  await Promise.all([loadInfo(), loadPhotos()])
  loading.value = false
})

function pick() {
  fileInput.value?.click()
}

async function onFilesPicked(e) {
  const files = Array.from(e.target.files || [])
  e.target.value = ''
  if (!files.length) return

  error.value = ''
  uploading.value = true
  totalToUpload.value = files.length
  uploadedCount.value = 0

  for (const file of files) {
    try {
      const blob = await compressImage(file)
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

      photos.value = sortPhotos([
        ...photos.value,
        {
          id: crypto.randomUUID(),
          url: pub.publicUrl,
          uploader_name: uploaderName.value || null,
          likes_count: 0,
          created_at: new Date().toISOString(),
        },
      ])
    } catch (err) {
      error.value = err.message || 'No se pudo subir una de las fotos.'
    } finally {
      uploadedCount.value++
    }
  }

  uploading.value = false
}

async function like(photo) {
  if (likedIds.value.has(photo.id)) return
  likedIds.value.add(photo.id)
  persistLiked()
  photo.likes_count = (photo.likes_count || 0) + 1
  try {
    await supabase.rpc('dar_like_foto', { p_photo_id: photo.id })
  } catch {
    /* no vale la pena revertir el like si falla la red */
  }
}

async function downloadPhoto(photo) {
  try {
    const res = await fetch(photo.url)
    const blob = await res.blob()
    const blobUrl = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = blobUrl
    a.download = `foto-${photo.id}.jpg`
    document.body.appendChild(a)
    a.click()
    a.remove()
    URL.revokeObjectURL(blobUrl)
  } catch {
    window.open(photo.url, '_blank', 'noopener')
  }
}

// --- Lightbox (ver a pantalla completa, deslizar entre fotos) -----------
const lightboxIndex = ref(-1)
const lightboxOpen = computed(() => lightboxIndex.value >= 0)
const currentPhoto = computed(() => (lightboxOpen.value ? photos.value[lightboxIndex.value] : null))

function openLightbox(i) {
  lightboxIndex.value = i
}
function closeLightbox() {
  lightboxIndex.value = -1
}
function nextPhoto() {
  if (lightboxIndex.value < photos.value.length - 1) lightboxIndex.value++
}
function prevPhoto() {
  if (lightboxIndex.value > 0) lightboxIndex.value--
}

let touchX = 0
function onTouchStart(e) {
  touchX = e.changedTouches[0].clientX
}
function onTouchEnd(e) {
  const dx = e.changedTouches[0].clientX - touchX
  if (dx > 50) prevPhoto()
  else if (dx < -50) nextPhoto()
}

function onKeydown(e) {
  if (!lightboxOpen.value) return
  if (e.key === 'ArrowRight') nextPhoto()
  else if (e.key === 'ArrowLeft') prevPhoto()
  else if (e.key === 'Escape') closeLightbox()
}

watch(lightboxOpen, (open) => {
  if (typeof document !== 'undefined') document.body.style.overflow = open ? 'hidden' : ''
})

onMounted(() => window.addEventListener('keydown', onKeydown))
onUnmounted(() => {
  window.removeEventListener('keydown', onKeydown)
  if (typeof document !== 'undefined') document.body.style.overflow = ''
})
</script>

<template>
  <div class="min-h-screen pb-24" :style="pageStyle">
    <!-- Mientras carga no mostramos el encabezado para no "saltar" de estilo. -->
    <template v-if="!loading">
      <header class="px-6 pt-14 pb-8 text-center">
        <p
          v-if="eventTitle"
          class="text-xs tracking-[0.35em] uppercase"
          :style="{ fontFamily: theme.kicker, color: 'var(--accent-text)' }"
        >
          {{ eventTitle }}
        </p>
        <h1
          class="mt-2 leading-tight"
          :style="{ fontFamily: theme.display, fontWeight: theme.displayWeight, fontSize: theme.displaySize, color: 'var(--accent-text)' }"
        >
          Compartí tus fotos
        </h1>
        <p class="mx-auto mt-3 max-w-sm text-sm" style="color: var(--muted)">
          Subí las fotos que saques durante el evento y quedan acá para que las vean todos.
        </p>
      </header>

      <div class="px-6">
        <input
          v-model="uploaderName"
          type="text"
          placeholder="Tu nombre, para firmar tus fotos"
          class="guest-field mx-auto mb-3 block w-full max-w-sm px-4 py-3 text-center text-sm"
        />
        <button
          type="button"
          @click="pick"
          :disabled="uploading || full"
          class="guest-btn mx-auto flex w-full max-w-sm items-center justify-center gap-2 px-6 py-4 font-semibold shadow-lg transition disabled:opacity-50"
        >
          <Camera :size="20" />
          {{ uploading ? `Subiendo ${uploadedCount}/${totalToUpload}…` : 'Subir fotos' }}
        </button>
        <input ref="fileInput" type="file" accept="image/*" multiple class="hidden" @change="onFilesPicked" />

        <p v-if="full" class="mt-3 text-center text-sm" style="color: var(--muted)">
          La galería llegó al máximo de fotos. ¡Gracias por compartir tantos momentos!
        </p>
        <p v-if="error" class="mt-3 text-center text-sm text-red-600">{{ error }}</p>
      </div>
    </template>

    <div class="mt-10 px-4">
      <p v-if="loading" class="pt-24 text-center text-sm opacity-50">Cargando…</p>
      <p v-else-if="!photos.length" class="text-center text-sm" style="color: var(--muted)">
        Todavía no hay fotos. ¡Subí la primera!
      </p>
      <div v-else class="columns-2 gap-2 sm:columns-3">
        <div
          v-for="(photo, i) in photos"
          :key="photo.id"
          class="relative mb-2 overflow-hidden shadow"
          style="break-inside: avoid; border-radius: var(--radius)"
        >
          <img
            :src="photo.url"
            alt=""
            loading="lazy"
            decoding="async"
            class="block w-full cursor-pointer object-cover"
            @click="openLightbox(i)"
          />
          <div
            class="absolute inset-x-0 bottom-0 flex items-center justify-between gap-2 bg-linear-to-t from-black/65 to-transparent px-2 py-1.5"
          >
            <span class="truncate text-[11px] text-white/90">
              {{ photo.uploader_name || 'Anónimo' }}
            </span>
            <button
              type="button"
              @click.stop="like(photo)"
              class="flex shrink-0 items-center gap-1 text-xs text-white"
              aria-label="Me gusta"
            >
              <Heart
                :size="14"
                :fill="likedIds.has(photo.id) ? 'currentColor' : 'none'"
                :style="likedIds.has(photo.id) ? { color: lightenForPhoto } : null"
              />
              {{ photo.likes_count || 0 }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Lightbox: pantalla completa, deslizar entre fotos -->
    <transition
      enter-active-class="transition-opacity duration-200"
      leave-active-class="transition-opacity duration-200"
      enter-from-class="opacity-0"
      leave-to-class="opacity-0"
    >
      <div
        v-if="lightboxOpen"
        class="fixed inset-0 z-50 flex flex-col bg-black/95"
        @touchstart.passive="onTouchStart"
        @touchend.passive="onTouchEnd"
      >
        <div class="flex items-center justify-between px-4 py-3 text-white">
          <span class="truncate text-sm">{{ currentPhoto.uploader_name || 'Anónimo' }}</span>
          <button type="button" @click="closeLightbox" aria-label="Cerrar" class="shrink-0">
            <X :size="24" />
          </button>
        </div>

        <div class="relative flex flex-1 items-center justify-center overflow-hidden px-1">
          <button
            v-if="lightboxIndex > 0"
            type="button"
            @click="prevPhoto"
            aria-label="Foto anterior"
            class="absolute left-1 z-10 grid h-10 w-10 place-items-center rounded-full bg-white/10 text-white backdrop-blur-sm sm:left-4"
          >
            <ChevronLeft :size="24" />
          </button>

          <img :src="currentPhoto.url" alt="" class="max-h-full max-w-full object-contain" />

          <button
            v-if="lightboxIndex < photos.length - 1"
            type="button"
            @click="nextPhoto"
            aria-label="Foto siguiente"
            class="absolute right-1 z-10 grid h-10 w-10 place-items-center rounded-full bg-white/10 text-white backdrop-blur-sm sm:right-4"
          >
            <ChevronRight :size="24" />
          </button>
        </div>

        <div class="flex items-center justify-center gap-4 px-4 py-5">
          <button
            type="button"
            @click="like(currentPhoto)"
            class="flex items-center gap-2 rounded-full bg-white/10 px-4 py-2.5 text-sm text-white"
          >
            <Heart
              :size="18"
              :fill="likedIds.has(currentPhoto.id) ? 'currentColor' : 'none'"
              :style="likedIds.has(currentPhoto.id) ? { color: lightenForPhoto } : null"
            />
            {{ currentPhoto.likes_count || 0 }}
          </button>
          <button
            type="button"
            @click="downloadPhoto(currentPhoto)"
            class="flex items-center gap-2 rounded-full bg-white/10 px-4 py-2.5 text-sm text-white"
          >
            <Download :size="18" />
            Descargar
          </button>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.guest-field {
  border-radius: 999px;
  background: var(--field);
  color: var(--ink);
  border: 1.5px solid var(--tint);
  outline: none;
  transition: border-color 150ms ease;
}
.guest-field::placeholder {
  color: var(--muted);
}
.guest-field:focus {
  border-color: var(--accent);
}
.guest-btn {
  border-radius: 999px;
  background: var(--accent);
  color: var(--accent-on);
}
.guest-btn:hover:not(:disabled) {
  filter: brightness(1.08);
}
</style>
