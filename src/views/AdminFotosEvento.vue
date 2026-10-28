<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import QRCode from 'qrcode'
import {
  Link2,
  Check,
  Trash2,
  Download,
  Printer,
  ImageOff,
  FileImage,
  QrCode,
  ExternalLink,
  Heart,
  X,
  ChevronLeft,
  ChevronRight,
  SquareCheckBig,
  Archive,
  Images,
} from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import PlanGate from '../components/PlanGate.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'
import { confirmDialog } from '../composables/useConfirm'
import { timeAgo } from '../lib/timeAgo'

// Fotos que suben los invitados escaneando el QR de las mesas (/fotos/:id).
// Acá: el QR (verlo, bajarlo, imprimir carteles para las mesas) y la galería
// (ver, borrar, descargar una, varias o todas en un .zip).
const { event, loadEvent } = useEvent()
const photos = ref([])
const loading = ref(true)
const error = ref('')
const LIMIT = 500 // mismo tope que agregar_foto_invitados() en la base

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) await fetchPhotos()
  loading.value = false
})

async function fetchPhotos() {
  const { data, error: err } = await supabase
    .from('event_photos')
    .select('id, url, path, uploader_name, likes_count, created_at')
    .eq('event_id', event.value.id)
    .order('created_at', { ascending: false })
  if (!err) photos.value = data
}

// Durante la fiesta las fotos van llegando: refrescamos cada 30 s mientras
// la pestaña está visible (sin abrir la galería de nuevo).
const REFRESH_MS = 30000
let timer = null
onMounted(() => {
  timer = setInterval(() => {
    if (event.value && document.visibilityState === 'visible' && !busy.value) fetchPhotos()
  }, REFRESH_MS)
})
onUnmounted(() => clearInterval(timer))

// --- Link y QR -----------------------------------------------------------------
const guestUrl = computed(() => (event.value ? `${window.location.origin}/fotos/${event.value.id}` : ''))
const copied = ref(false)

async function copyLink() {
  await navigator.clipboard.writeText(guestUrl.value)
  copied.value = true
  setTimeout(() => (copied.value = false), 1500)
}

function slugify(text) {
  return (text || 'evento')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
}

function saveBlob(blob, fileName) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = fileName
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

async function downloadQr() {
  const dataUrl = await QRCode.toDataURL(guestUrl.value, { width: 1200, margin: 2 })
  const a = document.createElement('a')
  a.href = dataUrl
  a.download = `qr-fotos-${slugify(event.value.name)}.png`
  a.click()
}

// --- Cartel para las mesas ---------------------------------------------------------
// Se dibuja en un canvas (ver lib/photoCard.js): vista previa liviana acá, y
// en alta resolución recién al descargar.
const cardPhotoChoices = computed(() => {
  const e = event.value
  if (!e) return []
  return ['retrato', 'banner', 'momentos', 'galeria', 'detalle'].flatMap((slot) => (e[slot] ?? []).map((p) => p.url))
})
// Las que se muestran para elegir (y las que se reparten en «una distinta por mesa»).
const cardPhotoPool = computed(() => cardPhotoChoices.value.slice(0, 11))
// undefined = la primera disponible; null = sin foto; 'all' = una distinta por mesa
const cardPhoto = ref(undefined)
const photoPerTable = computed(() => cardPhoto.value === 'all' && numbered.value && cardPhotoPool.value.length > 1)
const cardPhotoUrl = computed(() =>
  cardPhoto.value === undefined || cardPhoto.value === 'all' ? cardPhotoPool.value[0] ?? null : cardPhoto.value,
)
// --- Una foto distinta por mesa ---
// De entrada se reparten en orden (si hay más mesas que fotos, vuelven a
// empezar). Lo que el usuario cambia queda en `tablePhotoPicks`, por mesa
// (por su nombre o número, así sobrevive si cambia el «hasta»).
const tablePhotoPicks = ref({})
const tablePhoto = (i) => {
  const pool = cardPhotoPool.value
  const pick = tablePhotoPicks.value[tableLabels.value[i]]
  return pool.includes(pick) ? pick : pool[i % pool.length]
}
const photoFor = (i) => (photoPerTable.value ? tablePhoto(i) : cardPhotoUrl.value)
const photoUses = (url) => tableLabels.value.filter((_, i) => tablePhoto(i) === url).length

function setTablePhoto(i, url) {
  tablePhotoPicks.value = { ...tablePhotoPicks.value, [tableLabels.value[i]]: url }
}
function swapTablePhotos(a, b) {
  const [pa, pb] = [tablePhoto(a), tablePhoto(b)]
  setTablePhoto(a, pb)
  setTablePhoto(b, pa)
}

// Arrastrar (compu) o tocar (celu): mesa sobre mesa intercambia las fotos; una
// foto de «tus fotos» sobre una mesa se la pone. Tocando: primero la mesa,
// después la otra mesa o la foto.
const selectedTable = ref(null)
const dragging = ref(null) // { table: i } | { photo: url }
const dropTarget = ref(null)

