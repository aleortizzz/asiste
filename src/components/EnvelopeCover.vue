<script setup>
import { computed } from 'vue'
import { Music } from '@lucide/vue'

// Sobre compartido por las tres plantillas: la forma/animación es siempre la
// misma, lo que cambia es la paleta (via CSS custom properties) que cada
// plantilla le pasa como props, para que combine con su propia identidad
// visual. El sello y la carta muestran `monogramShort`/`monogramFull` tal
// cual se los pasan — la lógica de "qué letras mostrar" (o el campo manual
// del editor) vive en useInvitationLogic(), no acá.
const props = defineProps({
  monogramShort: { type: String, default: '✦' },
  monogramFull: { type: String, default: '✦' },
  // Línea corta escrita en la carta (ej. "Mis XV", "Te invitamos"). Si
  // viene, reemplaza al monograma adentro de la carta y la carta sube más,
  // para que el texto quede entero fuera del sobre y se lea. Opcional.
  text: { type: String, default: '' },
  musicId: { type: String, default: '' },
  opening: { type: Boolean, default: false },
  closing: { type: Boolean, default: false },
  bg: { type: String, required: true },
  paperFrom: { type: String, required: true },
  paperTo: { type: String, required: true },
  flapFrom: { type: String, required: true },
  flapTo: { type: String, required: true },
  // Color de los pliegues dibujados (claro en sobres oscuros, oscuro en claros).
  seam: { type: String, default: 'rgba(0, 0, 0, 0.07)' },
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
  // Modo embebido: para la vista previa del sobre en AdminSalon — mismo
  // sobre, pero contenido en una caja en vez de overlay a pantalla completa,
  // sin leyenda ni click (es solo para mostrar la paleta elegida).
  inline: { type: Boolean, default: false },
})

defineEmits(['open', 'fade-end'])

const cssVars = computed(() => ({
  '--ec-bg': props.bg,
  '--ec-paper-from': props.paperFrom,
  '--ec-paper-to': props.paperTo,
  '--ec-flap-from': props.flapFrom,
  '--ec-flap-to': props.flapTo,
  '--ec-seam': props.seam,
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
    class="ec-overlay flex flex-col items-center justify-center px-6 text-center"
    :class="[
      inline ? 'ec-overlay--inline relative' : 'fixed inset-0 z-50',
      { 'ec-overlay--out': closing },
    ]"
    :style="cssVars"
    @transitionend.self="$emit('fade-end')"
  >
    <button
      type="button"
      class="ec-envelope"
      :class="{ 'ec-envelope--open': opening }"
      :disabled="opening || inline"
      :aria-label="inline ? undefined : 'Abrir invitación'"
      :tabindex="inline ? -1 : undefined"
      @click="$emit('open')"
    >
      <span class="ec-shadow"></span>
      <span class="ec-back"></span>
      <span class="ec-letter" :class="{ 'ec-letter--text': text }">
        <span
          v-if="text"
          class="ec-letter-text"
          :class="{ 'ec-letter-text--long': text.length > 24 }"
        >{{ text }}</span>
        <span v-else class="ec-monogram">{{ monogramFull }}</span>
        <span class="ec-letter-rule"></span>
      </span>
      <span class="ec-pocket"></span>
      <span class="ec-flap"></span>
      <span class="ec-seal">{{ monogramShort }}</span>
    </button>

    <template v-if="!inline">
      <p class="ec-caption ec-in" :class="{ 'ec-caption--out': opening }">
        Tocá el sobre para abrir tu invitación
      </p>
      <p v-if="musicId" class="ec-caption ec-caption--muted ec-in" :class="{ 'ec-caption--out': opening }">
        <Music :size="12" /> con música
      </p>
    </template>
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

.ec-overlay--inline {
  /* Arriba deja lugar para la carta cuando se abre el sobre en la vista
     previa (con texto sube ~80px por encima del sobre). */
  padding: 5.5rem 0.75rem 1.5rem;
  border-radius: 1rem;
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
.ec-letter--text {
  justify-content: flex-start;
  padding: 0.9rem 0.75rem 0;
}
/* Con texto sube más (-72% en vez de -48%): así el texto, que va arriba de
   todo en la carta, queda entero por encima del borde del sobre y no lo
   recorta la boca en V del bolsillo. */
.ec-envelope--open .ec-letter--text {
  transform: translateY(-72%);
}
/* Tipografía fija para cualquier plantilla (no la del monograma): una serif
   neutra que se lee bien en el segundo que la carta queda a la vista. */
.ec-letter-text {
  font-family: 'Playfair Display', Georgia, serif;
  font-weight: 500;
  color: var(--ec-letter-ink);
  font-size: clamp(1.2rem, 5vw, 1.55rem);
  line-height: 1.2;
  text-align: center;
  overflow-wrap: anywhere;
}
/* Textos largos (hasta 40 caracteres en el editor): un poco más chico para
   que sigan entrando en dos líneas dentro de la parte visible de la carta. */
.ec-letter-text--long {
  font-size: clamp(1.05rem, 4.5vw, 1.3rem);
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
  inset: 0;
  background: linear-gradient(160deg, var(--ec-paper-from) 0%, var(--ec-paper-to) 100%);
  /* Frente del sobre a altura completa, con la boca en V que sale de las
     esquinas de arriba. La punta de la V (50%) queda apenas por encima de
     la punta de .ec-flap (58% * 90% = 52.2%), y como las dos diagonales
     salen de las mismas esquinas, la solapa cerrada tapa toda la boca: no
     asoma nada de la carta. Antes el bolsillo cubría solo el 60% de abajo y
     quedaban dos cuñas descubiertas a los costados de la solapa, por donde
     se veía la carta — parecía un sobre abierto. */
  clip-path: polygon(0 0, 50% 50%, 100% 0, 100% 100%, 0 100%);
  border-radius: 10px;
  z-index: 3;
  /* Capa propia desde el principio: sin esto, cuando la carta empieza a
     subir Chrome la pasa a una capa de GPU y re-agrupa al bolsillo (que está
     encima) perdiendo el clip-path durante la animación — el frente tapaba
     toda la boca en V y la carta "parpadeaba" entre atrás y adelante. */
  will-change: transform;
}
/* Pliegues de las solapas laterales/inferior: diagonales de cada esquina
   de abajo hacia el centro (la mitad de arriba de la X coincide con la V
   y queda recortada por el clip-path). */
.ec-pocket::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(to top right, transparent calc(50% - 0.6px), var(--ec-seam) 50%, transparent calc(50% + 0.6px)),
    linear-gradient(to top left, transparent calc(50% - 0.6px), var(--ec-seam) 50%, transparent calc(50% + 0.6px));
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
  transition:
    transform 620ms var(--ease-in-out),
    z-index 0ms 380ms;
  z-index: 4;
}
.ec-envelope--open .ec-flap {
  /* rotateX no cambia el orden de pintado por sí solo (eso lo decide
     z-index), así que sin este cambio la solapa se sigue dibujando encima
     de la carta aunque ya esté girada hacia atrás. La bajamos recién a los
     380ms, cuando ya rotó lo suficiente como para no notarse el salto y la
     carta está por empezar a subir. */
  transform: rotateX(-170deg);
  z-index: 1;
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
