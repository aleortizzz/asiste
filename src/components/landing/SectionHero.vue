<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { Check, DoorOpen, Images, Trophy, Music2 } from '@lucide/vue'

// Landing › Portada: panel «de noche» con un collage de fotos de fiestas y,
// encima, avisos como los del panel que van llegando solos («confirmó»,
// «llegó», «nueva foto»…). Es la animación principal de la página: muestra
// lo que hace Asiste mientras la fiesta pasa. Los nombres son inventados.
// Las fotos son de Unsplash (public/fondos y public/landing).
const EVENTS = [
  { icon: Check, tone: 'bg-go text-obsidian', title: 'Familia Romero confirmó', sub: '4 van · recién' },
  { icon: DoorOpen, tone: 'bg-sulfur text-obsidian', title: 'Llegó Martina Gómez', sub: 'Mesa 3' },
  { icon: Images, tone: 'bg-plasma text-chalk', title: 'Nueva foto en el álbum', sub: 'Desde la mesa 7' },
  { icon: Music2, tone: 'bg-chalk text-accent', title: 'Pidieron una canción', sub: 'Para el DJ' },
  { icon: Trophy, tone: 'bg-sulfur text-obsidian', title: 'Lucía ganó la trivia', sub: '28 de 30 correctas' },
]
const VISIBLE = 3
const STEP_MS = 2600

// Cola de avisos en pantalla: entra uno nuevo arriba y el más viejo se va.
// `uid` distinto cada vez para que TransitionGroup lo trate como nuevo.
let next = 0
let uid = 0
const take = () => ({ ...EVENTS[next++ % EVENTS.length], uid: uid++ })
const shown = ref([])

const reduced = typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches
let timer = null
let visible = true
const root = ref(null)
let io = null

function tick() {
  shown.value = [take(), ...shown.value].slice(0, VISIBLE)
}
function start() {
  if (timer || reduced) return
  timer = setInterval(() => {
    if (visible && !document.hidden) tick()
  }, STEP_MS)
}

onMounted(() => {
  if (reduced) {
    shown.value = [take(), take(), take()]
    return
  }
  // El primero enseguida, después uno cada STEP_MS (solo mientras se ve).
  setTimeout(tick, 900)
  start()
  io = new IntersectionObserver(([e]) => (visible = e.isIntersecting))
  io.observe(root.value)
})
onUnmounted(() => {
  clearInterval(timer)
  io?.disconnect()
})
</script>

