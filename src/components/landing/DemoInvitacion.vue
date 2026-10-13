<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { MapPin, Clock, Shirt, Gift, Music2, Pause, Copy, Check, ChevronDown } from '@lucide/vue'

// Demo de la portada: una invitación de ejemplo dentro de un celular, con
// scroll, como la plantilla Clásica (Playfair + Dancing Script). Cuenta
// regresiva en vivo, música, alias para copiar y la confirmación funcionando.
// La foto es de public/fondos (Unsplash).
const props = defineProps({ paused: Boolean }) // copia invisible para medir el alto

// Fiesta «dentro de 32 días a las 21:30», así la cuenta regresiva siempre tiene sentido.
const party = (() => {
  const d = new Date()
  d.setDate(d.getDate() + 32)
  d.setHours(21, 30, 0, 0)
  return d
})()
const partyDate = party.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })

const now = ref(Date.now())
let timer = null
onMounted(() => {
  if (!props.paused) timer = setInterval(() => (now.value = Date.now()), 1000)
})
onUnmounted(() => clearInterval(timer))

const countdown = computed(() => {
  const s = Math.max(0, Math.floor((party - now.value) / 1000))
  return [
    { n: Math.floor(s / 86400), l: 'días' },
    { n: Math.floor((s % 86400) / 3600), l: 'horas' },
    { n: Math.floor((s % 3600) / 60), l: 'min' },
    { n: s % 60, l: 'seg' },
  ]
})

const playing = ref(false)
const copied = ref(false)
function copyAlias() {
  copied.value = true
  setTimeout(() => (copied.value = false), 1400)
}

// Confirmación (como «Asiste / No asiste» por persona en la invitación real).
const family = ref([
  { name: 'Lucas', going: null },
  { name: 'Ana', going: null },
  { name: 'Mía', going: null },
])
const sent = ref(false)
const answered = computed(() => family.value.every((p) => p.going !== null))
const goingCount = computed(() => family.value.filter((p) => p.going).length)

const scrolled = ref(false)
</script>

