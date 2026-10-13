<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import {
  DoorOpen,
  Smartphone,
  MailQuestion,
  History,
  Images,
  Trophy,
  Table2,
  Check,
  Hand,
  Mail,
  ClipboardList,
  PartyPopper,
  MessageCircle,
  PenSquare,
  Sparkles,
  Users,
  ArrowLeft,
  RotateCcw,
} from '@lucide/vue'
import DemoInvitacion from '../components/landing/DemoInvitacion.vue'
import DemoRecepcion from '../components/landing/DemoRecepcion.vue'
import DemoRespuestas from '../components/landing/DemoRespuestas.vue'
import DemoMovimientos from '../components/landing/DemoMovimientos.vue'
import DemoAlbum from '../components/landing/DemoAlbum.vue'
import DemoTrivia from '../components/landing/DemoTrivia.vue'
import DemoMesas from '../components/landing/DemoMesas.vue'

// Página de inicio pública (/): la ve quien entra sin sesión; con sesión, el
// router lo manda al panel. Planes y precios acordados el 2026-10-13 (ver
// PROGRESO.md). Los nombres de las tarjetas de ejemplo son inventados.

// --- Carrusel de funciones (portada) -----------------------------------------------------
// Cada tarjeta es una demo que se puede tocar (components/landing/). Pasa sola
// a la siguiente después de `ms` (lo que tarda en verse lo que pasa en ella),
// hasta que la persona toca algo: desde ahí, solo cambia si elige otra.
const features = [
  { id: 'invitacion', label: 'Invitación', icon: Smartphone, demo: DemoInvitacion, ms: 10000, caption: 'Una invitación real, la de los XV de Antonella: fotos, cuenta regresiva, cómo llegar y la confirmación, todo en un link. Deslizá para verla.' },
  { id: 'respuestas', label: 'Quién falta', icon: MailQuestion, demo: DemoRespuestas, ms: 9000, caption: 'Las respuestas llegan solas: sabés quién confirmó, quién no va y quién todavía ni abrió el link.' },
  { id: 'mesas', label: 'Mesas', icon: Table2, demo: DemoMesas, ms: 8000, caption: 'Armás las mesas arrastrando a cada invitado, con los lugares contados.' },
  { id: 'album', label: 'Álbum', icon: Images, demo: DemoAlbum, ms: 8000, caption: 'Los invitados escanean el QR de la mesa y suben sus fotos a un mismo álbum.' },
  { id: 'trivia', label: 'Trivia', icon: Trophy, demo: DemoTrivia, ms: 12000, caption: 'Trivia en vivo el día de la fiesta: los invitados juegan desde el celular, el ranking sale en la pantalla del salón y al final se festeja al ganador.' },
  { id: 'recepcion', label: 'Recepción', icon: DoorOpen, demo: DemoRecepcion, ms: 6000, caption: 'El personal busca a cada invitado, ve su mesa y marca que llegó. Vos lo ves en vivo.' },
  { id: 'movimientos', label: 'Movimientos', icon: History, demo: DemoMovimientos, ms: 8000, caption: 'Cada respuesta, cambio o canción pedida, en el momento.' },
]
const active = ref(0)
const autoplay = ref(true)
const paused = ref(false)
let timer = null

function schedule() {
  clearTimeout(timer)
  if (!autoplay.value) return
  timer = setTimeout(() => {
    if (paused.value || document.visibilityState !== 'visible') return schedule()
    active.value = (active.value + 1) % features.length
    schedule()
  }, features[active.value].ms)
}

function select(i) {
  active.value = i
  stopAutoplay()
}
function stopAutoplay() {
  autoplay.value = false
  clearTimeout(timer)
}

onMounted(() => {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) autoplay.value = false
  schedule()
})
onUnmounted(() => clearTimeout(timer))

// --- Planes ------------------------------------------------------------------------------
const audience = ref('fiesta') // 'fiesta' | 'salon'

