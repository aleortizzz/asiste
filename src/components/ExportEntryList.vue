<script setup>
import { ref } from 'vue'
import { ClipboardList, FileSpreadsheet, FileText, ChevronDown } from '@lucide/vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'

// «Exportar lista para la entrada»: la lista de quienes confirmaron que
// asisten, con su mesa, para darle a quien recibe a la gente en la puerta.
// En Excel (para editar o compartir) o en PDF (para imprimir y tachar).
//
// Las librerías se importan recién al tocar el botón (import() dinámico):
// son pesadas y la mayoría de las visitas al panel no las necesita.
const { event } = useEvent()
const open = ref(false)
const sortBy = ref('name') // 'name' | 'table'
const busy = ref(null) // 'xlsx' | 'pdf' | null
const error = ref('')

const collator = new Intl.Collator('es', { numeric: true, sensitivity: 'base' })

async function fetchRows() {
  const { data, error: err } = await supabase
    .from('guests')
    .select('full_name, tables(name), invitation_groups!inner(family_name, event_id)')
    .eq('invitation_groups.event_id', event.value.id)
    .eq('rsvp_status', 'attending')
  if (err) throw err
  const rows = data.map((g) => ({
    name: g.full_name,
    family: g.invitation_groups.family_name,
    table: g.tables?.name ?? '',
  }))
  // Por mesa: agrupados por mesa («Mesa 2» antes que «Mesa 10») y los sin
  // mesa al final. Por nombre: alfabético, que es como se busca en la puerta.
  return rows.sort((a, b) => {
    if (sortBy.value === 'table') {
      if (!a.table !== !b.table) return a.table ? -1 : 1
      const byTable = collator.compare(a.table, b.table)
      if (byTable) return byTable
    }
    return collator.compare(a.name, b.name)
  })
}

function baseFileName() {
  const slug = (event.value.name || 'evento')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
  return `lista-entrada-${slug}`
}

function eventDateLabel() {
  if (!event.value.event_date) return ''
  const [y, m, d] = event.value.event_date.split('-').map(Number)
  return new Date(y, m - 1, d).toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
}

async function run(kind, fn) {
  error.value = ''
  busy.value = kind
  try {
    const rows = await fetchRows()
    if (!rows.length) {
      error.value = 'Todavía nadie confirmó que asiste, no hay lista para exportar.'
      return
    }
    await fn(rows)
    open.value = false
  } catch (err) {
    error.value = `No se pudo exportar: ${err.message}`
  } finally {
    busy.value = null
  }
}

const exportXlsx = () =>
  run('xlsx', async (rows) => {
    const { default: writeExcelFile } = await import('write-excel-file/browser')
    const header = ['Llegó', 'Nombre', 'Invitación', 'Mesa'].map((value) => ({ value, fontWeight: 'bold' }))
    const sheetData = [header, ...rows.map((r) => [{ value: '' }, { value: r.name }, { value: r.family }, { value: r.table || 'Sin mesa' }])]
    await writeExcelFile(sheetData, {
      columns: [{ width: 7 }, { width: 32 }, { width: 28 }, { width: 14 }],
      stickyRowsCount: 1,
    }).toFile(`${baseFileName()}.xlsx`)
  })

const exportPdf = () =>
  run('pdf', async (rows) => {
    const [{ jsPDF }, { autoTable }] = await Promise.all([import('jspdf'), import('jspdf-autotable')])
    const doc = new jsPDF({ unit: 'mm', format: 'a4' })
    const margin = 14

    doc.setFont('helvetica', 'bold')
    doc.setFontSize(18)
    doc.text(event.value.name || 'Lista de invitados', margin, 20)
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(10)
    doc.setTextColor(110)
    const date = eventDateLabel()
    doc.text(
      `${date ? `${date} · ` : ''}Lista para la entrada · ${rows.length} ${rows.length === 1 ? 'invitado confirmado' : 'invitados confirmados'}`,
      margin,
      27,
    )

    autoTable(doc, {
      startY: 33,
      margin: { left: margin, right: margin, bottom: 18 },
      head: [['', 'Nombre', 'Invitación', 'Mesa']],
      body: rows.map((r) => ['', r.name, r.family, r.table || 'Sin mesa']),
      styles: { font: 'helvetica', fontSize: 10, cellPadding: 2.4, textColor: 20, lineColor: 220, lineWidth: 0.1 },
      headStyles: { fillColor: [78, 31, 110], textColor: 255, fontStyle: 'bold' },
      alternateRowStyles: { fillColor: [247, 246, 242] },
      columnStyles: { 0: { cellWidth: 9 }, 1: { fontStyle: 'bold' }, 3: { cellWidth: 26 } },
      // Casillero vacío para tachar a mano en la primera columna.
      didDrawCell: (data) => {
        if (data.section !== 'body' || data.column.index !== 0) return
        const size = 4
        doc.setDrawColor(90)
        doc.setLineWidth(0.3)
        doc.rect(data.cell.x + (data.cell.width - size) / 2, data.cell.y + (data.cell.height - size) / 2, size, size)
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
</script>

<template>
  <div class="relative">
    <button type="button" @click="(open = !open), (error = '')" :aria-expanded="open" class="admin-btn-secondary">
      <ClipboardList :size="18" />
      Exportar lista para la entrada
      <ChevronDown :size="16" class="transition-transform" :class="{ 'rotate-180': open }" />
    </button>

    <!-- Click afuera cierra el menú -->
    <div v-if="open" @click="open = false" class="fixed inset-0 z-30"></div>

    <div
      v-if="open"
      class="absolute right-0 z-40 mt-2 w-[min(20rem,calc(100vw-2rem))] rounded-[1.5rem] bg-chalk p-3 shadow-xl ring-1 ring-obsidian/5"
    >
      <p class="px-2 pt-1 text-xs text-obsidian/55">Quienes confirmaron que asisten, con su mesa y un casillero para marcar la llegada.</p>

      <div class="mt-3 flex items-center justify-between gap-2 px-2">
        <span class="text-sm font-bold">Ordenar por</span>
        <div class="flex rounded-full bg-pumice/70 p-0.5 text-sm font-bold">
          <button
            v-for="opt in [
              { id: 'name', label: 'Nombre' },
              { id: 'table', label: 'Mesa' },
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
      </div>

      <div class="mt-3 space-y-1">
        <button
          type="button"
          @click="exportPdf"
          :disabled="!!busy"
          class="flex w-full items-center gap-3 rounded-[1.1rem] px-2 py-2 text-left transition-colors hover:bg-limestone disabled:opacity-50"
        >
          <span class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-nogo/15 text-nogo"><FileText :size="17" /></span>
          <span>
            <span class="block text-sm font-bold">{{ busy === 'pdf' ? 'Generando…' : 'PDF' }}</span>
            <span class="block text-xs text-obsidian/55">Para imprimir y tachar en la puerta</span>
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
      </div>

      <p v-if="error" class="mt-3 rounded-[1rem] bg-nogo/15 px-3 py-2 text-sm font-bold">{{ error }}</p>
    </div>
  </div>
</template>
