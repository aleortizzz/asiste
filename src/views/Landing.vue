<script setup>
import { ref, computed, nextTick } from 'vue'
import {
  Check,
  X,
  ChevronDown,
  Mail,
  ClipboardList,
  PartyPopper,
  MessageCircle,
  PenSquare,
  Sparkles,
  ArrowLeft,
  RotateCcw,
} from '@lucide/vue'
import { PLANS as BASE_PLANS, SALON_PRICES, formatPrice } from '../lib/plans'
import { useAuth } from '../composables/useAuth'
import LandingHeader from '../components/landing/LandingHeader.vue'
import SectionHero from '../components/landing/SectionHero.vue'
import SectionDemos from '../components/landing/SectionDemos.vue'
import SectionPasos from '../components/landing/SectionPasos.vue'
import SectionMomentos from '../components/landing/SectionMomentos.vue'
import SectionPlantillas from '../components/landing/SectionPlantillas.vue'
import SectionEventos from '../components/landing/SectionEventos.vue'
import SectionSalones from '../components/landing/SectionSalones.vue'
import SectionCierre from '../components/landing/SectionCierre.vue'
import LandingFooter from '../components/landing/LandingFooter.vue'
import WhatsappFloat from '../components/landing/WhatsappFloat.vue'
import { waLink } from '../lib/contact'

// Página de inicio pública (/): la ve quien entra sin sesión; con sesión, el
// router lo manda al panel. Planes y precios acordados el 2026-10-13 (ver
// PROGRESO.md). Los nombres de las tarjetas de ejemplo son inventados.

// --- Planes ------------------------------------------------------------------------------
const audience = ref('fiesta') // 'fiesta' | 'salon'
// La tabla comparativa arranca plegada: las tarjetas ya cuentan lo principal.
const showTable = ref(false)

