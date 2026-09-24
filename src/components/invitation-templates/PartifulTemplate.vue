<script setup>
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
import { useInvitationLogic } from '../../composables/useInvitationLogic'

// Plantilla "Partiful" — negro/blanco con washes de gradiente pastel,
// tipografía grotesca (Space Grotesk + Inter como sustitutos de las
// custom del original), pills y botones sólidos negros. Mismo contrato de
// props/emits que ClasicoTemplate — toda la lógica vive en
// useInvitationLogic(), acá solo cambia el <template>/<style>.
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
  bannerFoto,
  detalleFoto,
  saludoFotos,
  momentosFotos,
  galeriaGrid,
  defaultIntro,
  heroTitle,
  shows,
  entered,
  musicPlaying,
  ytFrame,
  opening,
  closing,
  envelopeGone,
  musicId,
  ytSrc,
  toggleMusic,
  openEnvelope,
  onEnvelopeFadeEnd,
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
  slide,
  goTo,
  nextSlide,
  prevSlide,
  onTouchStart,
  onTouchEnd,
  stopMomentosAutoplay,
  startMomentosAutoplay,
  saludoLoop,
  saludoSlide,
  saludoNoTransition,
  saludoActive,
  saludoStep,
  saludoSet,
  stopSaludoAutoplay,
  startSaludoAutoplay,
  onSaludoTransitionEnd,
  onSaludoTouchStart,
  onSaludoTouchEnd,
  vReveal,
  scrollToRsvp,
  gridItems,
  countdown,
  countdownUnits,
  addName,
  removeName,
  formatDate,
  formatDateLong,
  formatTime,
  confirmarGenerico,
  declinarGenerico,
  enviarRespuestasNominales,
} = useInvitationLogic(props, emit)
</script>

