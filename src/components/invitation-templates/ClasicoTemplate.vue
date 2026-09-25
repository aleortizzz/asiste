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
import EnvelopeCover from '../EnvelopeCover.vue'

// Plantilla "Clásica" — la invitación original de asiste (sobre animado,
// paleta rosa/ámbar, tipografía cursiva). 100% presentacional: toda la
// lógica compartida entre plantillas vive en useInvitationLogic().
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
  bgColor,
  primaryColor,
  primaryDark,
  primaryTint,
  primaryLight,
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
</script>

<template>
  <div
    class="min-h-screen overflow-x-clip text-stone-700"
    :style="{
      backgroundColor: bgColor,
      '--pc': primaryColor,
      '--pc-dark': primaryDark,
      '--pc-tint': primaryTint,
      '--pc-soft': primaryLight,
    }"
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
    <EnvelopeCover
      v-if="!preview && !envelopeGone"
      :monogram-short="envelopeMonogram.short"
      :monogram-full="envelopeMonogram.full"
      :music-id="musicId"
      :opening="opening"
      :closing="closing"
      v-bind="envelopePalette"
      monogram-font="'Dancing Script', cursive"
      @open="openEnvelope"
      @fade-end="onEnvelopeFadeEnd"
    />

    <!-- ============ SALUDO ============ -->
    <section v-reveal data-anchor="saludo" class="py-20 text-center">
      <div class="mx-auto max-w-xl px-6">
        <div class="divider">✦</div>
        <p v-if="invite.family_name" class="pc-eyebrow text-xs uppercase tracking-[0.3em]">
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
              class="pc-ring block aspect-3/4 w-full rounded-[2rem] object-cover shadow-xl ring-1"
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
          class="pc-dot h-1.5 rounded-full transition-all"
          :class="i === saludoActive ? 'w-5 opacity-100' : 'w-1.5 opacity-30'"
        ></button>
      </div>
    </section>

    <!-- ============ COUNTDOWN ============ -->
    <section v-if="countdown" v-reveal class="relative overflow-hidden py-20">
      <div class="relative mx-auto max-w-xl px-6 text-center">
        <p class="pc-eyebrow text-xs uppercase tracking-[0.3em]">Falta poco</p>
        <div class="mt-6 grid grid-cols-4 gap-2 sm:gap-3">
          <div
            v-for="u in countdownUnits"
            :key="u.label"
            class="pc-ring rounded-2xl bg-white/80 py-4 shadow ring-1 backdrop-blur-sm"
          >
            <p class="pc-heading text-2xl font-semibold sm:text-3xl">{{ u.value }}</p>
            <p class="mt-1 text-[9px] uppercase tracking-widest text-stone-400 sm:text-[10px]">
              {{ u.label }}
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ DETALLES DE LA FIESTA ============ -->
    <section v-reveal data-anchor="fiesta" class="mx-auto max-w-xl px-6 py-24">
      <p class="pc-eyebrow text-center text-[0.7rem] uppercase tracking-[0.45em]">
        Los detalles
      </p>
      <h2
        class="pc-heading mt-2 text-center text-4xl"
        style="font-family: 'Dancing Script', cursive"
      >
        La celebración
      </h2>
      <div class="divider">✦</div>

      <!-- Tarjeta con doble marco -->
      <div
        class="pc-ring relative mt-8 rounded-[1.9rem] bg-white/90 p-2.5 shadow-[0_28px_60px_-28px_rgba(120,72,40,0.35)] ring-1 backdrop-blur-sm"
      >
        <div class="pc-border rounded-[1.5rem] border px-6 sm:px-8">
          <div class="pc-divide divide-y">
            <!-- Cuándo -->
            <div v-if="invite.event_date" class="flex items-center gap-4 py-5">
              <span
                class="pc-ring pc-icon grid h-11 w-11 shrink-0 place-items-center rounded-full ring-1"
              >
                <CalendarHeart :size="18" :stroke-width="1.5" />
              </span>
              <div class="min-w-0">
                <p class="pc-eyebrow text-[0.62rem] uppercase tracking-[0.28em]">Cuándo</p>
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
                class="pc-ring pc-icon grid h-11 w-11 shrink-0 place-items-center rounded-full ring-1"
              >
                <MapPin :size="18" :stroke-width="1.5" />
              </span>
              <div class="min-w-0">
                <p class="pc-eyebrow text-[0.62rem] uppercase tracking-[0.28em]">Dónde</p>
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
                  class="pc-link pc-border mt-2 inline-flex items-center gap-1 rounded-full border px-3 py-1 text-[0.7rem] font-medium uppercase tracking-wider transition pc-hover-tint"
                >
                  Cómo llegar <ArrowUpRight :size="13" :stroke-width="2" />
                </a>
              </div>
            </div>

            <!-- Dress code -->
            <div v-if="invite.dress_code" class="flex items-center gap-4 py-5">
              <span
                class="pc-ring pc-icon grid h-11 w-11 shrink-0 place-items-center rounded-full ring-1"
              >
                <Gem :size="18" :stroke-width="1.5" />
              </span>
              <div class="min-w-0">
                <p class="pc-eyebrow text-[0.62rem] uppercase tracking-[0.28em]">Dress code</p>
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
        class="pc-ring mt-12 overflow-hidden rounded-[2rem] shadow-xl ring-1"
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
        class="pc-ring pc-icon mx-auto grid h-12 w-12 place-items-center rounded-full ring-1"
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
        class="pc-ring pc-hover-tint mt-3 inline-flex items-center gap-2 rounded-full bg-white px-4 py-2 font-mono text-sm text-stone-700 shadow ring-1 transition"
      >
        {{ aliasCopied ? '¡Copiado!' : invite.gift_alias }}
        <Check v-if="aliasCopied" :size="14" />
        <Copy v-else :size="14" />
      </button>
    </section>

    <!-- ============ CANCIONES (plan "plus") ============ -->
    <section v-if="invite.plan === 'plus'" v-reveal data-anchor="canciones" class="mx-auto max-w-xl px-6 py-20">
      <p class="pc-eyebrow text-center text-[0.7rem] uppercase tracking-[0.45em]">
        Ayudanos con el playlist
      </p>
      <h2 class="pc-heading mt-2 text-center text-4xl" style="font-family: 'Dancing Script', cursive">
        ¿Qué canción no puede faltar?
      </h2>
      <div class="divider">✦</div>

      <div class="pc-ring mt-8 rounded-[2rem] bg-white p-6 shadow-xl ring-1 sm:p-8">
        <template v-if="justAddedSong">
          <p class="py-2 text-center text-4xl">🎶</p>
          <p class="text-center text-stone-600">¡Gracias! La sumamos a la lista.</p>
          <button
            type="button"
            @click="justAddedSong = false"
            class="pc-link mx-auto mt-4 block text-sm font-medium underline pc-decoration-tint"
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
              class="pc-border pc-input w-full rounded-xl border bg-black/5 px-3 py-2 pr-9 focus:outline-none"
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
                class="pc-hover-tint flex w-full items-center gap-3 rounded-xl px-2 py-2 text-left transition"
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
            class="pc-tint-bg pc-ring mt-3 flex items-center gap-3 rounded-xl px-3 py-2 ring-1"
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
              class="pc-link-soft shrink-0 px-1"
            >
              ✕
            </button>
          </div>

          <form v-if="selectedSong" @submit.prevent="submitSong" class="mt-4 space-y-3">
            <input
              v-model="songRequesterName"
              placeholder="Tu nombre o familia"
              class="pc-border pc-input w-full rounded-xl border bg-black/5 px-3 py-2 focus:outline-none"
            />
            <p v-if="displaySongError" class="text-sm text-red-600">{{ displaySongError }}</p>
            <button
              type="submit"
              :disabled="songSubmitting"
              class="pc-btn w-full rounded-full px-4 py-3 font-medium text-white shadow-md transition disabled:opacity-50"
            >
              {{ songSubmitting ? 'Agregando…' : 'Agregar canción' }}
            </button>
          </form>
        </template>
      </div>
    </section>

    <!-- ============ CARRUSEL ============ -->
    <section v-if="shows('momentos')" v-reveal data-anchor="momentos" class="py-20">
      <h2 class="pc-heading text-center text-3xl" style="font-family: 'Dancing Script', cursive">
        Momentos
      </h2>
      <div class="divider">✦</div>

      <div
        class="pc-ring relative mx-auto mt-6 max-w-2xl overflow-hidden shadow-xl sm:rounded-[2rem] sm:ring-1"
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
      <p class="pc-eyebrow text-center text-[0.7rem] uppercase tracking-[0.45em]">Recuerdos</p>
      <h2
        class="pc-heading mt-2 text-center text-4xl"
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
          class="pc-ring overflow-hidden rounded-2xl shadow-lg ring-1 will-change-transform"
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
      <div class="pc-ring rounded-[2rem] bg-white p-8 shadow-xl ring-1">
        <h2 class="pc-heading text-center text-3xl" style="font-family: 'Dancing Script', cursive">
          Confirmá tu asistencia
        </h2>
        <div class="divider">✦</div>

        <p
          v-if="preview"
          class="pc-tint-bg pc-eyebrow mb-4 rounded-lg px-3 py-2 text-center text-xs"
        >
          Vista previa — la confirmación funciona en la invitación real.
        </p>

        <!-- Respuesta enviada -->
        <div v-if="submitted" class="py-4 text-center">
          <p class="text-5xl">💌</p>
          <p class="pc-heading mt-4 text-lg" style="font-family: 'Playfair Display', serif">
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
              class="pc-border flex items-center justify-between gap-2 rounded-xl border bg-black/5 px-3 py-2"
            >
              <span class="text-stone-800">{{ guest.full_name }}</span>
              <div class="flex shrink-0 gap-2">
                <button
                  type="button"
                  translate="no"
                  @click="guest.attending = true"
                  :class="guest.attending ? 'pc-btn text-white' : 'bg-white text-stone-400'"
                  class="pc-ring rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset transition sm:text-sm"
                >
                  Asiste
                </button>
                <button
                  type="button"
                  translate="no"
                  @click="guest.attending = false"
                  :class="!guest.attending ? 'bg-stone-700 text-white' : 'bg-white text-stone-400'"
                  class="pc-ring rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset transition sm:text-sm"
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
            class="pc-btn mt-6 w-full rounded-full px-4 py-3 font-medium text-white shadow-md transition disabled:opacity-50"
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
                class="pc-border pc-input flex-1 rounded-xl border bg-black/5 px-3 py-2 focus:outline-none"
              />
              <button
                v-if="names.length > 1"
                type="button"
                @click="removeName(i)"
                aria-label="Quitar invitado"
                class="pc-link-soft px-2"
              >
                ✕
              </button>
            </div>

            <button
              v-if="names.length < invite.allowed_guests"
              type="button"
              @click="addName"
              class="pc-link text-sm font-medium underline pc-decoration-tint"
            >
              + Agregar invitado
            </button>

            <p v-if="displayError" class="text-sm text-red-600">{{ displayError }}</p>

            <div class="flex flex-col gap-2 pt-2 sm:flex-row">
              <button
                type="submit"
                :disabled="submitting"
                class="pc-btn flex-1 rounded-full px-4 py-3 font-medium text-white shadow-md transition disabled:opacity-50"
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
      <p class="pc-heading text-4xl" style="font-family: 'Dancing Script', cursive">
        {{ invite.closing_text || '¡Los esperamos!' }}
      </p>
    </footer>

    <!-- Botón flotante: música -->
    <button
      v-if="entered && musicId && !preview"
      type="button"
      @click="toggleMusic"
      :aria-label="musicPlaying ? 'Pausar música' : 'Reproducir música'"
      class="pc-btn fixed bottom-5 left-5 z-30 grid h-11 w-11 place-items-center rounded-full text-white shadow-lg ring-1 ring-white/20 transition"
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
  color: var(--pc-dark);
  font-size: 0.8rem;
}
.divider::before,
.divider::after {
  content: '';
  height: 1px;
  width: 46px;
}
.divider::before {
  background: linear-gradient(to right, transparent, var(--pc-tint));
}
.divider::after {
  background: linear-gradient(to left, transparent, var(--pc-tint));
}

