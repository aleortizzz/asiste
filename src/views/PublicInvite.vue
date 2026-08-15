<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'

const route = useRoute()
const invite = ref(null)
const loading = ref(true)
const notFound = ref(false)
const error = ref('')
const submitting = ref(false)
const submitted = ref(false)
const now = ref(new Date())
let clockTimer = null

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
  clockTimer = setInterval(() => {
    now.value = new Date()
  }, 1000)
})

onUnmounted(() => {
  if (clockTimer) clearInterval(clockTimer)
})

// Cuenta regresiva hasta la fecha/hora del evento. Si no hay reception_time
// cargado, usamos el arranque del día (00:00) como referencia.
const countdown = computed(() => {
  if (!invite.value?.event_date) return null
  const time = invite.value.reception_time ?? '00:00:00'
  const target = new Date(`${invite.value.event_date}T${time}`)
  const diff = target.getTime() - now.value.getTime()
  if (diff <= 0) return null
  return {
    days: Math.floor(diff / (1000 * 60 * 60 * 24)),
    hours: Math.floor((diff / (1000 * 60 * 60)) % 24),
    minutes: Math.floor((diff / (1000 * 60)) % 60),
    seconds: Math.floor((diff / 1000) % 60),
  }
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
  <div
    class="flex min-h-screen items-center justify-center p-4"
    style="background: radial-gradient(circle at top, #fdf2f8 0%, #fbe8d3 55%, #f7dcc0 100%)"
  >
    <p v-if="loading" class="text-rose-900/60">Cargando...</p>

    <p v-else-if="notFound" class="text-lg text-rose-900/70">No encontramos esta invitación.</p>

    <div
      v-else
      class="w-full max-w-md overflow-hidden rounded-3xl bg-[#fffaf3] shadow-2xl ring-1 ring-amber-200/60"
    >
      <div class="h-2 bg-linear-to-r from-rose-300 via-amber-300 to-rose-300"></div>

      <div class="p-8">
        <p class="text-center text-amber-600 tracking-[0.3em] text-xs uppercase">✦ Están invitados ✦</p>

        <h1
          class="mt-2 text-center text-4xl text-rose-800"
          style="font-family: 'Dancing Script', cursive"
        >
          {{ invite.family_name }}
        </h1>

        <h2
          class="mt-3 text-center text-2xl text-stone-800"
          style="font-family: 'Playfair Display', serif"
        >
          {{ invite.event_name }}
        </h2>
        <p v-if="invite.venue_name" class="mt-1 text-center text-sm text-stone-500">
          en {{ invite.venue_name }}
        </p>

        <div v-if="countdown" class="mt-6">
          <p class="text-center text-xs tracking-widest text-amber-700 uppercase">Faltan</p>
          <div class="mt-2 grid grid-cols-4 gap-2 text-center">
            <div class="rounded-xl bg-linear-to-b from-rose-700 to-rose-800 py-3 text-white shadow">
              <p class="text-2xl font-bold">{{ countdown.days }}</p>
              <p class="text-[10px] tracking-wide uppercase opacity-80">días</p>
            </div>
            <div class="rounded-xl bg-linear-to-b from-rose-700 to-rose-800 py-3 text-white shadow">
              <p class="text-2xl font-bold">{{ countdown.hours }}</p>
              <p class="text-[10px] tracking-wide uppercase opacity-80">hs</p>
            </div>
            <div class="rounded-xl bg-linear-to-b from-rose-700 to-rose-800 py-3 text-white shadow">
              <p class="text-2xl font-bold">{{ countdown.minutes }}</p>
              <p class="text-[10px] tracking-wide uppercase opacity-80">min</p>
            </div>
            <div class="rounded-xl bg-linear-to-b from-rose-700 to-rose-800 py-3 text-white shadow">
              <p class="text-2xl font-bold">{{ countdown.seconds }}</p>
              <p class="text-[10px] tracking-wide uppercase opacity-80">seg</p>
            </div>
          </div>
        </div>

        <div class="mt-6 space-y-2 rounded-2xl border border-amber-200/70 bg-white/60 p-4 text-sm text-stone-700">
          <p v-if="invite.event_date" class="flex items-center gap-2">
            <span>📅</span>
            <span>
              {{ formatDate(invite.event_date) }}
              <span v-if="invite.reception_time">
                — {{ formatTime(invite.reception_time) }}<span v-if="invite.end_time"> a {{ formatTime(invite.end_time) }}</span> hs
              </span>
            </span>
          </p>
          <p v-if="invite.venue_address" class="flex items-center gap-2">
            <span>📍</span> <span>{{ invite.venue_address }}</span>
          </p>
          <p v-if="invite.maps_url">
            <a
              :href="invite.maps_url"
              target="_blank"
              rel="noopener"
              class="ml-6 font-medium text-rose-700 underline decoration-rose-300"
            >
              Ver en Google Maps
            </a>
          </p>
          <p v-if="invite.dress_code" class="flex items-center gap-2">
            <span>👔</span> <span>Código de vestimenta: {{ invite.dress_code }}</span>
          </p>
          <p v-if="invite.gift_alias" class="flex items-center gap-2">
            <span>🎁</span> <span>Alias para regalos: {{ invite.gift_alias }}</span>
          </p>
          <p v-if="invite.notes" class="italic text-stone-500">{{ invite.notes }}</p>
          <p v-if="invite.rsvp_deadline" class="font-medium text-rose-700">
            Por favor confirmá antes del {{ formatDate(invite.rsvp_deadline) }}
          </p>
        </div>

        <div v-if="submitted" class="mt-6 rounded-2xl bg-rose-50 p-4 text-center text-rose-800">
          ¡Gracias, registramos tu respuesta! ✨
        </div>

        <!-- Modo con nombres precargados por el anfitrión -->
        <template v-else-if="invite.named_by_host">
          <p class="mt-6 text-center text-sm text-stone-500">Invitaciones para:</p>
          <ul class="mt-3 space-y-2">
            <li
              v-for="guest in namedGuests"
              :key="guest.id"
              class="flex items-center justify-between rounded-xl border border-amber-200/70 bg-white/60 px-3 py-2"
            >
              <span class="text-stone-800">{{ guest.full_name }}</span>
              <div class="flex gap-2">
                <button
                  type="button"
                  @click="guest.attending = true"
                  :class="guest.attending ? 'bg-rose-700 text-white' : 'bg-stone-100 text-stone-500'"
                  class="rounded-full px-3 py-1 text-sm transition"
                >
                  Asiste
                </button>
                <button
                  type="button"
                  @click="guest.attending = false"
                  :class="!guest.attending ? 'bg-stone-700 text-white' : 'bg-stone-100 text-stone-500'"
                  class="rounded-full px-3 py-1 text-sm transition"
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
            class="mt-6 w-full rounded-full bg-linear-to-r from-rose-700 to-rose-800 px-4 py-3 font-medium text-white shadow-md transition hover:brightness-105 disabled:opacity-50"
          >
            Confirmar respuestas
          </button>
        </template>

        <!-- Modo genérico: la familia escribe los nombres -->
        <template v-else>
          <p class="mt-6 text-center text-sm text-stone-500">Tienen {{ invite.allowed_guests }} invitaciones.</p>

          <form @submit.prevent="confirmarGenerico" class="mt-4 space-y-3">
            <div v-for="(name, i) in names" :key="i" class="flex gap-2">
              <input
                v-model="names[i]"
                placeholder="Nombre y apellido"
                class="flex-1 rounded-xl border border-amber-200 bg-white/70 px-3 py-2 focus:border-rose-400 focus:outline-none"
              />
              <button v-if="names.length > 1" type="button" @click="removeName(i)" class="text-rose-500">
                ✕
              </button>
            </div>

            <button
              v-if="names.length < invite.allowed_guests"
              type="button"
              @click="addName"
              class="text-sm font-medium text-rose-700 underline decoration-rose-300"
            >
              + Agregar invitado
            </button>

            <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

            <div class="flex gap-2 pt-2">
              <button
                type="submit"
                :disabled="submitting"
                class="flex-1 rounded-full bg-linear-to-r from-rose-700 to-rose-800 px-4 py-3 font-medium text-white shadow-md transition hover:brightness-105 disabled:opacity-50"
              >
                Confirmar asistencia
              </button>
              <button
                type="button"
                :disabled="submitting"
                @click="declinarGenerico"
                class="rounded-full border border-stone-300 px-4 py-3 text-stone-600 disabled:opacity-50"
              >
                No podemos ir
              </button>
            </div>
          </form>
        </template>
      </div>
    </div>
  </div>
</template>
