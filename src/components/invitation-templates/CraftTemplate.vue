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
import { darken } from '../../lib/color'
import EnvelopeCover from '../EnvelopeCover.vue'

// Plantilla "Craft" - invernadero botánico sobre papel crema: bone linen,
// un único momento oscuro (forest depths) al abrir, verde lima como acento
// repetido en varios detalles (no solo el botón principal), cards planas sin
// sombra. Pulida con las skills de diseño/animación instaladas
// (emilkowalski/skills + taste-skill): curvas de easing propias, feedback
// táctil, hover gateado a mouse real, stagger en grillas, reduced-motion
// que solo saca el movimiento. Mismo contrato de props/emits que las otras
// plantillas - toda la lógica vive en useInvitationLogic().
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
  bgColor,
  primaryColor,
  primaryDark,
  primaryTint,
  primaryLight,
  onPrimary,
  envelopePalette,
  envelopeMonogram,
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

// Foto única del hero: banner primero, si no hay usa la primera de saludo.
// Solo cuenta como "propia" si el host la cargó (no las de demo). Sin foto
// real, el hero se queda con el verde + blobs solo.
const heroPhoto = computed(() => [...slotUrls('banner'), ...slotUrls('retrato')][0] || '')

// Sombra profunda del color principal: preserva el "único momento oscuro" del
// hero sin foto (antes forest fijo) pero siguiendo el color que elija el host.
const heroDeep = computed(() => darken(primaryColor.value, 0.72))
</script>