/* Color principal: todas las plantillas comparten este esquema de acento
   (definido como custom properties en el root, ver :style del wrapper) para
   que un solo color elegido por el host teña textos, rings, botones, etc. */
.pc-heading {
  color: var(--pc);
}
.pc-eyebrow {
  color: var(--pc-dark);
}
.pc-icon {
  color: var(--pc-dark);
}
.pc-link {
  color: var(--pc);
}
.pc-link-soft {
  color: var(--pc);
  opacity: 0.75;
}
.pc-decoration-tint {
  text-decoration-color: var(--pc-tint);
}
.pc-ring {
  --tw-ring-color: var(--pc-tint);
}
.pc-border {
  border-color: var(--pc-tint);
}
.pc-divide > * + * {
  border-color: var(--pc-tint);
}
.pc-dot {
  background-color: var(--pc);
}
.pc-tint-bg {
  background-color: var(--pc-soft);
}
.pc-hover-tint {
  transition: background-color 0.2s ease;
}
@media (hover: hover) and (pointer: fine) {
  .pc-hover-tint:hover {
    background-color: var(--pc-soft);
  }
}
.pc-btn {
  background-color: var(--pc);
  transition:
    filter 0.15s ease,
    transform 0.1s ease;
}
@media (hover: hover) and (pointer: fine) {
  .pc-btn:hover {
    filter: brightness(1.08);
  }
}
.pc-btn:active {
  transform: scale(0.98);
}
.pc-input:focus {
  border-color: var(--pc) !important;
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
</style>