// «Ver precios para salones» (sección Salones): abre esa pestaña y baja a Planes.
async function showSalonPrices() {
  audience.value = 'salon'
  await nextTick()
  document.getElementById('planes')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

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

// Botones de compra: sin sesión, a registrarse (el plan elegido queda
// guardado y «Tu plan» lo muestra primero); con sesión (vino desde el panel
// con ?planes), directo a pagarlo.
const { user } = useAuth()
const buyLink = (plan) =>
  user.value ? { name: 'admin-plan', query: { plan } } : { name: 'admin-signup', query: { plan } }

// --- ¿Cuál me conviene? (de a una pregunta) ------------------------------------------------
const PLANS = {
  invitacion: {
    name: 'Invitación',
    get price() {
      return formatPrice(BASE_PLANS.invitacion.price)
    },
    includes: BASE_PLANS.invitacion.includes,
  },
  plus: {
    name: 'Plus',
    get price() {
      return formatPrice(BASE_PLANS.plus.price)
    },
    includes: BASE_PLANS.plus.includes,
  },
  premium: {
    name: 'Premium',
    get price() {
      return formatPrice(BASE_PLANS.premium.price)
    },
    includes: BASE_PLANS.premium.includes,
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
  return { ...PLANS[key], id: key, why }
})

// --- Con y sin Asiste --------------------------------------------------------------------
const WITHOUT = [
  'Una invitación en imagen y las respuestas llegan por WhatsApp, mezcladas con todo',
  'Una planilla que hay que actualizar a mano cada vez que alguien confirma o cancela',
  'Las mesas en un papel, que cambia diez veces',
  'Una lista impresa en la puerta y alguien buscando nombres con el dedo',
  'Las fotos de los invitados quedan en sus celulares',
]
const WITH = [
  'Cada familia recibe su link y confirma en un toque',
  'El panel se actualiza solo: quién viene, quién no y quién falta responder',
  'Armás las mesas arrastrando, con los lugares contados',
  'En la puerta buscan el nombre, ven la mesa y marcan que llegó',
  'Todas las fotos de la noche en un mismo álbum',
]

// --- Calculadora para salones ------------------------------------------------------------
// Precios de precios_planes (Superadmin). computed: si cambian, la cuenta se rehace.
const PER_PARTY = computed(() => SALON_PRICES.fiesta)
const SUBSCRIPTION = computed(() => SALON_PRICES.abono)
// Desde cuántas fiestas por mes conviene el abono.
const subscriptionFrom = computed(() => Math.ceil(SUBSCRIPTION.value / PER_PARTY.value))
const parties = ref(6)
const resale = ref(BASE_PLANS.premium.price)
const money = (n) => `$${Math.round(n).toLocaleString('es-AR')}`

const byParty = computed(() => parties.value * PER_PARTY.value)
const best = computed(() => Math.min(byParty.value, SUBSCRIPTION.value))
const left = computed(() => parties.value * resale.value - best.value)
const verdict = computed(() => {
  const s = parties.value === 1 ? 'fiesta' : 'fiestas'
  const sub = SUBSCRIPTION.value
  if (sub < byParty.value) return `Con ${parties.value} ${s}, el abono te ahorra ${money(byParty.value - sub)} por mes.`
  if (sub === byParty.value) return `Con ${parties.value} ${s}, da lo mismo.`
  return `Con ${parties.value} ${s}, te conviene pagar por fiesta: ${money(byParty.value)} contra ${money(sub)} del abono.`
})
</script>

<template>
  <div id="inicio" class="landing font-ui min-h-dvh bg-pumice text-obsidian">
    <LandingHeader />
    <div class="mx-auto max-w-6xl px-4">

      <SectionHero />
      <SectionPasos />
      <SectionDemos />
      <SectionMomentos />
      <SectionPlantillas />
      <SectionEventos />
      <SectionSalones @ver-precios="showSalonPrices" />

      <!-- Planes -->
      <section id="planes" class="scroll-mt-24 space-y-6 py-12" aria-labelledby="h-planes">
        <div v-reveal class="max-w-2xl">
          <h2 id="h-planes" class="admin-display text-5xl sm:text-6xl">Planes</h2>
          <p class="mt-3 text-lg text-obsidian/65">
            Elegí tu plan y pagalo de una: armás la invitación cuando quieras y ya nace con todo. Un solo pago por evento, sin
            abonos ni costo por invitado.
          </p>
          <p class="mt-2 text-obsidian/55">
            ¿Querés verla antes de pagar?
            <router-link :to="{ name: 'admin-signup' }" class="font-bold text-accent hover:underline">Probala gratis</router-link>
            con hasta 5 familias.
          </p>
        </div>

        <div v-reveal class="inline-flex gap-1 rounded-full bg-limestone p-1" role="tablist" aria-label="Tipo de cliente">
          <button
            v-for="a in [{ id: 'fiesta', label: 'Para tu fiesta' }, { id: 'salon', label: 'Para salones' }]"
            :key="a.id"
            type="button"
            role="tab"
            :aria-selected="audience === a.id"
            @click="audience = a.id"
            class="rounded-full px-5 py-2 font-bold transition-colors"
            :class="audience === a.id ? 'bg-obsidian text-chalk' : 'hover:bg-chalk'"
          >
            {{ a.label }}
          </button>
        </div>

        <!-- Particulares -->
        <div v-if="audience === 'fiesta'" class="space-y-6">
          <div class="grid gap-4 pt-3 md:grid-cols-3">
            <article v-reveal class="lift flex flex-col gap-4 rounded-[2rem] bg-limestone p-6">
              <h3 class="text-lg font-bold">Invitación</h3>
              <p class="min-h-12 text-obsidian/60">Para mandar una invitación linda.</p>
              <p class="admin-display text-5xl">{{ formatPrice(BASE_PLANS.invitacion.price) }} <span class="font-ui text-sm tracking-normal text-obsidian/55 normal-case">por evento</span></p>
              <ul class="flex-1 space-y-2 text-[0.95rem]">
                <li v-for="i in PLANS.invitacion.includes" :key="i" class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-go" />{{ i }}</li>
              </ul>
              <router-link :to="buyLink('invitacion')" class="admin-btn-secondary w-full">Comprar Invitación</router-link>
            </article>
            <article v-reveal data-delay="100" class="lift night flex flex-col gap-4 rounded-[2rem] p-6 md:-my-3 md:py-9">
              <span class="self-start rounded-full bg-sulfur px-2.5 py-1 text-xs font-bold tracking-wide text-obsidian uppercase">El más elegido</span>
              <h3 class="text-lg font-bold">Plus</h3>
              <p class="min-h-12 text-chalk/70">Para saber quién viene y organizar la fiesta.</p>
              <p class="admin-display text-5xl">{{ formatPrice(BASE_PLANS.plus.price) }} <span class="font-ui text-sm tracking-normal text-chalk/60 normal-case">por evento</span></p>
              <ul class="flex-1 space-y-2 text-[0.95rem]">
                <li class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-sulfur" />Todo lo de Invitación</li>
                <li v-for="i in PLANS.plus.includes" :key="i" class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-sulfur" />{{ i }}</li>
              </ul>
              <router-link :to="buyLink('plus')" class="admin-btn-primary w-full !bg-sulfur !text-obsidian">Comprar Plus</router-link>
            </article>
            <article v-reveal data-delay="200" class="lift flex flex-col gap-4 rounded-[2rem] bg-limestone p-6">
              <h3 class="text-lg font-bold">Premium</h3>
              <p class="min-h-12 text-obsidian/60">Para que la fiesta también se viva con Asiste.</p>
              <p class="admin-display text-5xl">{{ formatPrice(BASE_PLANS.premium.price) }} <span class="font-ui text-sm tracking-normal text-obsidian/55 normal-case">por evento</span></p>
              <ul class="flex-1 space-y-2 text-[0.95rem]">
                <li v-for="i in PLANS.premium.includes" :key="i" class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-go" />{{ i }}</li>
              </ul>
              <router-link :to="buyLink('premium')" class="admin-btn-secondary w-full">Comprar Premium</router-link>
            </article>
          </div>

          <div class="flex justify-center pt-2">
            <button
              type="button"
              @click="showTable = !showTable"
              :aria-expanded="showTable"
              aria-controls="tabla-planes"
              class="flex items-center gap-2 rounded-full bg-limestone px-5 py-2.5 font-bold transition-colors hover:bg-chalk"
            >
              {{ showTable ? 'Ocultar la comparación' : 'Ver la comparación completa' }}
              <ChevronDown :size="17" class="transition-transform duration-300" :class="showTable ? 'rotate-180' : ''" />
            </button>
          </div>
          <!-- Plegada: se despliega animando la altura con grid-template-rows (ver estilos) -->
          <div id="tabla-planes" class="collapse-grid" :class="{ open: showTable }" :inert="!showTable">
          <div class="min-h-0 overflow-hidden">
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
                  <td class="p-3 text-center">{{ formatPrice(BASE_PLANS.invitacion.price) }}</td>
                  <td class="bg-accent-soft p-3 text-center">{{ formatPrice(BASE_PLANS.plus.price) }}</td>
                  <td class="p-3 text-center">{{ formatPrice(BASE_PLANS.premium.price) }}</td>
                </tr>
              </tfoot>
            </table>
          </div>
          </div>
          </div>
        </div>

        <!-- Salones -->
        <div v-else class="space-y-6">
          <div class="grid gap-4 pt-3 md:grid-cols-2">
            <article class="lift flex flex-col gap-4 rounded-[2rem] bg-limestone p-6">
              <h3 class="text-lg font-bold">Por fiesta</h3>
              <p class="min-h-12 text-obsidian/60">Pagás solo las fiestas que usás.</p>
              <p class="admin-display text-5xl">{{ formatPrice(SALON_PRICES.fiesta) }} <span class="font-ui text-sm tracking-normal text-obsidian/55 normal-case">por fiesta</span></p>
              <ul class="flex-1 space-y-2 text-[0.95rem]">
                <li v-for="i in ['Todo lo del Premium en cada fiesta', 'Tu logo en cada invitación', 'Usuarios para tu personal de recepción', 'La primera fiesta, gratis']" :key="i" class="flex gap-2">
                  <Check :size="17" class="mt-0.5 shrink-0 text-go" />{{ i }}
                </li>
              </ul>
              <a :href="waLink('Hola! Tengo un salón y quiero probar Asiste en una fiesta.')" target="_blank" rel="noopener" class="admin-btn-secondary w-full">Quiero probarlo</a>
            </article>
            <article class="lift night flex flex-col gap-4 rounded-[2rem] p-6">
              <span class="self-start rounded-full bg-sulfur px-2.5 py-1 text-xs font-bold tracking-wide text-obsidian uppercase">Desde {{ subscriptionFrom }} fiestas por mes</span>
              <h3 class="text-lg font-bold">Abono</h3>
              <p class="min-h-12 text-chalk/70">Para salones con movimiento todos los fines de semana.</p>
              <p class="admin-display text-5xl">{{ formatPrice(SALON_PRICES.abono) }} <span class="font-ui text-sm tracking-normal text-chalk/60 normal-case">por mes</span></p>
              <ul class="flex-1 space-y-2 text-[0.95rem]">
                <li
                  v-for="i in ['Fiestas ilimitadas', 'Sin permanencia: mes a mes', 'En un mes flojo, volvés a pagar por fiesta', 'Lo que pagaste por fiesta el último mes se descuenta del primer abono']"
                  :key="i"
                  class="flex gap-2"
                >
                  <Check :size="17" class="mt-0.5 shrink-0 text-sulfur" />{{ i }}
                </li>
              </ul>
              <a :href="waLink('Hola! Tengo un salón y me interesa el abono de Asiste.')" target="_blank" rel="noopener" class="admin-btn-primary w-full !bg-sulfur !text-obsidian">Hablemos</a>
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
      <section id="conviene" class="scroll-mt-24 py-12" aria-labelledby="h-conviene">
        <div v-reveal="'scale'" class="night grid gap-8 rounded-[2.5rem] p-6 sm:p-10 lg:grid-cols-[0.8fr_1.2fr] lg:p-14">
        <div>
          <h2 id="h-conviene" class="admin-display text-5xl sm:text-6xl">¿Cuál me conviene?</h2>
          <p class="mt-3 text-lg text-chalk/75">Dos preguntas y te decimos qué plan elegir.</p>
        </div>

        <div>
          <!-- Pregunta -->
          <div v-if="!finished" :key="step" class="finder-in space-y-5">
            <div class="flex items-center justify-between gap-3">
              <p class="text-sm font-bold text-chalk/60">Pregunta {{ step + 1 }} de {{ stepKeys.length }}</p>
              <div class="flex gap-1.5" aria-hidden="true">
                <span v-for="n in stepKeys.length" :key="n" class="h-1.5 w-8 rounded-full transition-colors duration-500" :class="n <= step + 1 ? 'bg-sulfur' : 'bg-chalk/20'"></span>
              </div>
            </div>
            <h3 class="admin-display text-4xl sm:text-5xl">{{ currentQuestion.text }}</h3>
            <div class="grid gap-3" :class="currentQuestion.options.length === 3 ? 'sm:grid-cols-3' : 'sm:grid-cols-2'">
              <button
                v-for="o in currentQuestion.options"
                :key="o.value"
                type="button"
                @click="answer(o.value)"
                class="lift group flex flex-col items-start gap-3 rounded-[1.5rem] border-[1.5px] border-transparent bg-chalk p-5 text-left text-obsidian hover:border-sulfur focus-visible:border-sulfur"
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
            <button v-if="step > 0" type="button" @click="back" class="flex items-center gap-1 text-sm font-bold text-chalk/60 hover:text-chalk">
              <ArrowLeft :size="15" /> Volver
            </button>
          </div>

          <!-- Resultado -->
          <div v-else class="finder-in grid gap-6 sm:grid-cols-[1fr_1.1fr] sm:items-center">
            <div class="space-y-2">
              <p class="text-sm font-bold text-chalk/60">Te conviene</p>
              <p class="admin-display text-6xl text-sulfur">{{ recommendation.name }}</p>
              <p class="admin-display text-3xl">
                {{ recommendation.price }} <span class="font-ui text-sm tracking-normal text-chalk/60 normal-case">por evento</span>
              </p>
              <p class="text-chalk/75">{{ recommendation.why }}</p>
            </div>
            <div class="space-y-4 rounded-[1.5rem] bg-chalk p-5 text-obsidian">
              <ul class="space-y-2 text-[0.95rem]">
                <li v-for="i in recommendation.includes" :key="i" class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-go" />{{ i }}</li>
              </ul>
              <router-link :to="buyLink(recommendation.id)" class="admin-btn-primary w-full">
                Comprar {{ recommendation.name }}
              </router-link>
              <button type="button" @click="restartFinder" class="mx-auto flex items-center gap-1 text-sm font-bold text-obsidian/55 hover:text-obsidian">
                <RotateCcw :size="14" /> Volver a empezar
              </button>
            </div>
          </div>
        </div>
        </div>
      </section>

      <!-- Con y sin -->
      <section class="space-y-8 py-14" aria-labelledby="h-vs">
        <h2 v-reveal id="h-vs" class="admin-display max-w-3xl text-5xl text-balance sm:text-6xl">Organizar una fiesta, con y sin Asiste</h2>
        <div class="grid gap-4 md:grid-cols-2">
          <div v-reveal="'left'" class="rounded-[2rem] bg-limestone p-6 sm:p-8">
            <h3 class="admin-display text-3xl text-obsidian/70">Sin Asiste</h3>
            <ul class="mt-5 space-y-3.5">
              <li v-for="t in WITHOUT" :key="t" class="flex gap-3 text-obsidian/70">
                <span class="mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full bg-nogo/15 text-nogo-ink"><X :size="14" /></span>
                {{ t }}
              </li>
            </ul>
          </div>
          <div v-reveal="'right'" class="rounded-[2rem] bg-go p-6 text-obsidian shadow-[0_26px_50px_-30px_rgb(63_203_127/0.9)] sm:p-8">
            <h3 class="admin-display text-3xl">Con Asiste</h3>
            <ul class="mt-5 space-y-3.5">
              <li v-for="t in WITH" :key="t" class="flex gap-3 font-medium">
                <span class="mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full bg-obsidian text-go"><Check :size="14" /></span>
                {{ t }}
              </li>
            </ul>
          </div>
        </div>
      </section>

      <!-- Preguntas -->
      <section id="preguntas" class="scroll-mt-24 grid gap-8 py-14 lg:grid-cols-[0.75fr_1.25fr]" aria-labelledby="h-faq">
        <div v-reveal class="lg:sticky lg:top-28 lg:self-start">
          <h2 id="h-faq" class="admin-display text-5xl sm:text-6xl">Preguntas</h2>
          <div class="night mt-6 rounded-[2rem] p-6">
            <p class="text-lg font-bold">¿Te quedó otra duda?</p>
            <p class="mt-1 text-chalk/70">Escribinos y te respondemos nosotros, no un robot.</p>
            <a :href="waLink('Hola! Tengo una duda sobre Asiste: ')" target="_blank" rel="noopener" class="admin-btn-primary mt-4 !bg-sulfur !text-obsidian">
              <MessageCircle :size="17" /> Escribinos por WhatsApp
            </a>
          </div>
        </div>
        <div v-reveal data-delay="100" class="space-y-2">
          <details v-for="q in [
            { q: '¿Es un pago por mes?', a: 'No. Para tu fiesta pagás una sola vez por evento. El abono mensual es solo para salones.' },
            { q: '¿Tengo que armar la invitación antes de pagar?', a: 'No. Elegís el plan, creás tu cuenta y pagás con Mercado Pago en el momento. Después armás la invitación cuando quieras, y ya nace con todo lo del plan.' },
            { q: '¿Puedo probarlo gratis?', a: 'Sí. Armás tu invitación completa sin pagar y la probás con hasta 5 familias. Mientras es de prueba lleva un cartel que lo indica, y el link se cierra a las 15 visitas o a las 24 horas de que la abre la primera persona. Cuando elegís un plan se levantan los límites y el mismo link sigue andando, sin perder nada de lo que armaste.' },
            { q: '¿Qué es la reunión del Plus?', a: 'Una videollamada de una hora con nosotros para armar la invitación y la lista de invitados juntos, y sacarte todas las dudas.' },
            { q: '¿Cómo funciona la trivia?', a: 'Es para jugar en vivo el día de la fiesta. Vos armás las preguntas antes; en la fiesta la abrís, los invitados juegan desde su celular escaneando el QR de la mesa, el ranking se ve en la pantalla del salón y al cerrarla se festeja al ganador.' },
            { q: '¿Mis invitados tienen que bajarse una app?', a: 'No. Abren el link desde WhatsApp y confirman desde el navegador del celular.' },
            { q: '¿Qué pasa si alguien cambia su respuesta?', a: 'El panel se actualiza solo y queda registrado en los movimientos, así sabés qué cambió y cuándo.' },
            { q: 'Tengo un salón, ¿cómo funciona?', a: 'Tu salón ofrece Asiste en cada fiesta, con tu logo en las invitaciones y usuarios para tu personal. Pagás por fiesta o un abono mensual sin permanencia, y vos decidís cuánto se lo cobrás a tus clientes.' },
          ]" :key="q.q" class="faq group rounded-[1.25rem] bg-limestone transition-colors hover:bg-chalk open:bg-chalk">
            <summary class="flex cursor-pointer list-none items-center justify-between gap-4 px-5 py-4 font-bold [&::-webkit-details-marker]:hidden">
              {{ q.q }}
              <span class="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-chalk text-accent transition-[transform,background-color] duration-300 group-open:rotate-180 group-open:bg-accent group-open:text-chalk">
                <ChevronDown :size="17" />
              </span>
            </summary>
            <p class="max-w-3xl px-5 pb-5 text-obsidian/70">{{ q.a }}</p>
          </details>
        </div>
      </section>

      <SectionCierre />
      <LandingFooter />
    </div>
    <WhatsappFloat />
  </div>
</template>

<style scoped>
/* Tabla de planes plegada: animar grid-template-rows de 0fr a 1fr despliega
   la altura real sin medirla. */
.collapse-grid {
  display: grid;
  grid-template-rows: 0fr;
  opacity: 0;
  transition:
    grid-template-rows 0.5s cubic-bezier(0.16, 1, 0.3, 1),
    opacity 0.4s ease;
}
.collapse-grid.open {
  grid-template-rows: 1fr;
  opacity: 1;
}
@media (prefers-reduced-motion: no-preference) {
  .faq[open] p {
    animation: faq-in 0.35s cubic-bezier(0.16, 1, 0.3, 1);
  }
}
@keyframes faq-in {
  from {
    opacity: 0;
    transform: translateY(-6px);
  }
}
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
