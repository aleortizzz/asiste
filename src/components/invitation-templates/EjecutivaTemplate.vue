<script setup>
import { computed, ref } from 'vue'
import { MapPin, ArrowUpRight, Music, Pause, Copy, Check, Search, CalendarPlus, X, Mail, MessageCircle } from '@lucide/vue'
import { useInvitationLogic } from '../../composables/useInvitationLogic'
import { isDark } from '../../lib/color'
import { googleCalendarUrl, openGoogleCalendar, downloadIcs, isIOS } from '../../lib/calendar'
import EjecutivaCarousel from './EjecutivaCarousel.vue'

// Plantilla «Ejecutiva» — para eventos empresariales: tarjeta impresa con
// marco fino doble, serif fina (Cormorant Garamond) y versalitas espaciadas
// (Inter), sin sobre ni adornos. La portada se arma sola con una animación
// corta (marco → logo → línea dorada que se dibuja → textos).
//
// Colores: `primary_color` es el tono profundo (marino, negro, grafito…),
// `accent_color` el de los detalles (champagne, dorado) y `bg_color` el papel
// en modo claro. `theme_mode` elige papel claro u oscuro.
// Textos: `tono` ('usted' | 'vos') y si la invitación es para una o varias
// personas deciden cómo se le habla al invitado.
//
// Mismo contrato de props/emits que las otras plantillas; la lógica (RSVP,
// canciones, música, cuenta regresiva…) vive en useInvitationLogic().
const props = defineProps({
  invite: { type: Object, required: true },
  preview: { type: Boolean, default: false },
  submitting: { type: Boolean, default: false },
  submitted: { type: Boolean, default: false },
  error: { type: String, default: '' },
  songSubmitting: { type: Boolean, default: false },
  songError: { type: String, default: '' },
})

const emit = defineEmits(['submit-generic', 'submit-named', 'submit-song'])

const {
  names,
  namedGuests,
  displayError,
  slotUrls,
  heroTitle,
  primaryColor,
  bgColor,
  shows,
  showGifts,
  showSongs,
  showIntro,
  showClosing,
  showFinePrint,
  defaultIntro,
  entered,
  musicPlaying,
  ytFrame,
  musicId,
  ytSrc,
  toggleMusic,
  aliasCopied,
  copyAlias,
  songQuery,
  songResults,
  songSearching,
  songSearchError,
  selectedSong,
  songRequesterName,
  displaySongError,
  justAddedSong,
  onSongQueryInput,
  selectSong,
  clearSelectedSong,
  submitSong,
  vReveal,
  countdown,
  now,
  addName,
  removeName,
  formatDate,
  formatTime,
  rsvpDeadlinePassed,
  rsvpClosed,
  confirmarGenerico,
  declinarGenerico,
  enviarRespuestasNominales,
} = useInvitationLogic(props, emit)

// Sin sobre: la invitación está «abierta» desde el principio (useInvitationLogic
// bloquea el scroll mientras `entered` es false).
entered.value = true

// --- Colores ------------------------------------------------------------------
const dark = computed(() => props.invite.theme_mode === 'oscuro')
const accent = computed(() => props.invite.accent_color || '#c8a96a')
// En oscuro el fondo es el color principal; la tinta, clara u oscura según él.
const pageBg = computed(() => (dark.value ? primaryColor.value : bgColor.value))
const ink = computed(() => {
  if (dark.value) return isDark(primaryColor.value) ? '#f3efe6' : '#141414'
  return isDark(bgColor.value) ? '#f3efe6' : primaryColor.value
})
const btnBg = computed(() => (dark.value ? accent.value : primaryColor.value))
const btnInk = computed(() => (isDark(btnBg.value) ? '#f7f4ee' : '#141414'))

// --- Textos según el tono y la cantidad de invitados ---------------------------
const usted = computed(() => props.invite.tono === 'usted')
const plural = computed(() => {
  const named = props.invite.named_by_host ? props.invite.guests?.length ?? 0 : 0
  return Math.max(props.invite.allowed_guests ?? 1, named) > 1
})

// Todas las frases evitan el género («lo/la»): «contar con su presencia».
const t = computed(() => {
  const u = usted.value
  const p = plural.value
  return {
    invite: u ? 'tenemos el agrado de contar con su presencia en' : p ? 'queremos que nos acompañen en' : 'queremos que nos acompañes en',
    rsvpLead: u
      ? p ? 'Les pedimos que confirmen su asistencia.' : 'Le pedimos que confirme su asistencia.'
      : p ? 'Confirmen su asistencia, por favor.' : 'Confirmá tu asistencia, por favor.',
    thanks: u || p ? 'Gracias. Registramos su respuesta.' : 'Gracias. Registramos tu respuesta.',
    decline: p ? 'No podremos asistir' : 'No podré asistir',
    closing: u ? (p ? 'Los esperamos.' : 'Esperamos contar con su presencia.') : p ? 'Los esperamos.' : 'Te esperamos.',
    gift: u
      ? `Su presencia es el mejor obsequio. Si ${p ? 'desean' : 'desea'} hacernos llegar un presente, este es nuestro alias:`
      : p
        ? 'Su presencia es lo más importante. Si quieren hacernos llegar un presente, este es nuestro alias:'
        : 'Tu presencia es lo más importante. Si querés hacernos llegar un presente, este es nuestro alias:',
    songName: u || p ? 'Su nombre' : 'Tu nombre',
  }
})