<template>
  <div class="flex justify-center">
    <!-- Celular -->
    <div class="relative w-full max-w-[17.5rem] rounded-[2.4rem] bg-obsidian p-2 shadow-xl">
      <div class="absolute top-3.5 left-1/2 z-20 h-4 w-20 -translate-x-1/2 rounded-full bg-obsidian"></div>
      <div
        class="invite relative h-[21rem] overflow-y-auto overscroll-contain rounded-[1.9rem] bg-[#fbf4f1] text-[#3d2530]"
        @scroll.passive="scrolled = true"
      >
        <!-- Portada -->
        <div class="relative grid h-[21rem] place-items-end overflow-hidden">
          <img src="/fondos/cel-3.jpg" alt="" class="absolute inset-0 h-full w-full object-cover" />
          <div class="absolute inset-0 bg-gradient-to-t from-[#3d2530]/85 via-[#3d2530]/20 to-transparent"></div>
          <div class="relative w-full p-5 pb-12 text-center text-white">
            <p class="script text-3xl">Mis XV</p>
            <p class="serif text-4xl leading-none">Valentina</p>
            <p class="mt-2 text-xs tracking-widest uppercase first-letter:uppercase">{{ partyDate }}</p>
          </div>
          <Transition name="fade">
            <p v-if="!scrolled" class="hint absolute bottom-3 left-1/2 flex -translate-x-1/2 items-center gap-1 rounded-full bg-white/90 px-3 py-1 text-[0.7rem] font-bold text-[#3d2530]">
              Deslizá <ChevronDown :size="13" />
            </p>
          </Transition>
        </div>

        <div class="space-y-5 px-5 py-6 text-center">
          <!-- Cuenta regresiva -->
          <div>
            <p class="script text-2xl text-[#9b3d5a]">Faltan</p>
            <div class="mt-2 grid grid-cols-4 gap-1.5">
              <div v-for="c in countdown" :key="c.l" class="rounded-xl bg-white py-2">
                <p class="serif text-xl leading-none tabular-nums">{{ String(c.n).padStart(2, '0') }}</p>
                <p class="mt-1 text-[0.6rem] tracking-wide uppercase opacity-60">{{ c.l }}</p>
              </div>
            </div>
          </div>

          <p class="serif text-[0.95rem] leading-snug italic">“Hay momentos que se esperan toda la vida. Quiero compartir este con vos.”</p>

          <!-- Música -->
          <button type="button" @click="playing = !playing" class="mx-auto flex items-center gap-2 rounded-full bg-[#9b3d5a] px-4 py-2 text-xs font-bold text-white">
            <Pause v-if="playing" :size="14" />
            <Music2 v-else :size="14" />
            {{ playing ? 'Sonando: nuestra canción' : 'Escuchá nuestra canción' }}
            <span v-if="playing" class="eq flex h-3 items-end gap-0.5"><i></i><i></i><i></i></span>
          </button>

          <!-- Fiesta -->
          <div class="space-y-1.5 rounded-2xl bg-white p-4">
            <p class="serif text-lg">La fiesta</p>
            <p class="flex items-center justify-center gap-1.5 text-sm"><Clock :size="14" /> 21:30 a 5:00</p>
            <p class="flex items-center justify-center gap-1.5 text-sm"><MapPin :size="14" /> Salón Los Aromos</p>
            <span class="mt-1 inline-block rounded-full border border-[#9b3d5a] px-3 py-1 text-xs font-bold text-[#9b3d5a]">Cómo llegar</span>
          </div>

          <div class="grid grid-cols-2 gap-2">
            <div class="rounded-2xl bg-white p-3">
              <Shirt :size="16" class="mx-auto text-[#9b3d5a]" />
              <p class="mt-1 text-xs font-bold">Dress code</p>
              <p class="text-xs opacity-70">Elegante</p>
            </div>
            <div class="rounded-2xl bg-white p-3">
              <Gift :size="16" class="mx-auto text-[#9b3d5a]" />
              <p class="mt-1 text-xs font-bold">Regalos</p>
              <button type="button" @click="copyAlias" class="text-xs font-bold text-[#9b3d5a] underline underline-offset-2">
                <template v-if="copied"><Check :size="11" class="inline" /> Copiado</template>
                <template v-else><Copy :size="11" class="inline" /> vale.xv</template>
              </button>
            </div>
          </div>

          <!-- Confirmación -->
          <div class="rounded-2xl bg-white p-4">
            <p class="serif text-lg">¿Venís?</p>
            <template v-if="!sent">
              <p class="mb-3 text-xs opacity-70">Familia Romero · confirmá antes del 1/11</p>
              <div class="space-y-1.5">
                <div v-for="p in family" :key="p.name" class="flex items-center justify-between gap-2">
                  <span class="text-sm font-bold">{{ p.name }}</span>
                  <span class="flex rounded-full bg-[#fbf4f1] p-0.5 text-[0.7rem] font-bold">
                    <button type="button" @click="p.going = true" class="rounded-full px-2.5 py-1 transition-colors" :class="p.going === true ? 'bg-[#3fcb7f] text-[#0b2a18]' : 'opacity-60'">Asiste</button>
                    <button type="button" @click="p.going = false" class="rounded-full px-2.5 py-1 transition-colors" :class="p.going === false ? 'bg-[#f2685c] text-white' : 'opacity-60'">No</button>
                  </span>
                </div>
              </div>
              <button
                type="button"
                @click="sent = true"
                :disabled="!answered"
                class="mt-3 w-full rounded-full bg-[#9b3d5a] py-2 text-sm font-bold text-white transition-opacity disabled:opacity-40"
              >
                Confirmar asistencia
              </button>
            </template>
            <div v-else class="py-2">
              <p class="script text-2xl text-[#9b3d5a]">¡Gracias!</p>
              <p class="text-xs">
                {{ goingCount ? `Te esperamos: ${goingCount === 1 ? '1 persona' : `${goingCount} personas`}.` : 'Lamentamos que no puedan venir.' }}
              </p>
              <button type="button" @click="(sent = false), family.forEach((p) => (p.going = null))" class="mt-2 text-xs underline opacity-60">Cambiar respuesta</button>
            </div>
          </div>

          <p class="script pb-2 text-2xl text-[#9b3d5a]">¡Te espero!</p>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.serif {
  font-family: 'Playfair Display', Georgia, serif;
}
.script {
  font-family: 'Dancing Script', cursive;
}
.invite {
  scrollbar-width: none;
}
.invite::-webkit-scrollbar {
  display: none;
}
.eq i {
  display: block;
  width: 2px;
  background: currentColor;
  animation: eq 0.8s ease-in-out infinite alternate;
}
.eq i:nth-child(2) {
  animation-delay: 0.2s;
}
.eq i:nth-child(3) {
  animation-delay: 0.4s;
}
@keyframes eq {
  from {
    height: 3px;
  }
  to {
    height: 12px;
  }
}
@media (prefers-reduced-motion: no-preference) {
  .hint {
    animation: nudge 1.4s ease-in-out infinite;
  }
}
@keyframes nudge {
  50% {
    transform: translateY(4px);
  }
}
.fade-leave-active {
  transition: opacity 0.3s ease;
}
.fade-leave-to {
  opacity: 0;
}
</style>
