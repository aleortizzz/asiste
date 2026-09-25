<script setup>
import { computed } from 'vue'
import { Music } from '@lucide/vue'

// Sobre compartido por las tres plantillas: la forma/animación es siempre la
// misma, lo que cambia es la paleta (via CSS custom properties) que cada
// plantilla le pasa como props, para que combine con su propia identidad
// visual. El sello muestra las iniciales sacadas de heroTitle en vez de un
// ícono genérico — "Sofía & Juan" -> "S & J" en la carta, "SJ" en el sello.
const props = defineProps({
  heroTitle: { type: String, default: '' },
  musicId: { type: String, default: '' },
  opening: { type: Boolean, default: false },
  closing: { type: Boolean, default: false },
  bg: { type: String, required: true },
  paperFrom: { type: String, required: true },
  paperTo: { type: String, required: true },
  flapFrom: { type: String, required: true },
  flapTo: { type: String, required: true },
  sealFrom: { type: String, required: true },
  sealTo: { type: String, required: true },
  sealText: { type: String, required: true },
  // `ink`/`inkMuted`: texto de las leyendas de abajo, sobre `bg` (puede ser
  // claro u oscuro según el fondo de cada plantilla). `letterInk`: el
  // monograma DENTRO de la carta, que siempre va sobre papel blanco/claro —
  // por eso es una variable aparte, no puede compartir valor con `ink`.
  ink: { type: String, required: true },
  inkMuted: { type: String, required: true },
  letterInk: { type: String, required: true },
  monogramFont: { type: String, default: 'inherit' },
})

defineEmits(['open', 'fade-end'])

// Iniciales del título: "Sofía & Juan" -> ['S','J'], "Antonella" -> ['A'].
const initials = computed(() => {
  const t = (props.heroTitle || '').trim()
  if (!t) return []
  const byAmp = t.split('&').map((s) => s.trim()).filter(Boolean)
  if (byAmp.length >= 2) {
    return byAmp.slice(0, 2).map((p) => p[0]?.toUpperCase()).filter(Boolean)
  }
  const words = t.split(/\s+/).filter(Boolean)
  if (words.length >= 2) return [words[0][0]?.toUpperCase(), words[1][0]?.toUpperCase()].filter(Boolean)
  return words[0] ? [words[0][0].toUpperCase()] : []
})
const monogramShort = computed(() => initials.value.join('') || '✦')
const monogramFull = computed(() =>
  initials.value.length >= 2 ? initials.value.join(' & ') : initials.value[0] || '✦',
)

const cssVars = computed(() => ({
  '--ec-bg': props.bg,
  '--ec-paper-from': props.paperFrom,
  '--ec-paper-to': props.paperTo,
  '--ec-flap-from': props.flapFrom,
  '--ec-flap-to': props.flapTo,
  '--ec-seal-from': props.sealFrom,
  '--ec-seal-to': props.sealTo,
  '--ec-seal-text': props.sealText,
  '--ec-ink': props.ink,
  '--ec-ink-muted': props.inkMuted,
  '--ec-letter-ink': props.letterInk,
  '--ec-monogram-font': props.monogramFont,
}))
</script>

<template>
  <div
    class="ec-overlay fixed inset-0 z-50 flex flex-col items-center justify-center px-6 text-center"
    :class="{ 'ec-overlay--out': closing }"
    :style="cssVars"
    @transitionend.self="$emit('fade-end')"
  >
    <button
      type="button"
      class="ec-envelope"
      :class="{ 'ec-envelope--open': opening }"
      :disabled="opening"
      aria-label="Abrir invitación"
      @click="$emit('open')"
    >
      <span class="ec-shadow"></span>
      <span class="ec-back"></span>
      <span class="ec-letter">
        <span class="ec-monogram">{{ monogramFull }}</span>
        <span class="ec-letter-rule"></span>
      </span>
      <span class="ec-pocket"></span>
      <span class="ec-flap"></span>
      <span class="ec-seal">{{ monogramShort }}</span>
    </button>

    <p class="ec-caption ec-in" :class="{ 'ec-caption--out': opening }">
      Tocá el sobre para abrir tu invitación
    </p>
    <p v-if="musicId" class="ec-caption ec-caption--muted ec-in" :class="{ 'ec-caption--out': opening }">
      <Music :size="12" /> con música
    </p>
  </div>
</template>

<style scoped>
.ec-overlay {
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
  --ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
  background: var(--ec-bg);
  transition:
    opacity 550ms var(--ease-out),
    filter 550ms var(--ease-out);
}
.ec-overlay--out {
  opacity: 0;
  filter: blur(6px);
  pointer-events: none;
}

.ec-in {
  animation: ec-settle 0.6s var(--ease-out) both;
}
@keyframes ec-settle {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
  to {
    opacity: 1;
    transform: none;
  }
}

.ec-envelope {
  position: relative;
  width: clamp(230px, 74vw, 310px);
  aspect-ratio: 10 / 7;
  padding: 0;
  border: none;
  background: none;
  perspective: 1000px;
  cursor: pointer;
  animation: ec-settle 0.7s var(--ease-out) both;
  transition: transform 150ms var(--ease-out);
}
.ec-envelope:active:not(:disabled) {
  transform: scale(0.98);
}
.ec-envelope:disabled {
  cursor: default;
}

