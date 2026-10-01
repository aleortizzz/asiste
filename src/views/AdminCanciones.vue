<script setup>
import { ref, computed, onMounted } from 'vue'
import { Trash2, Music2, Search, ClipboardCopy, Check, ExternalLink, ListMusic, ChevronDown, FileText, FileSpreadsheet } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'
import { confirmDialog } from '../composables/useConfirm'
import { timeAgo } from '../lib/timeAgo'

// Pedidos de canciones de los invitados (plan Plus), del más reciente al más
// viejo. «Lista para el DJ» la copia como texto (para WhatsApp) o la exporta
// en PDF / Excel.
const { event, loadEvent } = useEvent()
const songs = ref([])
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) await fetchSongs()
  loading.value = false
})

async function fetchSongs() {
  const { data, error: err } = await supabase
    .from('song_requests')
    .select('id, song_title, artist, youtube_video_id, requested_by, created_at')
    .eq('event_id', event.value.id)
    .order('created_at', { ascending: false })
  if (err) error.value = `No se pudieron cargar las canciones: ${err.message}`
  else songs.value = data
}

const isPlus = computed(() => event.value?.plan === 'plus')

const norm = (s) => (s ?? '').trim().toLowerCase().replace(/\s+/g, ' ')
const people = computed(() => new Set(songs.value.map((s) => norm(s.requested_by))).size)

// --- Búsqueda ---------------------------------------------------------------------
const search = ref('')
const visibleSongs = computed(() => {
  const q = norm(search.value)
  return songs.value.filter(
    (s) => !q || norm(s.song_title).includes(q) || norm(s.artist).includes(q) || norm(s.requested_by).includes(q),
  )
})

const thumb = (s) => (s.youtube_video_id ? `https://i.ytimg.com/vi/${s.youtube_video_id}/mqdefault.jpg` : null)
const youtubeUrl = (s) => (s.youtube_video_id ? `https://www.youtube.com/watch?v=${s.youtube_video_id}` : null)
const shortUrl = (s) => (s.youtube_video_id ? `https://youtu.be/${s.youtube_video_id}` : '')

