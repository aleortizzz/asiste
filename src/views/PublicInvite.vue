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

// ---------------------------------------------------------------------------
// FOTOS — por ahora hardcodeadas desde /public/invitaciones-demo. Cuando cada
// evento tenga sus propias imágenes (Supabase Storage), reemplazar estas
// constantes por datos que vengan en `invite.value` (ej: invite.value.banner_url,
// invite.value.portrait_url, invite.value.gallery[]).
// ---------------------------------------------------------------------------
const bannerFoto = '/invitaciones-demo/demo-02.jpeg'
const retratoFoto = '/invitaciones-demo/demo-05.jpeg'
const detalleFoto = '/invitaciones-demo/demo-07.jpeg'
const galeria = [
  '/invitaciones-demo/demo-01.jpeg',
  '/invitaciones-demo/demo-03.jpeg',
  '/invitaciones-demo/demo-04.jpeg',
  '/invitaciones-demo/demo-06.jpeg',
  '/invitaciones-demo/demo-08.jpeg',
]

const reducedMotion =
  typeof window !== 'undefined' &&
  window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true

// --- Carrusel --------------------------------------------------------------
const slide = ref(0)
let slideTimer = null

function goTo(i) {
  slide.value = (i + galeria.length) % galeria.length
}
function nextSlide() {
  goTo(slide.value + 1)
}
function prevSlide() {
  goTo(slide.value - 1)
}
function startAutoplay() {
  if (reducedMotion) return
  stopAutoplay()
  slideTimer = setInterval(nextSlide, 4500)
}
function stopAutoplay() {
  if (slideTimer) {
    clearInterval(slideTimer)
    slideTimer = null
  }
}

let touchX = 0
function onTouchStart(e) {
  touchX = e.changedTouches[0].clientX
  stopAutoplay()
}
function onTouchEnd(e) {
  const dx = e.changedTouches[0].clientX - touchX
  if (dx > 40) prevSlide()
  else if (dx < -40) nextSlide()
  startAutoplay()
}

// --- Reveal al hacer scroll (directiva local v-reveal) -------------------
const vReveal = {
  mounted(el) {
    if (reducedMotion || typeof IntersectionObserver === 'undefined') {
      el.classList.add('reveal-in')
      return
    }
    el.classList.add('reveal')
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('reveal-in')
            io.unobserve(entry.target)
          }
        })
      },
      { threshold: 0.15 },
    )
    io.observe(el)
    el._revealObserver = io
  },
  unmounted(el) {
    el._revealObserver?.disconnect()
  },
}

// --- Botón flotante "Confirmar" -----------------------------------------
const showFab = ref(false)
function onScroll() {
  showFab.value = window.scrollY > 520
}
function scrollToRsvp() {
  document
    .getElementById('rsvp')
    ?.scrollIntoView({ behavior: reducedMotion ? 'auto' : 'smooth', block: 'start' })
}

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
  startAutoplay()
  window.addEventListener('scroll', onScroll, { passive: true })
})