function onDragStart(e, source) {
  dragging.value = source
  e.dataTransfer.effectAllowed = 'move'
  e.dataTransfer.setData('text/plain', '') // Firefox no arrastra sin esto
}
function onDragEnd() {
  dragging.value = null
  dropTarget.value = null
}
function onDropOnTable(i) {
  const src = dragging.value
  if (src?.photo) setTablePhoto(i, src.photo)
  else if (src && src.table !== i) swapTablePhotos(src.table, i)
  selectedTable.value = i
  onDragEnd()
}
function onTableClick(i) {
  if (selectedTable.value === null || selectedTable.value === i) {
    selectedTable.value = selectedTable.value === i ? null : i
  } else {
    swapTablePhotos(selectedTable.value, i)
    selectedTable.value = null
  }
}
function onPoolPhotoClick(url) {
  if (selectedTable.value !== null) setTablePhoto(selectedTable.value, url)
}
watch(tableLabels, (labels) => {
  if (selectedTable.value !== null && selectedTable.value >= labels.length) selectedTable.value = null
})
// La vista previa muestra la mesa que estás tocando (o la primera).
const previewIndex = computed(() => (photoPerTable.value && selectedTable.value !== null ? selectedTable.value : 0))

// Tamaño del papel. Los de portarretrato son los más comunes en Argentina.
const CARD_SIZES = [
  { id: 'a5', label: 'A5', hint: '14,8 × 21 cm', w: 148, h: 210 },
  { id: '10x15', label: '10 × 15', hint: 'portarretrato', w: 100, h: 150 },
  { id: '13x18', label: '13 × 18', hint: 'portarretrato', w: 130, h: 180 },
  { id: '15x20', label: '15 × 20', hint: 'portarretrato', w: 150, h: 200 },
  { id: 'a4', label: 'A4', hint: 'hoja entera', w: 210, h: 297 },
  { id: 'custom', label: 'Otra medida', hint: 'en cm' },
]
const cardSize = ref('a5')
const customW = ref(10) // cm
const customH = ref(15)
const cmToMm = (cm, fallback) => Math.round(Math.min(Math.max(Number(cm) || fallback, 5), 60) * 10)
const cardDims = computed(() => {
  if (cardSize.value !== 'custom') return CARD_SIZES.find((s) => s.id === cardSize.value)
  return { w: cmToMm(customW.value, 10), h: cmToMm(customH.value, 15) }
})

// Número de mesa: un cartel por mesa, del «desde» al «hasta», más las mesas
// con nombre («Principal», «Novios»…), que van primero.
const MAX_TABLES = 150
const numbered = ref(false)
const tableFrom = ref(1)
const tableTo = ref(10)
const namedTables = ref([])
const newTableName = ref('')

function addNamedTable() {
  const name = newTableName.value.trim()
  if (name && !namedTables.value.some((t) => t.toLowerCase() === name.toLowerCase())) {
    namedTables.value = [...namedTables.value, name]
  }
  newTableName.value = ''
}

const tableLabels = computed(() => {
  if (!numbered.value) return []
  const from = Math.max(1, Math.floor(Number(tableFrom.value) || 1))
  const to = Math.max(from, Math.floor(Number(tableTo.value) || from))
  const numbers = Array.from({ length: to - from + 1 }, (_, i) => from + i)
  return [...namedTables.value, ...numbers].slice(0, MAX_TABLES)
})

// Si ya cargó las mesas, arrancamos con esa cantidad.
watch(
  () => event.value?.id,
  async (id) => {
    if (!id) return
    const { count } = await supabase.from('tables').select('id', { count: 'exact', head: true }).eq('event_id', id)
    if (count) tableTo.value = count
  },
  { immediate: true },
)

const cardsPerSheet = ref(0)
watch(
  cardDims,
  async ({ w, h }) => {
    const { packSheet } = await import('../lib/photoCard')
    cardsPerSheet.value = packSheet(w, h).slots.length
  },
  { immediate: true },
)

// --- Exportar ------------------------------------------------------------------------
// Cada imprenta pide algo distinto: hojas A4 para recortar en casa, un PDF con
// una página por cartel, o un archivo por cartel.
const exportFormat = ref('sheet')
const sizeText = computed(() => {
  const s = CARD_SIZES.find((x) => x.id === cardSize.value)
  if (s?.id === 'a5' || s?.id === 'a4') return s.label
  const cm = (mm) => String(mm / 10).replace('.', ',')
  return `${cm(cardDims.value.w)} × ${cm(cardDims.value.h)} cm`
})
const exportOptions = computed(() => {
  const n = cardsPerSheet.value
  const fitsA4 = n > 0
  const many = numbered.value
  return [
    fitsA4 &&
      n > 1 && {
        id: 'sheet',
        label: 'Aprovechar la hoja A4',
        help: `Entran ${n} carteles por hoja, con líneas para recortar. Gasta menos papel.`,
      },
    fitsA4 &&
      cardSize.value !== 'a4' && {
        id: 'a4',
        label: 'Un cartel por hoja A4',
        help: 'Centrado en la hoja, con línea para recortar.',
      },
    {
      id: 'exact',
      label: many ? 'Un PDF, una página por cartel' : 'PDF del tamaño exacto',
      help: `Cada página mide ${sizeText.value}. Es lo que suelen pedir en la imprenta.`,
    },
    many && {
      id: 'pdfs',
      label: 'Un PDF por cartel',
      help: `Archivos separados (mesa-1.pdf, mesa-2.pdf…) de ${sizeText.value}, en un .zip.`,
    },
    {
      id: 'png',
      label: many ? 'Una imagen por cartel' : 'Imagen (PNG)',
      help: `${many ? 'Archivos PNG separados, en un .zip. ' : ''}En alta calidad, para casas de fotos.`,
    },
  ].filter(Boolean)
})
// Si al cambiar tamaño o número la opción elegida ya no está, pasamos a la primera.
watch(exportOptions, (opts) => {
  if (!opts.some((o) => o.id === exportFormat.value)) exportFormat.value = opts[0].id
})

