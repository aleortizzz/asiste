<script setup>
import { ref, computed, watch, nextTick, onMounted, onUnmounted } from 'vue'
import { onBeforeRouteLeave, useRoute } from 'vue-router'
import { Cake, Heart, Briefcase, ChevronLeft, ChevronRight, Eye, X, Check } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import EnvelopeCover from '../components/EnvelopeCover.vue'
import ColorPicker from '../components/ColorPicker.vue'
import { useEvent } from '../composables/useEvent'
import { useEventPhotos, MAX_GALERIA } from '../composables/useEventPhotos'
import { deriveEnvelopePalette, deriveEnvelopeMonogram } from '../lib/envelope'
import { confirmDialog } from '../composables/useConfirm'

const { event, loadEvent, saveEvent } = useEvent()
const { uploadFile, removeFile, savePhotoColumns } = useEventPhotos()

// El editor va por pasos, en el orden en que se arma una invitación. Todos
// comparten un solo formulario y un solo «Guardar» — los pasos solo ordenan
// la pantalla. `anchor`: parte de la vista previa a la que se desliza.
const STEPS = [
  { id: 'estilo', label: 'Estilo', title: 'Elegí el estilo', desc: 'El tipo de evento, el diseño y los colores de tu invitación.', anchor: 'hero' },
  { id: 'portada', label: 'Portada', title: 'La portada', desc: 'Lo primero que ven tus invitados al abrir el link.', anchor: 'hero' },
  { id: 'sobre', label: 'Sobre', title: 'El sobre', desc: 'Antes de ver la invitación, tus invitados abren un sobre animado. Acá elegís cómo se ve.', anchor: 'hero' },
  { id: 'textos', label: 'Saludo', title: 'Saludo y cierre', desc: 'Unas palabras para tus invitados, al principio y al final.', anchor: 'saludo' },
  { id: 'fiesta', label: 'La fiesta', title: 'La fiesta', desc: 'Cuándo, dónde y todo lo que tus invitados necesitan saber.', anchor: 'fiesta' },
  { id: 'confirmacion', label: 'Confirmaciones', title: 'Confirmaciones', desc: 'Hasta cuándo pueden confirmar y cuántos invitados entran.', anchor: 'rsvp' },
  { id: 'fotos', label: 'Fotos', title: 'Fotos', desc: 'Se guardan solas apenas las subís. Podés ocultar las secciones que no quieras usar.', anchor: 'hero' },
]
// ?paso=<id> abre directo en ese paso (lo usa el checklist del Inicio).
const route = useRoute()
const stepIndex = ref(Math.max(0, STEPS.findIndex((s) => s.id === route.query.paso)))
const step = computed(() => STEPS[stepIndex.value])