onUnmounted(() => {
  if (clockTimer) clearInterval(clockTimer)
  stopAutoplay()
  window.removeEventListener('scroll', onScroll)
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

const countdownUnits = computed(() => {
  const c = countdown.value
  if (!c) return []
  return [
    { label: 'días', value: c.days },
    { label: 'hs', value: c.hours },
    { label: 'min', value: c.minutes },
    { label: 'seg', value: c.seconds },
  ]
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

function formatDateLong(isoDate) {
  if (!isoDate) return ''
  const [y, m, d] = isoDate.split('-').map(Number)
  try {
    const s = new Date(y, m - 1, d).toLocaleDateString('es-AR', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    })
    return s.charAt(0).toUpperCase() + s.slice(1)
  } catch {
    return formatDate(isoDate)
  }
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
  <div class="min-h-screen bg-[#fdf7f1] text-stone-700">
    <p v-if="loading" class="flex min-h-screen items-center justify-center text-rose-900/50">
      Cargando…
    </p>

    <p
      v-else-if="notFound"
      class="flex min-h-screen items-center justify-center px-6 text-center text-lg text-rose-900/70"
    >
      No encontramos esta invitación.
    </p>

    <template v-else>
      <!-- ============ HERO / BANNER ============ -->
      <header
        class="relative flex h-svh min-h-[560px] items-center justify-center overflow-hidden"
      >
        <img
          :src="bannerFoto"
          alt=""
          fetchpriority="high"
          class="kenburns absolute inset-0 h-full w-full object-cover"
        />
        <div class="absolute inset-0 bg-linear-to-b from-black/45 via-black/25 to-black/75"></div>

        <div class="hero-in relative z-10 px-6 text-center text-white">
          <p class="text-[0.7rem] uppercase tracking-[0.4em] text-white/80">Te invito a mis</p>
          <p
            class="mt-1 leading-none drop-shadow-lg"
            style="font-family: 'Dancing Script', cursive; font-size: clamp(5rem, 26vw, 10rem)"
          >
            XV
          </p>
          <h1
            class="mt-1 text-2xl font-medium tracking-wide sm:text-3xl"
            style="font-family: 'Playfair Display', serif"
          >
            {{ invite.event_name || 'Mis XV' }}
          </h1>
          <div class="mx-auto mt-5 h-px w-20 bg-white/50"></div>
          <p
            v-if="invite.event_date"
            class="mt-4 text-xs uppercase tracking-[0.25em] text-white/90 sm:text-sm"
          >
            {{ formatDateLong(invite.event_date) }}
          </p>
        </div>

        <button
          v-if="!submitted"
          type="button"
          @click="scrollToRsvp"
          class="absolute bottom-7 z-10 flex flex-col items-center gap-1 text-[0.65rem] uppercase tracking-[0.3em] text-white/80 transition hover:text-white"
        >
          Confirmar asistencia
          <span class="animate-bounce text-lg">↓</span>
        </button>
      </header>

      <!-- ============ SALUDO ============ ​-->
      <section v-reveal class="mx-auto max-w-xl px-6 py-20 text-center">
        <div class="divider">✦</div>
        <p class="text-xs uppercase tracking-[0.3em] text-amber-700">
          Familia {{ invite.family_name }}
        </p>
        <p
          class="mt-6 text-lg leading-relaxed text-stone-600"
          style="font-family: 'Playfair Display', serif"
        >
          Hay días que quedan guardados para siempre en el corazón. Este es uno de ellos, y quiero
          celebrarlo con ustedes.
        </p>
        <div
          class="mx-auto mt-10 max-w-[16rem] overflow-hidden rounded-[2rem] shadow-xl ring-1 ring-amber-200"
        >
          <img
            :src="retratoFoto"
            alt=""
            loading="lazy"
            decoding="async"
            class="block aspect-3/4 w-full object-cover"
          />
        </div>
      </section>

      <!-- ============ COUNTDOWN ============ -->
      <section v-if="countdown" v-reveal class="relative overflow-hidden py-20">
        <img
          :src="galeria[0]"
          alt=""
          loading="lazy"
          class="absolute inset-0 h-full w-full object-cover opacity-25"
        />
        <div class="absolute inset-0 bg-[#fdf7f1]/85"></div>
        <div class="relative mx-auto max-w-xl px-6 text-center">
          <p class="text-xs uppercase tracking-[0.3em] text-amber-700">Falta poco</p>
          <div class="mt-6 grid grid-cols-4 gap-2 sm:gap-3">
            <div
              v-for="u in countdownUnits"
              :key="u.label"
              class="rounded-2xl bg-white/80 py-4 shadow ring-1 ring-amber-100 backdrop-blur-sm"
            >
              <p class="text-2xl font-semibold text-rose-800 sm:text-3xl">{{ u.value }}</p>
              <p class="mt-1 text-[9px] uppercase tracking-widest text-stone-400 sm:text-[10px]">
                {{ u.label }}
              </p>
            </div>
          </div>
        </div>
      </section>

      <!-- ============ DETALLES DE LA FIESTA ============ -->
      <section v-reveal class="mx-auto max-w-xl px-6 py-20">
        <h2 class="text-center text-3xl text-rose-800" style="font-family: 'Dancing Script', cursive">
          La fiesta
        </h2>
        <div class="divider">✦</div>

        <div class="mt-6 space-y-4 rounded-[2rem] bg-white p-6 text-sm shadow-lg ring-1 ring-amber-100">
          <p v-if="invite.event_date" class="flex items-start gap-3">
            <span class="text-lg">📅</span>
            <span>
              {{ formatDateLong(invite.event_date) }}
              <span v-if="invite.reception_time" class="block text-stone-500">
                {{ formatTime(invite.reception_time) }}<span v-if="invite.end_time"> a {{ formatTime(invite.end_time) }}</span> hs
              </span>
            </span>
          </p>
          <p v-if="invite.venue_name" class="flex items-start gap-3">
            <span class="text-lg">💒</span>
            <span>{{ invite.venue_name }}</span>
          </p>
          <p v-if="invite.venue_address" class="flex items-start gap-3">
            <span class="text-lg">📍</span>
            <span>
              {{ invite.venue_address }}
              <a
                v-if="invite.maps_url"
                :href="invite.maps_url"
                target="_blank"
                rel="noopener"
                class="mt-1 block font-medium text-rose-700 underline decoration-rose-300"
              >
                Ver en Google Maps
              </a>
            </span>
          </p>
          <p v-if="invite.dress_code" class="flex items-start gap-3">
            <span class="text-lg">👗</span>
            <span>Código de vestimenta: {{ invite.dress_code }}</span>
          </p>
          <p v-if="invite.gift_alias" class="flex items-start gap-3">
            <span class="text-lg">🎁</span>
            <span>Alias para regalos: <span class="font-medium">{{ invite.gift_alias }}</span></span>
          </p>
          <p v-if="invite.notes" class="border-t border-amber-100 pt-3 italic text-stone-500">
            {{ invite.notes }}
          </p>
        </div>

        <div
          class="mt-10 overflow-hidden rounded-[2rem] shadow-xl ring-1 ring-amber-200"
        >
          <img
            :src="detalleFoto"
            alt=""
            loading="lazy"
            decoding="async"
            class="block aspect-4/3 w-full object-cover"
          />
        </div>
      </section>

      <!-- ============ CARRUSEL ============ -->
      <section v-reveal class="py-20">
        <h2 class="text-center text-3xl text-rose-800" style="font-family: 'Dancing Script', cursive">
          Momentos
        </h2>
        <div class="divider">✦</div>

        <div
          class="relative mx-auto mt-6 max-w-2xl overflow-hidden shadow-xl sm:rounded-[2rem] sm:ring-1 sm:ring-amber-200"
          @touchstart.passive="onTouchStart"
          @touchend.passive="onTouchEnd"
          @mouseenter="stopAutoplay"
          @mouseleave="startAutoplay"
        >
          <div
            class="flex transition-transform duration-700 ease-out"
            :style="{ transform: `translateX(-${slide * 100}%)` }"
          >
            <div v-for="(src, i) in galeria" :key="i" class="min-w-full">
              <img
                :src="src"
                :alt="`Foto ${i + 1}`"
                loading="lazy"
                decoding="async"
                class="block aspect-4/5 w-full object-cover sm:aspect-16/10"
              />
            </div>
          </div>

          <button
            type="button"
            aria-label="Foto anterior"
            @click="prevSlide"
            class="absolute left-2 top-1/2 grid h-9 w-9 -translate-y-1/2 place-items-center rounded-full bg-white/70 text-lg text-stone-700 shadow backdrop-blur-sm transition hover:bg-white sm:left-3"
          >
            ‹
          </button>
          <button
            type="button"
            aria-label="Foto siguiente"
            @click="nextSlide"
            class="absolute right-2 top-1/2 grid h-9 w-9 -translate-y-1/2 place-items-center rounded-full bg-white/70 text-lg text-stone-700 shadow backdrop-blur-sm transition hover:bg-white sm:right-3"
          >
            ›
          </button>

          <div class="absolute inset-x-0 bottom-4 flex justify-center gap-2">
            <button
              v-for="(s, i) in galeria"
              :key="i"
              type="button"
              :aria-label="`Ir a la foto ${i + 1}`"
              @click="goTo(i)"
              class="h-2 rounded-full bg-white transition-all"
              :class="i === slide ? 'w-6 opacity-100' : 'w-2 opacity-50'"
            ></button>
          </div>
        </div>
      </section>

      <!-- ============ RSVP ============ -->
      <section id="rsvp" v-reveal class="mx-auto max-w-xl scroll-mt-6 px-6 py-20">
        <div class="rounded-[2rem] bg-white p-8 shadow-xl ring-1 ring-amber-100">
          <h2
            class="text-center text-3xl text-rose-800"
            style="font-family: 'Dancing Script', cursive"
          >
            Confirmá tu asistencia
          </h2>
          <div class="divider">✦</div>

          <!-- Respuesta enviada -->
          <div v-if="submitted" class="py-4 text-center">
            <p class="text-5xl">💌</p>
            <p class="mt-4 text-lg text-rose-800" style="font-family: 'Playfair Display', serif">
              ¡Gracias! Registramos tu respuesta.
            </p>
            <p class="mt-2 text-sm text-stone-500">Nos vemos muy pronto.</p>
          </div>

          <!-- Modo con nombres precargados por el anfitrión -->
          <template v-else-if="invite.named_by_host">
            <p class="text-center text-sm text-stone-500">Invitaciones para:</p>
            <ul class="mt-4 space-y-2">
              <li
                v-for="guest in namedGuests"
                :key="guest.id"
                class="flex items-center justify-between gap-2 rounded-xl border border-amber-200/70 bg-[#fdf7f1] px-3 py-2"
              >
                <span class="text-stone-800">{{ guest.full_name }}</span>
                <div class="flex shrink-0 gap-2">
                  <button
                    type="button"
                    @click="guest.attending = true"
                    :class="guest.attending ? 'bg-rose-700 text-white' : 'bg-white text-stone-400'"
                    class="rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset ring-amber-200 transition sm:text-sm"
                  >
                    Asiste
                  </button>
                  <button
                    type="button"
                    @click="guest.attending = false"
                    :class="!guest.attending ? 'bg-stone-700 text-white' : 'bg-white text-stone-400'"
                    class="rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset ring-amber-200 transition sm:text-sm"
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
              {{ submitting ? 'Enviando…' : 'Confirmar respuestas' }}
            </button>
          </template>

          <!-- Modo genérico: la familia escribe los nombres -->
          <template v-else>
            <p class="text-center text-sm text-stone-500">
              Tienen {{ invite.allowed_guests }}
              {{ invite.allowed_guests === 1 ? 'invitación' : 'invitaciones' }}.
            </p>

            <form @submit.prevent="confirmarGenerico" class="mt-4 space-y-3">
              <div v-for="(name, i) in names" :key="i" class="flex gap-2">
                <input
                  v-model="names[i]"
                  placeholder="Nombre y apellido"
                  class="flex-1 rounded-xl border border-amber-200 bg-[#fdf7f1] px-3 py-2 focus:border-rose-400 focus:outline-none"
                />
                <button
                  v-if="names.length > 1"
                  type="button"
                  @click="removeName(i)"
                  aria-label="Quitar invitado"
                  class="px-2 text-rose-500"
                >
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

              <div class="flex flex-col gap-2 pt-2 sm:flex-row">
                <button
                  type="submit"
                  :disabled="submitting"
                  class="flex-1 rounded-full bg-linear-to-r from-rose-700 to-rose-800 px-4 py-3 font-medium text-white shadow-md transition hover:brightness-105 disabled:opacity-50"
                >
                  {{ submitting ? 'Enviando…' : 'Confirmar asistencia' }}
                </button>
                <button
                  type="button"
                  :disabled="submitting"
                  @click="declinarGenerico"
                  class="rounded-full border border-stone-300 px-4 py-3 text-stone-600 transition hover:bg-stone-50 disabled:opacity-50"
                >
                  No podemos ir
                </button>
              </div>
            </form>
          </template>
        </div>

        <p
          v-if="!submitted && invite.rsvp_deadline"
          class="mt-4 text-center text-xs uppercase tracking-widest text-stone-400"
        >
          Confirmá antes del {{ formatDate(invite.rsvp_deadline) }}
        </p>
      </section>

      <!-- ============ CIERRE ============ -->
      <footer class="px-6 pb-16 pt-4 text-center">
        <div class="divider">✦</div>
        <p class="text-4xl text-rose-800" style="font-family: 'Dancing Script', cursive">
          ¡Te espero!
        </p>
      </footer>
    </template>

    <!-- Botón flotante -->
    <transition name="fab">
      <button
        v-if="showFab && !submitted && !loading && !notFound"
        type="button"
        @click="scrollToRsvp"
        class="fixed bottom-5 right-5 z-30 rounded-full bg-rose-800 px-5 py-3 text-sm font-medium text-white shadow-lg ring-1 ring-white/20 transition hover:brightness-110"
      >
        Confirmar
      </button>
    </transition>
  </div>
</template>

<style scoped>
.reveal {
  opacity: 0;
  transform: translateY(28px);
  transition:
    opacity 0.8s ease,
    transform 0.8s ease;
}
.reveal-in {
  opacity: 1;
  transform: none;
}

.divider {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.7rem;
  margin: 0.9rem 0 0.2rem;
  color: #b45309;
  font-size: 0.8rem;
}
.divider::before,
.divider::after {
  content: '';
  height: 1px;
  width: 46px;
}
.divider::before {
  background: linear-gradient(to right, transparent, #d6a756);
}
.divider::after {
  background: linear-gradient(to left, transparent, #d6a756);
}

.kenburns {
  animation:
    kb-zoom 22s ease-out forwards,
    kb-fade 1.4s ease both;
}
@keyframes kb-zoom {
  from {
    transform: scale(1);
  }
  to {
    transform: scale(1.14);
  }
}
@keyframes kb-fade {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

.hero-in {
  animation: hero-up 1.1s ease 0.15s both;
}
@keyframes hero-up {
  from {
    opacity: 0;
    transform: translateY(18px);
  }
  to {
    opacity: 1;
    transform: none;
  }
}

.fab-enter-active,
.fab-leave-active {
  transition:
    opacity 0.3s ease,
    transform 0.3s ease;
}
.fab-enter-from,
.fab-leave-to {
  opacity: 0;
  transform: translateY(12px);
}

@media (prefers-reduced-motion: reduce) {
  .kenburns,
  .hero-in {
    animation: none;
  }
  .kenburns {
    opacity: 1;
  }
}
</style>