<template>
  <div class="partiful min-h-screen overflow-x-clip bg-white text-black">
    <iframe
      v-if="ytSrc && !preview"
      ref="ytFrame"
      :src="ytSrc"
      title="Música"
      allow="autoplay"
      class="pointer-events-none fixed bottom-0 left-0 -z-10 h-px w-px opacity-[0.01]"
    ></iframe>

    <!-- ============ HERO ============ -->
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
      <div class="absolute inset-0 bg-black/55"></div>
      <div
        class="absolute inset-0"
        style="background: linear-gradient(120deg, rgba(248, 196, 255, 0.35), rgba(240, 182, 224, 0.1) 55%, transparent 80%)"
      ></div>

      <div class="hero-in relative z-10 w-full min-w-0 px-6 text-center text-white">
        <p v-if="invite.hero_kicker" class="pf-label text-white/80">{{ invite.hero_kicker }}</p>
        <p class="pf-display mt-2 leading-[0.95] break-words" style="font-size: clamp(3rem, 16vw, 6.5rem)">
          {{ heroTitle }}
        </p>
        <p v-if="invite.hero_subtitle" class="pf-body mt-3 text-white/80">{{ invite.hero_subtitle }}</p>
        <p v-if="invite.event_date" class="pf-label mt-5 text-white/90">
          {{ formatDateLong(invite.event_date) }}
        </p>
      </div>

      <button
        v-if="entered && !submitted"
        type="button"
        @click="scrollToRsvp"
        class="pf-btn-ghost-invert absolute bottom-7 z-10"
      >
        Confirmar asistencia
      </button>
    </header>

    <!-- ============ PORTADA ============ -->
    <div
      v-if="!preview && !envelopeGone"
      class="pf-cover fixed inset-0 z-50 flex flex-col items-center justify-center px-6"
      :class="{ 'pf-cover--out': closing }"
      @transitionend.self="onEnvelopeFadeEnd"
    >
      <div class="pf-cover-card">
        <img :src="bannerFoto" alt="" class="pf-cover-photo" />
      </div>
      <p class="pf-label mt-8 text-black/50">Estás invitado/a</p>
      <p class="pf-display mt-2 text-center leading-[0.95]" style="font-size: clamp(2.2rem, 9vw, 3.5rem)">
        {{ heroTitle }}
      </p>
      <button
        type="button"
        class="pf-btn-primary mt-8"
        :disabled="opening"
        @click="openEnvelope"
      >
        Ver invitación
      </button>
      <p v-if="musicId" class="pf-label mt-4 flex items-center justify-center gap-1.5 text-black/40">
        <Music :size="12" /> con música
      </p>
    </div>

    <!-- ============ SALUDO ============ -->
    <section v-reveal data-anchor="saludo" class="py-20 text-center">
      <div class="mx-auto max-w-xl px-6">
        <span v-if="invite.family_name" class="pf-pill">{{ invite.family_name }}</span>
        <p class="pf-body mt-6 leading-relaxed whitespace-pre-line text-[#333333]">
          {{ invite.intro_text || defaultIntro }}
        </p>
      </div>

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
              i === saludoSlide ? 'scale-100 opacity-100' : 'scale-[0.9] opacity-40',
            ]"
          >
            <img
              :src="src"
              alt=""
              loading="lazy"
              decoding="async"
              class="pf-card block aspect-3/4 w-full object-cover"
            />
          </div>
        </div>

        <button type="button" aria-label="Foto anterior" @click="saludoStep(-1)" class="pf-nav-arrow left-3">
          ‹
        </button>
        <button type="button" aria-label="Foto siguiente" @click="saludoStep(1)" class="pf-nav-arrow right-3">
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
          class="h-1.5 rounded-full bg-black transition-all"
          :class="i === saludoActive ? 'w-5 opacity-100' : 'w-1.5 opacity-20'"
        ></button>
      </div>
    </section>

    <!-- ============ COUNTDOWN ============ -->
    <section v-if="countdown" v-reveal class="pf-wash py-20">
      <div class="mx-auto max-w-xl px-6 text-center">
        <p class="pf-label text-black/50">Falta poco</p>
        <div class="mt-6 grid grid-cols-4 gap-2 sm:gap-3">
          <div v-for="u in countdownUnits" :key="u.label" class="pf-card px-1 py-4">
            <p class="pf-display text-2xl sm:text-3xl">{{ u.value }}</p>
            <p class="mt-1 text-[9px] uppercase tracking-widest text-[#999999] sm:text-[10px]">
              {{ u.label }}
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ DETALLES ============ -->
    <section v-reveal data-anchor="fiesta" class="mx-auto max-w-xl px-6 py-24">
      <p class="pf-label text-center text-black/50">Los detalles</p>
      <h2 class="pf-display mt-2 text-center text-3xl sm:text-4xl">La celebración</h2>

      <div class="pf-card mt-8 divide-y divide-black/10 px-6 sm:px-8">
        <div v-if="invite.event_date" class="flex items-center gap-4 py-5">
          <span class="pf-icon-circle"><CalendarHeart :size="18" :stroke-width="1.75" /></span>
          <div class="min-w-0">
            <p class="pf-label text-black/45">Cuándo</p>
            <p class="pf-heading-sm mt-1">{{ formatDateLong(invite.event_date) }}</p>
            <p v-if="invite.reception_time" class="mt-0.5 text-xs tracking-wide text-[#999999]">
              {{ formatTime(invite.reception_time)
              }}<span v-if="invite.end_time"> — {{ formatTime(invite.end_time) }}</span> h
            </p>
          </div>
        </div>

        <div v-if="invite.venue_name || invite.venue_address" class="flex items-center gap-4 py-5">
          <span class="pf-icon-circle"><MapPin :size="18" :stroke-width="1.75" /></span>
          <div class="min-w-0">
            <p class="pf-label text-black/45">Dónde</p>
            <p v-if="invite.venue_name" class="pf-heading-sm mt-1">{{ invite.venue_name }}</p>
            <p v-if="invite.venue_address" class="mt-0.5 text-xs text-[#999999]">{{ invite.venue_address }}</p>
            <a v-if="invite.maps_url" :href="invite.maps_url" target="_blank" rel="noopener" class="pf-link mt-2">
              Cómo llegar <ArrowUpRight :size="13" :stroke-width="2" />
            </a>
          </div>
        </div>

        <div v-if="invite.dress_code" class="flex items-center gap-4 py-5">
          <span class="pf-icon-circle"><Gem :size="18" :stroke-width="1.75" /></span>
          <div class="min-w-0">
            <p class="pf-label text-black/45">Dress code</p>
            <p class="pf-heading-sm mt-1">{{ invite.dress_code }}</p>
          </div>
        </div>
      </div>

      <p v-if="invite.notes" class="pf-body mt-6 text-center italic text-[#666666]">{{ invite.notes }}</p>

      <div v-if="shows('detalle')" class="pf-card mt-12 overflow-hidden">
        <img :src="detalleFoto" alt="" loading="lazy" decoding="async" class="block aspect-4/3 w-full object-cover" />
      </div>
    </section>

    <!-- ============ REGALOS ============ -->
    <section v-if="invite.gift_alias" v-reveal data-anchor="regalos" class="mx-auto max-w-md px-6 pb-8 text-center">
      <span class="pf-icon-circle mx-auto"><Gift :size="20" :stroke-width="1.75" /></span>
      <p class="pf-body mt-4 italic text-[#333333]">El mejor regalo que podés hacerme es tu presencia.</p>
      <p class="mt-3 text-sm text-[#999999]">Pero si querés acercarme un presente, te dejo mi alias:</p>
      <button type="button" @click="copyAlias" class="pf-btn-primary mt-3 font-mono">
        {{ aliasCopied ? '¡Copiado!' : invite.gift_alias }}
        <Check v-if="aliasCopied" :size="14" />
        <Copy v-else :size="14" />
      </button>
    </section>

    <!-- ============ CANCIONES (plan "plus") ============ -->
    <section v-if="invite.plan === 'plus'" v-reveal data-anchor="canciones" class="pf-wash px-6 py-20">
      <div class="mx-auto max-w-xl">
        <p class="pf-label text-center text-black/50">Ayudanos con el playlist</p>
        <h2 class="pf-display mt-2 text-center text-3xl sm:text-4xl">¿Qué canción no puede faltar?</h2>

        <div class="pf-card mt-8 p-6 sm:p-8">
          <template v-if="justAddedSong">
            <p class="py-2 text-center text-4xl">🎶</p>
            <p class="pf-body text-center">¡Gracias! La sumamos a la lista.</p>
            <button type="button" @click="justAddedSong = false" class="pf-link mx-auto mt-4 block text-center">
              Agregar otra
            </button>
          </template>

          <template v-else>
            <div class="relative">
              <input
                v-model="songQuery"
                type="text"
                placeholder="Buscá una canción o artista…"
                class="pf-input pr-9"
                @input="onSongQueryInput"
              />
              <Search :size="16" class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-[#999999]" />
            </div>

            <p v-if="songSearching" class="mt-2 text-center text-xs text-[#999999]">Buscando…</p>
            <p v-else-if="songSearchError" class="mt-2 text-center text-xs text-red-600">{{ songSearchError }}</p>

            <ul v-if="songResults.length && !selectedSong" class="mt-2 max-h-64 space-y-1 overflow-y-auto">
              <li v-for="r in songResults" :key="r.videoId">
                <button
                  type="button"
                  @click="selectSong(r)"
                  class="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left transition hover:bg-black/5"
                >
                  <img :src="r.thumbnail" alt="" class="h-10 w-10 shrink-0 rounded-lg object-cover" />
                  <span class="min-w-0">
                    <span class="block truncate text-sm">{{ r.title }}</span>
                    <span class="block truncate text-xs text-[#999999]">{{ r.channel }}</span>
                  </span>
                </button>
              </li>
            </ul>

            <div v-if="selectedSong" class="mt-3 flex items-center gap-3 rounded-lg bg-black/5 px-3 py-2">
              <img :src="selectedSong.thumbnail" alt="" class="h-10 w-10 shrink-0 rounded-lg object-cover" />
              <span class="min-w-0 flex-1">
                <span class="block truncate text-sm">{{ selectedSong.title }}</span>
                <span class="block truncate text-xs text-[#999999]">{{ selectedSong.channel }}</span>
              </span>
              <button type="button" @click="clearSelectedSong" aria-label="Quitar canción elegida" class="shrink-0 px-1">
                ✕
              </button>
            </div>

            <form v-if="selectedSong" @submit.prevent="submitSong" class="mt-4 space-y-3">
              <input v-model="songRequesterName" placeholder="Tu nombre o familia" class="pf-input" />
              <p v-if="displaySongError" class="text-sm text-red-600">{{ displaySongError }}</p>
              <button type="submit" :disabled="songSubmitting" class="pf-btn-primary w-full justify-center">
                {{ songSubmitting ? 'Agregando…' : 'Agregar canción' }}
              </button>
            </form>
          </template>
        </div>
      </div>
    </section>

    <!-- ============ MOMENTOS ============ -->
    <section v-if="shows('momentos')" v-reveal data-anchor="momentos" class="py-20">
      <h2 class="pf-display text-center text-2xl sm:text-3xl">Momentos</h2>

      <div
        class="pf-card relative mx-auto mt-6 max-w-2xl overflow-hidden"
        @touchstart.passive="onTouchStart"
        @touchend.passive="onTouchEnd"
        @mouseenter="stopMomentosAutoplay"
        @mouseleave="startMomentosAutoplay"
      >
        <div class="flex transition-transform duration-700 ease-out" :style="{ transform: `translateX(-${slide * 100}%)` }">
          <div v-for="(src, i) in momentosFotos" :key="i" class="min-w-full">
            <img :src="src" :alt="`Foto ${i + 1}`" loading="lazy" decoding="async" class="block aspect-4/5 w-full object-cover sm:aspect-16/10" />
          </div>
        </div>

        <button type="button" aria-label="Foto anterior" @click="prevSlide" class="pf-nav-arrow left-2 sm:left-3">‹</button>
        <button type="button" aria-label="Foto siguiente" @click="nextSlide" class="pf-nav-arrow right-2 sm:right-3">›</button>

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

    <!-- ============ GALERÍA ============ -->
    <section v-if="shows('galeria')" v-reveal data-anchor="galeria" class="pf-wash overflow-hidden py-20">
      <p class="pf-label text-center text-black/50">Recuerdos</p>
      <h2 class="pf-display mt-2 text-center text-2xl sm:text-3xl">Galería</h2>

      <div class="mx-auto mt-8 grid max-w-4xl grid-cols-2 gap-3 px-4 sm:grid-cols-4 sm:gap-4">
        <div v-for="(src, i) in galeriaGrid" :key="i" ref="gridItems" class="pf-card overflow-hidden will-change-transform">
          <img :src="src" :alt="`Recuerdo ${i + 1}`" loading="lazy" decoding="async" class="block aspect-square w-full object-cover" />
        </div>
      </div>
    </section>

    <!-- ============ RSVP ============ -->
    <section id="rsvp" v-reveal data-anchor="rsvp" class="mx-auto max-w-xl scroll-mt-6 px-6 py-20">
      <div class="pf-card p-8">
        <h2 class="pf-display text-center text-2xl sm:text-3xl">Confirmá tu asistencia</h2>

        <p v-if="preview" class="mt-4 rounded-lg bg-black/5 px-3 py-2 text-center text-xs text-[#666666]">
          Vista previa — la confirmación funciona en la invitación real.
        </p>

        <div v-if="submitted" class="py-4 text-center">
          <p class="text-5xl">🎉</p>
          <p class="pf-heading-sm mt-4">¡Gracias! Registramos tu respuesta.</p>
          <p class="mt-2 text-sm text-[#666666]">Nos vemos muy pronto.</p>
        </div>

        <template v-else-if="invite.named_by_host">
          <p class="mt-4 text-center text-sm text-[#666666]">Invitaciones para:</p>
          <ul class="mt-4 space-y-2">
            <li v-for="guest in namedGuests" :key="guest.id" class="flex items-center justify-between gap-2 rounded-lg bg-black/5 px-3 py-2">
              <span>{{ guest.full_name }}</span>
              <div class="flex shrink-0 gap-2">
                <button
                  type="button"
                  translate="no"
                  @click="guest.attending = true"
                  :class="guest.attending ? 'pf-pill-going' : 'pf-pill-off'"
                  class="pf-pill-btn"
                >
                  Asiste
                </button>
                <button
                  type="button"
                  translate="no"
                  @click="guest.attending = false"
                  :class="!guest.attending ? 'pf-pill-cant' : 'pf-pill-off'"
                  class="pf-pill-btn"
                >
                  No asiste
                </button>
              </div>
            </li>
          </ul>

          <p v-if="displayError" class="mt-3 text-sm text-red-600">{{ displayError }}</p>

          <button type="button" :disabled="submitting" @click="enviarRespuestasNominales" class="pf-btn-primary mt-6 w-full justify-center">
            {{ submitting ? 'Enviando…' : 'Confirmar respuestas' }}
          </button>
        </template>

        <template v-else>
          <p class="mt-4 text-center text-sm text-[#666666]">
            Tienen {{ invite.allowed_guests }} {{ invite.allowed_guests === 1 ? 'invitación' : 'invitaciones' }}.
          </p>

          <form @submit.prevent="confirmarGenerico" class="mt-4 space-y-3">
            <div v-for="(name, i) in names" :key="i" class="flex gap-2">
              <input v-model="names[i]" placeholder="Nombre y apellido" class="pf-input flex-1" />
              <button v-if="names.length > 1" type="button" @click="removeName(i)" aria-label="Quitar invitado" class="px-2">✕</button>
            </div>

            <button v-if="names.length < invite.allowed_guests" type="button" @click="addName" class="pf-link">
              + Agregar invitado
            </button>

            <p v-if="displayError" class="text-sm text-red-600">{{ displayError }}</p>

            <div class="flex flex-col gap-2 pt-2 sm:flex-row">
              <button type="submit" :disabled="submitting" class="pf-btn-primary flex-1 justify-center">
                {{ submitting ? 'Enviando…' : 'Confirmar asistencia' }}
              </button>
              <button type="button" :disabled="submitting" @click="declinarGenerico" class="pf-btn-ghost justify-center">
                No podemos ir
              </button>
            </div>
          </form>
        </template>
      </div>

      <p v-if="!submitted && invite.rsvp_deadline" class="mt-4 text-center text-xs uppercase tracking-widest text-[#999999]">
        Confirmá antes del {{ formatDate(invite.rsvp_deadline) }}
      </p>
    </section>

    <!-- ============ CIERRE ============ -->
    <footer data-anchor="cierre" class="px-6 pb-16 pt-4 text-center">
      <p class="pf-display text-2xl sm:text-3xl">{{ invite.closing_text || '¡Los esperamos!' }}</p>
    </footer>

    <button
      v-if="entered && musicId && !preview"
      type="button"
      @click="toggleMusic"
      :aria-label="musicPlaying ? 'Pausar música' : 'Reproducir música'"
      class="fixed bottom-5 left-5 z-30 grid h-11 w-11 place-items-center rounded-full bg-black text-white shadow-lg transition hover:brightness-110"
    >
      <Pause v-if="musicPlaying" :size="18" />
      <Music v-else :size="18" />
    </button>
  </div>
</template>

<style scoped>
.partiful {
  --pf-ink: #000000;
  --pf-canvas: #ffffff;
  --pf-graphite: #333333;
  --pf-slate: #666666;
  --pf-ash: #999999;
  --pf-silver: #cccccc;
  --pf-sand: #d9c58b;
  font-family: 'Inter', ui-sans-serif, system-ui, sans-serif;
}

.pf-display {
  font-family: 'Space Grotesk', ui-sans-serif, system-ui, sans-serif;
  font-weight: 500;
  letter-spacing: -0.02em;
  line-height: 1;
}

.pf-body {
  font-family: 'Inter', ui-sans-serif, system-ui, sans-serif;
  font-size: 1.05rem;
  line-height: 1.5;
}

.pf-heading-sm {
  font-weight: 700;
  font-size: 1.05rem;
  letter-spacing: -0.02em;
}

.pf-label {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.25em;
}

.pf-wash {
  background: linear-gradient(to bottom, rgba(150, 196, 255, 0.12), #ffffff 65%);
}

.pf-card {
  background: #ffffff;
  border-radius: 12px;
  box-shadow: rgba(0, 0, 0, 0.1) 0px 0px 6px 0px;
}

.pf-icon-circle {
  display: grid;
  place-items: center;
  height: 2.75rem;
  width: 2.75rem;
  flex-shrink: 0;
  border-radius: 999px;
  background: rgba(0, 0, 0, 0.05);
  color: #000000;
}

.pf-pill {
  display: inline-block;
  padding: 6px 14px;
  border-radius: 960px;
  background: rgba(0, 0, 0, 0.05);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.02em;
}

.pf-link {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.85rem;
  font-weight: 600;
  text-decoration: underline;
  text-underline-offset: 3px;
}

.pf-input {
  width: 100%;
  border-radius: 8px;
  border: 1px solid #000000;
  padding: 10px 14px;
  font-family: 'Inter', sans-serif;
  background: #ffffff;
}
.pf-input:focus {
  outline: 2px solid #000000;
  outline-offset: 1px;
}

.pf-btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border-radius: 8px;
  background: #000000;
  color: #ffffff;
  padding: 10px 24px;
  font-weight: 700;
  font-size: 0.9rem;
  letter-spacing: -0.02em;
  transition: opacity 0.15s ease;
}
.pf-btn-primary:hover {
  opacity: 0.85;
}
.pf-btn-primary:disabled {
  opacity: 0.5;
  cursor: default;
}

.pf-btn-ghost {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  border-radius: 8px;
  border: 1px solid #000000;
  color: #000000;
  padding: 10px 24px;
  font-weight: 600;
  font-size: 0.9rem;
  background: transparent;
  transition: background 0.15s ease;
}
.pf-btn-ghost:hover {
  background: rgba(0, 0, 0, 0.05);
}
.pf-btn-ghost:disabled {
  opacity: 0.5;
}

.pf-btn-ghost-invert {
  border-radius: 8px;
  border: 1px solid rgba(255, 255, 255, 0.8);
  color: #ffffff;
  padding: 8px 20px;
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.2em;
  backdrop-filter: blur(2px);
  transition: background 0.15s ease;
}
.pf-btn-ghost-invert:hover {
  background: rgba(255, 255, 255, 0.15);
}

.pf-nav-arrow {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  z-index: 10;
  display: grid;
  height: 2.25rem;
  width: 2.25rem;
  place-items: center;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.85);
  font-size: 1.1rem;
  color: #000000;
  transition: background 0.15s ease;
}
.pf-nav-arrow:hover {
  background: #ffffff;
}