const cardPreview = ref('')
const cardPhotoFailed = ref(false)
const cardBusy = ref(null) // 'preview' | 'export' | null
const cardProgress = ref({ done: 0, total: 0 })

function cardOptions(pxPerMm, tableNumber = null, index = 0) {
  return {
    url: guestUrl.value,
    color: event.value.primary_color,
    photoUrl: photoFor(index),
    eventType: event.value.event_type,
    tableNumber,
    width: cardDims.value.w,
    height: cardDims.value.h,
    pxPerMm,
  }
}

let previewRun = 0
watch(
  () =>
    event.value && [
      guestUrl.value,
      photoFor(previewIndex.value),
      event.value.primary_color,
      cardDims.value.w,
      cardDims.value.h,
      tableLabels.value[previewIndex.value],
    ],
  async (deps) => {
    if (!deps) return
    const run = ++previewRun
    cardBusy.value = 'preview'
    try {
      const { renderPhotoCard } = await import('../lib/photoCard')
      // Vista previa siempre de ~450 px de ancho, sea cual sea el papel.
      const canvas = await renderPhotoCard(cardOptions(444 / cardDims.value.w, tableLabels.value[0] ?? null))
      if (run === previewRun) {
        cardPreview.value = canvas.toDataURL('image/png')
        cardPhotoFailed.value = canvas.dataset.photo === 'failed'
      }
    } catch (err) {
      error.value = `No se pudo armar la vista previa del cartel: ${err.message}`
    } finally {
      if (run === previewRun) cardBusy.value = null
    }
  },
  { immediate: true },
)

async function downloadCard() {
  const format = exportFormat.value
  error.value = ''
  cardBusy.value = 'export'
  const tables = tableLabels.value
  const { w, h } = cardDims.value
  cardProgress.value = { done: 0, total: tables.length }
  try {
    const { renderPhotoCard, photoCardPdf } = await import('../lib/photoCard')
    const render = (n = null, i = 0) => renderPhotoCard(cardOptions(11.8, n, i)) // ≈ 300 dpi
    const name = `cartel-fotos-${slugify(event.value.name)}${tables.length ? '-mesas' : ''}`
    const onProgress = (done) => (cardProgress.value.done = done)
    const pad = String(tables.filter((n) => typeof n === 'number').at(-1) ?? '').length
    const fileName = (n, ext) => `mesa-${typeof n === 'number' ? String(n).padStart(pad, '0') : slugify(n)}.${ext}`
    const toPng = (canvas) => new Promise((r) => canvas.toBlob(r, 'image/png'))

    if (format === 'pdfs' || (format === 'png' && tables.length)) {
      // Un archivo por mesa, todos en un .zip.
      const { zip } = await import('fflate')
      const files = {}
      for (const [i, n] of tables.entries()) {
        const data =
          format === 'pdfs'
            ? (await photoCardPdf({ width: w, height: h, count: 1, layout: 'exact', render: () => render(n, i) })).output('arraybuffer')
            : await (await toPng(await render(n, i))).arrayBuffer()
        files[fileName(n, format === 'pdfs' ? 'pdf' : 'png')] = [new Uint8Array(data), { level: 0 }]
        onProgress(Object.keys(files).length)
      }
      const data = await new Promise((resolve, reject) => zip(files, (err, out) => (err ? reject(err) : resolve(out))))
      saveBlob(new Blob([data], { type: 'application/zip' }), `${name}.zip`)
    } else if (format === 'png') {
      saveBlob(await toPng(await render()), `${name}.png`)
    } else if (tables.length) {
      const doc = await photoCardPdf({ width: w, height: h, count: tables.length, layout: format, render: (i) => render(tables[i], i), onProgress })
      doc.save(`${name}.pdf`)
    } else {
      // Sin número: en «aprovechar la hoja» la llenamos de copias del mismo cartel.
      const canvas = await render()
      const count = format === 'sheet' ? Math.max(1, cardsPerSheet.value) : 1
      ;(await photoCardPdf({ width: w, height: h, count, layout: format, render: () => canvas })).save(`${name}.pdf`)
    }
  } catch (err) {
    error.value = `No se pudo generar el cartel: ${err.message}`
  } finally {
    cardBusy.value = null
  }
}

const exportLabel = computed(() => {
  if (cardBusy.value !== 'export') return 'Descargar'
  const { done, total } = cardProgress.value
  return total > 1 ? `Generando ${done} de ${total}…` : 'Generando…'
})

// --- Galería ---------------------------------------------------------------------
const sortBy = ref('recent') // 'recent' | 'likes'
const sortedPhotos = computed(() =>
  sortBy.value === 'likes'
    ? [...photos.value].sort((a, b) => b.likes_count - a.likes_count || (a.created_at < b.created_at ? 1 : -1))
    : photos.value,
)
const usedPct = computed(() => Math.min(100, (photos.value.length / LIMIT) * 100))

// Modo selección: para borrar o descargar varias de una.
const selecting = ref(false)
const selected = ref(new Set())

function toggleSelect(photo) {
  const next = new Set(selected.value)
  next.has(photo.id) ? next.delete(photo.id) : next.add(photo.id)
  selected.value = next
}

function stopSelecting() {
  selecting.value = false
  selected.value = new Set()
}

function onTileClick(photo, i) {
  if (selecting.value) toggleSelect(photo)
  else openLightbox(i)
}