<template>
  <div class="craft min-h-screen overflow-x-clip text-[#2a1a1d]">
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
      class="craft-hero relative flex h-svh min-h-[560px] items-center justify-center overflow-hidden px-6 text-center"
    >
      <template v-if="heroPhoto">
        <img
          :src="heroPhoto"
          alt=""
          fetchpriority="high"
          class="kenburns absolute inset-0 h-full w-full object-cover"
        />
        <div class="craft-hero-scrim absolute inset-0"></div>
        <div class="craft-hero-flare-wash absolute inset-0"></div>
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
    <EnvelopeCover
      v-if="!preview && !envelopeGone"
      :monogram-short="envelopeMonogram.short"
      :monogram-full="envelopeMonogram.full"
      :music-id="musicId"
      :opening="opening"
      :closing="closing"
      v-bind="envelopePalette"
      monogram-font="'Bodoni Moda', serif"
      @open="openEnvelope"
      @fade-end="onEnvelopeFadeEnd"
    />

    <!-- ============ SALUDO ============ -->
    <section v-reveal data-anchor="saludo" class="py-16">
      <div class="mx-auto max-w-[720px] px-6 text-center">
        <p v-if="invite.family_name" class="craft-label text-[var(--pc)]">{{ invite.family_name }}</p>
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
          class="flex"
          :class="saludoNoTransition ? '' : 'craft-slide-track'"
          :style="{ transform: `translateX(calc(14% - ${saludoSlide * 72}%))` }"
          @transitionend="onSaludoTransitionEnd"
        >
          <div
            v-for="(src, i) in saludoLoop"
            :key="i"
            class="w-[72%] shrink-0 px-2"
            :class="[saludoNoTransition ? '' : 'craft-slide-item', i === saludoSlide ? 'scale-100 opacity-100' : 'scale-[0.9] opacity-40']"
          >
            <img
              :src="src"
              alt=""
              loading="lazy"
              decoding="async"
              class="craft-card block aspect-3/4 w-full object-cover"
              :class="{ 'craft-ring': i === saludoSlide }"
            />
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
          class="craft-dot h-1.5 rounded-full"
          :class="i === saludoActive ? 'w-5 bg-[var(--pc)] opacity-100' : 'w-1.5 bg-[#2a1a1d] opacity-20'"
        ></button>
      </div>
    </section>

    <!-- ============ COUNTDOWN → stat cards ============ -->
    <section v-if="countdown" v-reveal class="mx-auto max-w-[1200px] px-6 py-16">
      <p class="craft-label text-center text-[#645757]">Falta poco</p>
      <div class="craft-stagger mt-6 grid grid-cols-4 gap-3 sm:gap-4">
        <div v-for="(u, i) in countdownUnits" :key="u.label" class="craft-stat-card" :style="{ '--i': i }">
          <p class="craft-display-sm text-[var(--pc-dark)]">{{ u.value }}</p>
          <p class="mt-1 text-[11px] leading-[1.5] text-[#645757] sm:text-[13px]">{{ u.label }}</p>
        </div>
      </div>
    </section>

    <!-- ============ DETALLES ============ -->
    <section v-reveal data-anchor="fiesta" class="mx-auto max-w-[720px] px-6 py-16 text-center">
      <p class="craft-label text-[#645757]">Los detalles</p>
      <h2 class="craft-display-sm mt-2">La celebración</h2>
      <div class="craft-rule"></div>

      <div class="craft-card craft-accent-top craft-stagger mt-8 divide-y divide-[#d7d2cc] px-6 text-left sm:px-8">
        <div v-if="invite.event_date" class="flex items-center gap-4 py-5" style="--i: 0">
          <span class="craft-icon-circle"><CalendarHeart :size="18" :stroke-width="1.5" /></span>
          <div class="min-w-0">
            <p class="craft-label text-[#645757]">Cuándo</p>
            <p class="craft-heading-sm mt-1">{{ formatDateLong(invite.event_date) }}</p>
            <p v-if="invite.reception_time" class="mt-0.5 text-xs text-[#645757]">
              {{ formatTime(invite.reception_time)
              }}<span v-if="invite.end_time"> - {{ formatTime(invite.end_time) }}</span> h
            </p>
          </div>
        </div>

        <div v-if="invite.venue_name || invite.venue_address" class="flex items-center gap-4 py-5" style="--i: 1">
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

        <div v-if="invite.dress_code" class="flex items-center gap-4 py-5" style="--i: 2">
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
      <h2 class="craft-display-sm">¿Qué canción no puede faltar?</h2>
      <div class="craft-rule"></div>

      <div class="craft-card craft-accent-top mt-8 p-6 text-left sm:p-8">
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
              <button type="button" @click="selectSong(r)" class="craft-song-row flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left">
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
      <h2 class="craft-display-sm text-center">Momentos</h2>
      <div class="craft-rule"></div>

      <div
        class="craft-card craft-accent-top relative mx-auto mt-6 max-w-2xl overflow-hidden"
        @touchstart.passive="onTouchStart"
        @touchend.passive="onTouchEnd"
        @mouseenter="stopMomentosAutoplay"
        @mouseleave="startMomentosAutoplay"
      >
        <div class="craft-slide-track flex" :style="{ transform: `translateX(-${slide * 100}%)` }">
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
            class="craft-dot h-2 rounded-full bg-white"
            :class="i === slide ? 'w-6 opacity-100' : 'w-2 opacity-50'"
          ></button>
        </div>
      </div>
    </section>

    <!-- ============ GALERÍA ============ -->
    <section v-if="shows('galeria')" v-reveal data-anchor="galeria" class="mx-auto max-w-[1200px] px-6 py-16">
      <p class="craft-label text-center text-[#645757]">Recuerdos</p>
      <h2 class="craft-display-sm mt-2 text-center">Galería</h2>
      <div class="craft-rule"></div>

      <div class="mt-8 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div
          v-for="(src, i) in galeriaGrid"
          :key="i"
          ref="gridItems"
          class="craft-card overflow-hidden will-change-transform"
        >
          <img :src="src" :alt="`Recuerdo ${i + 1}`" loading="lazy" decoding="async" class="block aspect-square w-full object-cover" />
        </div>
      </div>
    </section>

    <!-- ============ RSVP ============ -->
    <section id="rsvp" v-reveal data-anchor="rsvp" class="mx-auto max-w-[600px] scroll-mt-6 px-6 py-16">
      <div class="craft-card craft-accent-top p-8 text-center">
        <h2 class="craft-display-sm">Confirmá tu asistencia</h2>

        <p v-if="preview" class="mt-4 rounded-lg bg-[#d7d2cc]/40 px-3 py-2 text-center text-xs text-[#645757]">
          Vista previa. La confirmación funciona en la invitación real.
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
      class="craft-fab fixed bottom-5 left-5 z-30 grid h-11 w-11 place-items-center rounded-full bg-[var(--pc-deep)] text-[#f7f5f2]"
    >
      <Pause v-if="musicPlaying" :size="18" />
      <Music v-else :size="18" />
    </button>
  </div>