<template>
  <section ref="root" class="night mt-2 rounded-[2.5rem] px-6 pt-12 pb-10 sm:px-10 sm:pt-16 lg:px-14" aria-labelledby="h-hero">
    <div class="grid items-center gap-12 lg:grid-cols-[1fr_0.95fr]">
      <div class="hero-copy">
        <h1 id="h-hero" class="admin-display text-[clamp(3rem,8vw,5.6rem)] text-balance">
          Tu fiesta, organizada de punta a punta
        </h1>
        <p class="mt-5 max-w-xl text-lg text-chalk/75">
          Invitación, confirmaciones, mesas, recepción, fotos y trivia en un solo lugar. Sabés quién viene, dónde se sienta
          y quién ya llegó, sin planillas ni mensajes sueltos.
        </p>
        <div class="mt-8 flex flex-wrap gap-3">
          <a href="#planes" class="admin-btn-primary !bg-sulfur !text-obsidian">Ver planes</a>
          <router-link :to="{ name: 'crear' }" class="admin-btn-secondary !border-chalk hover:!bg-chalk/10">
            Creá tu invitación gratis
          </router-link>
        </div>
        <p class="mt-4 text-sm text-chalk/60">Probala sin crear cuenta. Pago único por evento.</p>
      </div>

      <!-- Collage: tres fotos y los avisos en vivo encima -->
      <div class="relative mx-auto aspect-[5/5.4] w-full max-w-[30rem]">
        <img
          src="/fondos/pc-4.jpg"
          alt="Guirnaldas de luces sobre una fiesta"
          class="photo photo-a absolute top-[6%] left-0 h-[62%] w-[44%] rounded-[1.75rem] object-cover shadow-2xl"
          loading="eager"
        />
        <img
          src="/landing/mesa.jpg"
          alt="Una mesa de fiesta armada con flores"
          class="photo photo-b absolute right-0 bottom-[4%] h-[46%] w-[50%] rounded-[1.75rem] object-cover shadow-2xl"
          loading="eager"
        />
        <img
          src="/fondos/cel-3.jpg"
          alt="Una quinceañera entrando a su fiesta de noche"
          class="photo photo-c absolute top-0 left-[24%] h-[80%] w-[50%] rounded-[2rem] object-cover shadow-2xl ring-4 ring-accent"
          loading="eager"
        />

        <!-- Avisos: como los del panel, llegan solos -->
        <TransitionGroup
          tag="ul"
          name="ping"
          aria-label="Así se ve tu fiesta en el panel"
          class="absolute bottom-[6%] left-[-3%] flex w-[min(17.5rem,72%)] flex-col gap-2"
        >
          <li
            v-for="e in shown"
            :key="e.uid"
            class="flex items-center gap-3 rounded-2xl bg-chalk/95 py-2.5 pr-4 pl-2.5 text-obsidian shadow-[0_14px_30px_-14px_rgb(7_6_7/0.6)] backdrop-blur"
          >
            <span class="grid h-9 w-9 shrink-0 place-items-center rounded-xl" :class="e.tone">
              <component :is="e.icon" :size="17" />
            </span>
            <span class="min-w-0">
              <span class="block truncate text-sm font-bold">{{ e.title }}</span>
              <span class="block truncate text-xs text-obsidian/55">{{ e.sub }}</span>
            </span>
          </li>
        </TransitionGroup>
      </div>
    </div>
  </section>
</template>

<style scoped>
/* Entrada de la portada: el texto sube y las fotos caen en su lugar, una
   después de la otra, con un leve giro. */
@media (prefers-reduced-motion: no-preference) {
  .hero-copy > * {
    animation: rise 0.9s cubic-bezier(0.16, 1, 0.3, 1) both;
  }
  .hero-copy > :nth-child(2) {
    animation-delay: 0.08s;
  }
  .hero-copy > :nth-child(3) {
    animation-delay: 0.16s;
  }
  .hero-copy > :nth-child(4) {
    animation-delay: 0.24s;
  }
  .photo {
    animation: drop 1.1s cubic-bezier(0.16, 1, 0.3, 1) both;
  }
  .photo-a {
    animation-delay: 0.15s;
  }
  .photo-b {
    animation-delay: 0.3s;
  }
  .photo-c {
    animation-delay: 0.45s;
  }
}
.photo-a {
  rotate: -6deg;
}
.photo-b {
  rotate: 5deg;
}
.photo-c {
  rotate: 1.5deg;
}
@keyframes rise {
  from {
    opacity: 0;
    transform: translateY(24px);
  }
}
@keyframes drop {
  from {
    opacity: 0;
    transform: translateY(40px) scale(0.92);
    filter: blur(8px);
  }
}

/* Cada aviso entra desde abajo, como una notificación; el último se va. */
.ping-enter-active {
  transition:
    opacity 0.55s cubic-bezier(0.16, 1, 0.3, 1),
    transform 0.55s cubic-bezier(0.16, 1, 0.3, 1),
    filter 0.55s ease;
}
.ping-leave-active {
  position: absolute;
  width: 100%;
  transition:
    opacity 0.3s ease,
    transform 0.3s ease;
}
.ping-move {
  transition: transform 0.55s cubic-bezier(0.16, 1, 0.3, 1);
}
.ping-enter-from {
  opacity: 0;
  transform: translateY(-14px) scale(0.95);
  filter: blur(4px);
}
.ping-leave-to {
  opacity: 0;
  transform: translateY(10px) scale(0.97);
}
</style>