const selectedPhotos = computed(() => photos.value.filter((p) => selected.value.has(p.id)))

// --- Borrar ------------------------------------------------------------------------
const busy = ref(null) // 'delete' | 'zip' | null

async function removePhotos(list) {
  if (!list.length) return
  const one = list.length === 1
  const ok = await confirmDialog({
    title: one ? '¿Eliminar esta foto?' : `¿Eliminar ${list.length} fotos?`,
    message: 'Deja de verse también en la galería de los invitados. No se puede deshacer.',
    confirmText: 'Eliminar',
    tone: 'danger',
  })
  if (!ok) return
  error.value = ''
  busy.value = 'delete'
  try {
    const { error: stErr } = await supabase.storage.from('guest-uploads').remove(list.map((p) => p.path))
    if (stErr) throw stErr
    const ids = list.map((p) => p.id)
    const { error: dbErr } = await supabase.from('event_photos').delete().in('id', ids)
    if (dbErr) throw dbErr
    photos.value = photos.value.filter((p) => !ids.includes(p.id))
    stopSelecting()
    if (lightboxOpen.value) {
      if (!sortedPhotos.value.length) closeLightbox()
      else lightboxIndex.value = Math.min(lightboxIndex.value, sortedPhotos.value.length - 1)
    }
  } catch (err) {
    error.value = `No se pudo eliminar: ${err.message}`
  } finally {
    busy.value = null
  }
}

// --- Descargar -----------------------------------------------------------------------
function photoFileName(photo, n) {
  const who = photo.uploader_name ? `-${slugify(photo.uploader_name)}` : ''
  return `foto-${String(n).padStart(3, '0')}${who}.jpg`
}

async function downloadOne(photo) {
  try {
    const res = await fetch(photo.url)
    saveBlob(await res.blob(), photoFileName(photo, photos.value.length - photos.value.indexOf(photo)))
  } catch {
    window.open(photo.url, '_blank', 'noopener')
  }
}

// Todas (o las seleccionadas) en un .zip. Las fotos ya vienen comprimidas en
// JPG, así que el zip solo las junta sin volver a comprimir (level 0).
const zipProgress = ref({ done: 0, total: 0 })
async function downloadZip(list) {
  if (!list.length) return
  error.value = ''
  busy.value = 'zip'
  zipProgress.value = { done: 0, total: list.length }
  try {
    const { zip } = await import('fflate')
    // Numeradas por orden de llegada (la 001 es la primera que subieron).
    const ordered = [...list].sort((a, b) => (a.created_at < b.created_at ? -1 : 1))
    const files = {}
    let next = 0
    const worker = async () => {
      while (next < ordered.length) {
        const i = next++
        const res = await fetch(ordered[i].url)
        if (!res.ok) throw new Error(`no se pudo bajar una foto (${res.status})`)
        files[photoFileName(ordered[i], i + 1)] = [new Uint8Array(await res.arrayBuffer()), { level: 0 }]
        zipProgress.value.done++
      }
    }
    await Promise.all(Array.from({ length: 4 }, worker))
    const data = await new Promise((resolve, reject) => zip(files, (err, out) => (err ? reject(err) : resolve(out))))
    saveBlob(new Blob([data], { type: 'application/zip' }), `fotos-${slugify(event.value.name)}.zip`)
    stopSelecting()
  } catch (err) {
    error.value = `No se pudo armar el .zip: ${err.message}`
  } finally {
    busy.value = null
  }
}

// --- Lightbox ----------------------------------------------------------------------------
const lightboxIndex = ref(-1)
const lightboxOpen = computed(() => lightboxIndex.value >= 0)
const current = computed(() => (lightboxOpen.value ? sortedPhotos.value[lightboxIndex.value] : null))

const openLightbox = (i) => (lightboxIndex.value = i)
const closeLightbox = () => (lightboxIndex.value = -1)
function nextPhoto() {
  if (lightboxIndex.value < sortedPhotos.value.length - 1) lightboxIndex.value++
}
function prevPhoto() {
  if (lightboxIndex.value > 0) lightboxIndex.value--
}