</template>

<style scoped>
.craft {
  font-family: 'DM Serif Text', ui-serif, Georgia, serif;
  /* Curvas propias (emil-design-eng): las de CSS por default (ease, ease-in)
     son débiles y "ease-in" en especial se siente lento para UI. */
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
  --ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
  /* Color principal: --lime era un verde fijo, ahora sigue al color que
     elija el host (ver useInvitationLogic → primaryColor/envelopePalette). */
  --lime: v-bind(primaryColor);
  --pc: v-bind(primaryColor);
  --pc-dark: v-bind(primaryDark);
  --pc-tint: v-bind(primaryTint);
  --pc-soft: v-bind(primaryLight);
  --pc-on: v-bind(onPrimary);
  --pc-deep: v-bind(heroDeep);
  background-color: v-bind(bgColor);
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

/* Rayita verde repetida bajo los títulos de sección: la forma "prolija" de
   sumar detalles en el color principal sin caer en el glow difuso de IA. */
.craft-rule {
  width: 32px;
  height: 2px;
  border-radius: 999px;
  background: var(--lime);
  margin: 14px auto 0;
}

.craft-card {
  background: #eae6df;
  border-radius: 8px;
}
.craft-accent-top {
  border-top: 3px solid var(--lime);
  border-radius: 3px 3px 8px 8px;
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
  background: color-mix(in srgb, var(--lime) 14%, transparent);
  color: var(--pc-dark);
}

.craft-ring {
  box-shadow: 0 0 0 3px var(--lime);
}

.craft-link {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--pc-dark);
  text-decoration: underline;
  text-decoration-color: var(--pc-tint);
  text-underline-offset: 3px;
}

.craft-input {
  width: 100%;
  border-radius: 8px;
  border: 1px solid #d7d2cc;
  padding: 10px 14px;
  background: #ffffff;
  font-family: 'DM Serif Text', serif;
  transition: border-color 150ms ease;
}
.craft-input:focus {
  outline: 2px solid var(--pc-deep);
  outline-offset: 1px;
  border-color: var(--lime);
}

/* --- Botones: feedback táctil (:active) en todos, hover gateado a mouse real
     para que no quede "pegado" en touch (emil-design-eng + taste-skill). --- */
.craft-btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border-radius: 8px;
  background: var(--lime);
  color: var(--pc-on);
  padding: 10px 24px;
  font-weight: 700;
  font-size: 0.95rem;
  transition:
    filter 150ms ease,
    transform 120ms var(--ease-out);
}
.craft-btn-primary:active:not(:disabled) {
  transform: scale(0.97);
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
  transition:
    background 150ms ease,
    transform 120ms var(--ease-out);
}
.craft-btn-ghost:active:not(:disabled) {
  transform: scale(0.97);
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
  transition:
    background 150ms ease,
    transform 120ms var(--ease-out);
}
.craft-btn-ghost-invert:active {
  transform: scale(0.96);
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
  transition: background 150ms ease;
}
.craft-nav-arrow:active {
  transform: translateY(-50%) scale(0.92);
}

.craft-dot {
  transition:
    width 200ms var(--ease-out),
    opacity 200ms ease,
    transform 120ms var(--ease-out);
}
.craft-dot:active {
  transform: scale(0.9);
}

.craft-song-row {
  transition: background 150ms ease;
}

.craft-fab {
  transition:
    filter 150ms ease,
    transform 120ms var(--ease-out);
}
.craft-fab:active {
  transform: scale(0.94);
}

/* Hover solo para mouse real: en touch, :hover queda "pegado" tras el tap. */
@media (hover: hover) and (pointer: fine) {
  .craft-btn-primary:hover {
    filter: brightness(1.08);
  }
  .craft-btn-ghost:hover {
    background: #eae6df;
  }
  .craft-btn-ghost-invert:hover {
    background: rgba(247, 245, 242, 0.12);
  }
  .craft-nav-arrow:hover {
    background: #ffffff;
  }
  .craft-fab:hover {
    filter: brightness(1.1);
  }
  .craft-song-row:hover {
    background: #eae6df;
  }
}

