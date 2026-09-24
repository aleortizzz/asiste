<script setup>
import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import {
  CalendarHeart,
  MapPin,
  Gem,
  Gift,
  ArrowUpRight,
  Music,
  Pause,
  Copy,
  Check,
  Search,
} from '@lucide/vue'
import { searchYoutubeVideos } from '../lib/youtube'

// Componente 100% presentacional de la invitación. No sabe de Supabase ni de
// rutas: recibe `invite` como prop y emite eventos de RSVP hacia arriba.
// Se usa en 3 lados: la invitación pública real, el preview del panel y
// (a futuro) cualquier otra vista.
const props = defineProps({
  invite: { type: Object, required: true },
  // preview: modo vista previa (panel admin). Oculta el botón flotante y
  // desactiva el envío del RSVP.
  preview: { type: Boolean, default: false },
  submitting: { type: Boolean, default: false },
  submitted: { type: Boolean, default: false },
  error: { type: String, default: '' },
  // Pedido de canciones (plan "plus"): separado del RSVP porque acá se puede
  // mandar más de uno, no es una respuesta única por familia.
  songSubmitting: { type: Boolean, default: false },
  songError: { type: String, default: '' },
})

const emit = defineEmits(['submit-generic', 'submit-named', 'submit-song'])

const now = ref(new Date())
let clockTimer = null

// Modo "genérico" (sin nombres precargados): la familia tipea los nombres.
const names = ref([''])
// Modo "con nombres" (named_by_host): lista fija de {id, full_name, attending}.
const namedGuests = ref([])
const localError = ref('')
const displayError = computed(() => localError.value || props.error)

// Rehidrata las listas del RSVP cada vez que cambian los datos (en el preview
// el `invite` muta mientras se escribe en el formulario).
watch(
  () => props.invite,
  (data) => {
    if (!data) return
    if (data.named_by_host) {
      namedGuests.value = (data.guests ?? []).map((g) => ({
        id: g.id,
        full_name: g.full_name,
        attending: g.rsvp_status !== 'not_attending',
      }))
    } else if (data.guests?.length) {
      names.value = data.guests.map((g) => g.full_name)
    } else {
      names.value = ['']
    }
  },
  { immediate: true, deep: true },
)

// ---------------------------------------------------------------------------
// FOTOS — vienen de `props.invite.{banner,retrato,detalle,momentos,galeria}`
// (arrays de { url, path } desde Supabase Storage). Si un slot está vacío se
// usan las fotos de demo, así la invitación nunca se ve rota.
// ---------------------------------------------------------------------------
const DEMO = {
  banner: '/invitaciones-demo/demo-02.jpeg',
  detalle: '/invitaciones-demo/demo-07.jpeg',
  retrato: [
    '/invitaciones-demo/demo-05.jpeg',
    '/invitaciones-demo/demo-01.jpeg',
    '/invitaciones-demo/demo-04.jpeg',
    '/invitaciones-demo/demo-06.jpeg',
    '/invitaciones-demo/demo-08.jpeg',
  ],
  momentos: [
    '/invitaciones-demo/demo-01.jpeg',
    '/invitaciones-demo/demo-03.jpeg',
    '/invitaciones-demo/demo-04.jpeg',
    '/invitaciones-demo/demo-06.jpeg',
    '/invitaciones-demo/demo-08.jpeg',
  ],
  galeria: [
    '/invitaciones-demo/demo-01.jpeg',
    '/invitaciones-demo/demo-02.jpeg',
    '/invitaciones-demo/demo-03.jpeg',
    '/invitaciones-demo/demo-04.jpeg',
    '/invitaciones-demo/demo-05.jpeg',
    '/invitaciones-demo/demo-06.jpeg',
    '/invitaciones-demo/demo-07.jpeg',
    '/invitaciones-demo/demo-08.jpeg',
  ],
}
function slotUrls(slot) {
  const a = props.invite?.[slot]
  return Array.isArray(a) ? a.map((p) => p?.url).filter(Boolean) : []
}
const bannerFoto = computed(() => slotUrls('banner')[0] || DEMO.banner)
const detalleFoto = computed(() => slotUrls('detalle')[0] || DEMO.detalle)
const saludoFotos = computed(() => {
  const u = slotUrls('retrato')
  return u.length ? u : DEMO.retrato
})
const momentosFotos = computed(() => {
  const u = slotUrls('momentos')
  return u.length ? u : DEMO.momentos
})
const galeriaGrid = computed(() => {
  const u = slotUrls('galeria')
  return u.length ? u : DEMO.galeria
})

const reducedMotion =
  typeof window !== 'undefined' &&
  window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true

// Textos del hero/saludo/cierre: los define cada evento desde el admin.
const defaultIntro =
  'Hay días que quedan guardados para siempre en el corazón. Nos encantaría compartir este con ustedes.'
const heroTitle = computed(
  () => props.invite?.hero_title || props.invite?.event_name || 'Nuestro festejo',
)
const bgColor = computed(() => props.invite?.bg_color || '#fdf7f1')

// Secciones de fotos que el cliente ocultó desde el editor.
const hiddenSections = computed(() =>
  Array.isArray(props.invite?.hidden_sections) ? props.invite.hidden_sections : [],
)
const shows = (slot) => !hiddenSections.value.includes(slot)