function goToStep(i) {
  stepIndex.value = i
  scrollPreviewTo(STEPS[i].anchor)
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

// Fila de pasos: no entra entera en pantallas angostas, así que se desliza de
// costado. Al elegir un paso, la fila se corre para dejarlo centrado, y los
// bordes se difuminan del lado donde quedan pasos ocultos.
const stepsNav = ref(null)
const stepsFade = ref({ left: false, right: false })

function updateStepsFade() {
  const el = stepsNav.value
  if (!el) return
  stepsFade.value = {
    left: el.scrollLeft > 2,
    right: el.scrollLeft + el.clientWidth < el.scrollWidth - 2,
  }
}

function centerActiveStep() {
  const el = stepsNav.value
  const btn = el?.querySelector('[aria-current="step"]')
  if (!btn) return
  el.scrollTo({ left: btn.offsetLeft - (el.clientWidth - btn.offsetWidth) / 2, behavior: 'smooth' })
}
watch(stepIndex, () => nextTick(centerActiveStep))

// Barra de guardado: cuando queda flotando encima de la tarjeta (mismo color)
// se perdía, así que mientras flota pasa a blanco con sombra.
const saveBar = ref(null)
const saveBarStuck = ref(false)
function updateSaveBarStuck() {
  const el = saveBar.value
  if (!el) return
  const stickyTop = parseFloat(getComputedStyle(el).top) || 0
  saveBarStuck.value = window.scrollY > 0 && el.getBoundingClientRect().top <= stickyTop + 1
}

// Flechitas de los costados: corren la fila más o menos media pantalla.
function scrollSteps(dir) {
  const el = stepsNav.value
  if (el) el.scrollBy({ left: dir * el.clientWidth * 0.6, behavior: 'smooth' })
}

// Con mouse, la ruedita (vertical) mueve la fila de costado — solo mientras
// le quede para dónde correrse; si no, deja scrollear la página normal.
function onStepsWheel(e) {
  const el = stepsNav.value
  if (!el || Math.abs(e.deltaX) > Math.abs(e.deltaY)) return
  const atStart = el.scrollLeft <= 0 && e.deltaY < 0
  const atEnd = el.scrollLeft + el.clientWidth >= el.scrollWidth - 1 && e.deltaY > 0
  if (atStart || atEnd) return
  e.preventDefault()
  el.scrollLeft += e.deltaY
}

const stepsMask = computed(() => {
  // Transparente debajo de la flechita y difuminado justo después.
  const l = stepsFade.value.left ? 'transparent 0, transparent 2rem, #000 4rem' : '#000 0'
  const r = stepsFade.value.right ? '#000 calc(100% - 4rem), transparent calc(100% - 2rem), transparent 100%' : '#000 100%'
  const g = `linear-gradient(to right, ${l}, ${r})`
  return { maskImage: g, WebkitMaskImage: g }
})
// `optional`: se puede ocultar toda la sección en la invitación (la portada no).
const photoSections = [
  { slot: 'banner', label: 'Portada', help: 'Foto de fondo de la portada y el hero.', single: true, optional: false },
  { slot: 'retrato', label: 'Saludo', help: 'Carrusel de fotos del saludo.', single: false, optional: true },
  { slot: 'detalle', label: 'La celebración', help: 'Foto de la sección de detalles.', single: true, optional: true },
  { slot: 'momentos', label: 'Momentos', help: 'Carrusel principal de fotos.', single: false, optional: true },
  { slot: 'galeria', label: 'Galería', help: `Grid de hasta ${MAX_GALERIA} fotos.`, single: false, optional: true },
]

function isHidden(slot) {
  return form.value.hidden_sections.includes(slot)
}
async function toggleSection(slot) {
  const h = form.value.hidden_sections
  form.value.hidden_sections = h.includes(slot) ? h.filter((s) => s !== slot) : [...h, slot]
  await persistPhotos()
}

const uploading = ref(false)
const uploadingSlot = ref(null)
const photoError = ref('')
// Sección donde pasó el error, para mostrarlo justo debajo de esa sección
// (antes salía al final de la pestaña y, subiendo la portada, quedaba fuera
// de la pantalla: parecía que no se había cargado nada sin decir por qué).
const photoErrorSlot = ref(null)
const fileInput = ref(null)
let pendingSlot = null

const PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp']
const MB = 1024 * 1024
// La portada va sin tope propio (solo el máximo de Supabase, 50 MB) para
// no perder calidad a pantalla completa; el resto, 5 MB.
const MAX_PHOTO_BYTES = 5 * MB
const MAX_BANNER_BYTES = 50 * MB

function setPhotoError(slot, msg) {
  photoErrorSlot.value = slot
  photoError.value = msg
}

function validatePhoto(slot, file) {
  if (!PHOTO_TYPES.includes(file.type)) {
    const ext = (file.name.split('.').pop() || '').toUpperCase()
    return `El formato ${ext ? `«${ext}» ` : ''}no es compatible. Subí la foto en JPG, PNG o WEBP (las fotos HEIC del iPhone se pueden exportar como JPG).`
  }
  const max = slot === 'banner' ? MAX_BANNER_BYTES : MAX_PHOTO_BYTES
  if (file.size > max) {
    return `La foto pesa ${(file.size / MB).toFixed(1)} MB y el máximo para esta sección es ${max / MB} MB.`
  }
  return ''
}

// Supabase devuelve los errores de Storage en inglés: traducimos los
// habituales y, si es otro, mostramos el original para poder diagnosticarlo.
function uploadErrorMessage(err) {
  const msg = err?.message || ''
  if (/maximum allowed size|too large|413/i.test(msg)) {
    return 'La foto supera el tamaño máximo permitido por el servidor.'
  }
  if (/mime type|invalid_mime/i.test(msg)) {
    return 'El formato de la foto no es compatible. Subila en JPG, PNG o WEBP.'
  }
  return `No se pudo subir la foto${msg ? `: ${msg}` : '.'}`
}

function pickPhoto(slot) {
  if (!event.value) {
    setPhotoError(slot, 'Guardá tu invitación primero (botón «Guardar») para poder subir fotos.')
    return
  }
  setPhotoError(null, '')
  pendingSlot = slot
  if (fileInput.value) {
    fileInput.value.value = ''
    fileInput.value.click()
  }
}

async function onFilePicked(e) {
  const file = e.target.files?.[0]
  if (!file || !pendingSlot) return
  const slot = pendingSlot
  const single = photoSections.find((s) => s.slot === slot)?.single
  const invalid = validatePhoto(slot, file)
  if (invalid) {
    setPhotoError(slot, invalid)
    return
  }
  uploading.value = true
  uploadingSlot.value = slot
  setPhotoError(null, '')
  try {
    if (single && form.value[slot][0]) await removeFile(form.value[slot][0].path)
    const item = await uploadFile(slot, file, event.value.owner_user_id)
    if (single) form.value[slot] = [item]
    else form.value[slot] = [...form.value[slot], item]
    await persistPhotos()
  } catch (err) {
    setPhotoError(slot, uploadErrorMessage(err))
  } finally {
    uploading.value = false
  }
}

async function removePhoto(slot, i) {
  const item = form.value[slot][i]
  // Borra el archivo del servidor de verdad: sin confirmación, un toque de
  // más en el celular la perdía para siempre.
  const ok = await confirmDialog({
    title: '¿Eliminar esta foto?',
    message: 'Se borra de la invitación y del servidor. No se puede deshacer.',
    confirmText: 'Eliminar',
    tone: 'danger',
  })
  if (!ok) return
  uploading.value = true
  try {
    await removeFile(item?.path)
    form.value[slot] = form.value[slot].filter((_, idx) => idx !== i)
    await persistPhotos()
  } catch (err) {
    setPhotoError(slot, err.message || 'No se pudo eliminar la foto.')
  } finally {
    uploading.value = false
  }
}

async function persistPhotos() {
  if (!event.value) return
  await savePhotoColumns(event.value.id, {
    banner: form.value.banner,
    retrato: form.value.retrato,
    detalle: form.value.detalle,
    momentos: form.value.momentos,
    galeria: form.value.galeria,
    hidden_sections: form.value.hidden_sections,
  })
}

function canAdd(section) {
  const arr = form.value[section.slot]
  if (section.single) return arr.length === 0
  if (section.slot === 'galeria') return arr.length < MAX_GALERIA
  return true
}

// Plantillas visuales disponibles — ver src/components/invitation-templates/.
// Agregar una plantilla nueva ahí también implica sumarla acá para que el
// host la pueda elegir.
// El color (fondo + acento) es independiente de la plantilla — cada una es
// solo diseño/tipografía. Las swatches de acá son solo tipográficas
// (grises), no de color: el color real se elige aparte, más abajo.
const INVITATION_TEMPLATES = [
  {
    value: 'clasico',
    label: 'Clásica',
    help: 'Sobre animado y tipografía cursiva, estilo romántico.',
    font: "'Dancing Script', cursive",
  },
  {
    value: 'partiful',
    label: 'Partiful',
    help: 'Tipografía grotesca, pills y composición editorial moderna.',
    font: "'Space Grotesk', sans-serif",
  },
  {
    value: 'craft',
    label: 'Craft',
    help: 'Serif editorial, cards planas y un hero dramático al abrir.',
    font: "'Bodoni Moda', serif",
  },
]

// Los datos concretos (fecha, salón, dirección…) quedan vacíos a propósito:
// un valor falso ahí sería peor que uno vacío.
// Paleta curada de fondos para invitaciones (blanco puro primero para el que
// no quiere color, después pasteles claros, oscuros al final).
const BG_PRESETS = [
  '#ffffff',
  '#fdf7f1', '#f9f1e7', '#f6ede2', '#faf3f4', '#f7eef4',
  '#f3e8ef', '#eef1f7', '#e9eef4', '#eaf1ec', '#eef4ee',
  '#f0f0eb', '#f4f1ea', '#e7ded2', '#dfe6e2', '#d9e2ec',
  '#e6dde8', '#3b3a44', '#2a3b34', '#2e3a4d', '#43303a',
]

// Paleta curada de colores "principales" (acento) — evita el reflejo típico
// de morado/celeste de IA; variedad de familias para que no todas las
// invitaciones terminen pareciendo la misma con distinto fondo.
const PRIMARY_PRESETS = [
  '#9f1239', '#e11d48', '#c2410c', '#b45309', '#65a30d',
  '#0e7490', '#1d4ed8', '#7c3aed', '#be185d', '#1d3023',
  '#000000', '#334155',
]

const EMPTY = {
  template: 'clasico',
  hero_kicker: '',
  hero_title: '',
  monogram: '',
  envelope_text: '',
  hero_subtitle: '',
  intro_text: '',
  closing_text: '',
  bg_color: '#fdf7f1',
  primary_color: '#9f1239',
  envelope_color: '',
  music_url: '',
  banner: [],
  retrato: [],
  detalle: [],
  momentos: [],
  galeria: [],
  hidden_sections: [],
  event_date: '',
  reception_time: '',
  end_time: '',
  venue_name: '',
  venue_address: '',
  maps_url: '',
  dress_code: '',
  rsvp_deadline: '',
  rsvp_deadline_strict: false,
  notes: '',
  gift_alias: '',
}

// Textos genéricos según el tipo de evento. El switch de arriba cambia entre
// estos; solo pisa un campo si el usuario todavía no lo tocó (sigue igual al
// template anterior o vacío).
const TEMPLATES = {
  cumpleanos: {
    hero_kicker: 'Te invito a mis',
    hero_title: 'Antonella',
    hero_subtitle: '',
    intro_text:
      'Hay días que quedan guardados para siempre en el corazón. Nos encantaría compartir este con ustedes.',
    closing_text: '¡Te esperamos!',
  },
  casamiento: {
    hero_kicker: 'Nos casamos',
    hero_title: 'Ana & Luis',
    hero_subtitle: '',
    intro_text:
      'Con toda la ilusión queremos compartir con ustedes el día en que unimos nuestras vidas.',
    closing_text: '¡Los esperamos!',
  },
  empresarial: {
    hero_kicker: 'Te invitamos a',
    hero_title: 'Encuentro Anual',
    hero_subtitle: '',
    intro_text:
      'Queremos compartir con ustedes un encuentro para celebrar lo logrado juntos y todo lo que viene.',
    closing_text: '¡Los esperamos!',
  },
}

const TYPE_LABELS = { cumpleanos: 'Cumpleaños', casamiento: 'Casamiento', empresarial: 'Empresarial' }

const eventType = ref('cumpleanos')
const form = ref({ ...EMPTY, ...TEMPLATES.cumpleanos })

// Los textos que siguen vacíos o iguales a un ejemplo (de cualquier tipo) se
// cambian solos. Si hay textos propios, se pregunta antes de pisarlos: sin
// preguntar, en una invitación ya escrita el cambio de tipo no hacía nada
// visible y parecía roto.
async function applyTemplate(newType) {
  if (newType === eventType.value) return
  const next = TEMPLATES[newType]
  const keys = Object.keys(next)
  const isExample = (key) => {
    const value = (form.value[key] ?? '').trim()
    return value === '' || Object.values(TEMPLATES).some((t) => t[key] === value)
  }
  const custom = keys.filter((key) => !isExample(key) && form.value[key] !== next[key])

  let replaceCustom = false
  if (custom.length) {
    replaceCustom = await confirmDialog({
      title: '¿Usar los textos de ejemplo?',
      message: `Ya escribiste textos propios (título, saludo o cierre). ¿Los reemplazamos por los de ejemplo de «${TYPE_LABELS[newType]}»? Si decís que no, se cambia el tipo y tus textos quedan como están.`,
      confirmText: 'Reemplazar textos',
      cancelText: 'Mantener los míos',
    })
  }

  for (const key of keys) {
    if (replaceCustom || isExample(key)) form.value[key] = next[key]
  }
  eventType.value = newType
}

// Preview del sobre en la pestaña "Sobre": misma derivación que usa la
// invitación real (ver src/lib/envelope.js), pero calculada acá en vivo a
// partir del form, para no depender de guardar/recargar para verla.
const envelopePreviewPalette = computed(() =>
  deriveEnvelopePalette(form.value.bg_color, form.value.primary_color, form.value.envelope_color),
)
const envelopePreviewMonogram = computed(() =>
  deriveEnvelopeMonogram(form.value.monogram, form.value.hero_title),
)
const TEMPLATE_FONTS = {
  clasico: "'Dancing Script', cursive",
  partiful: "'Space Grotesk', sans-serif",
  craft: "'Bodoni Moda', serif",
}
const envelopePreviewOpen = ref(false)
const envelopePreviewFont = computed(() => TEMPLATE_FONTS[form.value.template] || 'inherit')

// La opción de cerrar confirmaciones solo aparece si la base ya tiene la
// columna (ver onSubmit) — hasta correr la migración, la fecha es informativa.
const strictAvailable = computed(() => !!event.value && 'rsvp_deadline_strict' in event.value)

const hasGuestLimit = ref(false)
const guestLimit = ref(1)
const saving = ref(false)
const saveError = ref('')

// --- Cambios sin guardar ---------------------------------------------------
// Foto del formulario tal como quedó guardado, para avisar si hay cambios
// pendientes y no perderlos al salir. Las fotos no cuentan: se guardan solas.
function snapshot() {
  // eslint-disable-next-line no-unused-vars
  const { banner, retrato, detalle, momentos, galeria, hidden_sections, ...fields } = form.value
  return JSON.stringify({
    ...fields,
    eventType: eventType.value,
    hasGuestLimit: hasGuestLimit.value,
    guestLimit: guestLimit.value,
  })
}
const savedSnapshot = ref(null)
const isDirty = computed(() => savedSnapshot.value !== null && snapshot() !== savedSnapshot.value)

async function markSaved() {
  await nextTick() // que los selectores de color terminen de normalizar el hex
  savedSnapshot.value = snapshot()
}

onBeforeRouteLeave(async () => {
  if (!isDirty.value) return
  const leave = await confirmDialog({
    title: 'Cambios sin guardar',
    message: 'Si salís ahora, se pierden los cambios que hiciste en tu invitación.',
    confirmText: 'Salir sin guardar',
    cancelText: 'Seguir editando',
    tone: 'danger',
  })
  if (!leave) return false
})

function onBeforeUnload(e) {
  if (isDirty.value) e.preventDefault()
}

onMounted(async () => {
  await loadEvent()
  if (event.value) {
    eventType.value = event.value.event_type ?? 'cumpleanos'
    form.value = {
      template: event.value.template ?? 'clasico',
      // Eventos viejos sin hero_title: usamos su `name` como texto principal.
      hero_title: event.value.hero_title ?? event.value.name ?? '',
      monogram: event.value.monogram ?? '',
      envelope_text: event.value.envelope_text ?? '',
      hero_kicker: event.value.hero_kicker ?? '',
      hero_subtitle: event.value.hero_subtitle ?? '',
      intro_text: event.value.intro_text ?? '',
      closing_text: event.value.closing_text ?? '',
      bg_color: event.value.bg_color ?? '#fdf7f1',
      primary_color: event.value.primary_color ?? '#9f1239',
      envelope_color: event.value.envelope_color ?? '',
      music_url: event.value.music_url ?? '',
      banner: event.value.banner ?? [],
      retrato: event.value.retrato ?? [],
      detalle: event.value.detalle ?? [],
      momentos: event.value.momentos ?? [],
      galeria: event.value.galeria ?? [],
      hidden_sections: event.value.hidden_sections ?? [],
      event_date: event.value.event_date ?? '',
      reception_time: event.value.reception_time ?? '',
      end_time: event.value.end_time ?? '',
      venue_name: event.value.venue_name ?? '',
      venue_address: event.value.venue_address ?? '',
      maps_url: event.value.maps_url ?? '',
      dress_code: event.value.dress_code ?? '',
      rsvp_deadline: event.value.rsvp_deadline ?? '',
      rsvp_deadline_strict: event.value.rsvp_deadline_strict ?? false,
      notes: event.value.notes ?? '',
      gift_alias: event.value.gift_alias ?? '',
    }
    hasGuestLimit.value = event.value.guest_limit != null
    guestLimit.value = event.value.guest_limit ?? 1
  }
  await markSaved()
})

// Postgres no acepta '' para columnas date/time — hay que mandar null
// cuando el campo quedó vacío.
const emptyAsNull = (value) => (value === '' ? null : value)

async function onSubmit() {
  saving.value = true
  saveError.value = ''
  try {
    const fields = { ...form.value }
    // rsvp_deadline_strict es una columna nueva (20260928_cierre_confirmaciones.sql):
    // si la base todavía no la tiene, mandarla haría fallar TODO el guardado.
    // Solo se manda si el evento cargado ya la trae.
    if (!event.value || !('rsvp_deadline_strict' in event.value)) delete fields.rsvp_deadline_strict
    // Sin fecha límite no hay nada que cerrar.
    else if (!form.value.rsvp_deadline) fields.rsvp_deadline_strict = false
    await saveEvent({
      ...fields,
      event_type: eventType.value,
      // `events.name` es NOT NULL y solo se usa internamente: lo derivamos del texto principal.
      name: form.value.hero_title?.trim() || 'Mi evento',
      hero_kicker: emptyAsNull(form.value.hero_kicker),
      hero_title: emptyAsNull(form.value.hero_title),
      monogram: emptyAsNull(form.value.monogram?.trim()),
      envelope_text: emptyAsNull(form.value.envelope_text?.trim()),
      envelope_color: emptyAsNull(form.value.envelope_color),
      hero_subtitle: emptyAsNull(form.value.hero_subtitle),
      intro_text: emptyAsNull(form.value.intro_text),
      closing_text: emptyAsNull(form.value.closing_text),
      music_url: emptyAsNull(form.value.music_url?.trim()),
      event_date: emptyAsNull(form.value.event_date),
      reception_time: emptyAsNull(form.value.reception_time),
      end_time: emptyAsNull(form.value.end_time),
      rsvp_deadline: emptyAsNull(form.value.rsvp_deadline),
      guest_limit: hasGuestLimit.value ? guestLimit.value : null,
    })
    await markSaved()
  } catch (err) {
    saveError.value = `No se pudo guardar: ${err.message}`
  } finally {
    saving.value = false
  }
}

// --- Vista previa en vivo -------------------------------------------------
// El iframe carga /admin/salon/preview y recibe el borrador por postMessage
// (y sessionStorage como respaldo / carga inicial).
const STORAGE_KEY = 'invite-preview-draft'
const previewUrl = '/admin/salon/preview'
const frameDesktop = ref(null)
const frameMobile = ref(null)
const showMobilePreview = ref(false)

// Arma el objeto que espera InvitationView a partir del formulario, con datos
// de ejemplo para las partes que dependen de la invitación puntual (familia,
// invitados) y no del evento.
const previewInvite = computed(() => ({
  ...form.value,
  event_name: form.value.hero_title,
  family_name: 'Familia García',
  named_by_host: false,
  allowed_guests: 2,
  status: 'pending',
  guests: [],
  // Solo lectura: el plan lo activa TizDigital, no es un campo del form.
  plan: event.value?.plan ?? 'basico',
}))

function pushPreview() {
  // JSON round-trip: saca los Proxy reactivos de Vue (postMessage no los puede
  // clonar) y deja un objeto plano.
  const payload = JSON.stringify(previewInvite.value)
  try {
    sessionStorage.setItem(STORAGE_KEY, payload)
  } catch {
    /* modo privado */
  }
  const msg = { type: 'invite-preview', invite: JSON.parse(payload) }
  frameDesktop.value?.contentWindow?.postMessage(msg, window.location.origin)
  frameMobile.value?.contentWindow?.postMessage(msg, window.location.origin)
}

function onFrameMessage(e) {
  if (e.origin !== window.location.origin) return
  if (e.data?.type === 'invite-preview-ready') pushPreview()
}

// El iframe SIEMPRE renderiza a un ancho real de celular (390px) para que el
// texto haga el mismo wrap que en un teléfono de verdad. Si la pantalla de
// quien edita no tiene altura para mostrarlo a tamaño completo, lo escalamos
// visualmente con transform en vez de angostarlo — angostarlo cambiaría cómo
// se acomoda el texto y mentiría sobre cómo se ve en un celular real.
const PHONE_W = 390
const PHONE_H = 844
const previewScale = ref(1)

function updateScale() {
  // El cartel de superadmin (si está) también come altura: --banner-h.
  const raw = getComputedStyle(document.documentElement).getPropertyValue('--banner-h').trim()
  const bannerPx = raw.endsWith('rem') ? parseFloat(raw) * 16 : parseFloat(raw) || 0
  const available = window.innerHeight - 170 - bannerPx // nav + paddings + label
  previewScale.value = Math.min(1, Math.max(0.4, available / PHONE_H))
}

// Al enfocar un campo, desliza la vista previa hasta la sección que ese campo
// modifica (data-preview en el input → data-anchor en la invitación).
function onFieldFocus(e) {
  const anchor = e.target?.dataset?.preview
  if (anchor) scrollPreviewTo(anchor)
}

function scrollPreviewTo(anchor) {
  const msg = { type: 'invite-preview-scroll', anchor }
  frameDesktop.value?.contentWindow?.postMessage(msg, window.location.origin)
  frameMobile.value?.contentWindow?.postMessage(msg, window.location.origin)
}

watch(previewInvite, pushPreview, { deep: true })

onMounted(() => {
  pushPreview()
  updateScale()
  window.addEventListener('message', onFrameMessage)
  window.addEventListener('resize', updateScale)
  window.addEventListener('beforeunload', onBeforeUnload)
  window.addEventListener('resize', updateStepsFade)
  window.addEventListener('scroll', updateSaveBarStuck, { passive: true })
  updateStepsFade()
  nextTick(centerActiveStep)
})
onUnmounted(() => {
  window.removeEventListener('message', onFrameMessage)
  window.removeEventListener('resize', updateScale)
  window.removeEventListener('beforeunload', onBeforeUnload)
  window.removeEventListener('resize', updateStepsFade)
  window.removeEventListener('scroll', updateSaveBarStuck)
})
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto flex max-w-[1200px] justify-center gap-10 px-4 pt-4 pb-32 lg:px-8 lg:pt-8 xl:gap-14">
      <!-- ================= EDITOR ================= -->
      <div class="w-full min-w-0 max-w-2xl">
        <h1 class="admin-display text-5xl sm:text-6xl">Creá tu invitación</h1>
        <p class="mt-3 max-w-md text-obsidian/60">
          Completá los pasos en el orden que quieras. La vista previa se actualiza mientras
          escribís.
        </p>

        <!-- Barra de guardado: siempre a mano mientras se edita. -->
        <div
          ref="saveBar"
          :class="
            saveBarStuck
              ? 'bg-chalk shadow-[0_14px_36px_-12px_rgba(7,6,7,0.35)] ring-1 ring-obsidian/10'
              : 'bg-limestone'
          "
          class="sticky top-[calc(4.5rem+var(--banner-h,0px))] z-30 mt-6 flex items-center justify-between gap-3 rounded-full py-2 pr-2 pl-5 transition-[background-color,box-shadow] duration-200 lg:top-[calc(1rem+var(--banner-h,0px))]"
        >
          <p class="flex min-w-0 items-center gap-2 text-sm">
            <span
              class="h-2.5 w-2.5 shrink-0 rounded-full"
              :class="saveError ? 'bg-red-600' : isDirty ? 'bg-accent' : 'bg-obsidian/25'"
            ></span>
            <span class="truncate" :class="saveError ? 'text-red-700' : ''">
              <template v-if="saving">Guardando…</template>
              <template v-else-if="saveError">{{ saveError }}</template>
              <template v-else-if="isDirty">Tenés cambios sin guardar</template>
              <template v-else-if="event">Todo guardado</template>
              <template v-else>Todavía no guardaste tu invitación</template>
            </span>
          </p>
          <button type="button" @click="onSubmit" :disabled="saving || (!isDirty && !!event)" class="admin-btn-primary shrink-0">
            <Check v-if="!isDirty && event && !saving" :size="18" />
            {{ saving ? 'Guardando…' : !isDirty && event ? 'Guardado' : 'Guardar' }}
          </button>
        </div>

        <!-- Pasos -->
        <div class="relative -mx-4 mt-5 lg:mx-0">
          <nav
            ref="stepsNav"
            @scroll.passive="updateStepsFade"
            @wheel="onStepsWheel"
            :style="stepsMask"
            class="relative overflow-x-auto px-4 [scrollbar-width:none] lg:px-0 [&::-webkit-scrollbar]:hidden"
          >
            <ol class="flex w-max gap-1.5">
              <li v-for="(s, i) in STEPS" :key="s.id">
                <button
                  type="button"
                  @click="goToStep(i)"
                  :aria-current="stepIndex === i ? 'step' : undefined"
                  :class="stepIndex === i ? 'bg-accent text-chalk' : 'bg-limestone/60 hover:bg-limestone'"
                  class="flex items-center gap-1.5 rounded-full py-1 pr-3 pl-1 text-[0.8125rem] font-bold transition-colors"
                >
                  <span
                    :class="stepIndex === i ? 'bg-chalk text-accent' : 'bg-chalk'"
                    class="grid h-6 w-6 place-items-center rounded-full text-[0.6875rem]"
                  >
                    {{ i + 1 }}
                  </span>
                  {{ s.label }}
                </button>
              </li>
            </ol>
          </nav>

          <!-- Flechitas: aparecen solo del lado donde quedan pasos ocultos. -->
          <button
            v-show="stepsFade.left"
            type="button"
            @click="scrollSteps(-1)"
            aria-label="Ver pasos anteriores"
            class="absolute top-1/2 left-2 grid h-7 w-7 -translate-y-1/2 place-items-center rounded-full bg-obsidian text-chalk lg:left-0"
          >
            <ChevronLeft :size="16" />
          </button>
          <button
            v-show="stepsFade.right"
            type="button"
            @click="scrollSteps(1)"
            aria-label="Ver más pasos"
            class="absolute top-1/2 right-2 grid h-7 w-7 -translate-y-1/2 place-items-center rounded-full bg-obsidian text-chalk lg:right-0"
          >
            <ChevronRight :size="16" />
          </button>
        </div>

        <!-- Tarjeta del paso actual -->
        <form
          @submit.prevent="onSubmit"
          @focusin="onFieldFocus"
          class="mt-4 rounded-[2rem] bg-limestone p-6 sm:rounded-[2.5rem] sm:p-10"
        >
          <p class="text-xs font-bold tracking-[0.2em] text-obsidian/45 uppercase">
            Paso {{ stepIndex + 1 }} de {{ STEPS.length }}
          </p>
          <h2 class="admin-display mt-2 text-4xl sm:text-5xl">{{ step.title }}</h2>
          <p class="mt-2 text-obsidian/60">{{ step.desc }}</p>

          <div class="mt-8 space-y-8">
            <!-- ========== 1. ESTILO ========== -->
            <template v-if="step.id === 'estilo'">
              <div>
                <p class="admin-label">¿Qué tipo de evento es?</p>
                <p class="admin-help">Cambia los textos de ejemplo. Lo que ya escribiste no se toca.</p>
                <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
                  <button
                    v-for="t in [
                      { id: 'cumpleanos', label: 'Cumpleaños', icon: Cake },
                      { id: 'casamiento', label: 'Casamiento', icon: Heart },
                      { id: 'empresarial', label: 'Empresarial', icon: Briefcase },
                    ]"
                    :key="t.id"
                    type="button"
                    @click="applyTemplate(t.id)"
                    :class="eventType === t.id ? 'border-obsidian bg-chalk' : 'border-transparent bg-chalk/60 hover:bg-chalk'"
                    class="flex items-center gap-3 rounded-[1.5rem] border-2 p-4 text-left font-bold transition-colors"
                  >
                    <span
                      :class="eventType === t.id ? 'bg-accent text-chalk' : 'bg-pumice'"
                      class="grid h-10 w-10 shrink-0 place-items-center rounded-full"
                    >
                      <component :is="t.icon" :size="18" />
                    </span>
                    {{ t.label }}
                  </button>
                </div>
              </div>

              <div>
                <p class="admin-label">Diseño</p>
                <p class="admin-help">Cada diseño tiene su tipografía y su estilo. Los colores los elegís abajo.</p>
                <div class="grid gap-3 sm:grid-cols-3">
                  <button
                    v-for="t in INVITATION_TEMPLATES"
                    :key="t.value"
                    type="button"
                    data-preview="hero"
                    @click="form.template = t.value"
                    :class="form.template === t.value ? 'border-obsidian bg-chalk' : 'border-transparent bg-chalk/60 hover:bg-chalk'"
                    class="relative rounded-[1.5rem] border-2 p-3 text-left transition-colors"
                  >
                    <span
                      class="flex h-20 items-center justify-center rounded-[1rem] text-3xl"
                      :style="{ fontFamily: t.font, backgroundColor: form.bg_color, color: form.primary_color }"
                    >
                      Aa
                    </span>
                    <span class="mt-3 block font-bold">{{ t.label }}</span>
                    <span class="mt-0.5 block text-xs leading-snug text-obsidian/55">{{ t.help }}</span>
                    <span
                      v-if="form.template === t.value"
                      class="absolute top-2 right-2 grid h-6 w-6 place-items-center rounded-full bg-accent text-chalk"
                    >
                      <Check :size="14" />
                    </span>
                  </button>
                </div>
              </div>

              <div>
                <p class="admin-label">Color de fondo</p>
                <p class="admin-help">El fondo de toda la invitación.</p>
                <ColorPicker v-model="form.bg_color" :presets="BG_PRESETS" preview="saludo" name="Color de fondo">
                  <a href="https://colorhunt.co" target="_blank" rel="noopener" class="text-xs text-obsidian/55 underline">
                    buscar más paletas
                  </a>
                </ColorPicker>
              </div>

              <div>
                <p class="admin-label">Color principal</p>
                <p class="admin-help">Botones, líneas y detalles. El sobre también lo usa, salvo que le elijas uno propio.</p>
                <ColorPicker v-model="form.primary_color" :presets="PRIMARY_PRESETS" preview="saludo" name="Color principal" />
              </div>
            </template>

            <!-- ========== 2. PORTADA ========== -->
            <template v-else-if="step.id === 'portada'">
              <div>
                <label class="admin-label" for="f-kicker">Línea de arriba</label>
                <input id="f-kicker" v-model="form.hero_kicker" data-preview="hero" placeholder="Ej. Te invito a mis · Nos casamos" class="admin-input" />
              </div>
              <div>
                <label class="admin-label" for="f-title">Texto principal</label>
                <p class="admin-help">El nombre grande de la portada.</p>
                <input id="f-title" v-model="form.hero_title" data-preview="hero" placeholder="Ej. Antonella · Ana & Luis" class="admin-input" />
              </div>
              <div>
                <label class="admin-label" for="f-subtitle">Línea de abajo</label>
                <input id="f-subtitle" v-model="form.hero_subtitle" data-preview="hero" placeholder="Opcional" class="admin-input" />
              </div>
              <div>
                <label class="admin-label" for="f-date">Fecha del evento</label>
                <input id="f-date" v-model="form.event_date" type="date" data-preview="hero" class="admin-input" />
              </div>
              <div>
                <label class="admin-label" for="f-music">Música</label>
                <p class="admin-help">Pegá el link de una canción de YouTube. Suena cuando abren el sobre. Dejalo vacío si no querés música.</p>
                <input id="f-music" v-model="form.music_url" type="url" data-preview="hero" placeholder="https://www.youtube.com/watch?v=…" class="admin-input" />
              </div>
            </template>

            <!-- ========== 3. SOBRE ========== -->
            <template v-else-if="step.id === 'sobre'">
              <div>
                <div class="flex justify-center overflow-hidden rounded-[1.5rem]" :style="{ backgroundColor: form.bg_color }">
                  <EnvelopeCover
                    inline
                    :opening="envelopePreviewOpen"
                    :monogram-short="envelopePreviewMonogram.short"
                    :monogram-full="envelopePreviewMonogram.full"
                    :text="form.envelope_text?.trim() || ''"
                    :monogram-font="envelopePreviewFont"
                    v-bind="envelopePreviewPalette"
                  />
                </div>
                <button type="button" @click="envelopePreviewOpen = !envelopePreviewOpen" class="admin-btn-secondary mt-3 w-full">
                  {{ envelopePreviewOpen ? 'Cerrar el sobre' : 'Abrir el sobre para ver la carta' }}
                </button>
              </div>

              <div>
                <label class="admin-label" for="f-seal">Sello</label>
                <p class="admin-help">
                  Lo que va en el círculo del sobre: hasta 3 letras o un símbolo (♥, ✦). Si lo dejás
                  vacío, usamos las iniciales del texto principal.
                </p>
                <input id="f-seal" v-model="form.monogram" data-preview="hero" maxlength="3" placeholder="Ej. XV" class="admin-input !w-32 text-center" />
              </div>

              <div>
                <label class="admin-label" for="f-letter">Texto de la carta</label>
                <p class="admin-help">Una frase corta que se lee cuando la carta sale del sobre. Opcional.</p>
                <input id="f-letter" v-model="form.envelope_text" maxlength="40" placeholder="Ej. Mis XV · Te invitamos" class="admin-input" />
                <p class="mt-1.5 pr-4 text-right text-xs text-obsidian/45">{{ form.envelope_text?.length || 0 }}/40</p>
              </div>

              <div>
                <div class="flex items-center justify-between gap-4">
                  <div>
                    <p class="admin-label !mb-0">Color propio para el sobre</p>
                    <p class="admin-help !mb-0">Si no, usa un tono claro del color principal.</p>
                  </div>
                  <button
                    type="button"
                    role="switch"
                    :aria-checked="!!form.envelope_color"
                    aria-label="Color propio para el sobre"
                    @click="form.envelope_color = form.envelope_color ? '' : '#000000'"
                    :class="form.envelope_color ? 'bg-accent' : 'bg-obsidian/20'"
                    class="relative h-7 w-12 shrink-0 rounded-full transition-colors"
                  >
                    <span
                      class="absolute top-1 left-1 h-5 w-5 rounded-full bg-chalk transition-transform"
                      :class="form.envelope_color ? 'translate-x-5' : ''"
                    ></span>
                  </button>
                </div>
                <ColorPicker
                  v-if="form.envelope_color"
                  v-model="form.envelope_color"
                  :presets="PRIMARY_PRESETS"
                  name="Color del sobre"
                  class="mt-4"
                />
              </div>
            </template>

            <!-- ========== 4. SALUDO Y CIERRE ========== -->
            <template v-else-if="step.id === 'textos'">
              <div>
                <label class="admin-label" for="f-intro">Saludo</label>
                <p class="admin-help">El párrafo que aparece después de la portada.</p>
                <textarea id="f-intro" v-model="form.intro_text" rows="4" data-preview="saludo" placeholder="Ej. Hay días que quedan guardados para siempre…" class="admin-input"></textarea>
              </div>
              <div>
                <label class="admin-label" for="f-closing">Frase de cierre</label>
                <p class="admin-help">Lo último que leen, al final de la invitación.</p>
                <input id="f-closing" v-model="form.closing_text" data-preview="cierre" placeholder="Ej. ¡Los esperamos!" class="admin-input" />
              </div>
            </template>

            <!-- ========== 5. LA FIESTA ========== -->
            <template v-else-if="step.id === 'fiesta'">
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="admin-label" for="f-start">Empieza</label>
                  <input id="f-start" v-model="form.reception_time" type="time" data-preview="fiesta" class="admin-input" />
                </div>
                <div>
                  <label class="admin-label" for="f-end">Termina</label>
                  <input id="f-end" v-model="form.end_time" type="time" data-preview="fiesta" class="admin-input" />
                </div>
              </div>
              <div>
                <label class="admin-label" for="f-venue">Nombre del lugar</label>
                <input id="f-venue" v-model="form.venue_name" data-preview="fiesta" placeholder="Ej. Salón Los Álamos" class="admin-input" />
              </div>
              <div>
                <label class="admin-label" for="f-address">Dirección</label>
                <input id="f-address" v-model="form.venue_address" data-preview="fiesta" placeholder="Ej. Av. Siempre Viva 742" class="admin-input" />
              </div>
              <div>
                <label class="admin-label" for="f-maps">Link de Google Maps</label>
                <p class="admin-help">En Google Maps: buscá el lugar → Compartir → Copiar vínculo.</p>
                <input id="f-maps" v-model="form.maps_url" type="url" data-preview="fiesta" placeholder="https://maps.app.goo.gl/…" class="admin-input" />
              </div>
              <div>
                <label class="admin-label" for="f-dress">Código de vestimenta</label>
                <input id="f-dress" v-model="form.dress_code" data-preview="fiesta" placeholder="Ej. Elegante sport" class="admin-input" />
              </div>
              <div>
                <label class="admin-label" for="f-gift">Alias para regalos</label>
                <p class="admin-help">Para que puedan hacer una transferencia. Opcional.</p>
                <input id="f-gift" v-model="form.gift_alias" data-preview="regalos" placeholder="Ej. antonella.15" class="admin-input" />
              </div>
              <div>
                <label class="admin-label" for="f-notes">Algo más que quieras contar</label>
                <textarea id="f-notes" v-model="form.notes" rows="3" data-preview="fiesta" placeholder="Ej. Hay estacionamiento · Evento sin niños" class="admin-input"></textarea>
              </div>
            </template>

            <!-- ========== 6. CONFIRMACIONES ========== -->
            <template v-else-if="step.id === 'confirmacion'">
              <div>
                <label class="admin-label" for="f-deadline">Fecha límite para confirmar</label>
                <p class="admin-help">Se muestra en la invitación para que no se olviden de responder.</p>
                <input id="f-deadline" v-model="form.rsvp_deadline" type="date" data-preview="rsvp" class="admin-input" />
              </div>
              <div v-if="form.rsvp_deadline">
                <p class="admin-label">Tipo de fecha límite</p>
                <p v-if="!strictAvailable" class="admin-help">
                  La fecha se muestra como referencia: las confirmaciones siguen abiertas después.
                </p>
                <div v-else class="grid gap-3 sm:grid-cols-2">
                  <button
                    v-for="opt in [
                      { value: false, label: 'Fecha orientativa', help: 'Se muestra como referencia. Las confirmaciones siguen abiertas después de esa fecha.' },
                      { value: true, label: 'Fecha de cierre', help: 'Pasada esa fecha, no se aceptan nuevas confirmaciones ni cambios.' },
                    ]"
                    :key="opt.label"
                    type="button"
                    data-preview="rsvp"
                    @click="form.rsvp_deadline_strict = opt.value"
                    :class="form.rsvp_deadline_strict === opt.value ? 'border-obsidian bg-chalk' : 'border-transparent bg-chalk/60 hover:bg-chalk'"
                    class="rounded-[1.5rem] border-2 p-4 text-left transition-colors"
                  >
                    <span class="block font-bold">{{ opt.label }}</span>
                    <span class="mt-0.5 block text-sm leading-snug text-obsidian/55">{{ opt.help }}</span>
                  </button>
                </div>
              </div>
              <div>
                <p class="admin-label">¿Hay un máximo de invitados?</p>
                <p class="admin-help">Con un tope, no vas a poder repartir más invitaciones que ese número.</p>
                <div class="grid grid-cols-2 gap-3">
                  <button
                    v-for="opt in [
                      { value: false, label: 'Sin tope' },
                      { value: true, label: 'Con tope' },
                    ]"
                    :key="opt.label"
                    type="button"
                    @click="hasGuestLimit = opt.value"
                    :class="hasGuestLimit === opt.value ? 'border-obsidian bg-chalk' : 'border-transparent bg-chalk/60 hover:bg-chalk'"
                    class="rounded-full border-2 px-4 py-3 font-bold transition-colors"
                  >
                    {{ opt.label }}
                  </button>
                </div>
                <div v-if="hasGuestLimit" class="mt-4">
                  <label class="admin-label" for="f-limit">Cantidad máxima</label>
                  <input id="f-limit" v-model.number="guestLimit" type="number" min="1" data-preview="rsvp" class="admin-input !w-40" />
                </div>
              </div>
            </template>

            <!-- ========== 7. FOTOS ========== -->
            <template v-else-if="step.id === 'fotos'">
              <p v-if="!event" class="rounded-[1.25rem] bg-accent-soft px-4 py-3 text-sm text-accent">
                Guardá tu invitación primero (botón «Guardar», arriba) para poder subir fotos.
              </p>

              <div v-for="s in photoSections" :key="s.slot" class="rounded-[1.5rem] bg-chalk p-4 sm:p-5">
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <p class="font-bold">{{ s.label }}</p>
                    <p class="text-sm text-obsidian/55">
                      <template v-if="s.optional && isHidden(s.slot)">Oculta: no aparece en la invitación.</template>
                      <template v-else>{{ s.help }}</template>
                    </p>
                  </div>
                  <button
                    v-if="s.optional"
                    type="button"
                    role="switch"
                    :aria-checked="!isHidden(s.slot)"
                    :aria-label="`Mostrar la sección ${s.label}`"
                    @click="toggleSection(s.slot)"
                    :class="isHidden(s.slot) ? 'bg-obsidian/20' : 'bg-accent'"
                    class="relative mt-0.5 h-7 w-12 shrink-0 rounded-full transition-colors"
                  >
                    <span
                      class="absolute top-1 left-1 h-5 w-5 rounded-full bg-chalk transition-transform"
                      :class="isHidden(s.slot) ? '' : 'translate-x-5'"
                    ></span>
                  </button>
                </div>

                <div
                  class="mt-4 grid grid-cols-3 gap-2 transition-opacity sm:grid-cols-4"
                  :class="{ 'pointer-events-none opacity-35': s.optional && isHidden(s.slot) }"
                >
                  <div v-for="(ph, i) in form[s.slot]" :key="ph.path" class="relative aspect-square overflow-hidden rounded-[1rem] bg-pumice">
                    <img :src="ph.url" alt="" class="h-full w-full object-cover" />
                    <button
                      type="button"
                      @click="removePhoto(s.slot, i)"
                      :disabled="uploading"
                      aria-label="Eliminar foto"
                      class="absolute top-1.5 right-1.5 grid h-7 w-7 place-items-center rounded-full bg-obsidian/70 text-chalk"
                    >
                      <X :size="14" />
                    </button>
                  </div>
                  <button
                    v-if="canAdd(s)"
                    type="button"
                    @click="pickPhoto(s.slot)"
                    :disabled="uploading"
                    class="flex aspect-square flex-col items-center justify-center gap-1 rounded-[1rem] border-[1.5px] border-dashed border-obsidian/30 text-obsidian/55 transition-colors hover:border-obsidian hover:text-obsidian disabled:opacity-50"
                  >
                    <span class="text-2xl leading-none">+</span>
                    <span class="text-xs font-bold">Subir</span>
                  </button>
                </div>
                <p v-if="uploading && uploadingSlot === s.slot" class="mt-3 text-sm text-obsidian/55">Subiendo…</p>
                <p v-if="photoError && photoErrorSlot === s.slot" class="mt-3 rounded-[1rem] bg-red-50 px-3 py-2 text-sm text-red-700">
                  {{ photoError }}
                </p>
              </div>
              <p v-if="photoError && !photoErrorSlot" class="text-sm text-red-700">{{ photoError }}</p>
            </template>
          </div>

          <!-- Anterior / Siguiente -->
          <div class="mt-10 flex items-center justify-between gap-3 border-t-[1.5px] border-dotted border-obsidian/25 pt-6">
            <button v-if="stepIndex > 0" type="button" @click="goToStep(stepIndex - 1)" class="admin-btn-secondary">
              <ChevronLeft :size="18" />
              <span class="hidden sm:inline">{{ STEPS[stepIndex - 1].label }}</span>
              <span class="sm:hidden">Anterior</span>
            </button>
            <span v-else></span>
            <button v-if="stepIndex < STEPS.length - 1" type="button" @click="goToStep(stepIndex + 1)" class="admin-btn-secondary">
              Siguiente: {{ STEPS[stepIndex + 1].label }}
              <ChevronRight :size="18" />
            </button>
          </div>
        </form>

        <input ref="fileInput" type="file" accept="image/jpeg,image/png,image/webp" class="hidden" @change="onFilePicked" />
      </div>

      <!-- ================= VISTA PREVIA (desktop) ================= -->
      <div class="hidden shrink-0 xl:block">
        <div class="sticky top-[calc(2rem+var(--banner-h,0px))]">
          <p class="mb-3 text-center text-xs font-bold tracking-[0.2em] text-obsidian/45 uppercase">Vista previa</p>
          <!-- Bisel: envuelve por afuera, no achica el área de contenido. -->
          <div class="mx-auto inline-block rounded-[2.4rem] border-[10px] border-obsidian">
            <!-- Caja de recorte: mide EXACTO lo que ocupa el iframe ya escalado. -->
            <div
              class="overflow-hidden rounded-[1.6rem]"
              :style="{ width: `${PHONE_W * previewScale}px`, height: `${PHONE_H * previewScale}px` }"
            >
              <iframe
                ref="frameDesktop"
                :src="previewUrl"
                title="Vista previa de la invitación"
                class="block bg-white"
                :style="{
                  width: `${PHONE_W}px`,
                  height: `${PHONE_H}px`,
                  border: 0,
                  transform: `scale(${previewScale})`,
                  transformOrigin: 'top left',
                }"
              ></iframe>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ================= VISTA PREVIA (celular/tablet) ================= -->
    <button
      type="button"
      @click="showMobilePreview = true"
      class="admin-btn-primary font-ui fixed right-4 bottom-5 z-40 xl:hidden"
    >
      <Eye :size="18" />
      Ver cómo queda
    </button>

    <div v-if="showMobilePreview" class="font-ui fixed inset-0 z-[70] flex flex-col bg-obsidian xl:hidden">
      <div class="flex items-center justify-between px-4 py-3 text-chalk">
        <span class="admin-display text-2xl">Vista previa</span>
        <button type="button" @click="showMobilePreview = false" class="grid h-10 w-10 place-items-center rounded-full bg-chalk text-obsidian" aria-label="Cerrar vista previa">
          <X :size="18" />
        </button>
      </div>
      <iframe ref="frameMobile" :src="previewUrl" title="Vista previa de la invitación" class="w-full flex-1 bg-white"></iframe>
    </div>
  </div>
</template>