.craft-toggle {
  border-radius: 999px;
  padding: 4px 12px;
  font-size: 0.75rem;
  font-weight: 700;
  transition: transform 120ms var(--ease-out);
}
.craft-toggle:active {
  transform: scale(0.94);
}
.craft-toggle-off {
  background: transparent;
  color: #645757;
  box-shadow: inset 0 0 0 1px #d7d2cc;
}
.craft-toggle-on {
  background: var(--lime);
  color: var(--pc-on);
}
.craft-toggle-off-active {
  background: var(--pc-deep);
  color: #f7f5f2;
}

/* --- Hero sin foto: shape orgánico fluido, sin librerías ---------------- */
.craft-blob {
  position: absolute;
  border-radius: 60% 40% 30% 70% / 60% 30% 70% 40%;
  filter: blur(50px);
  opacity: 0.55;
  animation: craft-morph 16s var(--ease-in-out) infinite;
}
.craft-blob-1 {
  top: -10%;
  left: -10%;
  height: 60vh;
  width: 60vh;
  background: radial-gradient(circle at 30% 30%, var(--lime), var(--pc-deep) 70%);
}
.craft-blob-2 {
  bottom: -15%;
  right: -12%;
  height: 55vh;
  width: 55vh;
  background: radial-gradient(circle at 70% 70%, var(--pc-dark), var(--pc-deep) 70%);
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

/* --- Hero con foto: foto de fondo completa (como Clásica/Partiful), con un
     wash de luz verde por encima en vez del overlay plano negro. ---------- */
.craft-hero {
  background-color: var(--pc-deep);
}

.craft-hero-scrim {
  background: linear-gradient(
    to bottom,
    color-mix(in srgb, var(--pc-deep) 65%, transparent),
    color-mix(in srgb, var(--pc-deep) 35%, transparent),
    color-mix(in srgb, var(--pc-deep) 85%, transparent)
  );
}

.craft-hero-flare-wash {
  background: radial-gradient(circle at 12% 8%, color-mix(in srgb, var(--lime) 40%, transparent), transparent 24%);
  animation: craft-flare-pulse 8s var(--ease-in-out) infinite;
}
@keyframes craft-flare-pulse {
  0%,
  100% {
    opacity: 0.3;
  }
  50% {
    opacity: 0.6;
  }
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
  animation: hero-up 1.1s var(--ease-out) 0.15s both;
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

/* Carruseles: la curva de "algo que se mueve en pantalla" es ease-in-out,
   no ease-out (que es para elementos que entran/salen). */
.craft-slide-track {
  transition-property: transform;
  transition-duration: 500ms;
  transition-timing-function: var(--ease-in-out);
}
.craft-slide-item {
  transition-property: transform, opacity;
  transition-duration: 500ms;
  transition-timing-function: var(--ease-in-out);
}

.reveal {
  opacity: 0;
  transform: translateY(28px);
  transition:
    opacity 0.7s var(--ease-out),
    transform 0.7s var(--ease-out);
}
.reveal-in {
  opacity: 1;
  transform: none;
}

/* Stagger (emil-design-eng): varios elementos que entran juntos se sienten
   más naturales con una cascada corta entre ellos, no todos a la vez. */
.craft-stagger > * {
  opacity: 0;
  transform: translateY(10px);
  transition:
    opacity 0.5s var(--ease-out),
    transform 0.5s var(--ease-out);
  transition-delay: calc(var(--i, 0) * 70ms);
}
.reveal-in.craft-stagger > *,
.reveal-in .craft-stagger > * {
  opacity: 1;
  transform: none;
}

@media (prefers-reduced-motion: reduce) {
  /* "Menos y más suave, no cero": se saca el movimiento (transform) pero se
     deja el fade de opacidad, que no marea a nadie. */
  .hero-in,
  .craft-blob,
  .craft-hero-flare-wash,
  .kenburns,
  .craft-slide-track,
  .craft-slide-item,
  .reveal,
  .craft-stagger > * {
    animation: none;
    transform: none !important;
    transition-property: opacity;
    transition-duration: 300ms;
  }
}
</style>