// Tres planes, pago único por evento (decidido el 2026-10-13).
const rows = [
  { group: 'La invitación' },
  { label: 'Plantillas, sobre animado, música, galería y cuenta regresiva', i: true, p: true, x: true },
  { label: 'Mapa, horarios, dress code y datos para regalar', i: true, p: true, x: true },
  { label: 'Vista previa linda al mandarla por WhatsApp', i: true, p: true, x: true },
  { group: 'Confirmaciones' },
  { label: 'Cómo confirman los invitados', i: 'Por WhatsApp', p: 'Link por familia', x: 'Link por familia' },
  { label: 'Panel con quién viene, quién no y quién falta', i: false, p: true, x: true },
  { label: 'Fecha límite y movimientos', i: false, p: true, x: true },
  { group: 'Organización' },
  { label: 'Mesas', i: false, p: true, x: true },
  { label: 'Lista de la entrada en PDF y Excel', i: false, p: true, x: true },
  { group: 'Durante la fiesta' },
  { label: 'Pedido de canciones para el DJ', i: false, p: false, x: true },
  { label: 'Álbum de fotos de los invitados con QR', i: false, p: false, x: true },
  { label: 'Trivia en vivo el día de la fiesta, con ranking en la pantalla', i: false, p: false, x: true },
  { label: 'Recepción en vivo con el personal', i: false, p: false, x: true },
  { group: 'Atención' },
  { label: 'Soporte por WhatsApp', i: true, p: true, x: 'Prioritario' },
  { label: 'Reunión de 1 hora para armar todo juntos', i: false, p: true, x: true },
  { label: 'Cargamos los invitados y armamos la invitación por vos', i: false, p: false, x: true },
]

// --- ¿Cuál me conviene? (de a una pregunta) ------------------------------------------------
const PLANS = {
  invitacion: {
    name: 'Invitación',
    price: '$35.000',
    includes: ['Invitación completa con música, fotos, mapa y regalos', 'Un solo link para todos', 'Confirmaciones por WhatsApp', 'Soporte por WhatsApp'],
  },
  plus: {
    name: 'Plus',
    price: '$70.000',
    includes: ['Un link por familia y panel de confirmaciones', 'Mesas y lista de la entrada', 'Reunión de 1 hora para armar todo juntos', 'Soporte por WhatsApp'],
  },
  premium: {
    name: 'Premium',
    price: '$120.000',
    includes: ['Todo lo del Plus', 'Canciones para el DJ y álbum de fotos', 'Trivia en vivo el día de la fiesta', 'Recepción en la puerta con tu personal', 'Cargamos los invitados y armamos la invitación', 'Soporte prioritario'],
  },
}

// La segunda pregunta depende de la primera.
const QUESTIONS = {
  goal: {
    text: '¿Qué querés resolver?',
    options: [
      { value: 'invitacion', label: 'Solo mandar una invitación linda', hint: 'Y que me confirmen por WhatsApp', icon: Mail },
      { value: 'organizar', label: 'Saber quién viene y armar las mesas', hint: 'Confirmaciones ordenadas, mesas y lista de la puerta', icon: ClipboardList },
      { value: 'todo', label: 'Todo, también la noche de la fiesta', hint: 'Fotos, canciones, recepción y trivia en vivo en la fiesta', icon: PartyPopper },
    ],
  },
  invitacion: {
    text: '¿Cómo querés recibir las confirmaciones?',
    options: [
      { value: 'whatsapp', label: 'Por WhatsApp está bien', hint: 'Cada uno me escribe que viene', icon: MessageCircle },
      { value: 'panel', label: 'Todas juntas en una lista', hint: 'Sin perseguir a nadie por chat', icon: ClipboardList },
    ],
  },
  organizar: {
    text: '¿Querés algo para la noche de la fiesta?',
    options: [
      { value: 'no', label: 'No, con organizar me alcanza', hint: 'Invitación, confirmaciones y mesas', icon: Check },
      { value: 'si', label: 'Sí, que también se viva', hint: 'Fotos, recepción o trivia en vivo en la fiesta', icon: PartyPopper },
    ],
  },
  todo: {
    text: '¿Quién arma la invitación?',
    options: [
      { value: 'yo', label: 'La armo yo', hint: 'Con una reunión para arrancar', icon: PenSquare },
      { value: 'ustedes', label: 'Que la armen ustedes', hint: 'Les paso la lista y las fotos', icon: Sparkles },
    ],
  },
}

