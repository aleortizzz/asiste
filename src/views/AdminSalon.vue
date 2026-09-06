<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'

const { event, loadEvent, saveEvent } = useEvent()

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
  family_name: 'García',
  named_by_host: false,
  allowed_guests: 2,
  status: 'pending',
  guests: [],
}))

function pushPreview() {
  const payload = JSON.stringify(previewInvite.value)
  try {
    sessionStorage.setItem(STORAGE_KEY, payload)
  } catch {
    /* modo privado */
  }
  const msg = { type: 'invite-preview', invite: previewInvite.value }
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
          <div class="inline-flex rounded-full border border-gray-300 p-0.5 text-sm">
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

        <form @submit.prevent="onSubmit" @focusin="onFieldFocus" class="mt-6 space-y-6">
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
                data-preview="fiesta"
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