function formatDateTime(iso) {
  return new Date(iso).toLocaleString('es-AR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

// --- Lista para el DJ: copiar, PDF o Excel ------------------------------------------
// Siempre la lista completa (no la filtrada por el buscador), de la más
// reciente a la más vieja, igual que en pantalla. Las librerías de PDF y
// Excel se importan recién al usarlas, como en ExportEntryList.vue.
const menuOpen = ref(false)
const busy = ref(null) // 'copy' | 'pdf' | 'xlsx' | null
const copied = ref(false)
const exportError = ref('')

const eventTitle = () => event.value.hero_title || event.value.name || 'el evento'

function baseFileName() {
  const slug = (event.value.name || 'evento')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
  return `canciones-${slug}`
}

async function run(kind, fn) {
  exportError.value = ''
  busy.value = kind
  try {
    await fn()
    if (kind !== 'copy') menuOpen.value = false
  } catch (err) {
    exportError.value = `No se pudo ${kind === 'copy' ? 'copiar' : 'exportar'}: ${err.message}`
  } finally {
    busy.value = null
  }
}

const copyList = () =>
  run('copy', async () => {
    const lines = songs.value.map((s, i) => {
      const link = s.youtube_video_id ? `\n   ${shortUrl(s)}` : ''
      return `${i + 1}. ${s.song_title}${s.artist ? ` — ${s.artist}` : ''} (pidió ${s.requested_by.trim()})${link}`
    })
    await navigator.clipboard.writeText(`Canciones pedidas · ${eventTitle()}\n\n${lines.join('\n')}`)
    copied.value = true
    setTimeout(() => {
      copied.value = false
      menuOpen.value = false
    }, 1200)
  })

const exportPdf = () =>
  run('pdf', async () => {
    const [{ jsPDF }, { autoTable }] = await Promise.all([import('jspdf'), import('jspdf-autotable')])
    const doc = new jsPDF({ unit: 'mm', format: 'a4' })
    const margin = 14

    doc.setFont('helvetica', 'bold')
    doc.setFontSize(18)
    doc.text(`Canciones · ${eventTitle()}`, margin, 20)
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(10)
    doc.setTextColor(110)
    doc.text(`${songs.value.length} ${songs.value.length === 1 ? 'pedido' : 'pedidos'} · de la más reciente a la más vieja`, margin, 27)

    autoTable(doc, {
      startY: 33,
      margin: { left: margin, right: margin, bottom: 18 },
      head: [['#', 'Canción', 'Artista', 'Pidió', 'YouTube']],
      body: songs.value.map((s, i) => [i + 1, s.song_title, s.artist ?? '', s.requested_by, shortUrl(s)]),
      styles: { font: 'helvetica', fontSize: 9.5, cellPadding: 2.4, textColor: 20, lineColor: 220, lineWidth: 0.1, overflow: 'linebreak' },
      headStyles: { fillColor: [78, 31, 110], textColor: 255, fontStyle: 'bold' },
      alternateRowStyles: { fillColor: [247, 246, 242] },
      columnStyles: { 0: { cellWidth: 9, halign: 'right', textColor: 140 }, 1: { fontStyle: 'bold' }, 4: { cellWidth: 44, textColor: [78, 31, 110] } },
      // El link de YouTube se puede tocar en el PDF.
      didDrawCell: (data) => {
        if (data.section !== 'body' || data.column.index !== 4) return
        const url = shortUrl(songs.value[data.row.index])
        if (url) doc.link(data.cell.x, data.cell.y, data.cell.width, data.cell.height, { url })
      },
    })

    const pages = doc.getNumberOfPages()
    for (let i = 1; i <= pages; i++) {
      doc.setPage(i)
      doc.setFontSize(8)
      doc.setTextColor(140)
      doc.text(`Página ${i} de ${pages}`, doc.internal.pageSize.getWidth() - margin, doc.internal.pageSize.getHeight() - 8, { align: 'right' })
    }

    doc.save(`${baseFileName()}.pdf`)
  })

const exportXlsx = () =>
  run('xlsx', async () => {
    const { default: writeExcelFile } = await import('write-excel-file/browser')
    const header = ['Canción', 'Artista', 'Pidió', 'Fecha', 'YouTube'].map((value) => ({ value, fontWeight: 'bold' }))
    const sheetData = [
      header,
      ...songs.value.map((s) => [
        { value: s.song_title },
        { value: s.artist ?? '' },
        { value: s.requested_by },
        { value: formatDateTime(s.created_at) },
        { value: shortUrl(s) },
      ]),
    ]
    await writeExcelFile(sheetData, {
      columns: [{ width: 36 }, { width: 26 }, { width: 24 }, { width: 18 }, { width: 32 }],
      stickyRowsCount: 1,
    }).toFile(`${baseFileName()}.xlsx`)
  })

// --- Eliminar -----------------------------------------------------------------------
const deletingId = ref(null)

async function removeSong(song) {
  const ok = await confirmDialog({
    title: '¿Eliminar este pedido?',
    message: `«${song.song_title}», pedida por ${song.requested_by}, deja de aparecer en la lista. No se puede deshacer.`,
    confirmText: 'Eliminar',
    tone: 'danger',
  })
  if (!ok) return
  error.value = ''
  deletingId.value = song.id
  const { error: err } = await supabase.from('song_requests').delete().eq('id', song.id)
  if (err) error.value = `No se pudo eliminar: ${err.message}`
  else songs.value = songs.value.filter((s) => s.id !== song.id)
  deletingId.value = null
}
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-3xl px-4 pt-4 pb-16 lg:px-8 lg:pt-8">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 class="admin-display text-5xl sm:text-6xl">Canciones</h1>
          <p class="mt-3 max-w-lg text-obsidian/60">
            <template v-if="songs.length">
              <strong class="text-obsidian">{{ songs.length }} {{ songs.length === 1 ? 'pedido' : 'pedidos' }}</strong>
              de {{ people }} {{ people === 1 ? 'persona' : 'personas' }}
            </template>
            <template v-else>Lo que van pidiendo tus invitados desde la invitación, y quién lo pidió.</template>
          </p>
        </div>
        <div v-if="songs.length" class="relative">
          <button type="button" @click="(menuOpen = !menuOpen), (exportError = '')" :aria-expanded="menuOpen" class="admin-btn-secondary">
            <ListMusic :size="18" />
            Lista para el DJ
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
              @click="copyList"
              :disabled="!!busy"
              class="flex w-full items-center gap-3 rounded-[1.1rem] px-2 py-2 text-left transition-colors hover:bg-limestone disabled:opacity-50"
            >
              <span
                :class="copied ? 'bg-accent text-chalk' : 'bg-accent-soft text-accent'"
                class="grid h-9 w-9 shrink-0 place-items-center rounded-full transition-colors"
              >
                <Check v-if="copied" :size="17" />
                <ClipboardCopy v-else :size="17" />
              </span>
              <span>
                <span class="block text-sm font-bold">{{ copied ? '¡Copiada!' : 'Copiar lista' }}</span>
                <span class="block text-xs text-obsidian/55">Para pegarla en WhatsApp, con los links</span>
              </span>
            </button>
            <button
              type="button"
              @click="exportPdf"
              :disabled="!!busy"
              class="flex w-full items-center gap-3 rounded-[1.1rem] px-2 py-2 text-left transition-colors hover:bg-limestone disabled:opacity-50"
            >
              <span class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-nogo/15 text-nogo"><FileText :size="17" /></span>
              <span>
                <span class="block text-sm font-bold">{{ busy === 'pdf' ? 'Generando…' : 'PDF' }}</span>
                <span class="block text-xs text-obsidian/55">Para imprimir o mandar como archivo</span>
              </span>
            </button>
            <button
              type="button"
              @click="exportXlsx"
              :disabled="!!busy"
              class="flex w-full items-center gap-3 rounded-[1.1rem] px-2 py-2 text-left transition-colors hover:bg-limestone disabled:opacity-50"
            >
              <span class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-go/20 text-obsidian"><FileSpreadsheet :size="17" /></span>
              <span>
                <span class="block text-sm font-bold">{{ busy === 'xlsx' ? 'Generando…' : 'Excel (.xlsx)' }}</span>
                <span class="block text-xs text-obsidian/55">Para editar, o abrir en Google Sheets</span>
              </span>
            </button>
            <p v-if="exportError" class="mt-2 rounded-[1rem] bg-nogo/15 px-3 py-2 text-sm font-bold">{{ exportError }}</p>
          </div>
        </div>
      </div>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>

      <div v-else-if="!event" class="mt-8 rounded-[2rem] bg-limestone p-8">
        <p class="text-obsidian/60">Primero creá tu invitación, después vas a ver acá las canciones que pidan.</p>
        <router-link :to="{ name: 'admin-salon' }" class="admin-btn-primary mt-5">Creá tu invitación</router-link>
      </div>

      <template v-else>
        <!-- Sin plan Plus -->
        <div v-if="!isPlus" class="mt-6 flex items-start gap-4 rounded-[2rem] bg-limestone p-6 sm:p-8">
          <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-accent-soft text-accent">
            <Music2 :size="20" />
          </span>
          <div>
            <p class="font-bold">
              Pedido de canciones
              <span class="ml-1 rounded-full bg-accent-soft px-2 py-0.5 text-xs text-accent">Plan Plus</span>
            </p>
            <p class="mt-1 text-sm text-obsidian/60">
              Con el plan Plus, tus invitados pueden sugerir canciones desde la invitación y vos las ves acá. Todavía no
              está activado para tu evento, así que la sección no aparece en la invitación.
            </p>
          </div>
        </div>

        <p v-if="error" class="mt-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ error }}</p>

        <div v-if="isPlus && !songs.length && !error" class="mt-6 rounded-[2rem] bg-limestone p-8 text-center">
          <span class="mx-auto grid h-12 w-12 place-items-center rounded-full bg-chalk">
            <Music2 :size="20" />
          </span>
          <p class="mt-4 font-bold">Todavía nadie pidió canciones</p>
          <p class="mt-1 text-sm text-obsidian/60">Cuando tus invitados sugieran temas desde la invitación, van a aparecer acá.</p>
        </div>

        <template v-if="songs.length">
          <!-- Buscador -->
          <div class="mt-6 flex flex-wrap items-center gap-2">
            <label class="relative ml-auto w-full sm:w-64">
              <Search :size="16" class="pointer-events-none absolute top-1/2 left-4 -translate-y-1/2 text-obsidian/40" />
              <input v-model="search" type="search" placeholder="Buscar canción o persona" class="admin-input !py-2 !pl-10 text-sm" />
            </label>
          </div>

          <p
            v-if="visibleSongs.length === 0"
            class="mt-6 rounded-[2rem] bg-limestone p-8 text-center text-obsidian/60"
          >
            No hay canciones que coincidan con «{{ search.trim() }}».
          </p>

          <ul v-else class="mt-4 space-y-2">
            <li v-for="s in visibleSongs" :key="s.id" class="flex items-center gap-3 rounded-[1.5rem] bg-limestone p-3 pr-4">
              <img v-if="thumb(s)" :src="thumb(s)" alt="" loading="lazy" class="h-12 w-16 shrink-0 rounded-[0.75rem] object-cover" />
              <span v-else class="grid h-12 w-16 shrink-0 place-items-center rounded-[0.75rem] bg-chalk text-obsidian/45">
                <Music2 :size="18" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate font-bold">{{ s.song_title }}</p>
                <p class="truncate text-sm text-obsidian/55">
                  <template v-if="s.artist">{{ s.artist }} · </template>Pedida por {{ s.requested_by }}
                </p>
                <p class="text-xs text-obsidian/40" :title="formatDateTime(s.created_at)">{{ timeAgo(s.created_at) }}</p>
              </div>
              <a
                v-if="youtubeUrl(s)"
                :href="youtubeUrl(s)"
                target="_blank"
                rel="noopener"
                :aria-label="`Escuchar ${s.song_title} en YouTube`"
                class="grid h-9 w-9 shrink-0 place-items-center rounded-full transition-colors hover:bg-chalk"
              >
                <ExternalLink :size="16" />
              </a>
              <button
                type="button"
                @click="removeSong(s)"
                :disabled="deletingId === s.id"
                :aria-label="`Eliminar ${s.song_title}`"
                class="grid h-9 w-9 shrink-0 place-items-center rounded-full text-obsidian/55 transition-colors hover:bg-nogo/15 hover:text-nogo"
              >
                <Trash2 :size="16" />
              </button>
            </li>
          </ul>
        </template>
      </template>
    </div>
  </div>
</template>