const answers = ref({})
const stepKeys = computed(() => ['goal', answers.value.goal ?? 'invitacion'])
const step = ref(0)
const currentQuestion = computed(() => QUESTIONS[stepKeys.value[step.value]])
const finished = computed(() => step.value >= stepKeys.value.length)

function answer(value) {
  answers.value = { ...answers.value, [stepKeys.value[step.value]]: value }
  step.value++
}
function back() {
  if (step.value > 0) step.value--
}
function restartFinder() {
  answers.value = {}
  step.value = 0
}

const recommendation = computed(() => {
  const a = answers.value
  let key, why
  if (a.goal === 'invitacion' && a.invitacion === 'whatsapp') {
    key = 'invitacion'
    why = 'Querés una invitación linda y que te confirmen por WhatsApp: no necesitás más.'
  } else if (a.goal === 'invitacion') {
    key = 'plus'
    why = 'Para tener todas las respuestas juntas necesitás el panel de confirmaciones, y de paso ya tenés las mesas.'
  } else if (a.goal === 'organizar' && a.organizar === 'no') {
    key = 'plus'
    why = 'Sabés quién viene, armás las mesas y llevás la lista a la puerta. Y arrancamos juntos en una reunión.'
  } else if (a.goal === 'organizar') {
    key = 'premium'
    why = 'Además de organizar, querés que la noche de la fiesta también se viva: eso está en el Premium.'
  } else {
    key = 'premium'
    why =
      a.todo === 'ustedes'
        ? 'Nos pasás la lista y las fotos, y nosotros armamos todo. Incluye todo lo de la fiesta.'
        : 'Tenés todo: organización y la noche de la fiesta, con soporte prioritario.'
  }
  return { ...PLANS[key], why }
})

// --- Calculadora para salones ------------------------------------------------------------
const PER_PARTY = 70000
const SUBSCRIPTION = 250000
const parties = ref(6)
const resale = ref(120000)
const money = (n) => `$${Math.round(n).toLocaleString('es-AR')}`

const byParty = computed(() => parties.value * PER_PARTY)
const best = computed(() => Math.min(byParty.value, SUBSCRIPTION))
const left = computed(() => parties.value * resale.value - best.value)
const verdict = computed(() => {
  const s = parties.value === 1 ? 'fiesta' : 'fiestas'
  if (SUBSCRIPTION < byParty.value) return `Con ${parties.value} ${s}, el abono te ahorra ${money(byParty.value - SUBSCRIPTION)} por mes.`
  if (SUBSCRIPTION === byParty.value) return `Con ${parties.value} ${s}, da lo mismo.`
  return `Con ${parties.value} ${s}, te conviene pagar por fiesta: ${money(byParty.value)} contra ${money(SUBSCRIPTION)} del abono.`
})
</script>