// --- Portada (sobre) + música ---------------------------------------------
// `entered` = ya se abrió el sobre. En preview arranca abierto para no tapar
// la edición.
const entered = ref(props.preview)
const musicPlaying = ref(false)
const ytFrame = ref(null)

// Animación del sobre: `opening` dispara el flip de la solapa + la carta
// asomando; `closing` recién arranca el fade del overlay completo un poco
// después, así el sobre termina de "abrirse" antes de desaparecer.
// `envelopeGone` saca el overlay del DOM al terminar el fade.
const opening = ref(false)
const closing = ref(false)
const envelopeGone = ref(false)

// Saca el id del video de cualquier forma de link de YouTube.
const musicId = computed(() => {
  const url = props.invite?.music_url?.trim()
  if (!url) return ''
  const m = url.match(
    /(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([\w-]{11})/,
  )
  return m ? m[1] : /^[\w-]{11}$/.test(url) ? url : ''
})

const ytSrc = computed(() =>
  musicId.value
    ? `https://www.youtube.com/embed/${musicId.value}?enablejsapi=1&playsinline=1&controls=0&loop=1&playlist=${musicId.value}&modestbranding=1`
    : '',
)

function ytCommand(func) {
  ytFrame.value?.contentWindow?.postMessage(
    JSON.stringify({ event: 'command', func, args: [] }),
    '*',
  )
}

function toggleMusic() {
  if (musicPlaying.value) {
    ytCommand('pauseVideo')
    musicPlaying.value = false
  } else {
    ytCommand('playVideo')
    musicPlaying.value = true
  }
}

function playMusic() {
  if (!musicId.value) return
  // Reintento por si el iframe todavía no terminó de cargar cuando se toca.
  ytCommand('playVideo')
  setTimeout(() => ytCommand('playVideo'), 400)
  setTimeout(() => ytCommand('playVideo'), 1200)
  musicPlaying.value = true
}

// Mientras la portada está arriba, bloqueamos el scroll de la página para que
// no se pueda "scrollear a ciegas" y aparecer abajo de todo al abrir.
watch(
  entered,
  (v) => {
    if (typeof document === 'undefined') return
    document.body.style.overflow = v ? '' : 'hidden'
    if (v) window.scrollTo(0, 0)
  },
  { immediate: true },
)

const aliasCopied = ref(false)
async function copyAlias() {
  try {
    await navigator.clipboard.writeText(props.invite.gift_alias)
    aliasCopied.value = true
    setTimeout(() => (aliasCopied.value = false), 1800)
  } catch {
    /* portapapeles bloqueado */
  }
}

// --- Pedido de canciones (plan "plus") -------------------------------------
const songQuery = ref('')
const songResults = ref([])
const songSearching = ref(false)
const songSearchError = ref('')
const selectedSong = ref(null)
const songRequesterName = ref('')
const localSongError = ref('')
const displaySongError = computed(() => localSongError.value || props.songError)
// Se prende solo después de un envío exitoso (ver watch de songSubmitting
// más abajo): a diferencia del RSVP, acá se puede mandar más de una canción,
// así que no es un estado final sino un cartel temporal entre pedidos.
const justAddedSong = ref(false)

let songDebounce = null
function onSongQueryInput() {
  clearTimeout(songDebounce)
  selectedSong.value = null
  if (songQuery.value.trim().length < 3) {
    songResults.value = []
    songSearchError.value = ''
    return
  }
  songDebounce = setTimeout(runSongSearch, 450)
}

async function runSongSearch() {
  const q = songQuery.value.trim()
  if (q.length < 3) return
  songSearching.value = true
  songSearchError.value = ''
  try {
    songResults.value = await searchYoutubeVideos(q)
  } catch {
    songSearchError.value = 'No pudimos buscar canciones ahora, probá de nuevo.'
  } finally {
    songSearching.value = false
  }
}

function selectSong(result) {
  selectedSong.value = result
  songResults.value = []
  songQuery.value = result.title
}

function clearSelectedSong() {
  selectedSong.value = null
  songQuery.value = ''
}

function submitSong() {
  localSongError.value = ''
  if (props.preview) return
  if (!songRequesterName.value.trim()) {
    localSongError.value = 'Nos falta tu nombre para saber quién la pidió.'
    return
  }
  emit('submit-song', {
    songTitle: selectedSong.value.title,
    artist: selectedSong.value.channel,
    youtubeVideoId: selectedSong.value.videoId,
    requestedBy: songRequesterName.value.trim(),
  })
}

// Al terminar un envío sin error, mostramos el cartelito de "gracias" y
// dejamos listo el buscador para la próxima (mantenemos el nombre cargado,
// es común que la misma persona pida varias canciones seguidas).
watch(
  () => props.songSubmitting,
  (submitting, wasSubmitting) => {
    if (wasSubmitting && !submitting && !props.songError) {
      justAddedSong.value = true
      songQuery.value = ''
      songResults.value = []
      selectedSong.value = null
    }
  },
)

// Tocar el sobre: arranca la música ya (gesto del usuario, para que el
// autoplay no se bloquee) y encadena la animación de apertura antes de
// mostrar el contenido de la invitación.
function openEnvelope() {
  if (opening.value) return
  opening.value = true
  playMusic()
  if (reducedMotion) {
    entered.value = true
    envelopeGone.value = true
    return
  }
  setTimeout(() => {
    entered.value = true
  }, 950)
  setTimeout(() => {
    closing.value = true
  }, 950)
}

function onEnvelopeFadeEnd() {
  envelopeGone.value = true
}

// --- Carrusel --------------------------------------------------------------
const slide = ref(0)
let momentosTimer = null

function goTo(i) {
  const n = momentosFotos.value.length
  slide.value = ((i % n) + n) % n
}
function nextSlide() {
  goTo(slide.value + 1)
}
function prevSlide() {
  goTo(slide.value - 1)
}
function startMomentosAutoplay() {
  if (reducedMotion) return
  stopMomentosAutoplay()
  momentosTimer = setInterval(nextSlide, 3000)
}
function stopMomentosAutoplay() {
  if (momentosTimer) {
    clearInterval(momentosTimer)
    momentosTimer = null
  }
}

let touchX = 0
function onTouchStart(e) {
  touchX = e.changedTouches[0].clientX
  stopMomentosAutoplay()
}
function onTouchEnd(e) {
  const dx = e.changedTouches[0].clientX - touchX
  if (dx > 40) nextSlide()
  else if (dx < -40) prevSlide()
  startMomentosAutoplay()
}

// --- Carrusel centrado del saludo (infinito) ------------------------------
// Repetimos las fotos 3 veces y arrancamos en la copia del medio: así siempre
// hay fotos asomando a ambos lados. Al llegar a una copia del borde, saltamos
// sin transición a la posición equivalente del medio.
const saludoLen = computed(() => saludoFotos.value.length)
const saludoLoop = computed(() => [
  ...saludoFotos.value,
  ...saludoFotos.value,
  ...saludoFotos.value,
])
const saludoSlide = ref(saludoLen.value)
const saludoNoTransition = ref(false)
const saludoActive = computed(() => {
  const n = saludoLen.value
  return n ? ((saludoSlide.value % n) + n) % n : 0
})

function saludoStep(delta) {
  saludoSlide.value += delta
}
function saludoSet(realIndex) {
  saludoSlide.value = saludoLen.value + realIndex
}

let saludoTimer = null
function startSaludoAutoplay() {
  if (reducedMotion || saludoLen.value < 2) return
  stopSaludoAutoplay()
  saludoTimer = setInterval(() => saludoStep(1), 3000)
}
function stopSaludoAutoplay() {
  if (saludoTimer) {
    clearInterval(saludoTimer)
    saludoTimer = null
  }
}
function onSaludoTransitionEnd(e) {
  if (e.propertyName !== 'transform' || e.target !== e.currentTarget) return
  const n = saludoLen.value
  if (saludoSlide.value < n || saludoSlide.value >= n * 2) {
    saludoNoTransition.value = true
    saludoSlide.value = n + saludoActive.value
    requestAnimationFrame(() =>
      requestAnimationFrame(() => {
        saludoNoTransition.value = false
      }),
    )
  }
}
// Si cambia la cantidad de fotos (se agregan/quitan en el editor), reencuadrar.
watch(saludoLen, (n) => {
  saludoSlide.value = n + Math.min(saludoActive.value, Math.max(0, n - 1))
})

let saludoTouchX = 0
function onSaludoTouchStart(e) {
  saludoTouchX = e.changedTouches[0].clientX
  stopSaludoAutoplay()
}
function onSaludoTouchEnd(e) {
  const dx = e.changedTouches[0].clientX - saludoTouchX
  if (dx > 40) saludoStep(1)
  else if (dx < -40) saludoStep(-1)
  startSaludoAutoplay()
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

function scrollToRsvp() {
  document
    .getElementById('rsvp')
    ?.scrollIntoView({ behavior: reducedMotion ? 'auto' : 'smooth', block: 'start' })
}

// --- Galería: las fotos convergen al centro a medida que se scrollea --------
const gridItems = ref([])
let gridRaf = null

function updateGridParallax() {
  if (reducedMotion) return
  const vh = window.innerHeight
  const vw = window.innerWidth
  for (const el of gridItems.value) {
    if (!el) continue
    const r = el.getBoundingClientRect()
    // p: 0 cuando la foto está en el centro vertical de la pantalla, ±1 lejos.
    let p = ((r.top + r.height / 2 - vh / 2) / vh) * 1.7
    p = Math.max(-1, Math.min(1, p))
    const k = Math.abs(p)
    const side = r.left + r.width / 2 < vw / 2 ? -1 : 1
    el.style.transform = `translateX(${(side * k * 44).toFixed(1)}px) scale(${(1 - k * 0.05).toFixed(3)})`
    el.style.opacity = (1 - k * 0.3).toFixed(2)
  }
}

function onGridScroll() {
  if (gridRaf) return
  gridRaf = requestAnimationFrame(() => {
    gridRaf = null
    updateGridParallax()
  })
}

onMounted(() => {
  clockTimer = setInterval(() => {
    now.value = new Date()
  }, 1000)
  startMomentosAutoplay()
  startSaludoAutoplay()
  window.addEventListener('scroll', onGridScroll, { passive: true })
  window.addEventListener('resize', onGridScroll)
  setTimeout(updateGridParallax, 60)
})

onUnmounted(() => {
  if (clockTimer) clearInterval(clockTimer)
  stopMomentosAutoplay()
  stopSaludoAutoplay()
  window.removeEventListener('scroll', onGridScroll)
  window.removeEventListener('resize', onGridScroll)
  if (gridRaf) cancelAnimationFrame(gridRaf)
  if (typeof document !== 'undefined') document.body.style.overflow = ''
})

// Al cerrar la portada cambia el layout: recalcular posiciones.
watch(entered, () => setTimeout(updateGridParallax, 60))

// Cuenta regresiva hasta la fecha/hora del evento.
const countdown = computed(() => {
  if (!props.invite?.event_date) return null
  const time = props.invite.reception_time ?? '00:00:00'
  const target = new Date(`${props.invite.event_date}T${time}`)
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
  if (names.value.length < props.invite.allowed_guests) {
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

function confirmarGenerico() {
  localError.value = ''
  if (props.preview) return
  const hasBlank = names.value.some((n) => n.trim() === '')
  if (hasBlank) {
    localError.value = 'Completá el nombre en todos los campos, o quitá los que no vayas a usar.'
    return
  }
  emit('submit-generic', names.value.map((n) => n.trim()))
}

function declinarGenerico() {
  localError.value = ''
  if (props.preview) return
  emit('submit-generic', [])
}

function enviarRespuestasNominales() {
  localError.value = ''
  if (props.preview) return
  emit(
    'submit-named',
    namedGuests.value.map((g) => ({ id: g.id, attending: g.attending })),
  )
}
</script>

<template>
  <div
    class="min-h-screen overflow-x-clip text-stone-700"
    :style="{ backgroundColor: bgColor }"
  >
    <!-- iframe de YouTube oculto: se carga desde el inicio para poder controlarlo -->
    <iframe
      v-if="ytSrc && !preview"
      ref="ytFrame"
      :src="ytSrc"
      title="Música"
      allow="autoplay"
      class="pointer-events-none fixed bottom-0 left-0 -z-10 h-px w-px opacity-[0.01]"
    ></iframe>

    <!-- ============ HERO / PORTADA ============ -->
    <!-- Una sola pantalla: antes de "entrar" muestra el botón de abrir (y
         bloquea el scroll); una vez abierta, el mismo header se queda de
         hero normal con el link para saltar al RSVP. Antes eran 2 pantallas
         casi idénticas (portada + hero) que se veían "duplicadas". -->
    <header
      data-anchor="hero"
      class="relative flex h-svh min-h-[560px] items-center justify-center overflow-hidden"
    >
      <img
        :src="bannerFoto"
        alt=""
        fetchpriority="high"
        class="kenburns absolute inset-0 h-full w-full object-cover"
      />
      <div class="absolute inset-0 bg-linear-to-b from-black/45 via-black/25 to-black/75"></div>

      <div class="hero-in relative z-10 w-full min-w-0 px-6 text-center text-white">
        <p v-if="invite.hero_kicker" class="text-[0.7rem] uppercase tracking-[0.4em] text-white/80">
          {{ invite.hero_kicker }}
        </p>
        <p
          class="mt-1 leading-[1.05] break-words drop-shadow-lg"
          style="font-family: 'Dancing Script', cursive; font-size: clamp(4rem, 20vw, 8.5rem)"
        >
          {{ heroTitle }}
        </p>
        <p
          v-if="invite.hero_subtitle"
          class="mt-3 text-[0.7rem] uppercase tracking-[0.4em] text-white/80"
        >
          {{ invite.hero_subtitle }}
        </p>
        <div class="mx-auto mt-5 h-px w-20 bg-white/50"></div>
        <p
          v-if="invite.event_date"
          class="mt-4 text-xs uppercase tracking-[0.25em] text-white/90 sm:text-sm"
        >
          {{ formatDateLong(invite.event_date) }}
        </p>

      </div>

      <button
        v-if="entered && !submitted"
        type="button"
        @click="scrollToRsvp"
        class="absolute bottom-7 z-10 flex flex-col items-center gap-1 text-[0.65rem] uppercase tracking-[0.3em] text-white/80 transition hover:text-white"
      >
        Confirmar asistencia
        <span class="animate-bounce text-lg">↓</span>
      </button>
    </header>

    <!-- ============ SOBRE (portada) ============ -->
    <!-- Tapa toda la pantalla hasta que el invitado lo toca. Al abrirse dispara
         la música (dentro del gesto de click, para que el navegador no la
         bloquee) y después de la animación revela la invitación de atrás. -->
    <div
      v-if="!preview && !envelopeGone"
      class="envelope-overlay fixed inset-0 z-50 flex flex-col items-center justify-center px-6"
      :class="{ 'envelope-overlay--out': closing }"
      :style="{ backgroundColor: bgColor }"
      @transitionend.self="onEnvelopeFadeEnd"
    >
      <button
        type="button"
        class="envelope"
        :class="{ 'envelope--open': opening }"
        :disabled="opening"
        aria-label="Abrir invitación"
        @click="openEnvelope"
      >
        <span class="envelope-back"></span>
        <span class="envelope-letter">
          <span class="envelope-letter-mark">✦</span>
        </span>
        <span class="envelope-pocket"></span>
        <span class="envelope-flap"></span>
        <span class="envelope-seal">✦</span>
      </button>

      <p
        class="envelope-caption mt-8 text-center text-xs uppercase tracking-[0.35em] text-amber-800/80"
        :class="{ 'envelope-caption--out': opening }"
      >
        Tocá el sobre para abrir tu invitación
      </p>
      <p
        v-if="musicId"
        class="envelope-caption mt-3 flex items-center justify-center gap-1.5 text-[0.65rem] uppercase tracking-widest text-amber-800/60"
        :class="{ 'envelope-caption--out': opening }"
      >
        <Music :size="12" /> con música
      </p>
    </div>

    <!-- ============ SALUDO ============ -->
    <section v-reveal data-anchor="saludo" class="py-20 text-center">
      <div class="mx-auto max-w-xl px-6">
        <div class="divider">✦</div>
        <p v-if="invite.family_name" class="text-xs uppercase tracking-[0.3em] text-amber-700">
          {{ invite.family_name }}
        </p>
        <p
          class="mt-6 text-lg leading-relaxed whitespace-pre-line text-stone-600"
          style="font-family: 'Playfair Display', serif"
        >
          {{ invite.intro_text || defaultIntro }}
        </p>
      </div>

      <!-- Carrusel centrado infinito: la foto del medio se ve más grande -->
      <div
        v-if="shows('retrato')"
        class="relative mt-10 overflow-hidden"
        @touchstart.passive="onSaludoTouchStart"
        @touchend.passive="onSaludoTouchEnd"
        @mouseenter="stopSaludoAutoplay"
        @mouseleave="startSaludoAutoplay"
      >
        <div
          class="flex ease-out"
          :class="saludoNoTransition ? '' : 'transition-transform duration-500'"
          :style="{ transform: `translateX(calc(14% - ${saludoSlide * 72}%))` }"
          @transitionend="onSaludoTransitionEnd"
        >
          <div
            v-for="(src, i) in saludoLoop"
            :key="i"
            class="w-[72%] shrink-0 px-2 ease-out"
            :class="[
              saludoNoTransition ? '' : 'transition-all duration-500',
              i === saludoSlide ? 'scale-100 opacity-100' : 'scale-[0.84] opacity-40',
            ]"
          >
            <img
              :src="src"
              alt=""
              loading="lazy"
              decoding="async"
              class="block aspect-3/4 w-full rounded-[2rem] object-cover shadow-xl ring-1 ring-amber-200"
            />
          </div>
        </div>

        <button
          type="button"
          aria-label="Foto anterior"
          @click="saludoStep(-1)"
          class="absolute left-3 top-1/2 z-10 grid h-9 w-9 -translate-y-1/2 place-items-center rounded-full bg-white/80 text-lg text-stone-700 shadow backdrop-blur-sm transition hover:bg-white"
        >
          ‹
        </button>
        <button
          type="button"
          aria-label="Foto siguiente"
          @click="saludoStep(1)"
          class="absolute right-3 top-1/2 z-10 grid h-9 w-9 -translate-y-1/2 place-items-center rounded-full bg-white/80 text-lg text-stone-700 shadow backdrop-blur-sm transition hover:bg-white"
        >
          ›
        </button>
      </div>

      <div v-if="shows('retrato')" class="mt-5 flex justify-center gap-2">
        <button
          v-for="(s, i) in saludoFotos"
          :key="i"
          type="button"
          :aria-label="`Ir a la foto ${i + 1}`"
          @click="saludoSet(i)"
          class="h-1.5 rounded-full bg-rose-800 transition-all"
          :class="i === saludoActive ? 'w-5 opacity-100' : 'w-1.5 opacity-30'"
        ></button>
      </div>
    </section>

    <!-- ============ COUNTDOWN ============ -->
    <section v-if="countdown" v-reveal class="relative overflow-hidden py-20">
      <img
        :src="bannerFoto"
        alt=""
        loading="lazy"
        class="absolute inset-0 h-full w-full object-cover opacity-25"
      />
      <div class="absolute inset-0 opacity-90" :style="{ backgroundColor: bgColor }"></div>
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
    <section v-reveal data-anchor="fiesta" class="mx-auto max-w-xl px-6 py-24">
      <p class="text-center text-[0.7rem] uppercase tracking-[0.45em] text-amber-700/80">
        Los detalles
      </p>
      <h2
        class="mt-2 text-center text-4xl text-rose-800"
        style="font-family: 'Dancing Script', cursive"
      >
        La celebración
      </h2>
      <div class="divider">✦</div>

      <!-- Tarjeta con doble marco -->
      <div
        class="relative mt-8 rounded-[1.9rem] bg-white/90 p-2.5 shadow-[0_28px_60px_-28px_rgba(120,72,40,0.35)] ring-1 ring-amber-200/70 backdrop-blur-sm"
      >
        <div class="rounded-[1.5rem] border border-amber-200/70 px-6 sm:px-8">
          <div class="divide-y divide-amber-100">
            <!-- Cuándo -->
            <div v-if="invite.event_date" class="flex items-center gap-4 py-5">
              <span
                class="grid h-11 w-11 shrink-0 place-items-center rounded-full text-amber-700 ring-1 ring-amber-300/70"
              >
                <CalendarHeart :size="18" :stroke-width="1.5" />
              </span>
              <div class="min-w-0">
                <p class="text-[0.62rem] uppercase tracking-[0.28em] text-amber-700/80">Cuándo</p>
                <p
                  class="mt-1 text-[17px] leading-tight text-stone-700"
                  style="font-family: 'Playfair Display', serif"
                >
                  {{ formatDateLong(invite.event_date) }}
                </p>
                <p v-if="invite.reception_time" class="mt-0.5 text-xs tracking-wide text-stone-400">
                  {{ formatTime(invite.reception_time)
                  }}<span v-if="invite.end_time"> — {{ formatTime(invite.end_time) }}</span> h
                </p>
              </div>
            </div>

            <!-- Dónde -->
            <div
              v-if="invite.venue_name || invite.venue_address"
              class="flex items-center gap-4 py-5"
            >
              <span
                class="grid h-11 w-11 shrink-0 place-items-center rounded-full text-amber-700 ring-1 ring-amber-300/70"
              >
                <MapPin :size="18" :stroke-width="1.5" />
              </span>
              <div class="min-w-0">
                <p class="text-[0.62rem] uppercase tracking-[0.28em] text-amber-700/80">Dónde</p>
                <p
                  v-if="invite.venue_name"
                  class="mt-1 text-[17px] leading-tight text-stone-700"
                  style="font-family: 'Playfair Display', serif"
                >
                  {{ invite.venue_name }}
                </p>
                <p v-if="invite.venue_address" class="mt-0.5 text-xs text-stone-400">
                  {{ invite.venue_address }}
                </p>
                <a
                  v-if="invite.maps_url"
                  :href="invite.maps_url"
                  target="_blank"
                  rel="noopener"
                  class="mt-2 inline-flex items-center gap-1 rounded-full border border-rose-200 px-3 py-1 text-[0.7rem] font-medium uppercase tracking-wider text-rose-700 transition hover:bg-rose-50"
                >
                  Cómo llegar <ArrowUpRight :size="13" :stroke-width="2" />
                </a>
              </div>
            </div>

            <!-- Dress code -->
            <div v-if="invite.dress_code" class="flex items-center gap-4 py-5">
              <span
                class="grid h-11 w-11 shrink-0 place-items-center rounded-full text-amber-700 ring-1 ring-amber-300/70"
              >
                <Gem :size="18" :stroke-width="1.5" />
              </span>
              <div class="min-w-0">
                <p class="text-[0.62rem] uppercase tracking-[0.28em] text-amber-700/80">Dress code</p>
                <p
                  class="mt-1 text-[17px] leading-tight text-stone-700"
                  style="font-family: 'Playfair Display', serif"
                >
                  {{ invite.dress_code }}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <p
        v-if="invite.notes"
        class="mt-6 text-center text-sm italic leading-relaxed text-stone-500"
        style="font-family: 'Playfair Display', serif"
      >
        {{ invite.notes }}
      </p>

      <div
        v-if="shows('detalle')"
        class="mt-12 overflow-hidden rounded-[2rem] shadow-xl ring-1 ring-amber-200"
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

    <!-- ============ REGALOS ============ -->
    <section
      v-if="invite.gift_alias"
      v-reveal
      data-anchor="regalos"
      class="mx-auto max-w-md px-6 pb-8 text-center"
    >
      <span
        class="mx-auto grid h-12 w-12 place-items-center rounded-full text-amber-700 ring-1 ring-amber-300/70"
      >
        <Gift :size="20" :stroke-width="1.5" />
      </span>
      <p
        class="mt-4 text-lg italic leading-relaxed text-stone-600"
        style="font-family: 'Playfair Display', serif"
      >
        El mejor regalo que podés hacerme es tu presencia.
      </p>
      <p class="mt-3 text-sm text-stone-400">
        Pero si querés acercarme un presente, te dejo mi alias:
      </p>
      <button
        type="button"
        @click="copyAlias"
        class="mt-3 inline-flex items-center gap-2 rounded-full bg-white px-4 py-2 font-mono text-sm text-stone-700 shadow ring-1 ring-amber-200 transition hover:bg-amber-50"
      >
        {{ aliasCopied ? '¡Copiado!' : invite.gift_alias }}
        <Check v-if="aliasCopied" :size="14" />
        <Copy v-else :size="14" />
      </button>
    </section>

    <!-- ============ CANCIONES (plan "plus") ============ -->
    <section v-if="invite.plan === 'plus'" v-reveal data-anchor="canciones" class="mx-auto max-w-xl px-6 py-20">
      <p class="text-center text-[0.7rem] uppercase tracking-[0.45em] text-amber-700/80">
        Ayudanos con el playlist
      </p>
      <h2 class="mt-2 text-center text-4xl text-rose-800" style="font-family: 'Dancing Script', cursive">
        ¿Qué canción no puede faltar?
      </h2>
      <div class="divider">✦</div>

      <div class="mt-8 rounded-[2rem] bg-white p-6 shadow-xl ring-1 ring-amber-100 sm:p-8">
        <template v-if="justAddedSong">
          <p class="py-2 text-center text-4xl">🎶</p>
          <p class="text-center text-stone-600">¡Gracias! La sumamos a la lista.</p>
          <button
            type="button"
            @click="justAddedSong = false"
            class="mx-auto mt-4 block text-sm font-medium text-rose-700 underline decoration-rose-300"
          >
            Agregar otra
          </button>
        </template>

        <template v-else>
          <div class="relative">
            <input
              v-model="songQuery"
              type="text"
              placeholder="Buscá una canción o artista…"
              class="w-full rounded-xl border border-amber-200 bg-black/5 px-3 py-2 pr-9 focus:border-rose-400 focus:outline-none"
              @input="onSongQueryInput"
            />
            <Search
              :size="16"
              class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-stone-400"
            />
          </div>

          <p v-if="songSearching" class="mt-2 text-center text-xs text-stone-400">Buscando…</p>
          <p v-else-if="songSearchError" class="mt-2 text-center text-xs text-red-500">
            {{ songSearchError }}
          </p>

          <ul v-if="songResults.length && !selectedSong" class="mt-2 max-h-64 space-y-1 overflow-y-auto">
            <li v-for="r in songResults" :key="r.videoId">
              <button
                type="button"
                @click="selectSong(r)"
                class="flex w-full items-center gap-3 rounded-xl px-2 py-2 text-left transition hover:bg-amber-50"
              >
                <img :src="r.thumbnail" alt="" class="h-10 w-10 shrink-0 rounded object-cover" />
                <span class="min-w-0">
                  <span class="block truncate text-sm text-stone-700">{{ r.title }}</span>
                  <span class="block truncate text-xs text-stone-400">{{ r.channel }}</span>
                </span>
              </button>
            </li>
          </ul>

          <div
            v-if="selectedSong"
            class="mt-3 flex items-center gap-3 rounded-xl bg-amber-50 px-3 py-2 ring-1 ring-amber-200"
          >
            <img :src="selectedSong.thumbnail" alt="" class="h-10 w-10 shrink-0 rounded object-cover" />
            <span class="min-w-0 flex-1">
              <span class="block truncate text-sm text-stone-700">{{ selectedSong.title }}</span>
              <span class="block truncate text-xs text-stone-400">{{ selectedSong.channel }}</span>
            </span>
            <button
              type="button"
              @click="clearSelectedSong"
              aria-label="Quitar canción elegida"
              class="shrink-0 px-1 text-rose-500"
            >
              ✕
            </button>
          </div>

          <form v-if="selectedSong" @submit.prevent="submitSong" class="mt-4 space-y-3">
            <input
              v-model="songRequesterName"
              placeholder="Tu nombre o familia"
              class="w-full rounded-xl border border-amber-200 bg-black/5 px-3 py-2 focus:border-rose-400 focus:outline-none"
            />
            <p v-if="displaySongError" class="text-sm text-red-600">{{ displaySongError }}</p>
            <button
              type="submit"
              :disabled="songSubmitting"
              class="w-full rounded-full bg-linear-to-r from-rose-700 to-rose-800 px-4 py-3 font-medium text-white shadow-md transition hover:brightness-105 disabled:opacity-50"
            >
              {{ songSubmitting ? 'Agregando…' : 'Agregar canción' }}
            </button>
          </form>
        </template>
      </div>
    </section>

    <!-- ============ CARRUSEL ============ -->
    <section v-if="shows('momentos')" v-reveal data-anchor="momentos" class="py-20">
      <h2 class="text-center text-3xl text-rose-800" style="font-family: 'Dancing Script', cursive">
        Momentos
      </h2>
      <div class="divider">✦</div>

      <div
        class="relative mx-auto mt-6 max-w-2xl overflow-hidden shadow-xl sm:rounded-[2rem] sm:ring-1 sm:ring-amber-200"
        @touchstart.passive="onTouchStart"
        @touchend.passive="onTouchEnd"
        @mouseenter="stopMomentosAutoplay"
        @mouseleave="startMomentosAutoplay"
      >
        <div
          class="flex transition-transform duration-700 ease-out"
          :style="{ transform: `translateX(-${slide * 100}%)` }"
        >
          <div v-for="(src, i) in momentosFotos" :key="i" class="min-w-full">
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
            v-for="(s, i) in momentosFotos"
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

    <!-- ============ GALERÍA (grid) ============ -->
    <section v-if="shows('galeria')" v-reveal data-anchor="galeria" class="overflow-hidden py-20">
      <p class="text-center text-[0.7rem] uppercase tracking-[0.45em] text-amber-700/80">Recuerdos</p>
      <h2
        class="mt-2 text-center text-4xl text-rose-800"
        style="font-family: 'Dancing Script', cursive"
      >
        Galería
      </h2>
      <div class="divider">✦</div>

      <div class="mx-auto mt-8 grid max-w-4xl grid-cols-2 gap-3 px-4 sm:grid-cols-4 sm:gap-4">
        <div
          v-for="(src, i) in galeriaGrid"
          :key="i"
          ref="gridItems"
          class="overflow-hidden rounded-2xl shadow-lg ring-1 ring-amber-200/60 will-change-transform"
        >
          <img
            :src="src"
            :alt="`Recuerdo ${i + 1}`"
            loading="lazy"
            decoding="async"
            class="block aspect-square w-full object-cover"
          />
        </div>
      </div>
    </section>

    <!-- ============ RSVP ============ -->
    <section id="rsvp" v-reveal data-anchor="rsvp" class="mx-auto max-w-xl scroll-mt-6 px-6 py-20">
      <div class="rounded-[2rem] bg-white p-8 shadow-xl ring-1 ring-amber-100">
        <h2 class="text-center text-3xl text-rose-800" style="font-family: 'Dancing Script', cursive">
          Confirmá tu asistencia
        </h2>
        <div class="divider">✦</div>

        <p
          v-if="preview"
          class="mb-4 rounded-lg bg-amber-50 px-3 py-2 text-center text-xs text-amber-700"
        >
          Vista previa — la confirmación funciona en la invitación real.
        </p>

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
              class="flex items-center justify-between gap-2 rounded-xl border border-amber-200/70 bg-black/5 px-3 py-2"
            >
              <span class="text-stone-800">{{ guest.full_name }}</span>
              <div class="flex shrink-0 gap-2">
                <button
                  type="button"
                  translate="no"
                  @click="guest.attending = true"
                  :class="guest.attending ? 'bg-rose-700 text-white' : 'bg-white text-stone-400'"
                  class="rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset ring-amber-200 transition sm:text-sm"
                >
                  Asiste
                </button>
                <button
                  type="button"
                  translate="no"
                  @click="guest.attending = false"
                  :class="!guest.attending ? 'bg-stone-700 text-white' : 'bg-white text-stone-400'"
                  class="rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset ring-amber-200 transition sm:text-sm"
                >
                  No asiste
                </button>
              </div>
            </li>
          </ul>

          <p v-if="displayError" class="mt-3 text-sm text-red-600">{{ displayError }}</p>

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
                class="flex-1 rounded-xl border border-amber-200 bg-black/5 px-3 py-2 focus:border-rose-400 focus:outline-none"
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

            <p v-if="displayError" class="text-sm text-red-600">{{ displayError }}</p>

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
    <footer data-anchor="cierre" class="px-6 pb-16 pt-4 text-center">
      <div class="divider">✦</div>
      <p class="text-4xl text-rose-800" style="font-family: 'Dancing Script', cursive">
        {{ invite.closing_text || '¡Los esperamos!' }}
      </p>
    </footer>

    <!-- Botón flotante: música -->
    <button
      v-if="entered && musicId && !preview"
      type="button"
      @click="toggleMusic"
      :aria-label="musicPlaying ? 'Pausar música' : 'Reproducir música'"
      class="fixed bottom-5 left-5 z-30 grid h-11 w-11 place-items-center rounded-full bg-rose-800 text-white shadow-lg ring-1 ring-white/20 transition hover:brightness-110"
    >
      <Pause v-if="musicPlaying" :size="18" />
      <Music v-else :size="18" />
    </button>
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

@media (prefers-reduced-motion: reduce) {
  .kenburns,
  .hero-in {
    animation: none;
  }
  .kenburns {
    opacity: 1;
  }
}

/* --- Sobre (portada) ----------------------------------------------------- */
.envelope-overlay {
  transition: opacity 0.6s ease;
}
.envelope-overlay--out {
  opacity: 0;
  pointer-events: none;
}

.envelope {
  position: relative;
  width: clamp(220px, 72vw, 300px);
  aspect-ratio: 3 / 2;
  padding: 0;
  border: none;
  background: none;
  perspective: 900px;
  cursor: pointer;
}
.envelope:disabled {
  cursor: default;
}

.envelope-back {
  position: absolute;
  inset: 0;
  border-radius: 12px;
  background: linear-gradient(155deg, #fffdf9 0%, #fbe6cd 100%);
  box-shadow: 0 30px 60px -25px rgba(120, 72, 40, 0.45);
}

.envelope-letter {
  position: absolute;
  left: 10%;
  right: 10%;
  top: 4%;
  height: 58%;
  border-radius: 8px 8px 3px 3px;
  background: #fffdf9;
  box-shadow: 0 8px 20px -10px rgba(120, 72, 40, 0.3);
  display: flex;
  align-items: flex-end;
  justify-content: center;
  padding-bottom: 10%;
  color: #9f1239;
  font-size: 1.1rem;
  transform: translateY(0);
  transition: transform 0.7s cubic-bezier(0.22, 0.9, 0.32, 1) 0.35s;
  z-index: 2;
}
.envelope--open .envelope-letter {
  transform: translateY(-46%);
}

.envelope-pocket {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 62%;
  background: linear-gradient(155deg, #fde1c4, #f4bd85);
  clip-path: polygon(0 0, 50% 46%, 100% 0, 100% 100%, 0 100%);
  border-radius: 0 0 12px 12px;
  z-index: 3;
}

.envelope-flap {
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  height: 56%;
  background: linear-gradient(200deg, #f4bd85, #e6a05f);
  clip-path: polygon(0 0, 100% 0, 50% 92%);
  border-radius: 12px 12px 0 0;
  box-shadow: 0 4px 10px -6px rgba(120, 72, 40, 0.4);
  transform-origin: top center;
  transition: transform 0.6s cubic-bezier(0.5, 0, 0.2, 1);
  z-index: 4;
}
.envelope--open .envelope-flap {
  transform: rotateX(-165deg);
}

.envelope-seal {
  position: absolute;
  left: 50%;
  top: 44%;
  transform: translate(-50%, -50%);
  width: 44px;
  height: 44px;
  border-radius: 999px;
  display: grid;
  place-items: center;
  background: radial-gradient(circle at 32% 28%, #e11d48, #9f1239 70%);
  color: #fde7ea;
  font-size: 1.1rem;
  box-shadow: 0 6px 14px -6px rgba(159, 18, 57, 0.6);
  transition:
    opacity 0.35s ease,
    transform 0.35s ease;
  z-index: 5;
}
.envelope--open .envelope-seal {
  opacity: 0;
  transform: translate(-50%, -50%) scale(0.4);
}

.envelope-letter-mark {
  color: #d6a756;
  font-size: 1.3rem;
}

.envelope-caption {
  transition:
    opacity 0.35s ease,
    transform 0.35s ease;
}
.envelope-caption--out {
  opacity: 0;
  transform: translateY(6px);
}

@media (prefers-reduced-motion: reduce) {
  .envelope-overlay,
  .envelope-flap,
  .envelope-letter,
  .envelope-seal,
  .envelope-caption {
    transition: none;
  }
}
</style>