let touchX = 0
const onTouchStart = (e) => (touchX = e.changedTouches[0].clientX)
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
watch(lightboxOpen, (open) => (document.body.style.overflow = open ? 'hidden' : ''))
onMounted(() => window.addEventListener('keydown', onKeydown))
onUnmounted(() => {
  window.removeEventListener('keydown', onKeydown)
  document.body.style.overflow = ''
})
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <PlanGate feature="fotos" action="que tus invitados suban sus fotos de la fiesta">
    <div class="mx-auto max-w-5xl px-4 pt-4 pb-32 lg:px-8 lg:pt-8">
      <h1 class="admin-display text-5xl sm:text-6xl">Fotos del evento</h1>
      <p class="mt-3 max-w-xl text-obsidian/60">
        Los invitados escanean el QR de las mesas y suben sus fotos, sin registrarse. Aparecen acá y en una galería que ven todos.
      </p>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>

      <div v-else-if="!event" class="mt-8 rounded-[2rem] bg-limestone p-8">
        <p class="text-obsidian/60">Primero creá tu invitación, después vas a tener el QR para las fotos.</p>
        <router-link :to="{ name: 'admin-salon' }" class="admin-btn-primary mt-5">Creá tu invitación</router-link>
      </div>

      <template v-else>
        <!-- ============ CARTEL + QR ============ -->
        <section class="mt-6 grid gap-6 rounded-[2rem] bg-limestone p-6 sm:grid-cols-[15rem_1fr] sm:p-8">
          <!-- Vista previa del cartel -->
          <div class="relative mx-auto w-56 sm:mx-0 sm:w-full">
            <img
              v-if="cardPreview"
              :src="cardPreview"
              alt="Vista previa del cartel para las mesas"
              class="w-full rounded-[0.5rem] shadow-[0_8px_30px_rgb(7_6_7/0.14)] transition-opacity"
              :class="{ 'opacity-50': cardBusy === 'preview' }"
            />
            <div
              v-else
              class="w-full animate-pulse rounded-[0.5rem] bg-chalk"
              :style="{ aspectRatio: `${cardDims.w} / ${cardDims.h}` }"
            ></div>
          </div>

          <div class="min-w-0">
            <h2 class="flex items-center gap-2 text-lg font-bold"><QrCode :size="19" /> Cartel para las mesas</h2>
            <p class="mt-1 text-sm text-obsidian/55">
              Para un portacartel o un portarretrato en cada mesa. Usa el color de tu invitación.
            </p>

            <p class="admin-label mt-5">Tamaño del cartel</p>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="s in CARD_SIZES"
                :key="s.id"
                type="button"
                @click="cardSize = s.id"
                :class="cardSize === s.id ? 'bg-obsidian text-chalk' : 'bg-chalk text-obsidian/70 hover:text-obsidian'"
                class="rounded-full px-4 py-2 text-left text-sm font-bold leading-tight transition"
              >
                {{ s.label }}
                <span class="block text-[0.7rem] font-medium opacity-70">{{ s.hint }}</span>
              </button>
            </div>
            <div v-if="cardSize === 'custom'" class="mt-3 flex items-center gap-2 text-sm">
              <label class="sr-only" for="card-w">Ancho en cm</label>
              <input id="card-w" v-model.number="customW" type="number" min="5" max="60" step="0.5" class="admin-input !w-24 !py-2" />
              <span class="font-bold text-obsidian/55">×</span>
              <label class="sr-only" for="card-h">Alto en cm</label>
              <input id="card-h" v-model.number="customH" type="number" min="5" max="60" step="0.5" class="admin-input !w-24 !py-2" />
              <span class="text-obsidian/55">cm (ancho × alto)</span>
            </div>

            <label class="mt-5 flex items-start gap-2 rounded-[1.25rem] bg-chalk/60 px-4 py-3 text-sm">
              <input type="checkbox" v-model="numbered" class="mt-0.5 h-4 w-4 shrink-0 accent-[var(--color-accent)]" />
              <span>
                <span class="font-bold">Incluir número de mesa</span>
                <span class="block text-obsidian/55">Un cartel por mesa con el número grande, así sirve también para identificarla.</span>
              </span>
            </label>
            <div v-if="numbered" class="mt-3 flex flex-wrap items-center gap-2 text-sm">
              <label for="t-from" class="font-bold">Desde la mesa</label>
              <input id="t-from" v-model.number="tableFrom" type="number" min="1" class="admin-input !w-20 !py-2" />
              <label for="t-to" class="font-bold">hasta la</label>
              <input id="t-to" v-model.number="tableTo" type="number" min="1" class="admin-input !w-20 !py-2" />
              <span class="text-obsidian/55">
                ({{ tableLabels.length }} {{ tableLabels.length === 1 ? 'cartel' : 'carteles' }})
              </span>
            </div>
            <div v-if="numbered" class="mt-3">
              <label for="t-name" class="text-sm font-bold">Mesas con nombre</label>
              <p class="admin-help !mb-2">Por ejemplo «Principal». Sale «Mesa Principal» en vez de un número.</p>
              <form class="flex gap-2" @submit.prevent="addNamedTable">
                <input
                  id="t-name"
                  v-model="newTableName"
                  type="text"
                  maxlength="20"
                  placeholder="Principal"
                  class="admin-input !py-2 sm:!w-56"
                />
                <button type="submit" :disabled="!newTableName.trim()" class="admin-btn-secondary shrink-0 !px-4 !py-2 text-sm">Agregar</button>
              </form>
              <div v-if="namedTables.length" class="mt-2 flex flex-wrap gap-2">
                <span
                  v-for="name in namedTables"
                  :key="name"
                  class="inline-flex items-center gap-1 rounded-full bg-chalk py-1 pr-1.5 pl-3 text-sm font-bold"
                >
                  Mesa {{ name }}
                  <button
                    type="button"
                    @click="namedTables = namedTables.filter((t) => t !== name)"
                    :aria-label="`Quitar mesa ${name}`"
                    class="grid h-6 w-6 place-items-center rounded-full text-obsidian/55 hover:bg-pumice hover:text-obsidian"
                  >
                    <X :size="14" />
                  </button>
                </span>
              </div>
            </div>

            <p class="admin-label mt-5">Foto del cartel</p>
            <div v-if="numbered && cardPhotoPool.length > 1" class="mb-3 inline-flex rounded-full bg-chalk p-1 text-sm font-bold">
              <button
                type="button"
                @click="cardPhoto = 'all'"
                :class="photoPerTable ? 'bg-obsidian text-chalk' : 'text-obsidian/55 hover:text-obsidian'"
                class="inline-flex items-center gap-1.5 rounded-full px-3.5 py-1.5 transition"
              >
                <Images :size="15" /> Una distinta por mesa
              </button>
              <button
                type="button"
                @click="cardPhoto = cardPhotoUrl ?? cardPhotoPool[0]"
                :class="!photoPerTable ? 'bg-obsidian text-chalk' : 'text-obsidian/55 hover:text-obsidian'"
                class="rounded-full px-3.5 py-1.5 transition"
              >
                La misma en todas
              </button>
            </div>

            <!-- Una distinta por mesa: cada mesa con su foto; se intercambian arrastrando o tocando. -->
            <template v-if="photoPerTable">
              <p class="admin-help">
                Arrastrá una mesa sobre otra para intercambiar las fotos, o una de «Tus fotos» sobre una mesa.
                Desde el celular: tocá una mesa y después otra mesa o una foto.
              </p>
              <div class="grid grid-cols-[repeat(auto-fill,minmax(4.75rem,1fr))] gap-2">
                <button
                  v-for="(label, i) in tableLabels"
                  :key="label"
                  type="button"
                  draggable="true"
                  @dragstart="onDragStart($event, { table: i })"
                  @dragend="onDragEnd"
                  @dragover.prevent="dropTarget = i"
                  @dragleave="dropTarget === i && (dropTarget = null)"
                  @drop.prevent="onDropOnTable(i)"
                  @click="onTableClick(i)"
                  :title="`Mesa ${label}`"
                  :class="[
                    selectedTable === i || dropTarget === i ? 'ring-3 ring-accent' : 'hover:bg-pumice',
                    dragging?.table === i ? 'opacity-40' : '',
                  ]"
                  class="flex cursor-grab flex-col rounded-[0.9rem] bg-chalk p-1 transition active:cursor-grabbing"
                >
                  <img :src="tablePhoto(i)" alt="" draggable="false" class="pointer-events-none aspect-square w-full rounded-[0.6rem] object-cover" />
                  <span class="pointer-events-none mt-1 truncate px-0.5 text-center text-xs font-bold">
                    {{ typeof label === 'number' ? `Mesa ${label}` : label }}
                  </span>
                </button>
              </div>

              <p class="mt-4 mb-1.5 text-xs font-bold">
                Tus fotos
                <span class="font-medium text-obsidian/55">
                  {{ selectedTable !== null ? `· tocá una para ponérsela a la mesa ${tableLabels[selectedTable]}` : '· arrastralas a una mesa' }}
                </span>
              </p>
              <div class="flex flex-wrap gap-2">
                <button
                  v-for="url in cardPhotoPool"
                  :key="url"
                  type="button"
                  draggable="true"
                  @dragstart="onDragStart($event, { photo: url })"
                  @dragend="onDragEnd"
                  @click="onPoolPhotoClick(url)"
                  :class="selectedTable !== null ? 'hover:ring-3 hover:ring-accent' : ''"
                  class="relative h-12 w-12 cursor-grab overflow-hidden rounded-[0.75rem] bg-pumice transition active:cursor-grabbing"
                >
                  <img :src="url" alt="" draggable="false" class="pointer-events-none h-full w-full object-cover" :class="{ 'opacity-40': !photoUses(url) }" />
                  <span
                    v-if="photoUses(url) !== 1"
                    class="pointer-events-none absolute inset-x-0 bottom-0 bg-obsidian/70 text-center text-[0.6rem] font-bold text-chalk"
                  >
                    {{ photoUses(url) ? `en ${photoUses(url)} mesas` : 'sin usar' }}
                  </span>
                </button>
              </div>
              <button
                v-if="Object.keys(tablePhotoPicks).length"
                type="button"
                @click="tablePhotoPicks = {}"
                class="mt-3 text-xs font-bold text-obsidian/55 underline hover:text-obsidian"
              >
                Volver al orden automático
              </button>
            </template>

            <!-- La misma foto en todos los carteles. -->
            <div v-else class="flex flex-wrap gap-2">
              <button
                v-for="url in cardPhotoPool"
                :key="url"
                type="button"
                @click="cardPhoto = url"
                :class="cardPhotoUrl === url ? 'ring-3 ring-accent' : 'opacity-80 hover:opacity-100'"
                class="h-14 w-14 overflow-hidden rounded-[0.9rem] bg-pumice transition"
              >
                <img :src="url" alt="" loading="lazy" class="h-full w-full object-cover" />
              </button>
              <button
                type="button"
                @click="cardPhoto = null"
                :class="cardPhotoUrl === null ? 'ring-3 ring-accent' : 'text-obsidian/55 hover:text-obsidian'"
                class="grid h-14 w-14 place-items-center rounded-[0.9rem] bg-chalk text-[0.65rem] font-bold transition"
              >
                <span class="flex flex-col items-center gap-0.5"><ImageOff :size="16" /> Sin foto</span>
              </button>
            </div>
            <p v-if="cardPhotoFailed" class="mt-2 text-xs font-bold text-nogo">No se pudo cargar esa foto, el cartel sale sin foto. Probá con otra.</p>
            <p v-if="!cardPhotoChoices.length" class="admin-help mt-2">
              Las fotos salen de las que subiste en «Creá tu invitación».
            </p>

            <p class="admin-label mt-5">¿Cómo lo descargás?</p>
            <div class="grid gap-2 sm:grid-cols-2">
              <button
                v-for="opt in exportOptions"
                :key="opt.id"
                type="button"
                @click="exportFormat = opt.id"
                :class="exportFormat === opt.id ? 'border-accent bg-chalk' : 'border-transparent bg-chalk/60 hover:bg-chalk'"
                class="flex items-start gap-2.5 rounded-[1.25rem] border-[1.5px] px-4 py-3 text-left text-sm transition"
              >
                <FileImage v-if="opt.id === 'png'" :size="17" class="mt-0.5 shrink-0 text-obsidian/60" />
                <Archive v-else-if="opt.id === 'pdfs'" :size="17" class="mt-0.5 shrink-0 text-obsidian/60" />
                <Printer v-else :size="17" class="mt-0.5 shrink-0 text-obsidian/60" />
                <span>
                  <span class="block font-bold">{{ opt.label }}</span>
                  <span class="mt-0.5 block leading-snug text-obsidian/55">{{ opt.help }}</span>
                </span>
              </button>
            </div>

            <div class="mt-4">
              <button type="button" @click="downloadCard" :disabled="!!cardBusy && cardBusy !== 'preview'" class="admin-btn-primary !px-5 !py-2.5 text-sm">
                <Download :size="16" />
                {{ exportLabel }}
              </button>
            </div>

            <div class="mt-6 border-t-[1.5px] border-dotted border-obsidian/20 pt-5">
              <p class="text-sm font-bold">Link para subir fotos</p>
              <p class="mt-1 text-xs text-obsidian/55">También lo podés mandar por WhatsApp. El QR lleva siempre a este link.</p>
              <p class="mt-2 truncate rounded-full bg-chalk px-4 py-2 font-mono text-xs text-obsidian/70">{{ guestUrl }}</p>
              <div class="mt-3 flex flex-wrap gap-2">
                <button
                  type="button"
                  @click="copyLink"
                  :class="copied ? 'border-accent bg-accent text-chalk' : ''"
                  class="admin-btn-secondary !px-4 !py-2 text-sm"
                >
                  <Check v-if="copied" :size="16" />
                  <Link2 v-else :size="16" />
                  {{ copied ? 'Copiado' : 'Copiar link' }}
                </button>
                <button type="button" @click="downloadQr" class="admin-btn-secondary !px-4 !py-2 text-sm">
                  <Download :size="16" /> Solo el QR
                </button>
                <a :href="guestUrl" target="_blank" rel="noopener" class="admin-btn-secondary !px-4 !py-2 text-sm">
                  <ExternalLink :size="16" /> Ver como invitado
                </a>
              </div>
            </div>
          </div>
        </section>

        <p v-if="error" class="mt-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ error }}</p>

        <!-- ============ GALERÍA ============ -->
        <section class="mt-6 rounded-[2rem] bg-limestone p-5 sm:p-8">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="admin-display text-3xl">Galería</h2>
              <p class="mt-1 text-xs font-bold text-obsidian/45">{{ photos.length }} de {{ LIMIT }} fotos</p>
              <div class="mt-1.5 h-1.5 w-40 overflow-hidden rounded-full bg-chalk">
                <div class="h-full rounded-full" :class="usedPct >= 90 ? 'bg-nogo' : 'bg-accent'" :style="{ width: usedPct + '%' }"></div>
              </div>
            </div>
            <div v-if="photos.length" class="flex flex-wrap items-center gap-2">
              <div class="flex rounded-full bg-pumice/70 p-1 text-sm font-bold">
                <button
                  v-for="opt in [
                    { id: 'recent', label: 'Recientes' },
                    { id: 'likes', label: 'Más votadas' },
                  ]"
                  :key="opt.id"
                  type="button"
                  @click="sortBy = opt.id"
                  :class="sortBy === opt.id ? 'bg-chalk' : 'text-obsidian/55'"
                  class="rounded-full px-3 py-1 transition-colors"
                >
                  {{ opt.label }}
                </button>
              </div>
              <button
                type="button"
                @click="selecting ? stopSelecting() : (selecting = true)"
                :class="selecting ? 'bg-accent text-chalk' : 'bg-chalk'"
                class="flex items-center gap-1.5 rounded-full px-3 py-1.5 text-sm font-bold transition-colors"
              >
                <SquareCheckBig :size="15" /> {{ selecting ? 'Listo' : 'Seleccionar' }}
              </button>
              <button
                type="button"
                @click="downloadZip(photos)"
                :disabled="!!busy"
                class="flex items-center gap-1.5 rounded-full bg-chalk px-3 py-1.5 text-sm font-bold disabled:opacity-50"
              >
                <Archive :size="15" />
                {{ busy === 'zip' && !selecting ? `Bajando ${zipProgress.done}/${zipProgress.total}…` : 'Descargar todas' }}
              </button>
            </div>
          </div>

          <div v-if="!photos.length" class="mt-6 rounded-[1.5rem] bg-chalk p-8 text-center text-sm text-obsidian/55">
            Todavía no subieron fotos. Van a aparecer acá durante la fiesta (se actualiza sola).
          </div>

          <div v-else class="mt-6 grid grid-cols-3 gap-1.5 sm:grid-cols-4 sm:gap-2 lg:grid-cols-5">
            <div
              v-for="(photo, i) in sortedPhotos"
              :key="photo.id"
              class="group relative aspect-square cursor-pointer overflow-hidden rounded-[1rem] bg-pumice"
              :class="{ 'ring-4 ring-accent': selected.has(photo.id) }"
              @click="onTileClick(photo, i)"
            >
              <img
                :src="photo.url"
                alt=""
                loading="lazy"
                decoding="async"
                class="h-full w-full object-cover transition-transform duration-300"
                :class="selected.has(photo.id) ? 'scale-90 rounded-[0.75rem]' : 'group-hover:scale-[1.03]'"
              />
              <span
                v-if="selecting"
                class="absolute top-2 left-2 grid h-6 w-6 place-items-center rounded-full border-2 border-chalk"
                :class="selected.has(photo.id) ? 'bg-accent' : 'bg-obsidian/30'"
              >
                <Check v-if="selected.has(photo.id)" :size="13" :stroke-width="3" class="text-chalk" />
              </span>
              <div
                v-if="!selecting"
                class="pointer-events-none absolute inset-x-0 bottom-0 flex items-center justify-between gap-1 bg-linear-to-t from-obsidian/70 to-transparent px-2 pt-4 pb-1.5 text-[11px] font-bold text-chalk"
              >
                <span class="truncate">{{ photo.uploader_name || 'Anónimo' }}</span>
                <span v-if="photo.likes_count" class="flex shrink-0 items-center gap-0.5">
                  <Heart :size="11" fill="currentColor" /> {{ photo.likes_count }}
                </span>
              </div>
            </div>
          </div>
        </section>
      </template>
    </div>
    </PlanGate>

    <!-- Barra de selección -->
    <div v-if="selecting" class="font-ui fixed inset-x-0 bottom-4 z-30 flex justify-center px-4 lg:left-[16.5rem]">
      <div class="flex flex-wrap items-center justify-center gap-2 rounded-[1.75rem] bg-obsidian py-2 pr-2 pl-5 text-sm text-chalk shadow-lg">
        <span class="mr-1">
          <strong>{{ selected.size }}</strong> {{ selected.size === 1 ? 'seleccionada' : 'seleccionadas' }}
        </span>
        <button
          type="button"
          @click="downloadZip(selectedPhotos)"
          :disabled="!selected.size || !!busy"
          class="flex items-center gap-1.5 rounded-full bg-chalk/15 px-3 py-1.5 font-bold hover:bg-chalk/25 disabled:opacity-40"
        >
          <Download :size="15" />
          {{ busy === 'zip' ? `${zipProgress.done}/${zipProgress.total}…` : 'Descargar' }}
        </button>
        <button
          type="button"
          @click="removePhotos(selectedPhotos)"
          :disabled="!selected.size || !!busy"
          class="flex items-center gap-1.5 rounded-full bg-nogo px-3 py-1.5 font-bold text-chalk disabled:opacity-40"
        >
          <Trash2 :size="15" /> Eliminar
        </button>
        <button type="button" @click="stopSelecting" aria-label="Cancelar selección" class="grid h-8 w-8 place-items-center rounded-full hover:bg-chalk/15">
          <X :size="16" />
        </button>
      </div>
    </div>

    <!-- Lightbox -->
    <transition
      enter-active-class="transition-opacity duration-200"
      leave-active-class="transition-opacity duration-200"
      enter-from-class="opacity-0"
      leave-to-class="opacity-0"
    >
      <div
        v-if="lightboxOpen && current"
        class="font-ui fixed inset-0 z-[70] flex flex-col bg-obsidian/95 text-chalk"
        @touchstart.passive="onTouchStart"
        @touchend.passive="onTouchEnd"
      >
        <div class="flex items-center justify-between gap-3 px-4 py-3">
          <div class="min-w-0">
            <p class="truncate text-sm font-bold">{{ current.uploader_name || 'Anónimo' }}</p>
            <p class="text-xs text-chalk/55">
              {{ timeAgo(current.created_at) }} · {{ lightboxIndex + 1 }} de {{ sortedPhotos.length }}
            </p>
          </div>
          <button type="button" @click="closeLightbox" aria-label="Cerrar" class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-chalk/10">
            <X :size="20" />
          </button>
        </div>

        <div class="relative flex flex-1 items-center justify-center overflow-hidden px-1">
          <button
            v-if="lightboxIndex > 0"
            type="button"
            @click="prevPhoto"
            aria-label="Foto anterior"
            class="absolute left-2 z-10 grid h-11 w-11 place-items-center rounded-full bg-chalk/10 backdrop-blur-sm sm:left-4"
          >
            <ChevronLeft :size="22" />
          </button>
          <img :src="current.url" alt="" class="max-h-full max-w-full object-contain" />
          <button
            v-if="lightboxIndex < sortedPhotos.length - 1"
            type="button"
            @click="nextPhoto"
            aria-label="Foto siguiente"
            class="absolute right-2 z-10 grid h-11 w-11 place-items-center rounded-full bg-chalk/10 backdrop-blur-sm sm:right-4"
          >
            <ChevronRight :size="22" />
          </button>
        </div>

        <div class="flex items-center justify-center gap-2 px-4 py-5 text-sm font-bold">
          <span class="flex items-center gap-1.5 rounded-full bg-chalk/10 px-4 py-2.5">
            <Heart :size="16" :fill="current.likes_count ? 'currentColor' : 'none'" /> {{ current.likes_count || 0 }}
          </span>
          <button type="button" @click="downloadOne(current)" class="flex items-center gap-1.5 rounded-full bg-chalk/10 px-4 py-2.5 hover:bg-chalk/20">
            <Download :size="16" /> Descargar
          </button>
          <button
            type="button"
            @click="removePhotos([current])"
            :disabled="busy === 'delete'"
            class="flex items-center gap-1.5 rounded-full bg-nogo px-4 py-2.5 text-chalk"
          >
            <Trash2 :size="16" /> Eliminar
          </button>
        </div>
      </div>
    </transition>
  </div>
</template>