<template>
  <div class="font-ui min-h-dvh bg-pumice text-obsidian">
    <div class="mx-auto max-w-6xl px-4">
      <!-- Barra -->
      <header class="flex items-center justify-between gap-4 py-5">
        <span class="admin-display text-4xl">Asiste</span>
        <nav class="flex items-center gap-2 sm:gap-3">
          <a href="#planes" class="hidden rounded-full px-3 py-2 font-bold sm:inline">Planes</a>
          <router-link :to="{ name: 'admin-login' }" class="rounded-full px-3 py-2 font-bold">Ingresar</router-link>
          <router-link :to="{ name: 'admin-signup' }" class="admin-btn-primary !px-4 !py-2 text-sm">Crear mi invitación</router-link>
        </nav>
      </header>

      <!-- Portada -->
      <div class="grid items-center gap-10 pt-6 pb-16 lg:grid-cols-[1.05fr_0.95fr]">
        <div>
          <h1 class="admin-display text-[clamp(2.8rem,8vw,5.4rem)] text-balance">Tu fiesta, organizada de punta a punta</h1>
          <p class="mt-5 max-w-xl text-lg text-obsidian/65">
            Invitación, confirmaciones, mesas y recepción en un solo lugar. Sabés quién viene, dónde se sienta y quién ya
            llegó, sin planillas ni mensajes sueltos.
          </p>
          <div class="mt-7 flex flex-wrap gap-3">
            <router-link :to="{ name: 'admin-signup' }" class="admin-btn-primary">Crear mi invitación</router-link>
            <a href="#conviene" class="admin-btn-secondary">¿Cuál me conviene?</a>
          </div>
          <p class="mt-4 text-sm text-obsidian/55">Armala gratis y pagás recién cuando la querés mandar a todos. Pago único por evento.</p>
        </div>

        <!-- Carrusel de funciones -->
        <div @mouseenter="paused = true" @mouseleave="paused = false" @focusin="paused = true" @focusout="paused = false">
          <div class="flex flex-wrap gap-1.5" role="tablist" aria-label="Funciones de Asiste">
            <button
              v-for="(f, i) in features"
              :key="f.id"
              type="button"
              role="tab"
              :id="`feat-tab-${f.id}`"
              :aria-selected="active === i"
              :aria-controls="`feat-panel`"
              @click="select(i)"
              class="flex items-center gap-1.5 rounded-full px-3 py-1.5 text-sm font-bold transition-colors"
              :class="active === i ? 'bg-obsidian text-chalk' : 'bg-limestone hover:bg-chalk'"
            >
              <component :is="f.icon" :size="15" />
              {{ f.label }}
            </button>
          </div>

          <div id="feat-panel" role="tabpanel" :aria-labelledby="`feat-tab-${features[active].id}`" class="mt-3 rounded-[2rem] bg-limestone p-4 sm:p-5">
            <!-- Todas las demos apiladas en la misma celda: las copias invisibles (quietas) le dan
                 al recuadro el alto de la más grande, así no salta al cambiar de pestaña. -->
            <div class="grid" @pointerdown="stopAutoplay" @keydown="stopAutoplay">
              <div v-for="f in features" :key="`medida-${f.id}`" class="invisible col-start-1 row-start-1" aria-hidden="true" inert>
                <component :is="f.demo" paused />
              </div>
              <component :is="features[active].demo" :key="features[active].id" class="feat-in col-start-1 row-start-1 self-start" />
            </div>
            <div class="mt-3 grid border-t-[1.5px] border-dotted border-obsidian/20 pt-3 text-sm text-obsidian/65">
              <p v-for="f in features" :key="`texto-${f.id}`" class="invisible col-start-1 row-start-1 pr-20" aria-hidden="true">{{ f.caption }}</p>
              <p class="col-start-1 row-start-1 flex items-start gap-2">
                <span class="min-w-0 flex-1">{{ features[active].caption }}</span>
                <span class="flex shrink-0 items-center gap-1 text-xs font-bold text-accent"><Hand :size="13" /> Probalo</span>
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Planes -->
      <section id="planes" class="scroll-mt-4 space-y-6 py-12" aria-labelledby="h-planes">
        <div class="max-w-2xl">
          <h2 id="h-planes" class="admin-display text-5xl sm:text-6xl">Planes</h2>
          <p class="mt-3 text-lg text-obsidian/65">
            Armá tu invitación gratis y probala con hasta 5 familias. Para mandarla a todos, elegís un plan: un solo pago por
            evento, sin abonos ni costo por invitado.
          </p>
        </div>

        <div class="inline-flex gap-1 rounded-full bg-limestone p-1" role="tablist" aria-label="Tipo de cliente">
          <button
            v-for="a in [{ id: 'fiesta', label: 'Para tu fiesta' }, { id: 'salon', label: 'Para salones' }]"
            :key="a.id"
            type="button"
            role="tab"
            :aria-selected="audience === a.id"
            @click="audience = a.id"
            class="rounded-full px-5 py-2 font-bold transition-colors"
            :class="audience === a.id ? 'bg-obsidian text-chalk' : ''"
          >
            {{ a.label }}
          </button>
        </div>

        <!-- Particulares -->
        <div v-if="audience === 'fiesta'" class="space-y-6">
          <div class="grid gap-4 pt-3 md:grid-cols-3">
            <article class="flex flex-col gap-4 rounded-[2rem] bg-limestone p-6">
              <h3 class="text-lg font-bold">Invitación</h3>
              <p class="min-h-12 text-obsidian/60">Para mandar una invitación linda.</p>
              <p class="admin-display text-5xl">$35.000 <span class="font-ui text-sm tracking-normal text-obsidian/55 normal-case">por evento</span></p>
              <ul class="flex-1 space-y-2 text-[0.95rem]">
                <li v-for="i in PLANS.invitacion.includes" :key="i" class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-go" />{{ i }}</li>
              </ul>
              <router-link :to="{ name: 'admin-signup' }" class="admin-btn-secondary w-full">Elegir Invitación</router-link>
            </article>
            <article class="relative flex flex-col gap-4 rounded-[2rem] bg-chalk p-6 ring-[2.5px] ring-accent">
              <span class="absolute -top-3 left-6 rounded-full bg-sulfur px-2.5 py-1 text-xs font-bold tracking-wide uppercase">El más elegido</span>
              <h3 class="text-lg font-bold">Plus</h3>
              <p class="min-h-12 text-obsidian/60">Para saber quién viene y organizar la fiesta.</p>
              <p class="admin-display text-5xl">$70.000 <span class="font-ui text-sm tracking-normal text-obsidian/55 normal-case">por evento</span></p>
              <ul class="flex-1 space-y-2 text-[0.95rem]">
                <li class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-go" />Todo lo de Invitación</li>
                <li v-for="i in PLANS.plus.includes" :key="i" class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-go" />{{ i }}</li>
              </ul>
              <router-link :to="{ name: 'admin-signup' }" class="admin-btn-primary w-full">Elegir Plus</router-link>
            </article>
            <article class="flex flex-col gap-4 rounded-[2rem] bg-limestone p-6">
              <h3 class="text-lg font-bold">Premium</h3>
              <p class="min-h-12 text-obsidian/60">Para que la fiesta también se viva con Asiste.</p>
              <p class="admin-display text-5xl">$120.000 <span class="font-ui text-sm tracking-normal text-obsidian/55 normal-case">por evento</span></p>
              <ul class="flex-1 space-y-2 text-[0.95rem]">
                <li v-for="i in PLANS.premium.includes" :key="i" class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-go" />{{ i }}</li>
              </ul>
              <router-link :to="{ name: 'admin-signup' }" class="admin-btn-secondary w-full">Elegir Premium</router-link>
            </article>
          </div>

          <div class="overflow-x-auto rounded-[1.5rem] bg-chalk">
            <table class="w-full min-w-[36rem] border-collapse text-[0.95rem]">
              <thead>
                <tr class="text-xs tracking-wide text-obsidian/55 uppercase">
                  <th class="p-3 pl-4 text-left">Qué incluye</th>
                  <th class="p-3">Invitación</th>
                  <th class="p-3 text-accent">Plus</th>
                  <th class="p-3">Premium</th>
                </tr>
              </thead>
              <tbody>
                <template v-for="r in rows" :key="r.group || r.label">
                  <tr v-if="r.group">
                    <td colspan="4" class="bg-limestone px-4 py-2 text-xs font-bold tracking-widest text-obsidian/55 uppercase">{{ r.group }}</td>
                  </tr>
                  <tr v-else class="border-b border-pumice">
                    <td class="p-3 pl-4">{{ r.label }}</td>
                    <td v-for="(v, k) in { i: r.i, p: r.p, x: r.x }" :key="k" class="p-3 text-center" :class="k === 'p' ? 'bg-accent-soft' : ''">
                      <Check v-if="v === true" :size="18" class="mx-auto text-go" aria-label="Incluido" />
                      <span v-else-if="v === false" class="text-obsidian/30" aria-label="No incluido">—</span>
                      <strong v-else class="text-sm">{{ v }}</strong>
                    </td>
                  </tr>
                </template>
              </tbody>
              <tfoot>
                <tr class="font-bold tabular-nums">
                  <td class="p-3 pl-4">Precio por evento</td>
                  <td class="p-3 text-center">$35.000</td>
                  <td class="bg-accent-soft p-3 text-center">$70.000</td>
                  <td class="p-3 text-center">$120.000</td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>

        <!-- Salones -->
        <div v-else class="space-y-6">
          <div class="grid gap-4 pt-3 md:grid-cols-2">
            <article class="flex flex-col gap-4 rounded-[2rem] bg-limestone p-6">
              <h3 class="text-lg font-bold">Por fiesta</h3>
              <p class="min-h-12 text-obsidian/60">Pagás solo las fiestas que usás.</p>
              <p class="admin-display text-5xl">$70.000 <span class="font-ui text-sm tracking-normal text-obsidian/55 normal-case">por fiesta</span></p>
              <ul class="flex-1 space-y-2 text-[0.95rem]">
                <li v-for="i in ['Todo lo del Premium en cada fiesta', 'Tu logo en cada invitación', 'Usuarios para tu personal de recepción', 'La primera fiesta, gratis']" :key="i" class="flex gap-2">
                  <Check :size="17" class="mt-0.5 shrink-0 text-go" />{{ i }}
                </li>
              </ul>
              <router-link :to="{ name: 'admin-signup' }" class="admin-btn-secondary w-full">Quiero probarlo</router-link>
            </article>
            <article class="relative flex flex-col gap-4 rounded-[2rem] bg-chalk p-6 ring-[2.5px] ring-accent">
              <span class="absolute -top-3 left-6 rounded-full bg-sulfur px-2.5 py-1 text-xs font-bold tracking-wide uppercase">Desde 4 fiestas por mes</span>
              <h3 class="text-lg font-bold">Abono</h3>
              <p class="min-h-12 text-obsidian/60">Para salones con movimiento todos los fines de semana.</p>
              <p class="admin-display text-5xl">$250.000 <span class="font-ui text-sm tracking-normal text-obsidian/55 normal-case">por mes</span></p>
              <ul class="flex-1 space-y-2 text-[0.95rem]">
                <li
                  v-for="i in ['Fiestas ilimitadas', 'Sin permanencia: mes a mes', 'En un mes flojo, volvés a pagar por fiesta', 'Lo que pagaste por fiesta el último mes se descuenta del primer abono']"
                  :key="i"
                  class="flex gap-2"
                >
                  <Check :size="17" class="mt-0.5 shrink-0 text-go" />{{ i }}
                </li>
              </ul>
              <router-link :to="{ name: 'admin-signup' }" class="admin-btn-primary w-full">Hablemos</router-link>
            </article>
          </div>

          <div class="space-y-5 rounded-[2rem] bg-limestone p-5 sm:p-7">
            <div>
              <label for="calc-parties" class="flex flex-wrap justify-between gap-2 font-bold">
                ¿Cuántas fiestas hace tu salón por mes? <output for="calc-parties" class="tabular-nums">{{ parties }}</output>
              </label>
              <input id="calc-parties" v-model.number="parties" type="range" min="1" max="12" class="mt-2 w-full accent-accent" />
            </div>
            <div>
              <label for="calc-resale" class="flex flex-wrap justify-between gap-2 font-bold">
                ¿A cuánto se lo cobrás a tus clientes?
                <output for="calc-resale" class="tabular-nums">{{ resale ? money(resale) : 'Lo regalo' }}</output>
              </label>
              <input id="calc-resale" v-model.number="resale" type="range" min="0" max="200000" step="10000" class="mt-2 w-full accent-accent" />
            </div>
            <div class="grid gap-3 sm:grid-cols-3">
              <div class="rounded-[1.25rem] bg-chalk p-4" :class="byParty <= SUBSCRIPTION ? 'ring-2 ring-go' : ''">
                <p class="text-sm font-bold text-obsidian/55">Pagando por fiesta</p>
                <p class="text-2xl font-bold tabular-nums">{{ money(byParty) }}</p>
              </div>
              <div class="rounded-[1.25rem] bg-chalk p-4" :class="SUBSCRIPTION < byParty ? 'ring-2 ring-go' : ''">
                <p class="text-sm font-bold text-obsidian/55">Con abono</p>
                <p class="text-2xl font-bold tabular-nums">{{ money(SUBSCRIPTION) }}</p>
              </div>
              <div class="rounded-[1.25rem] bg-chalk p-4">
                <p class="text-sm font-bold text-obsidian/55">Te queda por mes</p>
                <p class="text-2xl font-bold tabular-nums">{{ left < 0 ? '−' : '' }}{{ money(Math.abs(left)) }}</p>
              </div>
            </div>
            <p class="font-bold" aria-live="polite">{{ verdict }}</p>
          </div>
        </div>
      </section>

      <!-- ¿Cuál me conviene? -->
      <section id="conviene" class="scroll-mt-4 space-y-6 py-12" aria-labelledby="h-conviene">
        <div class="max-w-2xl">
          <h2 id="h-conviene" class="admin-display text-5xl sm:text-6xl">¿Cuál me conviene?</h2>
          <p class="mt-3 text-lg text-obsidian/65">Dos preguntas y te decimos qué plan elegir.</p>
        </div>

        <div class="mx-auto max-w-3xl rounded-[2rem] bg-limestone p-5 sm:p-8">
          <!-- Pregunta -->
          <div v-if="!finished" :key="step" class="finder-in space-y-5">
            <div class="flex items-center justify-between gap-3">
              <p class="text-sm font-bold text-obsidian/55">Pregunta {{ step + 1 }} de {{ stepKeys.length }}</p>
              <div class="flex gap-1.5" aria-hidden="true">
                <span v-for="n in stepKeys.length" :key="n" class="h-1.5 w-8 rounded-full" :class="n <= step + 1 ? 'bg-accent' : 'bg-pumice'"></span>
              </div>
            </div>
            <h3 class="admin-display text-4xl sm:text-5xl">{{ currentQuestion.text }}</h3>
            <div class="grid gap-3" :class="currentQuestion.options.length === 3 ? 'sm:grid-cols-3' : 'sm:grid-cols-2'">
              <button
                v-for="o in currentQuestion.options"
                :key="o.value"
                type="button"
                @click="answer(o.value)"
                class="group flex flex-col items-start gap-3 rounded-[1.5rem] border-[1.5px] border-transparent bg-chalk p-5 text-left transition-colors hover:border-accent focus-visible:border-accent"
              >
                <span class="grid h-11 w-11 place-items-center rounded-full bg-accent-soft text-accent transition-colors group-hover:bg-accent group-hover:text-chalk">
                  <component :is="o.icon" :size="20" />
                </span>
                <span>
                  <span class="block text-lg leading-tight font-bold">{{ o.label }}</span>
                  <span class="mt-1 block text-sm text-obsidian/55">{{ o.hint }}</span>
                </span>
              </button>
            </div>
            <button v-if="step > 0" type="button" @click="back" class="flex items-center gap-1 text-sm font-bold text-obsidian/55 hover:text-obsidian">
              <ArrowLeft :size="15" /> Volver
            </button>
          </div>

          <!-- Resultado -->
          <div v-else class="finder-in grid gap-6 sm:grid-cols-[1fr_1.1fr] sm:items-center">
            <div class="space-y-2">
              <p class="text-xs font-bold tracking-widest text-obsidian/55 uppercase">Te conviene</p>
              <p class="admin-display text-6xl text-accent">{{ recommendation.name }}</p>
              <p class="admin-display text-3xl">
                {{ recommendation.price }} <span class="font-ui text-sm tracking-normal text-obsidian/55 normal-case">por evento</span>
              </p>
              <p class="text-obsidian/70">{{ recommendation.why }}</p>
            </div>
            <div class="space-y-4 rounded-[1.5rem] bg-chalk p-5">
              <ul class="space-y-2 text-[0.95rem]">
                <li v-for="i in recommendation.includes" :key="i" class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-go" />{{ i }}</li>
              </ul>
              <router-link :to="{ name: 'admin-signup' }" class="admin-btn-primary w-full">
                Elegir {{ recommendation.name }}
              </router-link>
              <button type="button" @click="restartFinder" class="mx-auto flex items-center gap-1 text-sm font-bold text-obsidian/55 hover:text-obsidian">
                <RotateCcw :size="14" /> Volver a empezar
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Con y sin -->
      <section class="space-y-6 py-12" aria-labelledby="h-vs">
        <h2 id="h-vs" class="admin-display max-w-3xl text-5xl text-balance sm:text-6xl">Organizar una fiesta, con y sin Asiste</h2>
        <div class="grid gap-4 md:grid-cols-2">
          <div class="space-y-3 rounded-[2rem] bg-limestone p-6">
            <h3 class="text-xl font-bold">Sin Asiste</h3>
            <ul class="list-disc space-y-2 pl-5">
              <li>Una invitación en imagen y las respuestas llegan por WhatsApp, mezcladas con todo</li>
              <li>Una planilla que hay que actualizar a mano cada vez que alguien confirma o cancela</li>
              <li>Las mesas en un papel, que cambia diez veces</li>
              <li>Una lista impresa en la puerta y alguien buscando nombres con el dedo</li>
              <li>Las fotos de los invitados quedan en sus celulares</li>
            </ul>
          </div>
          <div class="space-y-3 rounded-[2rem] bg-go/20 p-6">
            <h3 class="text-xl font-bold">Con Asiste</h3>
            <ul class="list-disc space-y-2 pl-5">
              <li>Cada familia recibe su link y confirma en un toque</li>
              <li>El panel se actualiza solo: quién viene, quién no y quién falta responder</li>
              <li>Armás las mesas arrastrando, con los lugares contados</li>
              <li>En la puerta buscan el nombre, ven la mesa y marcan que llegó</li>
              <li>Todas las fotos de la noche en un mismo álbum</li>
            </ul>
          </div>
        </div>
      </section>

      <!-- Preguntas -->
      <section class="space-y-6 py-12" aria-labelledby="h-faq">
        <h2 id="h-faq" class="admin-display text-5xl sm:text-6xl">Preguntas</h2>
        <div class="space-y-2">
          <details v-for="q in [
            { q: '¿Es un pago por mes?', a: 'No. Para tu fiesta pagás una sola vez por evento. El abono mensual es solo para salones.' },
            { q: '¿Puedo probarlo gratis?', a: 'Sí. Armás tu invitación completa sin pagar y la probás con hasta 5 familias. Mientras es de prueba lleva un cartel que lo indica, y el link se cierra a las 15 visitas o a las 24 horas de que la abre la primera persona. Cuando elegís un plan se levantan los límites y el mismo link sigue andando, sin perder nada de lo que armaste.' },
            { q: '¿Qué es la reunión del Plus?', a: 'Una videollamada de una hora con nosotros para armar la invitación y la lista de invitados juntos, y sacarte todas las dudas.' },
            { q: '¿Cómo funciona la trivia?', a: 'Es para jugar en vivo el día de la fiesta. Vos armás las preguntas antes; en la fiesta la abrís, los invitados juegan desde su celular escaneando el QR de la mesa, el ranking se ve en la pantalla del salón y al cerrarla se festeja al ganador.' },
            { q: '¿Mis invitados tienen que bajarse una app?', a: 'No. Abren el link desde WhatsApp y confirman desde el navegador del celular.' },
            { q: '¿Qué pasa si alguien cambia su respuesta?', a: 'El panel se actualiza solo y queda registrado en los movimientos, así sabés qué cambió y cuándo.' },
            { q: 'Tengo un salón, ¿cómo funciona?', a: 'Tu salón ofrece Asiste en cada fiesta, con tu logo en las invitaciones y usuarios para tu personal. Pagás por fiesta o un abono mensual sin permanencia, y vos decidís cuánto se lo cobrás a tus clientes.' },
          ]" :key="q.q" class="rounded-[1.25rem] bg-limestone px-5 py-4">
            <summary class="cursor-pointer font-bold">{{ q.q }}</summary>
            <p class="mt-2 max-w-3xl text-obsidian/65">{{ q.a }}</p>
          </details>
        </div>
      </section>

      <footer class="flex flex-wrap items-center justify-between gap-3 py-10 text-sm text-obsidian/55">
        <span>Asiste · TizDigital</span>
        <span>Precios en pesos argentinos.</span>
      </footer>
    </div>
  </div>
</template>

<style scoped>
/* Cada tarjeta del carrusel entra suave (salvo con «reducir movimiento»). */
@media (prefers-reduced-motion: no-preference) {
  .feat-in,
  .finder-in {
    animation: feat-in 0.35s ease;
  }
}
@keyframes feat-in {
  from {
    opacity: 0;
    transform: translateY(6px);
  }
}
</style>