.ec-shadow {
  position: absolute;
  left: 6%;
  right: 6%;
  bottom: -14%;
  height: 26%;
  background: radial-gradient(ellipse at center, rgba(0, 0, 0, 0.35), transparent 72%);
  filter: blur(6px);
  z-index: 0;
  transition: opacity 400ms ease;
}
.ec-envelope--open .ec-shadow {
  opacity: 0.6;
}

.ec-back {
  position: absolute;
  inset: 0;
  border-radius: 10px;
  background: linear-gradient(160deg, var(--ec-paper-from) 0%, var(--ec-paper-to) 100%);
  box-shadow: 0 30px 70px -28px rgba(0, 0, 0, 0.55);
  z-index: 1;
}
/* Costura en diamante: así se arma un sobre real de un solo pliego. Sutil,
   solo se nota de cerca. */
.ec-back::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background-image:
    linear-gradient(35deg, transparent calc(50% - 0.5px), rgba(0, 0, 0, 0.06) 50%, transparent calc(50% + 0.5px)),
    linear-gradient(-35deg, transparent calc(50% - 0.5px), rgba(0, 0, 0, 0.06) 50%, transparent calc(50% + 0.5px));
  opacity: 0.7;
}
/* Textura de papel, apenas perceptible. */
.ec-back::after {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background-image: repeating-linear-gradient(135deg, rgba(0, 0, 0, 0.012) 0 1px, transparent 1px 3px);
}

.ec-letter {
  position: absolute;
  left: 9%;
  right: 9%;
  top: 5%;
  height: 56%;
  border-radius: 6px 6px 2px 2px;
  background: #fffdfa;
  box-shadow: 0 10px 24px -12px rgba(0, 0, 0, 0.35);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  padding-bottom: 12%;
  transform: translateY(0);
  transition: transform 750ms var(--ease-out) 380ms;
  z-index: 2;
}
.ec-envelope--open .ec-letter {
  transform: translateY(-48%);
}
.ec-monogram {
  font-family: var(--ec-monogram-font);
  color: var(--ec-letter-ink);
  font-size: clamp(1.1rem, 4.4vw, 1.6rem);
  letter-spacing: 0.02em;
}
.ec-letter-rule {
  margin-top: 8px;
  width: 28px;
  height: 2px;
  border-radius: 999px;
  background: var(--ec-seal-from);
  opacity: 0.7;
}

.ec-pocket {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 60%;
  background: linear-gradient(160deg, var(--ec-paper-from) 0%, var(--ec-paper-to) 100%);
  clip-path: polygon(0 0, 50% 44%, 100% 0, 100% 100%, 0 100%);
  border-radius: 0 0 10px 10px;
  z-index: 3;
}

.ec-flap {
  position: absolute;
  left: 0;
  right: 0;
  top: 0;
  height: 58%;
  background: linear-gradient(195deg, var(--ec-flap-from) 0%, var(--ec-flap-to) 100%);
  clip-path: polygon(0 0, 100% 0, 50% 90%);
  border-radius: 10px 10px 0 0;
  box-shadow: inset 0 -10px 16px -12px rgba(0, 0, 0, 0.35);
  filter: drop-shadow(0 8px 10px rgba(0, 0, 0, 0.28));
  transform-origin: top center;
  transition: transform 620ms var(--ease-in-out);
  z-index: 4;
}
.ec-envelope--open .ec-flap {
  transform: rotateX(-170deg);
}

.ec-seal {
  position: absolute;
  left: 50%;
  top: 43%;
  transform: translate(-50%, -50%);
  width: 48px;
  height: 48px;
  border-radius: 999px;
  display: grid;
  place-items: center;
  background: radial-gradient(circle at 32% 26%, var(--ec-seal-from), var(--ec-seal-to) 75%);
  color: var(--ec-seal-text);
  font-family: var(--ec-monogram-font);
  font-size: 0.95rem;
  font-weight: 600;
  letter-spacing: 0.01em;
  box-shadow:
    0 6px 14px -6px rgba(0, 0, 0, 0.5),
    inset 0 1px 1px rgba(255, 255, 255, 0.35);
  transition:
    opacity 350ms ease,
    transform 350ms var(--ease-out);
  z-index: 5;
}
.ec-envelope--open .ec-seal {
  opacity: 0;
  transform: translate(-50%, -50%) scale(0.4);
}

.ec-caption {
  position: relative;
  z-index: 10;
  margin-top: 2rem;
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.3em;
  color: var(--ec-ink);
  opacity: 0.85;
  transition:
    opacity 300ms ease,
    transform 300ms var(--ease-out);
}
.ec-caption--muted {
  margin-top: 0.85rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  font-size: 0.65rem;
  color: var(--ec-ink-muted);
  opacity: 0.7;
}
.ec-caption--out {
  opacity: 0;
  transform: translateY(6px);
}

@media (prefers-reduced-motion: reduce) {
  .ec-overlay,
  .ec-in,
  .ec-envelope,
  .ec-shadow,
  .ec-letter,
  .ec-flap,
  .ec-seal,
  .ec-caption {
    animation: none;
    transition-property: opacity;
    transition-duration: 250ms;
    transform: none !important;
  }
  .ec-overlay--out {
    filter: none;
  }
}
</style>