// --- Portada --------------------------------------------------------------------
const logoUrl = computed(() => slotUrls('logo')[0] || '')
const sponsorUrls = computed(() => slotUrls('sponsors'))

// Sponsors parejos: a la misma altura, un logo muy ancho se ve enorme y uno
// cuadrado diminuto. Cada uno toma un tamaño según su forma para que todos
// ocupen más o menos la misma superficie (con topes de ancho y alto).
const SPONSOR_AREA = 2600 // px² aprox. de cada logo
const sponsorRatio = ref({}) // { url: ancho / alto }
function onSponsorLoad(e, src) {
  const { naturalWidth: w, naturalHeight: h } = e.target
  if (w && h) sponsorRatio.value = { ...sponsorRatio.value, [src]: w / h }
}
function sponsorStyle(src) {
  const r = sponsorRatio.value[src]
  if (!r) return { maxHeight: '36px', maxWidth: '140px' } // mientras carga
  const h = Math.min(64, Math.max(22, Math.sqrt(SPONSOR_AREA / r)))
  const w = Math.min(170, h * r)
  return { width: `${w}px`, height: `${w / r}px` }
}
const dateStyle = computed(() => props.invite.date_style || 'regresiva')

// 'YYYY-MM-DD' en hora local (si no, se corre un día por el huso horario).
const eventDay = computed(() => {
  if (!props.invite.event_date) return null
  const [y, m, d] = props.invite.event_date.split('-').map(Number)
  return new Date(y, m - 1, d)
})
const fmt = (opts) => eventDay.value?.toLocaleDateString('es-AR', opts) ?? ''
const weekday = computed(() => fmt({ weekday: 'long' }))
const monthName = computed(() => fmt({ month: 'long' }))
const time = computed(() => (props.invite.reception_time ? `${formatTime(props.invite.reception_time)} h` : ''))
const dateLine = computed(() => fmt({ weekday: 'long', day: 'numeric', month: 'long' }))

const daysLeftText = computed(() => {
  if (!eventDay.value) return ''
  const today = new Date(now.value)
  today.setHours(0, 0, 0, 0)
  const days = Math.round((eventDay.value - today) / 86400000)
  if (days < 0) return ''
  if (days === 0) return 'Es hoy'
  if (days === 1) return 'Es mañana'
  return `Faltan ${days} días`
})

const countdownParts = computed(() => {
  const c = countdown.value
  if (!c) return []
  return [
    { label: 'Días', value: c.days },
    { label: 'Horas', value: c.hours },
    { label: 'Min', value: c.minutes },
  ]
})

// --- Agregar al calendario ---------------------------------------------------------
const calendarOpen = ref(false)
const googleUrl = computed(() => googleCalendarUrl(props.invite))
function onIcs() {
  downloadIcs(props.invite)
  calendarOpen.value = false
}
function onGoogle() {
  openGoogleCalendar(props.invite)
  calendarOpen.value = false
}
// La opción del propio teléfono va primero: en iPhone, su calendario (se abre
// la ventanita nativa encima de la invitación, sin salir).
const ios = isIOS()
const calendarOptions = computed(() => {
  const google = { key: 'google', label: 'Google Calendar', action: onGoogle }
  const ics = { key: 'ics', label: ios ? 'Calendario del iPhone' : 'iPhone, Outlook y otros', action: onIcs }
  return ios ? [ics, google] : [google, ics]
})

// --- Secciones empresariales (cada una: con datos y sin apagar) -----------------
// Programa: en el orden en que lo cargaron; las filas sin título no cuentan.
const agendaItems = computed(() =>
  shows('agenda') && Array.isArray(props.invite.agenda) ? props.invite.agenda.filter((i) => i?.title?.trim()) : [],
)
const accessInfo = computed(() => (shows('acceso') ? (props.invite.access_info || '').trim() : ''))

const contact = computed(() => {
  if (!shows('contacto')) return null
  const name = (props.invite.contact_name || '').trim()
  const email = (props.invite.contact_email || '').trim()
  const phone = (props.invite.contact_phone || '').trim()
  if (!name && !email && !phone) return null
  const digits = phone.replace(/\D/g, '')
  return { name, email, wa: digits ? `https://wa.me/${digits}` : '' }
})