.pf-pill-btn {
  border-radius: 960px;
  padding: 4px 12px;
  font-size: 0.75rem;
  font-weight: 700;
}
.pf-pill-off {
  background: #ffffff;
  color: var(--pf-ash);
  box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.15);
}
.pf-pill-going {
  background: #31c431;
  color: #ffffff;
}
.pf-pill-cant {
  background: #ff0000;
  color: #ffffff;
}

/* --- Portada --------------------------------------------------------- */
.pf-cover {
  background: linear-gradient(to bottom, #e8f1ff, #ffffff 60%);
  transition: opacity 0.6s ease;
}
.pf-cover--out {
  opacity: 0;
  pointer-events: none;
}

.pf-cover-card {
  width: clamp(180px, 55vw, 240px);
  aspect-ratio: 3 / 4;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: rgba(0, 0, 0, 0.05) 0px 0.8px 2.4px -0.6px, rgba(0, 0, 0, 0.05) 0px 2.4px 7.2px -1.25px,
    rgba(0, 0, 0, 0.05) 0px 6.4px 19.1px -1.875px, rgba(0, 0, 0, 0.05) 0px 20px 60px -2.5px;
  transform: rotate(-4deg);
}
.pf-cover-photo {
  height: 100%;
  width: 100%;
  object-fit: cover;
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

@media (prefers-reduced-motion: reduce) {
  .kenburns,
  .hero-in,
  .pf-cover {
    animation: none;
    transition: none;
  }
  .kenburns {
    opacity: 1;
  }
}
</style>
