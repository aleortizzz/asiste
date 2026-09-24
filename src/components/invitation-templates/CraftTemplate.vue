<script setup>
import { computed } from 'vue'
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

// Plantilla "Craft" — invernadero botánico sobre papel crema: fondo bone
// linen, un único momento oscuro (Forest Depths) al abrir con serif
// condensada gigante, verde lima reservado solo para la acción principal
// de cada sección, cards planas sin sombra (la separación es de color, no
// de elevación). Mismo contrato de props/emits que las otras plantillas —
// toda la lógica vive en useInvitationLogic().
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

// Collage del hero: solo aparece si el host cargó fotos propias (no las de
// demo) — banner + saludo, hasta 4. Sin fotos reales, el hero se queda tal
// cual (verde sólido + blobs), que es la versión que ya se aprobó.
const heroPhotos = computed(() => [...slotUrls('banner'), ...slotUrls('retrato')].slice(0, 4))
</script>

<template>
  <div class="craft min-h-screen overflow-x-clip bg-[#f7f5f2] text-[#2a1a1d]">
    <iframe
      v-if="ytSrc && !preview"
      ref="ytFrame"
      :src="ytSrc"
      title="Música"
      allow="autoplay"
      class="pointer-events-none fixed bottom-0 left-0 -z-10 h-px w-px opacity-[0.01]"
    ></iframe>

    <!-- ============ HERO (único momento oscuro) ============ -->
    <header
      data-anchor="hero"
      class="relative flex h-svh min-h-[560px] items-center justify-center overflow-hidden bg-[#1d3023] px-6 text-center"
    >
      <template v-if="heroPhotos.length">
        <div class="craft-glow craft-glow-1"></div>
        <div class="craft-glow craft-glow-2"></div>
        <div class="craft-hero-photos">
          <div v-for="(src, i) in heroPhotos" :key="i" :class="`craft-hero-photo craft-hero-photo-${i}`">
            <img :src="src" alt="" loading="lazy" decoding="async" />
          </div>
        </div>
        <div class="absolute inset-0 bg-[#1d3023]/35"></div>
      </template>
      <template v-else>
        <div class="craft-blob craft-blob-1"></div>
        <div class="craft-blob craft-blob-2"></div>
      </template>

      <div class="hero-in relative z-10 w-full min-w-0">
        <p v-if="invite.hero_kicker" class="craft-label text-[#eae6df]/70">{{ invite.hero_kicker }}</p>
        <p
          class="craft-display mt-3 break-words text-[#f7f5f2]"
          style="font-size: clamp(3rem, 15vw, 7rem)"
        >
          {{ heroTitle }}
        </p>
        <p v-if="invite.hero_subtitle" class="craft-body mt-4 text-[#eae6df]">{{ invite.hero_subtitle }}</p>
        <p v-if="invite.event_date" class="craft-label mt-5 text-[#eae6df]/80">
          {{ formatDateLong(invite.event_date) }}
        </p>
      </div>

      <button
        v-if="entered && !submitted"
        type="button"
        @click="scrollToRsvp"
        class="craft-btn-ghost-invert absolute bottom-7 z-10"
      >
        Confirmar asistencia
      </button>
    </header>

    <!-- ============ PORTADA ============ -->
    <div
      v-if="!preview && !envelopeGone"
      class="craft-cover fixed inset-0 z-50 flex flex-col items-center justify-center px-6 text-center"
      :class="{ 'craft-cover--out': closing }"
      @transitionend.self="onEnvelopeFadeEnd"
    >
      <div class="craft-blob craft-blob-1"></div>
      <div class="craft-blob craft-blob-2"></div>

      <p class="craft-label relative z-10 text-[#eae6df]/70">Estás invitado/a</p>
      <p class="craft-display relative z-10 mt-3 text-[#f7f5f2]" style="font-size: clamp(2.4rem, 11vw, 4.5rem)">
        {{ heroTitle }}
      </p>
      <button type="button" class="craft-btn-primary relative z-10 mt-8" :disabled="opening" @click="openEnvelope">
        Abrir invitación
      </button>
      <p v-if="musicId" class="craft-label relative z-10 mt-4 flex items-center justify-center gap-1.5 text-[#eae6df]/60">
        <Music :size="12" /> con música
      </p>
    </div>

    <!-- ============ SALUDO ============ -->
    <section v-reveal data-anchor="saludo" class="py-16">
      <div class="mx-auto max-w-[720px] px-6 text-center">
        <p v-if="invite.family_name" class="craft-label text-[#26d862]">{{ invite.family_name }}</p>
        <p class="craft-display-sm mt-4 whitespace-pre-line text-[#2a1a1d]">
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
            <img :src="src" alt="" loading="lazy" decoding="async" class="craft-card block aspect-3/4 w-full object-cover" />
          </div>
        </div>

        <button type="button" aria-label="Foto anterior" @click="saludoStep(-1)" class="craft-nav-arrow left-3">‹</button>
        <button type="button" aria-label="Foto siguiente" @click="saludoStep(1)" class="craft-nav-arrow right-3">›</button>
      </div>

      <div v-if="shows('retrato')" class="mt-5 flex justify-center gap-2">
        <button
          v-for="(s, i) in saludoFotos"
          :key="i"
          type="button"
          :aria-label="`Ir a la foto ${i + 1}`"
          @click="saludoSet(i)"
          class="h-1.5 rounded-full transition-all"
          :class="i === saludoActive ? 'w-5 bg-[#26d862] opacity-100' : 'w-1.5 bg-[#2a1a1d] opacity-20'"
        ></button>
      </div>
    </section>

    <!-- ============ COUNTDOWN → stat cards ============ -->
    <section v-if="countdown" v-reveal class="mx-auto max-w-[1200px] px-6 py-16">
      <p class="craft-label text-center text-[#645757]">Falta poco</p>
      <div class="mt-6 grid grid-cols-4 gap-3 sm:gap-4">
        <div v-for="u in countdownUnits" :key="u.label" class="craft-stat-card">
          <p class="craft-display-sm text-[#0e634f]">{{ u.value }}</p>
          <p class="mt-1 text-[11px] leading-[1.5] text-[#645757] sm:text-[13px]">{{ u.label }}</p>
        </div>
      </div>
    </section>

    <!-- ============ DETALLES ============ -->
    <section v-reveal data-anchor="fiesta" class="mx-auto max-w-[720px] px-6 py-16 text-center">
      <p class="craft-label text-[#645757]">Los detalles</p>
      <h2 class="craft-display-sm mt-2">La celebración</h2>

      <div class="craft-card mt-8 divide-y divide-[#d7d2cc] px-6 text-left sm:px-8">
        <div v-if="invite.event_date" class="flex items-center gap-4 py-5">
          <span class="craft-icon-circle"><CalendarHeart :size="18" :stroke-width="1.5" /></span>
          <div class="min-w-0">
            <p class="craft-label text-[#645757]">Cuándo</p>
            <p class="craft-heading-sm mt-1">{{ formatDateLong(invite.event_date) }}</p>
            <p v-if="invite.reception_time" class="mt-0.5 text-xs text-[#645757]">
              {{ formatTime(invite.reception_time)
              }}<span v-if="invite.end_time"> — {{ formatTime(invite.end_time) }}</span> h
            </p>
          </div>
        </div>

        <div v-if="invite.venue_name || invite.venue_address" class="flex items-center gap-4 py-5">
          <span class="craft-icon-circle"><MapPin :size="18" :stroke-width="1.5" /></span>
          <div class="min-w-0">
            <p class="craft-label text-[#645757]">Dónde</p>
            <p v-if="invite.venue_name" class="craft-heading-sm mt-1">{{ invite.venue_name }}</p>
            <p v-if="invite.venue_address" class="mt-0.5 text-xs text-[#645757]">{{ invite.venue_address }}</p>
            <a v-if="invite.maps_url" :href="invite.maps_url" target="_blank" rel="noopener" class="craft-link mt-2">
              Cómo llegar <ArrowUpRight :size="13" :stroke-width="2" />
            </a>
          </div>
        </div>

        <div v-if="invite.dress_code" class="flex items-center gap-4 py-5">
          <span class="craft-icon-circle"><Gem :size="18" :stroke-width="1.5" /></span>
          <div class="min-w-0">
            <p class="craft-label text-[#645757]">Dress code</p>
            <p class="craft-heading-sm mt-1">{{ invite.dress_code }}</p>
          </div>
        </div>
      </div>

      <p v-if="invite.notes" class="craft-body mt-6 text-[#645757] italic">{{ invite.notes }}</p>

      <div v-if="shows('detalle')" class="craft-card mt-12 overflow-hidden">
        <img :src="detalleFoto" alt="" loading="lazy" decoding="async" class="block aspect-4/3 w-full object-cover" />
      </div>
    </section>

    <!-- ============ REGALOS ============ -->
    <section v-if="invite.gift_alias" v-reveal data-anchor="regalos" class="mx-auto max-w-md px-6 pb-8 text-center">
      <span class="craft-icon-circle mx-auto"><Gift :size="20" :stroke-width="1.5" /></span>
      <p class="craft-body mt-4 text-[#2a1a1d] italic">El mejor regalo que podés hacerme es tu presencia.</p>
      <p class="mt-3 text-sm text-[#645757]">Pero si querés acercarme un presente, te dejo mi alias:</p>
      <button type="button" @click="copyAlias" class="craft-btn-ghost mt-3 font-mono">
        {{ aliasCopied ? '¡Copiado!' : invite.gift_alias }}
        <Check v-if="aliasCopied" :size="14" />
        <Copy v-else :size="14" />
      </button>
    </section>

    <!-- ============ CANCIONES (plan "plus") ============ -->
    <section v-if="invite.plan === 'plus'" v-reveal data-anchor="canciones" class="mx-auto max-w-[720px] px-6 py-16 text-center">
      <p class="craft-label text-[#645757]">Ayudanos con el playlist</p>
      <h2 class="craft-display-sm mt-2">¿Qué canción no puede faltar?</h2>

      <div class="craft-card mt-8 p-6 text-left sm:p-8">
        <template v-if="justAddedSong">
          <p class="py-2 text-center text-4xl">🌿</p>
          <p class="craft-body text-center">¡Gracias! La sumamos a la lista.</p>
          <button type="button" @click="justAddedSong = false" class="craft-link mx-auto mt-4 block text-center">
            Agregar otra
          </button>
        </template>

        <template v-else>
          <div class="relative">
            <input
              v-model="songQuery"
              type="text"
              placeholder="Buscá una canción o artista…"
              class="craft-input pr-9"
              @input="onSongQueryInput"
            />
            <Search :size="16" class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-[#645757]" />
          </div>

          <p v-if="songSearching" class="mt-2 text-center text-xs text-[#645757]">Buscando…</p>
          <p v-else-if="songSearchError" class="mt-2 text-center text-xs text-red-700">{{ songSearchError }}</p>

          <ul v-if="songResults.length && !selectedSong" class="mt-2 max-h-64 space-y-1 overflow-y-auto">
            <li v-for="r in songResults" :key="r.videoId">
              <button
                type="button"
                @click="selectSong(r)"
                class="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left transition hover:bg-[#eae6df]"
              >
                <img :src="r.thumbnail" alt="" class="h-10 w-10 shrink-0 rounded-lg object-cover" />
                <span class="min-w-0">
                  <span class="block truncate text-sm">{{ r.title }}</span>
                  <span class="block truncate text-xs text-[#645757]">{{ r.channel }}</span>
                </span>
              </button>
            </li>
          </ul>

          <div v-if="selectedSong" class="mt-3 flex items-center gap-3 rounded-lg bg-[#eae6df] px-3 py-2">
            <img :src="selectedSong.thumbnail" alt="" class="h-10 w-10 shrink-0 rounded-lg object-cover" />
            <span class="min-w-0 flex-1">
              <span class="block truncate text-sm">{{ selectedSong.title }}</span>
              <span class="block truncate text-xs text-[#645757]">{{ selectedSong.channel }}</span>
            </span>
            <button type="button" @click="clearSelectedSong" aria-label="Quitar canción elegida" class="shrink-0 px-1">✕</button>
          </div>

          <form v-if="selectedSong" @submit.prevent="submitSong" class="mt-4 space-y-3">
            <input v-model="songRequesterName" placeholder="Tu nombre o familia" class="craft-input" />
            <p v-if="displaySongError" class="text-sm text-red-700">{{ displaySongError }}</p>
            <button type="submit" :disabled="songSubmitting" class="craft-btn-primary w-full justify-center">
              {{ songSubmitting ? 'Agregando…' : 'Agregar canción' }}
            </button>
          </form>
        </template>
      </div>
    </section>

    <!-- ============ MOMENTOS ============ -->
    <section v-if="shows('momentos')" v-reveal data-anchor="momentos" class="py-16">
      <p class="craft-label text-center text-[#645757]">Especímenes</p>
      <h2 class="craft-display-sm mt-2 text-center">Momentos</h2>

      <div
        class="craft-card relative mx-auto mt-6 max-w-2xl overflow-hidden"
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

        <button type="button" aria-label="Foto anterior" @click="prevSlide" class="craft-nav-arrow left-2 sm:left-3">‹</button>
        <button type="button" aria-label="Foto siguiente" @click="nextSlide" class="craft-nav-arrow right-2 sm:right-3">›</button>

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
    <section v-if="shows('galeria')" v-reveal data-anchor="galeria" class="mx-auto max-w-[1200px] px-6 py-16">
      <p class="craft-label text-center text-[#645757]">Recuerdos</p>
      <h2 class="craft-display-sm mt-2 text-center">Galería</h2>

      <div class="mt-8 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div v-for="(src, i) in galeriaGrid" :key="i" ref="gridItems" class="craft-card overflow-hidden will-change-transform">
          <img :src="src" :alt="`Recuerdo ${i + 1}`" loading="lazy" decoding="async" class="block aspect-square w-full object-cover" />
        </div>
      </div>
    </section>

    <!-- ============ RSVP ============ -->
    <section id="rsvp" v-reveal data-anchor="rsvp" class="mx-auto max-w-[600px] scroll-mt-6 px-6 py-16">
      <div class="craft-card p-8 text-center">
        <h2 class="craft-display-sm">Confirmá tu asistencia</h2>

        <p v-if="preview" class="mt-4 rounded-lg bg-[#d7d2cc]/40 px-3 py-2 text-center text-xs text-[#645757]">
          Vista previa — la confirmación funciona en la invitación real.
        </p>

        <div v-if="submitted" class="py-4">
          <p class="text-5xl">🌿</p>
          <p class="craft-heading-sm mt-4">¡Gracias! Registramos tu respuesta.</p>
          <p class="mt-2 text-sm text-[#645757]">Nos vemos muy pronto.</p>
        </div>

        <template v-else-if="invite.named_by_host">
          <p class="mt-4 text-sm text-[#645757]">Invitaciones para:</p>
          <ul class="mt-4 space-y-2 text-left">
            <li v-for="guest in namedGuests" :key="guest.id" class="flex items-center justify-between gap-2 rounded-lg bg-[#eae6df] px-3 py-2">
              <span>{{ guest.full_name }}</span>
              <div class="flex shrink-0 gap-2">
                <button
                  type="button"
                  translate="no"
                  @click="guest.attending = true"
                  :class="guest.attending ? 'craft-toggle-on' : 'craft-toggle-off'"
                  class="craft-toggle"
                >
                  Asiste
                </button>
                <button
                  type="button"
                  translate="no"
                  @click="guest.attending = false"
                  :class="!guest.attending ? 'craft-toggle-off-active' : 'craft-toggle-off'"
                  class="craft-toggle"
                >
                  No asiste
                </button>
              </div>
            </li>
          </ul>

          <p v-if="displayError" class="mt-3 text-sm text-red-700">{{ displayError }}</p>

          <button type="button" :disabled="submitting" @click="enviarRespuestasNominales" class="craft-btn-primary mt-6 w-full justify-center">
            {{ submitting ? 'Enviando…' : 'Confirmar respuestas' }}
          </button>
        </template>

        <template v-else>
          <p class="mt-4 text-sm text-[#645757]">
            Tienen {{ invite.allowed_guests }} {{ invite.allowed_guests === 1 ? 'invitación' : 'invitaciones' }}.
          </p>

          <form @submit.prevent="confirmarGenerico" class="mt-4 space-y-3 text-left">
            <div v-for="(name, i) in names" :key="i" class="flex gap-2">
              <input v-model="names[i]" placeholder="Nombre y apellido" class="craft-input flex-1" />
              <button v-if="names.length > 1" type="button" @click="removeName(i)" aria-label="Quitar invitado" class="px-2">✕</button>
            </div>

            <button v-if="names.length < invite.allowed_guests" type="button" @click="addName" class="craft-link">
              + Agregar invitado
            </button>

            <p v-if="displayError" class="text-sm text-red-700">{{ displayError }}</p>

            <div class="flex flex-col gap-2 pt-2 sm:flex-row">
              <button type="submit" :disabled="submitting" class="craft-btn-primary flex-1 justify-center">
                {{ submitting ? 'Enviando…' : 'Confirmar asistencia' }}
              </button>
              <button type="button" :disabled="submitting" @click="declinarGenerico" class="craft-btn-ghost justify-center">
                No podemos ir
              </button>
            </div>
          </form>
        </template>
      </div>

      <p v-if="!submitted && invite.rsvp_deadline" class="mt-4 text-center text-xs tracking-widest text-[#645757] uppercase">
        Confirmá antes del {{ formatDate(invite.rsvp_deadline) }}
      </p>
    </section>

    <!-- ============ CIERRE ============ -->
    <footer data-anchor="cierre" class="px-6 pb-16 pt-4 text-center">
      <p class="craft-display-sm">{{ invite.closing_text || '¡Los esperamos!' }}</p>
    </footer>

    <button
      v-if="entered && musicId && !preview"
      type="button"
      @click="toggleMusic"
      :aria-label="musicPlaying ? 'Pausar música' : 'Reproducir música'"
      class="fixed bottom-5 left-5 z-30 grid h-11 w-11 place-items-center rounded-full bg-[#1d3023] text-[#f7f5f2] transition hover:brightness-110"
    >
      <Pause v-if="musicPlaying" :size="18" />
      <Music v-else :size="18" />
    </button>
  </div>
</template>

<style scoped>
.craft {
  font-family: 'DM Serif Text', ui-serif, Georgia, serif;
}

.craft-display {
  font-family: 'Bodoni Moda', ui-serif, Georgia, serif;
  font-weight: 400;
  letter-spacing: -0.03em;
  line-height: 0.9;
}
.craft-display-sm {
  font-family: 'Bodoni Moda', ui-serif, Georgia, serif;
  font-weight: 400;
  letter-spacing: -0.02em;
  line-height: 1;
  font-size: clamp(1.75rem, 5vw, 2.75rem);
}

.craft-heading-sm {
  font-weight: 700;
  font-family: 'DM Serif Text', serif;
  font-size: 1.05rem;
}

.craft-body {
  font-size: 1.05rem;
  line-height: 1.5;
}

.craft-label {
  font-size: 0.72rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.craft-card {
  background: #eae6df;
  border-radius: 8px;
}

.craft-stat-card {
  background: #eae6df;
  border-radius: 8px;
  padding: 20px 4px;
  text-align: center;
}

.craft-icon-circle {
  display: grid;
  place-items: center;
  height: 2.75rem;
  width: 2.75rem;
  flex-shrink: 0;
  border-radius: 999px;
  background: #d7d2cc;
  color: #1d3023;
}

.craft-link {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.85rem;
  font-weight: 600;
  color: #0e634f;
  text-decoration: underline;
  text-underline-offset: 3px;
}

.craft-input {
  width: 100%;
  border-radius: 8px;
  border: 1px solid #d7d2cc;
  padding: 10px 14px;
  background: #ffffff;
  font-family: 'DM Serif Text', serif;
}
.craft-input:focus {
  outline: 2px solid #1d3023;
  outline-offset: 1px;
}

.craft-btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border-radius: 8px;
  background: #26d862;
  color: #1d3023;
  padding: 10px 24px;
  font-weight: 700;
  font-size: 0.95rem;
  transition: filter 0.15s ease;
}
.craft-btn-primary:hover {
  filter: brightness(1.08);
}
.craft-btn-primary:disabled {
  opacity: 0.5;
  cursor: default;
}

.craft-btn-ghost {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  border-radius: 8px;
  border: 1px solid #2a1a1d;
  color: #2a1a1d;
  padding: 10px 24px;
  font-weight: 600;
  font-size: 0.9rem;
  background: transparent;
  transition: background 0.15s ease;
}
.craft-btn-ghost:hover {
  background: #eae6df;
}
.craft-btn-ghost:disabled {
  opacity: 0.5;
}

.craft-btn-ghost-invert {
  border-radius: 8px;
  border: 1px solid #f7f5f2;
  color: #f7f5f2;
  padding: 8px 20px;
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.15em;
  transition: background 0.15s ease;
}
.craft-btn-ghost-invert:hover {
  background: rgba(247, 245, 242, 0.12);
}

.craft-nav-arrow {
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
  color: #1d3023;
  transition: background 0.15s ease;
}
.craft-nav-arrow:hover {
  background: #ffffff;
}

.craft-toggle {
  border-radius: 999px;
  padding: 4px 12px;
  font-size: 0.75rem;
  font-weight: 700;
}
.craft-toggle-off {
  background: transparent;
  color: #645757;
  box-shadow: inset 0 0 0 1px #d7d2cc;
}
.craft-toggle-on {
  background: #26d862;
  color: #1d3023;
}
.craft-toggle-off-active {
  background: #1d3023;
  color: #f7f5f2;
}

/* --- Hero + portada: shape orgánico fluido, sin librerías --------------- */
.craft-blob {
  position: absolute;
  border-radius: 60% 40% 30% 70% / 60% 30% 70% 40%;
  filter: blur(50px);
  opacity: 0.55;
  animation: craft-morph 16s ease-in-out infinite;
}
.craft-blob-1 {
  top: -10%;
  left: -10%;
  height: 60vh;
  width: 60vh;
  background: radial-gradient(circle at 30% 30%, #26d862, #1d3023 70%);
}
.craft-blob-2 {
  bottom: -15%;
  right: -12%;
  height: 55vh;
  width: 55vh;
  background: radial-gradient(circle at 70% 70%, #0e634f, #1d3023 70%);
  animation-duration: 20s;
  animation-delay: -6s;
}
@keyframes craft-morph {
  0%,
  100% {
    border-radius: 60% 40% 30% 70% / 60% 30% 70% 40%;
    transform: rotate(0deg) scale(1);
  }
  33% {
    border-radius: 40% 60% 70% 30% / 40% 70% 30% 60%;
    transform: rotate(8deg) scale(1.05);
  }
  66% {
    border-radius: 70% 30% 50% 50% / 30% 60% 40% 70%;
    transform: rotate(-6deg) scale(0.97);
  }
}

/* --- Hero con fotos: el verde pasa a ser un glow detrás del collage, en vez
     del color de fondo dominante (esa versión solo se usa sin fotos). ----- */
.craft-glow {
  position: absolute;
  border-radius: 50%;
  filter: blur(70px);
  opacity: 0.6;
  mix-blend-mode: screen;
  animation: craft-morph 18s ease-in-out infinite;
}
.craft-glow-1 {
  top: -15%;
  left: -10%;
  height: 55vh;
  width: 55vh;
  background: radial-gradient(circle, #26d862, transparent 70%);
}
.craft-glow-2 {
  bottom: -20%;
  right: -10%;
  height: 50vh;
  width: 50vh;
  background: radial-gradient(circle, #0e634f, transparent 70%);
  animation-duration: 22s;
  animation-delay: -8s;
}

.craft-hero-photos {
  position: absolute;
  inset: 0;
  z-index: 1;
}
.craft-hero-photo {
  position: absolute;
  overflow: hidden;
  border-radius: 8px;
  box-shadow: 0 24px 60px -20px rgba(0, 0, 0, 0.65);
}
.craft-hero-photo img {
  display: block;
  height: 100%;
  width: 100%;
  object-fit: cover;
}
.craft-hero-photo-0 {
  top: 8%;
  left: 5%;
  width: 40%;
  aspect-ratio: 3 / 4;
  transform: rotate(-9deg);
}
.craft-hero-photo-1 {
  top: 12%;
  right: 5%;
  width: 34%;
  aspect-ratio: 3 / 4;
  transform: rotate(7deg);
}
.craft-hero-photo-2 {
  bottom: 10%;
  left: 9%;
  width: 32%;
  aspect-ratio: 4 / 5;
  transform: rotate(6deg);
}
.craft-hero-photo-3 {
  bottom: 8%;
  right: 8%;
  width: 30%;
  aspect-ratio: 4 / 5;
  transform: rotate(-5deg);
}
@media (max-width: 640px) {
  .craft-hero-photo-0 {
    width: 46%;
  }
  .craft-hero-photo-1 {
    width: 40%;
  }
  .craft-hero-photo-2,
  .craft-hero-photo-3 {
    width: 38%;
  }
}

.craft-cover {
  background: #1d3023;
  transition: opacity 0.6s ease;
  overflow: hidden;
}
.craft-cover--out {
  opacity: 0;
  pointer-events: none;
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
  .hero-in,
  .craft-cover,
  .craft-blob,
  .craft-glow {
    animation: none;
    transition: none;
  }
}
</style>