// Acepta links completos, «www.…» o (Instagram) «@usuario».
const withHttp = (u) => (/^https?:\/\//i.test(u) ? u : `https://${u}`)
const socials = computed(() => {
  if (!shows('redes')) return []
  const s = props.invite.social_links || {}
  const out = []
  if (s.linkedin?.trim()) out.push({ label: 'LinkedIn', url: withHttp(s.linkedin.trim()) })
  if (s.instagram?.trim()) {
    const v = s.instagram.trim()
    out.push({ label: 'Instagram', url: /instagram\.com/i.test(v) ? withHttp(v) : `https://instagram.com/${v.replace(/^@/, '')}` })
  }
  if (s.web?.trim()) out.push({ label: 'Web', url: withHttp(s.web.trim()) })
  return out
})

// --- Fotos: solo las que subió el organizador (nunca las de demo) ---------------
// La de portada va como franja panorámica debajo de la tarjeta; el carrusel
// del saludo, debajo de la bienvenida.
const bannerPhoto = computed(() => slotUrls('banner')[0] || '')
const saludoPhotos = computed(() => (shows('retrato') ? slotUrls('retrato') : []))
const detallePhoto = computed(() => (shows('detalle') ? slotUrls('detalle')[0] : '') || '')
const momentos = computed(() => (shows('momentos') ? slotUrls('momentos') : []))
const galeria = computed(() => (shows('galeria') ? slotUrls('galeria') : []))
</script>

<template>
  <div class="ej min-h-screen overflow-x-clip" :class="{ 'ej-dark': dark }">
    <iframe
      v-if="ytSrc && !preview"
      ref="ytFrame"
      :src="ytSrc"
      title="Música"
      allow="autoplay"
      class="pointer-events-none fixed bottom-0 left-0 -z-10 h-px w-px opacity-[0.01]"
    ></iframe>

    <!-- ============ PORTADA: la tarjeta ============ -->
    <header data-anchor="hero" class="flex min-h-svh items-center justify-center px-4 pt-7 pb-10 sm:px-6">
      <div class="ej-card relative w-full max-w-[620px] px-6 pt-16 pb-12 text-center sm:px-10">
        <img
          v-if="logoUrl"
          :src="logoUrl"
          alt=""
          class="ej-in mx-auto block max-h-12 max-w-[200px] object-contain"
          :class="{ 'ej-white': invite.logo_white }"
          style="--d: 0.5s"
        />

        <p class="ej-label ej-in" :class="logoUrl ? 'mt-9' : ''" style="--d: 0.9s">{{ invite.hero_kicker || 'Invitación' }}</p>
        <div class="ej-rule ej-draw mx-auto mt-5 mb-6" style="--d: 1.1s"></div>

        <p v-if="invite.family_name" class="ej-guest ej-in" style="--d: 1.5s">
          {{ invite.family_name }}, {{ t.invite }}
        </p>
        <h1 class="ej-title ej-in mt-2.5 break-words" style="--d: 1.7s">{{ heroTitle }}</h1>
        <p v-if="invite.hero_subtitle" class="ej-muted ej-in mt-3.5 text-[15px] leading-relaxed text-balance sm:text-[17px]" style="--d: 1.9s">
          {{ invite.hero_subtitle }}
        </p>

        <!-- Fecha, en el estilo que eligió el organizador -->
        <div v-if="eventDay" class="ej-in mt-10" style="--d: 2.1s">
          <div v-if="dateStyle === 'destacada'" class="flex items-center justify-center gap-[clamp(14px,4vw,28px)]">
            <p class="ej-label w-[108px] text-right leading-[1.9]">{{ weekday }}<br />{{ monthName }}</p>
            <p class="ej-day border-x px-[clamp(14px,4vw,26px)]">{{ eventDay.getDate() }}</p>
            <p class="ej-label w-[108px] text-left leading-[1.9]">{{ eventDay.getFullYear() }}<br />{{ time || ' ' }}</p>
          </div>

          <div v-else-if="dateStyle === 'discreta' || !countdownParts.length">
            <p class="ej-label ej-ink">
              <span class="whitespace-nowrap">{{ dateLine }}</span>
              <template v-if="time"><span class="hidden sm:inline"> · </span><span class="block whitespace-nowrap sm:inline">{{ time }}</span></template>
            </p>
            <p v-if="daysLeftText" class="ej-guest mt-2.5">{{ daysLeftText }}</p>
          </div>

          <div v-else>
            <div class="flex justify-center gap-[clamp(10px,3vw,22px)]">
              <div v-for="u in countdownParts" :key="u.label" class="min-w-16">
                <p class="ej-num">{{ u.value }}</p>
                <p class="ej-label mt-2 text-[10px]">{{ u.label }}</p>
              </div>
            </div>
            <p class="ej-label mt-5">{{ dateLine }}<template v-if="time"> · {{ time }}</template></p>
          </div>
        </div>

        <div v-if="invite.venue_name || invite.venue_address" class="ej-in mt-8 text-sm leading-relaxed" style="--d: 2.3s">
          <p v-if="invite.venue_name" class="ej-ink font-medium tracking-[0.02em]">{{ invite.venue_name }}</p>
          <p v-if="invite.venue_address" class="ej-muted">{{ invite.venue_address }}</p>
        </div>

        <!-- relative z-20: cada bloque con animación de entrada queda en su propia
             capa; sin esto, la leyenda de abajo se dibujaba encima del menú. -->
        <div class="ej-in relative z-20 mt-10 flex flex-wrap justify-center gap-2.5" style="--d: 2.5s">
          <div v-if="googleUrl" class="relative">
            <button type="button" class="ej-btn ej-btn-ghost" :aria-expanded="calendarOpen" @click="calendarOpen = !calendarOpen">
              Agregar al calendario
            </button>
            <div v-if="calendarOpen" class="fixed inset-0 z-30" @click="calendarOpen = false"></div>
            <div v-if="calendarOpen" class="ej-menu absolute left-1/2 z-40 mt-2 w-60 -translate-x-1/2 p-1.5 text-left">
              <button v-for="opt in calendarOptions" :key="opt.key" type="button" class="ej-menu-item w-full" @click="opt.action">
                <CalendarPlus :size="16" :stroke-width="1.5" /> {{ opt.label }}
              </button>
            </div>
          </div>
        </div>

        <p v-if="showFinePrint" class="ej-fine ej-in mt-11" style="--d: 2.8s">Invitación personal e intransferible</p>
      </div>
    </header>

    <!-- ============ FOTO DE PORTADA ============ -->
    <!-- Nunca se recorta (puede ser un logo o una gráfica con texto): se ve
         entera con su forma, y si es muy alta se achica para entrar en pantalla. -->
    <div v-if="bannerPhoto" v-reveal class="mx-auto max-w-[1100px] px-4 sm:px-6">
      <img :src="bannerPhoto" alt="" decoding="async" class="mx-auto block h-auto max-h-[85svh] w-auto max-w-full object-contain" />
    </div>

    <!-- ============ SALUDO ============ -->
    <section v-if="showIntro || saludoPhotos.length" v-reveal data-anchor="saludo" class="mx-auto max-w-[620px] px-6 py-16 text-center">
      <template v-if="showIntro">
        <p class="ej-label">Bienvenida</p>
        <p class="ej-lead mt-5 whitespace-pre-line">{{ invite.intro_text || defaultIntro }}</p>
      </template>
      <EjecutivaCarousel v-if="saludoPhotos.length" :photos="saludoPhotos" aspect="4 / 5" label="Bienvenida" :class="showIntro ? 'mt-12' : ''" />
    </section>

    <!-- ============ DETALLES ============ -->
    <section v-reveal data-anchor="fiesta" class="mx-auto max-w-[620px] px-6 py-16">
      <p class="ej-label text-center">El evento</p>
      <div class="ej-rule mx-auto mt-5"></div>

      <dl class="mt-10 divide-y border-y">
        <div v-if="eventDay" class="ej-row">
          <dt class="ej-label">Fecha</dt>
          <dd class="ej-ink first-letter:uppercase">{{ fmt({ weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }) }}</dd>
        </div>
        <div v-if="invite.reception_time" class="ej-row">
          <dt class="ej-label">Horario</dt>
          <dd class="ej-ink">
            {{ formatTime(invite.reception_time) }}<template v-if="invite.end_time"> a {{ formatTime(invite.end_time) }}</template> h
          </dd>
        </div>
        <div v-if="invite.venue_name || invite.venue_address" class="ej-row">
          <dt class="ej-label">Lugar</dt>
          <dd>
            <p v-if="invite.venue_name" class="ej-ink">{{ invite.venue_name }}</p>
            <p v-if="invite.venue_address" class="ej-muted text-sm">{{ invite.venue_address }}</p>
            <a v-if="invite.maps_url" :href="invite.maps_url" target="_blank" rel="noopener" class="ej-link mt-2">
              <MapPin :size="14" :stroke-width="1.5" /> Cómo llegar <ArrowUpRight :size="13" :stroke-width="1.5" />
            </a>
          </dd>
        </div>
        <div v-if="accessInfo" class="ej-row">
          <dt class="ej-label">Acceso</dt>
          <dd class="ej-muted text-sm leading-relaxed whitespace-pre-line">{{ accessInfo }}</dd>
        </div>
        <div v-if="invite.dress_code" class="ej-row">
          <dt class="ej-label">Vestimenta</dt>
          <dd class="ej-ink">{{ invite.dress_code }}</dd>
        </div>
        <div v-if="invite.notes" class="ej-row">
          <dt class="ej-label">Información</dt>
          <dd class="ej-muted text-sm leading-relaxed whitespace-pre-line">{{ invite.notes }}</dd>
        </div>
      </dl>

      <img
        v-if="detallePhoto"
        :src="detallePhoto"
        alt=""
        loading="lazy"
        decoding="async"
        class="mx-auto mt-12 block h-auto max-h-[85svh] w-auto max-w-full object-contain"
      />
    </section>

    <!-- ============ PROGRAMA ============ -->
    <section v-if="agendaItems.length" v-reveal data-anchor="programa" class="mx-auto max-w-[620px] px-6 py-16">
      <p class="ej-label text-center">Programa</p>
      <div class="ej-rule mx-auto mt-5"></div>
      <ol class="ej-agenda mt-10">
        <li v-for="(item, i) in agendaItems" :key="i" class="ej-agenda-item">
          <p class="ej-agenda-time">{{ item.time || '—' }}</p>
          <div class="min-w-0">
            <p class="ej-agenda-title">{{ item.title }}</p>
            <p v-if="item.detail" class="ej-muted mt-1 text-sm leading-relaxed">{{ item.detail }}</p>
          </div>
        </li>
      </ol>
    </section>

    <!-- ============ FOTOS (solo si el organizador subió) ============ -->
    <section v-if="momentos.length" v-reveal data-anchor="momentos" class="mx-auto max-w-[900px] px-6 py-16">
      <p class="ej-label text-center">Momentos</p>
      <div class="ej-rule mx-auto mt-5"></div>
      <EjecutivaCarousel :photos="momentos" aspect="3 / 2" label="Momentos" class="mt-10" />
    </section>

    <section v-if="galeria.length" v-reveal data-anchor="galeria" class="mx-auto max-w-[900px] px-6 py-16">
      <p class="ej-label text-center">Galería</p>
      <div class="ej-rule mx-auto mt-5"></div>
      <!-- Columnas en vez de cuadrados: cada foto con su forma, sin recortes. -->
      <div class="mt-10 columns-2 gap-3 sm:columns-3">
        <img
          v-for="(src, i) in galeria"
          :key="i"
          :src="src"
          alt=""
          loading="lazy"
          decoding="async"
          class="mb-3 block h-auto w-full break-inside-avoid"
        />
      </div>
    </section>

    <!-- ============ OBSEQUIOS ============ -->
    <section v-if="showGifts" v-reveal data-anchor="regalos" class="mx-auto max-w-[520px] px-6 py-14 text-center">
      <p class="ej-label">Obsequios</p>
      <p class="ej-muted mt-5 leading-relaxed">{{ t.gift }}</p>
      <button type="button" class="ej-btn ej-btn-ghost mt-5 inline-flex items-center gap-2 normal-case tracking-normal" @click="copyAlias">
        <span class="font-mono">{{ aliasCopied ? 'Copiado' : invite.gift_alias }}</span>
        <Check v-if="aliasCopied" :size="14" />
        <Copy v-else :size="14" />
      </button>
    </section>

    <!-- ============ CANCIONES (plan Plus) ============ -->
    <section v-if="showSongs" v-reveal data-anchor="canciones" class="mx-auto max-w-[620px] px-6 py-16 text-center">
      <p class="ej-label">Sugerencias musicales</p>
      <div class="ej-rule mx-auto mt-5"></div>

      <div class="ej-panel mt-10 p-6 text-left sm:p-8">
        <div v-if="justAddedSong" class="text-center">
          <p class="ej-lead">Gracias. La sumamos a la lista.</p>
          <button type="button" class="ej-link mx-auto mt-4" @click="justAddedSong = false">Sugerir otra</button>
        </div>

        <template v-else>
          <div class="relative">
            <input v-model="songQuery" type="text" placeholder="Buscar una canción o artista" class="ej-input pr-10" @input="onSongQueryInput" />
            <Search :size="16" class="ej-muted pointer-events-none absolute top-1/2 right-4 -translate-y-1/2" />
          </div>

          <p v-if="songSearching" class="ej-muted mt-3 text-center text-xs">Buscando…</p>
          <p v-else-if="songSearchError" class="ej-error mt-3 text-center text-xs">{{ songSearchError }}</p>

          <ul v-if="songResults.length && !selectedSong" class="mt-3 max-h-64 space-y-1 overflow-y-auto">
            <li v-for="r in songResults" :key="r.videoId">
              <button type="button" class="ej-song flex w-full items-center gap-3 px-2 py-2 text-left" @click="selectSong(r)">
                <img :src="r.thumbnail" alt="" class="h-10 w-10 shrink-0 object-cover" />
                <span class="min-w-0">
                  <span class="block truncate text-sm">{{ r.title }}</span>
                  <span class="ej-muted block truncate text-xs">{{ r.channel }}</span>
                </span>
              </button>
            </li>
          </ul>

          <div v-if="selectedSong" class="ej-chosen mt-3 flex items-center gap-3 px-3 py-2">
            <img :src="selectedSong.thumbnail" alt="" class="h-10 w-10 shrink-0 object-cover" />
            <span class="min-w-0 flex-1">
              <span class="block truncate text-sm">{{ selectedSong.title }}</span>
              <span class="ej-muted block truncate text-xs">{{ selectedSong.channel }}</span>
            </span>
            <button type="button" aria-label="Quitar canción elegida" class="shrink-0 p-1" @click="clearSelectedSong"><X :size="15" /></button>
          </div>

          <form v-if="selectedSong" class="mt-4 space-y-3" @submit.prevent="submitSong">
            <input v-model="songRequesterName" :placeholder="t.songName" class="ej-input" />
            <p v-if="displaySongError" class="ej-error text-sm">{{ displaySongError }}</p>
            <button type="submit" :disabled="songSubmitting" class="ej-btn ej-btn-solid w-full">
              {{ songSubmitting ? 'Enviando…' : 'Sugerir canción' }}
            </button>
          </form>
        </template>
      </div>
    </section>

    <!-- ============ CONFIRMACIÓN ============ -->
    <section id="rsvp" v-reveal data-anchor="rsvp" class="mx-auto max-w-[560px] scroll-mt-6 px-6 py-16 text-center">
      <p class="ej-label">Confirmación de asistencia</p>
      <div class="ej-rule mx-auto mt-5"></div>

      <div class="ej-panel mt-10 p-6 sm:p-9">
        <p v-if="preview" class="ej-muted mb-5 text-xs">Vista previa. La confirmación funciona en la invitación real.</p>

        <div v-if="submitted" class="py-2">
          <p class="ej-lead">{{ t.thanks }}</p>
        </div>

        <div v-else-if="rsvpClosed" class="py-2">
          <p class="ej-lead">Las confirmaciones ya cerraron.</p>
          <p class="ej-muted mt-2 text-sm">La fecha límite era el {{ formatDate(invite.rsvp_deadline) }}.</p>
        </div>

        <template v-else-if="invite.named_by_host">
          <p class="ej-muted text-sm">{{ t.rsvpLead }}</p>
          <ul class="mt-6 divide-y border-y text-left">
            <li v-for="guest in namedGuests" :key="guest.id" class="flex items-center justify-between gap-3 py-3">
              <span class="ej-ink min-w-0">{{ guest.full_name }}</span>
              <span class="flex shrink-0 gap-1.5">
                <button type="button" translate="no" class="ej-toggle" :class="{ 'ej-toggle-on': guest.attending }" @click="guest.attending = true">
                  Asiste
                </button>
                <button type="button" translate="no" class="ej-toggle" :class="{ 'ej-toggle-on': !guest.attending }" @click="guest.attending = false">
                  No asiste
                </button>
              </span>
            </li>
          </ul>
          <p v-if="displayError" class="ej-error mt-4 text-sm">{{ displayError }}</p>
          <button type="button" :disabled="submitting" class="ej-btn ej-btn-solid mt-7 w-full" @click="enviarRespuestasNominales">
            {{ submitting ? 'Enviando…' : 'Enviar respuesta' }}
          </button>
        </template>

        <template v-else>
          <p class="ej-muted text-sm">
            {{ t.rsvpLead }}
            <template v-if="invite.allowed_guests > 1"> Invitación para {{ invite.allowed_guests }} personas.</template>
          </p>
          <form class="mt-6 space-y-3 text-left" @submit.prevent="confirmarGenerico">
            <div v-for="(name, i) in names" :key="i" class="flex gap-2">
              <input v-model="names[i]" placeholder="Nombre y apellido" class="ej-input flex-1" />
              <button v-if="names.length > 1" type="button" aria-label="Quitar invitado" class="px-2" @click="removeName(i)"><X :size="15" /></button>
            </div>
            <button v-if="names.length < invite.allowed_guests" type="button" class="ej-link" @click="addName">+ Agregar otra persona</button>
            <p v-if="displayError" class="ej-error text-sm">{{ displayError }}</p>
            <div class="flex flex-col gap-2.5 pt-3 sm:flex-row">
              <button type="submit" :disabled="submitting" class="ej-btn ej-btn-solid flex-1">
                {{ submitting ? 'Enviando…' : 'Confirmar asistencia' }}
              </button>
              <button type="button" :disabled="submitting" class="ej-btn ej-btn-ghost" @click="declinarGenerico">{{ t.decline }}</button>
            </div>
          </form>
        </template>
      </div>

      <p v-if="!submitted && invite.rsvp_deadline && !rsvpDeadlinePassed" class="ej-fine mt-6">
        Por favor, confirmar antes del {{ formatDate(invite.rsvp_deadline) }}
      </p>
    </section>

    <!-- ============ CONSULTAS ============ -->
    <section v-if="contact" v-reveal data-anchor="contacto" class="mx-auto max-w-[560px] px-6 pb-14 text-center">
      <p class="ej-label">Consultas</p>
      <p v-if="contact.name" class="ej-lead mt-4">{{ contact.name }}</p>
      <div class="mt-5 flex flex-wrap justify-center gap-2.5">
        <a v-if="contact.email" :href="`mailto:${contact.email}`" class="ej-btn ej-btn-ghost inline-flex items-center gap-2">
          <Mail :size="15" :stroke-width="1.5" /> Escribir un mail
        </a>
        <a v-if="contact.wa" :href="contact.wa" target="_blank" rel="noopener" class="ej-btn ej-btn-ghost inline-flex items-center gap-2">
          <MessageCircle :size="15" :stroke-width="1.5" /> WhatsApp
        </a>
      </div>
    </section>

    <!-- ============ CIERRE ============ -->
    <footer data-anchor="cierre" class="mx-auto max-w-[620px] px-6 pt-6 pb-20 text-center">
      <p v-if="showClosing" class="ej-closing">{{ invite.closing_text || t.closing }}</p>

      <div v-if="sponsorUrls.length" class="mt-16 border-t pt-10">
        <p class="ej-label">Con el apoyo de</p>
        <div class="mt-7 flex flex-wrap items-center justify-center gap-x-10 gap-y-6">
          <img
            v-for="(src, i) in sponsorUrls"
            :key="i"
            :src="src"
            alt=""
            loading="lazy"
            class="object-contain"
            :class="{ 'ej-white': invite.sponsors_white }"
            :style="sponsorStyle(src)"
            @load="onSponsorLoad($event, src)"
          />
        </div>
      </div>

      <div v-if="socials.length" data-anchor="redes" class="mt-14">
        <p class="flex flex-wrap justify-center gap-x-6 gap-y-2">
          <a v-for="s in socials" :key="s.label" :href="s.url" target="_blank" rel="noopener" class="ej-social">{{ s.label }}</a>
        </p>
      </div>

      <img
        v-if="logoUrl"
        :src="logoUrl"
        alt=""
        class="mx-auto mt-14 block max-h-8 max-w-[140px] object-contain opacity-70"
        :class="{ 'ej-white': invite.logo_white }"
      />
      <p v-if="showFinePrint" class="ej-fine mt-6">Invitación personal e intransferible</p>
    </footer>

    <button
      v-if="musicId && !preview"
      type="button"
      :aria-label="musicPlaying ? 'Pausar música' : 'Reproducir música'"
      class="ej-fab fixed bottom-5 left-5 z-30 grid h-11 w-11 place-items-center rounded-full"
      @click="toggleMusic"
    >
      <Pause v-if="musicPlaying" :size="17" :stroke-width="1.5" />
      <Music v-else :size="17" :stroke-width="1.5" />
    </button>
  </div>
</template>

<style scoped>
.ej {
  --ease: cubic-bezier(0.22, 0.61, 0.36, 1);
  --deep: v-bind(primaryColor);
  --accent: v-bind(accent);
  --bg: v-bind(pageBg);
  --ink: v-bind(ink);
  --muted: color-mix(in srgb, var(--ink) 62%, var(--bg));
  --frame: color-mix(in srgb, var(--ink) 18%, var(--bg));
  --line: color-mix(in srgb, var(--accent) 85%, var(--ink));
  --panel: color-mix(in srgb, var(--ink) 4%, var(--bg));
  --btn-bg: v-bind(btnBg);
  --btn-ink: v-bind(btnInk);
  background: var(--bg);
  color: var(--ink);
  font-family: 'Inter', ui-sans-serif, system-ui, sans-serif;
}
.ej-dark {
  --frame: color-mix(in srgb, var(--accent) 35%, var(--bg));
  --line: var(--accent);
  --panel: color-mix(in srgb, var(--ink) 6%, var(--bg));
}
/* Bordes (divide-y, border-y…) en el color del marco. */
.ej * {
  border-color: var(--frame);
}

.ej-ink {
  color: var(--ink);
}
.ej-muted {
  color: var(--muted);
}
.ej-error {
  color: #c2410c;
}
/* «Mostrar en blanco»: cualquier logo de un color pasa a blanco puro. */
.ej-white {
  filter: brightness(0) invert(1);
}

/* --- Tipografía --- */
.ej-label {
  font: 500 11px/1.6 'Inter', sans-serif;
  letter-spacing: 0.38em;
  text-transform: uppercase;
  color: var(--muted);
}
.ej-label.ej-ink {
  color: var(--ink);
  letter-spacing: 0.3em;
  font-size: 12px;
}
.ej-fine {
  font: 500 10px/1.6 'Inter', sans-serif;
  letter-spacing: 0.3em;
  text-transform: uppercase;
  color: var(--muted);
}
.ej-guest {
  font: italic 400 clamp(19px, 3.4vw, 23px) / 1.4 'Cormorant Garamond', serif;
  color: var(--muted);
  text-wrap: balance;
}
.ej-title {
  font: 500 clamp(44px, 9vw, 78px) / 1.02 'Cormorant Garamond', serif;
  letter-spacing: -0.01em;
  text-wrap: balance;
}
.ej-day {
  font: 500 64px/1 'Cormorant Garamond', serif;
  border-color: var(--line);
}
.ej-num {
  font: 500 42px/1 'Cormorant Garamond', serif;
}
.ej-lead {
  font: 400 clamp(22px, 4vw, 28px) / 1.45 'Cormorant Garamond', serif;
}
.ej-closing {
  font: italic 400 clamp(26px, 5vw, 36px) / 1.3 'Cormorant Garamond', serif;
}

/* --- Tarjeta con marco fino doble --- */
.ej-card::before,
.ej-card::after {
  content: '';
  position: absolute;
  pointer-events: none;
  border: 1px solid var(--frame);
  animation: ej-fade 1.2s var(--ease) 0.1s both;
}
.ej-card::before {
  inset: 0;
}
.ej-card::after {
  inset: 8px;
}

.ej-rule {
  height: 1px;
  width: min(220px, 60%);
  background: var(--line);
}
section .ej-rule {
  width: 48px;
}

.ej-row {
  display: grid;
  grid-template-columns: 7.5rem 1fr;
  gap: 1rem;
  padding: 1.15rem 0;
  align-items: baseline;
}
@media (max-width: 480px) {
  .ej-row {
    grid-template-columns: 1fr;
    gap: 0.35rem;
  }
}

/* Programa: línea fina vertical con un punto por actividad. */
.ej-agenda {
  position: relative;
  max-width: 30rem;
  margin-inline: auto;
}
.ej-agenda-item {
  position: relative;
  display: grid;
  grid-template-columns: 4.25rem 1fr;
  gap: 1.5rem;
  padding: 0 0 1.75rem;
}
.ej-agenda-item::before {
  content: '';
  position: absolute;
  left: calc(4.25rem + 0.75rem);
  top: 0.55rem;
  bottom: -0.2rem;
  width: 1px;
  background: var(--frame);
}
.ej-agenda-item:last-child::before {
  display: none;
}
.ej-agenda-item::after {
  content: '';
  position: absolute;
  left: calc(4.25rem + 0.75rem - 3px);
  top: 0.4rem;
  height: 7px;
  width: 7px;
  border-radius: 999px;
  background: var(--line);
}
.ej-agenda-time {
  font: 500 13px/1.5 'Inter', sans-serif;
  letter-spacing: 0.08em;
  text-align: right;
  color: var(--ink);
  font-variant-numeric: tabular-nums;
}
.ej-agenda-title {
  font: 500 21px/1.3 'Cormorant Garamond', serif;
}

.ej-social {
  font: 500 11px 'Inter', sans-serif;
  letter-spacing: 0.3em;
  text-transform: uppercase;
  color: var(--ink);
  text-decoration: underline;
  text-decoration-color: var(--line);
  text-underline-offset: 5px;
}

.ej-panel {
  background: var(--panel);
  border: 1px solid var(--frame);
}

/* --- Botones, campos, links --- */
.ej-btn {
  white-space: nowrap;
  font: 500 12.5px 'Inter', sans-serif;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  padding: 15px 26px;
  border-radius: 2px;
  transition:
    transform 150ms var(--ease),
    opacity 150ms ease,
    background-color 150ms ease;
}
.ej-btn:active:not(:disabled) {
  transform: scale(0.98);
}
.ej-btn:disabled {
  opacity: 0.5;
}
.ej-btn-solid {
  background: var(--btn-bg);
  color: var(--btn-ink);
  border: 1px solid var(--btn-bg);
}
.ej-btn-ghost {
  background: transparent;
  color: var(--ink);
  border: 1px solid var(--frame);
}
@media (hover: hover) and (pointer: fine) {
  .ej-btn-solid:hover {
    opacity: 0.9;
  }
  .ej-btn-ghost:hover,
  .ej-song:hover,
  .ej-menu-item:hover {
    background: color-mix(in srgb, var(--ink) 6%, transparent);
  }
}

.ej-input {
  width: 100%;
  background: var(--bg);
  color: var(--ink);
  border: 1px solid var(--frame);
  border-radius: 2px;
  padding: 12px 14px;
  font-size: 15px;
  outline: none;
  transition: border-color 150ms ease;
}
.ej-input::placeholder {
  color: var(--muted);
}
.ej-input:focus {
  border-color: var(--line);
}

.ej-link {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 13px;
  font-weight: 500;
  color: var(--ink);
  text-decoration: underline;
  text-decoration-color: var(--line);
  text-underline-offset: 4px;
}

.ej-toggle {
  font: 500 11px 'Inter', sans-serif;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  padding: 7px 11px;
  border: 1px solid var(--frame);
  border-radius: 2px;
  color: var(--muted);
}
.ej-toggle-on {
  background: var(--btn-bg);
  border-color: var(--btn-bg);
  color: var(--btn-ink);
}

.ej-chosen {
  background: color-mix(in srgb, var(--ink) 6%, var(--bg));
}

.ej-menu {
  background: var(--bg);
  border: 1px solid var(--frame);
  box-shadow: 0 18px 40px -18px rgba(0, 0, 0, 0.35);
}
.ej-menu-item {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 10px 12px;
  font-size: 14px;
  color: var(--ink);
  text-align: left;
}

.ej-fab {
  background: var(--btn-bg);
  color: var(--btn-ink);
  transition: transform 150ms var(--ease);
}
.ej-fab:active {
  transform: scale(0.94);
}

/* --- Animaciones mínimas: la portada se arma una vez al abrir --- */
.ej-in {
  animation: ej-rise 1s var(--ease) var(--d, 0s) both;
}
.ej-draw {
  transform-origin: center;
  animation: ej-draw 1.3s var(--ease) var(--d, 0s) both;
}
@keyframes ej-fade {
  from {
    opacity: 0;
  }
}
@keyframes ej-rise {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
}
@keyframes ej-draw {
  from {
    transform: scaleX(0);
  }
}

.reveal {
  opacity: 0;
  transform: translateY(16px);
  transition:
    opacity 0.8s var(--ease),
    transform 0.8s var(--ease);
}
.reveal-in {
  opacity: 1;
  transform: none;
}

@media (prefers-reduced-motion: reduce) {
  .ej-in,
  .ej-draw,
  .ej-card::before,
  .ej-card::after {
    animation-duration: 0.01s;
    animation-delay: 0s;
  }
  .reveal {
    transform: none;
    transition-property: opacity;
  }
}
</style>
