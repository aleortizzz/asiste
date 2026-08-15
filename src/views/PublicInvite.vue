<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'

const route = useRoute()
const invite = ref(null)
const loading = ref(true)
const notFound = ref(false)
const error = ref('')
const submitting = ref(false)
const submitted = ref(false)

// Modo "genérico" (sin nombres precargados): la familia tipea los nombres.
const names = ref([''])

// Modo "con nombres" (named_by_host): lista fija de {id, full_name, attending}.
const namedGuests = ref([])

onMounted(async () => {
  const { data, error: err } = await supabase.rpc('obtener_invitacion', { p_slug: route.params.slug })
  if (err || !data) {
    notFound.value = true
  } else {
    invite.value = data
    if (data.named_by_host) {
      namedGuests.value = data.guests.map((g) => ({
        id: g.id,
        full_name: g.full_name,
        attending: g.rsvp_status !== 'not_attending',
      }))
    } else if (data.guests?.length) {
      names.value = data.guests.map((g) => g.full_name)
    }
  }
  loading.value = false
})

function addName() {
  if (names.value.length < invite.value.allowed_guests) {
    names.value.push('')
  }
}

function removeName(i) {
  names.value.splice(i, 1)
}

function formatDate(isoDate) {
  if (!isoDate) return ''
  const [year, month, day] = isoDate.split('-')
  return `${day}/${month}/${year}`
}

function formatTime(time) {
  if (!time) return ''
  return time.slice(0, 5)
}

async function confirmarGenerico() {
  const hasBlank = names.value.some((n) => n.trim() === '')
  if (hasBlank) {
    error.value = 'Completá el nombre en todos los campos, o quitá los que no vayas a usar.'
    return
  }
  await enviarGenerico(names.value.map((n) => n.trim()))
}

async function declinarGenerico() {
  await enviarGenerico([])
}

async function enviarGenerico(guestNames) {
  submitting.value = true
  error.value = ''
  const { error: err } = await supabase.rpc('confirmar_asistencia', {
    p_slug: route.params.slug,
    p_guest_names: guestNames,
  })
  if (err) error.value = err.message
  else submitted.value = true
  submitting.value = false
}

async function enviarRespuestasNominales() {
  submitting.value = true
  error.value = ''
  const respuestas = namedGuests.value.map((g) => ({ id: g.id, attending: g.attending }))
  const { error: err } = await supabase.rpc('responder_invitados', {
    p_slug: route.params.slug,
    p_respuestas: respuestas,
  })
  if (err) error.value = err.message
  else submitted.value = true
  submitting.value = false
}
</script>

<template>
  <div class="flex min-h-screen items-center justify-center bg-gray-50 p-4">
    <p v-if="loading" class="text-gray-500">Cargando...</p>

    <p v-else-if="notFound" class="text-lg text-gray-700">No encontramos esta invitación.</p>

    <div v-else class="w-full max-w-md rounded-lg bg-white p-8 shadow">
      <h1 class="text-2xl font-semibold">¡Hola, {{ invite.family_name }}!</h1>
      <p class="mt-2 text-gray-600">
        Están invitados a <strong>{{ invite.event_name }}</strong>
        <span v-if="invite.venue_name"> en {{ invite.venue_name }}</span>.
      </p>

      <div class="mt-4 space-y-1 rounded border border-gray-200 bg-gray-50 p-3 text-sm text-gray-700">
        <p v-if="invite.event_date">
          📅 {{ formatDate(invite.event_date) }}
          <span v-if="invite.reception_time">
            — {{ formatTime(invite.reception_time) }}<span v-if="invite.end_time"> a {{ formatTime(invite.end_time) }}</span> hs
          </span>
        </p>
        <p v-if="invite.venue_address">📍 {{ invite.venue_address }}</p>
        <p v-if="invite.maps_url">
          <a :href="invite.maps_url" target="_blank" rel="noopener" class="text-blue-600 underline">
            Ver en Google Maps
          </a>
        </p>
        <p v-if="invite.dress_code">👔 Código de vestimenta: {{ invite.dress_code }}</p>
        <p v-if="invite.gift_alias">🎁 Alias para regalos: {{ invite.gift_alias }}</p>
        <p v-if="invite.notes" class="italic">{{ invite.notes }}</p>
        <p v-if="invite.rsvp_deadline" class="font-medium">
          Por favor confirmá antes del {{ formatDate(invite.rsvp_deadline) }}
        </p>
      </div>

      <div v-if="submitted" class="mt-6 text-center text-green-700">
        ¡Gracias, registramos tu respuesta! ✅
      </div>

      <!-- Modo con nombres precargados por el anfitrión -->
      <template v-else-if="invite.named_by_host">
        <p class="mt-1 text-sm text-gray-500">Invitaciones para:</p>
        <ul class="mt-4 space-y-3">
          <li
            v-for="guest in namedGuests"
            :key="guest.id"
            class="flex items-center justify-between rounded border border-gray-200 px-3 py-2"
          >
            <span>{{ guest.full_name }}</span>
            <div class="flex gap-2">
              <button
                type="button"
                @click="guest.attending = true"
                :class="guest.attending ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-600'"
                class="rounded px-3 py-1 text-sm"
              >
                Asiste
              </button>
              <button
                type="button"
                @click="guest.attending = false"
                :class="!guest.attending ? 'bg-red-600 text-white' : 'bg-gray-100 text-gray-600'"
                class="rounded px-3 py-1 text-sm"
              >
                No asiste
              </button>
            </div>
          </li>
        </ul>

        <p v-if="error" class="mt-3 text-sm text-red-600">{{ error }}</p>

        <button
          type="button"
          :disabled="submitting"
          @click="enviarRespuestasNominales"
          class="mt-6 w-full rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50"
        >
          Confirmar respuestas
        </button>
      </template>

      <!-- Modo genérico: la familia escribe los nombres -->
      <template v-else>
        <p class="mt-1 text-sm text-gray-500">Tienen {{ invite.allowed_guests }} invitaciones.</p>

        <form @submit.prevent="confirmarGenerico" class="mt-6 space-y-3">
          <div v-for="(name, i) in names" :key="i" class="flex gap-2">
            <input
              v-model="names[i]"
              placeholder="Nombre y apellido"
              class="flex-1 rounded border border-gray-300 px-3 py-2"
            />
            <button v-if="names.length > 1" type="button" @click="removeName(i)" class="text-red-600">
              ✕
            </button>
          </div>

          <button
            v-if="names.length < invite.allowed_guests"
            type="button"
            @click="addName"
            class="text-sm text-blue-600 underline"
          >
            + Agregar invitado
          </button>

          <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

          <div class="flex gap-2 pt-2">
            <button
              type="submit"
              :disabled="submitting"
              class="flex-1 rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50"
            >
              Confirmar asistencia
            </button>
            <button
              type="button"
              :disabled="submitting"
              @click="declinarGenerico"
              class="rounded border border-gray-300 px-4 py-2 disabled:opacity-50"
            >
              No podemos ir
            </button>
          </div>
        </form>
      </template>
    </div>
  </div>
</template>
