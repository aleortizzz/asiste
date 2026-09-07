<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { useEventPhotos, MAX_GALERIA } from '../composables/useEventPhotos'

const { event, loadEvent, saveEvent } = useEvent()
const { uploadFile, removeFile, savePhotoColumns } = useEventPhotos()

// Panel de la izquierda: datos del evento o gestión de fotos.
const panel = ref('info')
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
const photoError = ref('')
const fileInput = ref(null)
let pendingSlot = null

function pickPhoto(slot) {
  if (!event.value) {
    photoError.value = 'Guardá primero los datos en «Información» para poder subir fotos.'
    return
  }
  photoError.value = ''
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
  uploading.value = true
  photoError.value = ''
  try {
    if (single && form.value[slot][0]) await removeFile(form.value[slot][0].path)
    const item = await uploadFile(slot, file)
    if (single) form.value[slot] = [item]
    else form.value[slot] = [...form.value[slot], item]
    await persistPhotos()
  } catch (err) {
    photoError.value = err.message || 'No se pudo subir la foto.'
  } finally {
    uploading.value = false
  }
}

async function removePhoto(slot, i) {
  const item = form.value[slot][i]
  uploading.value = true
  try {
    await removeFile(item?.path)
    form.value[slot] = form.value[slot].filter((_, idx) => idx !== i)
    await persistPhotos()
  } catch (err) {
    photoError.value = err.message || 'No se pudo eliminar la foto.'
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

// Los datos concretos (fecha, salón, dirección…) quedan vacíos a propósito:
// un valor falso ahí sería peor que uno vacío.
// Paleta curada de fondos para invitaciones (claros arriba, oscuros al final).
const BG_PRESETS = [
  '#fdf7f1', '#f9f1e7', '#f6ede2', '#faf3f4', '#f7eef4',
  '#f3e8ef', '#eef1f7', '#e9eef4', '#eaf1ec', '#eef4ee',
  '#f0f0eb', '#f4f1ea', '#e7ded2', '#dfe6e2', '#d9e2ec',
  '#e6dde8', '#3b3a44', '#2a3b34', '#2e3a4d', '#43303a',
]

const EMPTY = {
  hero_kicker: '',
  hero_title: '',
  hero_subtitle: '',
  intro_text: '',
  closing_text: '',
  bg_color: '#fdf7f1',
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
}

const eventType = ref('cumpleanos')
const form = ref({ ...EMPTY, ...TEMPLATES.cumpleanos })

function applyTemplate(newType) {
  if (newType === eventType.value) return
  const prev = TEMPLATES[eventType.value]
  const next = TEMPLATES[newType]
  for (const key of Object.keys(next)) {
    if (form.value[key] === prev[key] || form.value[key] === '') {
      form.value[key] = next[key]
    }
  }
  eventType.value = newType
}

// Campo de hex: buffer local para poder escribir libremente y solo aplicar
// cuando el valor es un color válido (#rrggbb).
const hexInput = ref(form.value.bg_color)
watch(
  () => form.value.bg_color,
  (v) => {
    if (v !== hexInput.value) hexInput.value = v
  },
)
watch(hexInput, (v) => {
  if (/^#[0-9a-fA-F]{6}$/.test(v)) form.value.bg_color = v.toLowerCase()
})
const hasGuestLimit = ref(false)
const guestLimit = ref(1)
const saving = ref(false)
const message = ref('')

onMounted(async () => {
  await loadEvent()
  if (event.value) {
    eventType.value = event.value.event_type ?? 'cumpleanos'
    form.value = {
      // Eventos viejos sin hero_title: usamos su `name` como texto principal.
      hero_title: event.value.hero_title ?? event.value.name ?? '',
      hero_kicker: event.value.hero_kicker ?? '',
      hero_subtitle: event.value.hero_subtitle ?? '',
      intro_text: event.value.intro_text ?? '',
      closing_text: event.value.closing_text ?? '',
      bg_color: event.value.bg_color ?? '#fdf7f1',
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
      notes: event.value.notes ?? '',
      gift_alias: event.value.gift_alias ?? '',
    }
    hasGuestLimit.value = event.value.guest_limit != null
    guestLimit.value = event.value.guest_limit ?? 1
  }
})

// Postgres no acepta '' para columnas date/time — hay que mandar null
// cuando el campo quedó vacío.
const emptyAsNull = (value) => (value === '' ? null : value)

async function onSubmit() {
  saving.value = true
  message.value = ''
  try {
    await saveEvent({
      ...form.value,
      event_type: eventType.value,
      // `events.name` es NOT NULL y solo se usa internamente: lo derivamos del texto principal.
      name: form.value.hero_title?.trim() || 'Mi evento',
      hero_kicker: emptyAsNull(form.value.hero_kicker),
      hero_title: emptyAsNull(form.value.hero_title),
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
    message.value = 'Guardado ✅'
  } catch (err) {
    message.value = `Error: ${err.message}`
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
  const available = window.innerHeight - 170 // nav + paddings + label
  previewScale.value = Math.min(1, Math.max(0.4, available / PHONE_H))
}

// Al enfocar un campo, desliza la vista previa hasta la sección que ese campo
// modifica (data-preview en el input → data-anchor en la invitación).
function onFieldFocus(e) {
  const anchor = e.target?.dataset?.preview
  if (!anchor) return
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
})
onUnmounted(() => {
  window.removeEventListener('message', onFrameMessage)
  window.removeEventListener('resize', updateScale)
})
</script>

<template>
  <div class="pl-16">
    <AdminNav />
    <div class="mx-auto flex max-w-6xl justify-center gap-10 p-6 lg:p-8 xl:gap-16">
      <!-- Formulario -->
      <div class="w-full max-w-lg">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <h1 class="text-2xl font-semibold">Creá tu invitación</h1>
          <div
            v-show="panel === 'info'"
            class="inline-flex rounded-full border border-gray-300 p-0.5 text-sm"
          >
            <button
              type="button"
              @click="applyTemplate('cumpleanos')"
              :class="eventType === 'cumpleanos' ? 'bg-gray-900 text-white' : 'text-gray-600 hover:bg-gray-100'"
              class="rounded-full px-3 py-1 font-medium transition-colors"
            >
              Cumpleaños
            </button>
            <button
              type="button"
              @click="applyTemplate('casamiento')"
              :class="eventType === 'casamiento' ? 'bg-gray-900 text-white' : 'text-gray-600 hover:bg-gray-100'"
              class="rounded-full px-3 py-1 font-medium transition-colors"
            >
              Casamiento
            </button>
          </div>
        </div>

        <!-- Switch Información / Fotos -->
        <div class="mt-4 grid grid-cols-2 rounded-lg border border-gray-300 p-0.5 text-sm">
          <button
            type="button"
            @click="panel = 'info'"
            :class="panel === 'info' ? 'bg-gray-900 text-white' : 'text-gray-600 hover:bg-gray-100'"
            class="rounded-md py-1.5 font-medium transition-colors"
          >
            Información
          </button>
          <button
            type="button"
            @click="panel = 'fotos'"
            :class="panel === 'fotos' ? 'bg-gray-900 text-white' : 'text-gray-600 hover:bg-gray-100'"
            class="rounded-md py-1.5 font-medium transition-colors"
          >
            Fotos
          </button>
        </div>

        <!-- ================= FOTOS ================= -->
        <div v-if="panel === 'fotos'" class="mt-6 space-y-6">
          <p v-if="!event" class="rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-700">
            Guardá primero los datos en «Información» para poder subir fotos.
          </p>
          <p class="text-xs text-gray-500">
            Las fotos se guardan solas al subirlas. Tocá el ✕ para eliminar una.
          </p>

          <div
            v-for="s in photoSections"
            :key="s.slot"
            class="space-y-2 border-t border-gray-200 pt-4"
          >
            <div class="flex items-center justify-between gap-3">
              <h2 class="text-sm font-semibold text-gray-500 uppercase">{{ s.label }}</h2>
              <button
                v-if="s.optional"
                type="button"
                role="switch"
                :aria-checked="!isHidden(s.slot)"
                @click="toggleSection(s.slot)"
                :class="isHidden(s.slot) ? 'bg-gray-300' : 'bg-gray-900'"
                class="relative h-5 w-9 shrink-0 rounded-full transition-colors"
              >
                <span
                  class="absolute top-0.5 h-4 w-4 rounded-full bg-white transition-all"
                  :class="isHidden(s.slot) ? 'left-0.5' : 'left-4'"
                ></span>
              </button>
            </div>
            <p class="text-xs text-gray-500">
              <template v-if="s.optional && isHidden(s.slot)">
                Esta sección no se muestra en la invitación.
              </template>
              <template v-else>{{ s.help }}</template>
            </p>
            <div
              class="grid grid-cols-4 gap-2 transition-opacity"
              :class="{ 'pointer-events-none opacity-40': s.optional && isHidden(s.slot) }"
            >
              <div
                v-for="(ph, i) in form[s.slot]"
                :key="ph.path"
                class="group relative aspect-square overflow-hidden rounded-lg ring-1 ring-gray-200"
              >
                <img :src="ph.url" alt="" class="h-full w-full object-cover" />
                <button
                  type="button"
                  @click="removePhoto(s.slot, i)"
                  :disabled="uploading"
                  aria-label="Eliminar foto"
                  class="absolute right-1 top-1 grid h-6 w-6 place-items-center rounded-full bg-black/60 text-sm text-white opacity-0 transition group-hover:opacity-100"
                >
                  ✕
                </button>
              </div>
              <button
                v-if="canAdd(s)"
                type="button"
                @click="pickPhoto(s.slot)"
                :disabled="uploading"
                class="grid aspect-square place-items-center rounded-lg border-2 border-dashed border-gray-300 text-2xl text-gray-400 transition hover:border-gray-400 hover:text-gray-600 disabled:opacity-50"
              >
                +
              </button>
            </div>
          </div>

          <p v-if="uploading" class="text-sm text-gray-500">Subiendo…</p>
          <p v-if="photoError" class="text-sm text-red-600">{{ photoError }}</p>
        </div>

        <input
          ref="fileInput"
          type="file"
          accept="image/jpeg,image/png,image/webp"
          class="hidden"
          @change="onFilePicked"
        />

        <!-- ================= INFORMACIÓN ================= -->
        <form
          v-if="panel === 'info'"
          @submit.prevent="onSubmit"
          @focusin="onFieldFocus"
          class="mt-6 space-y-6"
        >
          <p class="text-xs text-gray-500">
            Los campos vienen precargados con textos genéricos según el tipo de evento: cambiá
            solo lo que quieras. Siguen el orden de la invitación, y al tocar uno la vista previa
            se desliza hasta esa parte.
          </p>

          <!-- 1. PORTADA -->
          <div class="space-y-4 border-t border-gray-200 pt-4">
            <h2 class="text-sm font-semibold text-gray-500 uppercase">1 · Portada</h2>
            <div>
              <label class="block text-sm font-medium text-gray-700">Línea de arriba</label>
              <input
                v-model="form.hero_kicker"
                data-preview="hero"
                placeholder="Ej. Te invito a mis — Nos casamos"
                class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Texto principal</label>
              <input
                v-model="form.hero_title"
                data-preview="hero"
                placeholder="Ej. Antonella — Ana &amp; Luis"
                class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Línea de abajo</label>
              <input
                v-model="form.hero_subtitle"
                data-preview="hero"
                placeholder="Ej. Antonella — ¡Te esperamos!"
                class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Fecha</label>
              <input v-model="form.event_date" type="date" data-preview="hero" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Canción (link de YouTube)</label>
              <p class="text-xs text-gray-500">
                Suena al tocar «Abrir invitación». Dejalo vacío para no poner música.
              </p>
              <input
                v-model="form.music_url"
                type="url"
                data-preview="hero"
                placeholder="https://www.youtube.com/watch?v=..."
                class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              />
            </div>
          </div>

          <!-- 2. SALUDO -->
          <div class="space-y-4 border-t border-gray-200 pt-4">
            <h2 class="text-sm font-semibold text-gray-500 uppercase">2 · Saludo</h2>

            <div>
              <label class="block text-sm font-medium text-gray-700">Color de fondo</label>
              <p class="text-xs text-gray-500">El color de toda la invitación (menos las fotos).</p>
              <div class="mt-2 grid grid-cols-10 gap-2">
                <button
                  v-for="c in BG_PRESETS"
                  :key="c"
                  type="button"
                  @click="form.bg_color = c"
                  :style="{ backgroundColor: c }"
                  :class="
                    form.bg_color.toLowerCase() === c
                      ? 'ring-2 ring-gray-900 ring-offset-2'
                      : 'ring-1 ring-gray-300'
                  "
                  :aria-label="`Fondo ${c}`"
                  class="aspect-square w-full rounded-lg"
                ></button>
              </div>
              <div class="mt-3 flex items-center gap-2">
                <span
                  class="h-8 w-8 shrink-0 rounded-lg ring-1 ring-gray-300"
                  :style="{ backgroundColor: form.bg_color }"
                ></span>
                <input
                  v-model="hexInput"
                  data-preview="saludo"
                  maxlength="7"
                  spellcheck="false"
                  placeholder="#fdf7f1"
                  class="w-28 rounded border border-gray-300 px-3 py-1.5 font-mono text-sm uppercase"
                />
                <a
                  href="https://colorhunt.co"
                  target="_blank"
                  rel="noopener"
                  class="text-xs text-blue-600 underline"
                >
                  buscar paletas y copiar el hex
                </a>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Párrafo del saludo</label>
              <textarea
                v-model="form.intro_text"
                rows="3"
                data-preview="saludo"
                placeholder="Ej. Hay días que quedan guardados para siempre. Nos encantaría compartir este con vos."
                class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              ></textarea>
            </div>
          </div>

          <!-- 3. LA FIESTA -->
          <div class="space-y-4 border-t border-gray-200 pt-4">
            <h2 class="text-sm font-semibold text-gray-500 uppercase">3 · La fiesta</h2>
            <div class="flex gap-4">
              <div class="flex-1">
                <label class="block text-sm font-medium text-gray-700">Hora de recepción</label>
                <input v-model="form.reception_time" type="time" data-preview="fiesta" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
              </div>
              <div class="flex-1">
                <label class="block text-sm font-medium text-gray-700">Hora de fin</label>
                <input v-model="form.end_time" type="time" data-preview="fiesta" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Nombre del salón</label>
              <input v-model="form.venue_name" data-preview="fiesta" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Dirección</label>
              <input v-model="form.venue_address" data-preview="fiesta" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Link de Google Maps</label>
              <input
                v-model="form.maps_url"
                type="url"
                data-preview="fiesta"
                placeholder="https://maps.app.goo.gl/..."
                class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Código de vestimenta</label>
              <input
                v-model="form.dress_code"
                data-preview="fiesta"
                placeholder="Ej. Elegante sport"
                class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Alias para regalos</label>
              <input
                v-model="form.gift_alias"
                data-preview="regalos"
                placeholder="Ej. antonella.15"
                class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Notas adicionales</label>
              <textarea
                v-model="form.notes"
                rows="3"
                data-preview="fiesta"
                placeholder="Ej. hay estacionamiento, evento sin niños, etc."
                class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              ></textarea>
            </div>
          </div>

          <!-- 4. CONFIRMACIÓN -->
          <div class="space-y-4 border-t border-gray-200 pt-4">
            <h2 class="text-sm font-semibold text-gray-500 uppercase">4 · Confirmación de asistencia</h2>
            <div>
              <label class="block text-sm font-medium text-gray-700">Fecha límite para confirmar</label>
              <input v-model="form.rsvp_deadline" type="date" data-preview="rsvp" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
            </div>
            <div class="space-y-2">
              <label class="block text-sm font-medium text-gray-700">Cantidad de invitados</label>
              <div class="flex gap-4 text-sm text-gray-700">
                <label class="flex items-center gap-1">
                  <input type="radio" :value="false" v-model="hasGuestLimit" />
                  Ilimitado
                </label>
                <label class="flex items-center gap-1">
                  <input type="radio" :value="true" v-model="hasGuestLimit" />
                  Con tope
                </label>
              </div>
              <input
                v-if="hasGuestLimit"
                v-model.number="guestLimit"
                type="number"
                min="1"
                data-preview="rsvp"
                placeholder="Cantidad máxima de invitados"
                class="w-48 rounded border border-gray-300 px-3 py-2"
              />
            </div>
          </div>

          <!-- 5. CIERRE -->
          <div class="space-y-4 border-t border-gray-200 pt-4">
            <h2 class="text-sm font-semibold text-gray-500 uppercase">5 · Cierre</h2>
            <div>
              <label class="block text-sm font-medium text-gray-700">Frase de cierre</label>
              <input
                v-model="form.closing_text"
                data-preview="cierre"
                placeholder="Ej. ¡Los esperamos!"
                class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              />
            </div>
          </div>

          <p v-if="message" class="text-sm">{{ message }}</p>
          <button
            type="submit"
            :disabled="saving"
            class="rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50"
          >
            {{ saving ? 'Guardando...' : 'Guardar' }}
          </button>
        </form>
      </div>

      <!-- Vista previa (desktop) -->
      <div class="hidden shrink-0 xl:block">
        <div class="sticky top-6">
          <p class="mb-2 text-xs font-semibold text-gray-500 uppercase">Vista previa en vivo</p>
          <!-- Bisel: envuelve por afuera, no achica el área de contenido. -->
          <div class="mx-auto inline-block rounded-[2.2rem] border-[10px] border-gray-900 shadow-xl">
            <!-- Caja de recorte: mide EXACTO lo que ocupa el iframe ya escalado. -->
            <div
              class="overflow-hidden rounded-[1.4rem]"
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

    <!-- Vista previa (mobile): botón flotante + overlay -->
    <button
      type="button"
      @click="showMobilePreview = true"
      class="fixed bottom-5 right-5 z-40 rounded-full bg-rose-700 px-5 py-3 text-sm font-medium text-white shadow-lg xl:hidden"
    >
      Vista previa
    </button>

    <div
      v-if="showMobilePreview"
      class="fixed inset-0 z-50 flex flex-col bg-black/70 xl:hidden"
    >
      <div class="flex justify-end p-3">
        <button
          type="button"
          @click="showMobilePreview = false"
          class="rounded-full bg-white px-4 py-2 text-sm font-medium text-gray-800 shadow"
        >
          Cerrar
        </button>
      </div>
      <iframe
        ref="frameMobile"
        :src="previewUrl"
        title="Vista previa de la invitación"
        class="w-full flex-1 bg-white"
      ></iframe>
    </div>
  </div>
</template>
