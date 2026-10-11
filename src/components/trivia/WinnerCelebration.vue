<script setup>
import { onMounted, onUnmounted } from 'vue'
import { Trophy } from '@lucide/vue'
import { formatDuration } from '../../lib/trivia'

// Festejo del ganador al cerrarse la trivia, a pantalla completa (como la
// pantalla de «¡Listo!» de Mercado Pago): el verde se expande desde el
// centro, salta la copa, cae papel picado y aparece el nombre. Lo usan el
// celular (GuestTrivia) y el proyector (TriviaProyector); los tamaños van en
// vmin para que sirva en los dos.
const props = defineProps({
  winner: { type: Object, required: true }, // { name, correct, duration_ms }
  total: { type: Number, required: true },
  isMe: { type: Boolean, default: false }, // en el celular del que ganó
  buttonText: { type: String, default: 'Ver ranking' },
})
const emit = defineEmits(['close'])

// Papel picado: posiciones, colores y tiempos al azar (fijos por montaje).
const COLORS = ['#ffffff', '#fde047', '#facc15', '#bbf7d0', '#fef9c3', '#86efac']
const confetti = Array.from({ length: 46 }, (_, i) => ({
  left: `${Math.random() * 100}%`,
  background: COLORS[i % COLORS.length],
  width: `${0.5 + Math.random() * 0.7}vmin`,
  height: `${1 + Math.random() * 1.2}vmin`,
  animationDelay: `${0.6 + Math.random() * 1.6}s`,
  animationDuration: `${2.6 + Math.random() * 2.2}s`,
  '--drift': `${(Math.random() - 0.5) * 30}vmin`,
  '--spin': `${(Math.random() < 0.5 ? -1 : 1) * (360 + Math.random() * 540)}deg`,
}))

// Que no se pueda scrollear la página de atrás mientras está abierto.
onMounted(() => (document.body.style.overflow = 'hidden'))
onUnmounted(() => (document.body.style.overflow = ''))

const firstName = (name) => name.trim().split(/\s+/)[0]
</script>

<template>
  <div class="celebration fixed inset-0 z-[90] overflow-hidden" role="dialog" aria-modal="true" aria-label="Ganador del juego">
    <div class="flood absolute inset-0"></div>

    <div class="pointer-events-none absolute inset-0" aria-hidden="true">
      <span v-for="(c, i) in confetti" :key="i" class="confetti" :style="c"></span>
    </div>

    <div class="relative mx-auto flex h-full max-w-full flex-col items-center justify-center px-6 text-center text-white">
      <div class="badge-wrap relative">
        <span class="ring absolute inset-0 rounded-full"></span>
        <span class="badge grid place-items-center rounded-full bg-white">
          <Trophy class="cup" :stroke-width="2.2" />
        </span>
      </div>

      <p class="kicker mt-[5vmin] font-bold tracking-[0.18em] uppercase">
        {{ isMe ? `¡Felicitaciones, ${firstName(winner.name)}!` : '¡Tenemos ganador!' }}
      </p>
      <p class="name mt-[1.5vmin] font-extrabold break-words">
        {{ isMe ? '¡Ganaste!' : winner.name }}
      </p>
      <p class="meta mt-[2vmin] font-semibold">
        {{ winner.correct }}/{{ total }} correctas · {{ formatDuration(winner.duration_ms) }}
      </p>

      <button type="button" @click="emit('close')" class="close mt-[6vmin] rounded-full bg-white font-bold">
        {{ buttonText }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.celebration {
  font-family: 'Inter', ui-sans-serif, sans-serif;
  font-variant-numeric: lining-nums tabular-nums;
}

/* El verde se expande desde el centro. */
.flood {
  background: radial-gradient(circle at 50% 42%, #00b85c, #00a650 55%, #008f45);
  animation: flood 0.75s cubic-bezier(0.65, 0, 0.35, 1) both;
}
@keyframes flood {
  from {
    clip-path: circle(0% at 50% 42%);
  }
  to {
    clip-path: circle(150% at 50% 42%);
  }
}

/* La copa salta y deja un anillo que se expande. */
.badge {
  width: clamp(6rem, 26vmin, 16rem);
  height: clamp(6rem, 26vmin, 16rem);
  color: #00a650;
  box-shadow: 0 1.5vmin 5vmin rgb(0 0 0 / 0.18);
  animation: pop 0.7s cubic-bezier(0.34, 1.56, 0.64, 1) 0.45s both;
}
.cup {
  width: 52%;
  height: 52%;
  animation: wiggle 0.9s ease-in-out 1.1s both;
}
.ring {
  border: 0.6vmin solid rgb(255 255 255 / 0.7);
  animation: ring 1.4s ease-out 0.75s both;
}
@keyframes pop {
  from {
    transform: scale(0);
  }
}
@keyframes wiggle {
  0%,
  100% {
    transform: rotate(0);
  }
  25% {
    transform: rotate(-12deg);
  }
  50% {
    transform: rotate(10deg);
  }
  75% {
    transform: rotate(-5deg);
  }
}
@keyframes ring {
  from {
    transform: scale(1);
    opacity: 1;
  }
  to {
    transform: scale(1.9);
    opacity: 0;
  }
}

/* Los textos suben de a uno. */
.kicker,
.name,
.meta,
.close {
  animation: rise 0.6s cubic-bezier(0.22, 1, 0.36, 1) both;
}
.kicker {
  font-size: clamp(0.9rem, 3vmin, 2.2rem);
  opacity: 0.9;
  animation-delay: 0.9s;
}
.name {
  font-size: clamp(2.2rem, 9vmin, 7.5rem);
  line-height: 1.05;
  max-width: 90vw;
  overflow-wrap: anywhere;
  text-shadow: 0 0.6vmin 2.5vmin rgb(0 0 0 / 0.15);
  animation-delay: 1.05s;
}
.meta {
  font-size: clamp(1rem, 3.2vmin, 2.4rem);
  opacity: 0.85;
  animation-delay: 1.2s;
}
.close {
  color: #00843f;
  font-size: clamp(1rem, 2.6vmin, 1.6rem);
  padding: clamp(0.8rem, 2vmin, 1.2rem) clamp(1.8rem, 5vmin, 3rem);
  box-shadow: 0 1vmin 3vmin rgb(0 0 0 / 0.15);
  animation-delay: 1.8s;
  transition: transform 150ms ease;
}
.close:active {
  transform: scale(0.96);
}
@keyframes rise {
  from {
    opacity: 0;
    transform: translateY(3vmin);
  }
}

/* Papel picado. */
.confetti {
  position: absolute;
  top: -5vmin;
  border-radius: 0.2vmin;
  opacity: 0;
  animation-name: fall;
  animation-timing-function: cubic-bezier(0.25, 0.6, 0.5, 1);
  animation-fill-mode: both;
}
@keyframes fall {
  0% {
    opacity: 1;
    transform: translate(0, 0) rotate(0);
  }
  85% {
    opacity: 1;
  }
  100% {
    opacity: 0;
    transform: translate(var(--drift), 110vh) rotate(var(--spin));
  }
}

@media (prefers-reduced-motion: reduce) {
  .flood,
  .badge,
  .cup,
  .ring,
  .kicker,
  .name,
  .meta,
  .close {
    animation: none;
  }
  .confetti {
    display: none;
  }
}
</style>
