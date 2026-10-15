<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, Check, CircleCheck, Clock, CircleAlert, LoaderCircle, Sparkles } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'
import { PLANS, upgradePrice, formatPrice, chosenPlan, forgetChosenPlan } from '../lib/plans'

// «Tu plan»: el plan actual, los planes a los que se puede pasar (pagando
// la diferencia) y la vuelta desde Mercado Pago (?pago=aprobado|pendiente|rechazado&id=…).
// El cobro lo arma la Edge Function crear-pago y el plan lo sube mp-webhook
// cuando MP confirma (ver migrations/20261015_pagos.sql). Esta pantalla solo
// pide el link y después espera a que la base cambie.
const route = useRoute()
const router = useRouter()
const { event, loadEvent, viewing } = useEvent()

const loading = ref(true)
const paying = ref(null) // plan que se está por pagar (botón con «cargando»)
const error = ref('')
const pagos = ref([])

// Vuelta de Mercado Pago
const returned = ref(route.query.pago ?? null) // 'aprobado' | 'pendiente' | 'rechazado'
const returnedPago = ref(null) // la fila de pagos de esa vuelta
const waitedTooLong = ref(false)
let pollTimer = null

const PAID = ['invitacion', 'plus', 'premium']
const options = computed(() =>
  event.value ? PAID.filter((p) => upgradePrice(event.value.plan, p) !== null) : [],
)
const isUpgrade = computed(() => !!PLANS[event.value?.plan]?.price)
// Resaltado: el que vino en el link (PlanGate, landing) o el que eligió antes de registrarse.
const highlighted = computed(() => {
  const wanted = route.query.plan ?? chosenPlan()
  return options.value.includes(wanted) ? wanted : (options.value.includes('plus') ? 'plus' : options.value[0])
})

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) await fetchPagos()
  loading.value = false
  if (returned.value && route.query.id) watchReturn(route.query.id)
})
onUnmounted(() => clearTimeout(pollTimer))

async function fetchPagos() {
  const { data } = await supabase
    .from('pagos')
    .select('id, plan, plan_anterior, monto, estado, creado_en, aprobado_en')
    .eq('event_id', event.value.id)
    .order('creado_en', { ascending: false })
  pagos.value = data ?? []
}
const approvedPagos = computed(() => pagos.value.filter((p) => p.estado === 'aprobado' || p.estado === 'devuelto'))

// MP vuelve a la página apenas se paga, pero el aviso a mp-webhook puede
// tardar unos segundos (o más). Se consulta el pago cada 3 s durante 1 minuto;
// después se deja de esperar: cuando llegue, el plan se activa igual.
async function watchReturn(id, tries = 0) {
  const { data } = await supabase.from('pagos').select('id, plan, monto, estado').eq('id', id).maybeSingle()
  returnedPago.value = data
  if (data?.estado === 'aprobado') {
    forgetChosenPlan()
    await Promise.all([loadEvent(), fetchPagos()])
    returned.value = 'aprobado'
    return
  }
  if (data && data.estado !== 'pendiente') {
    returned.value = 'rechazado'
    return
  }
  // Pendiente: si MP dijo «aprobado» al volver, seguimos esperando el aviso.
  if (returned.value !== 'aprobado') return
  if (tries >= 20) {
    waitedTooLong.value = true
    return
  }
  pollTimer = setTimeout(() => watchReturn(id, tries + 1), 3000)
}
const confirmed = computed(() => returnedPago.value?.estado === 'aprobado')

function dismissReturn() {
  returned.value = null
  router.replace({ name: 'admin-plan' })
}

async function pay(plan) {
  error.value = ''
  paying.value = plan
  const { data, error: err } = await supabase.functions.invoke('crear-pago', { body: { plan } })
  if (err || !data?.url) {
    // Los errores de la función vienen con { error: '…' } en el cuerpo.
    let msg = 'No se pudo iniciar el pago. Probá de nuevo en un rato.'
    try {
      msg = (await err?.context?.json())?.error ?? msg
    } catch {
      /* respuesta sin JSON */
    }
    error.value = msg
    paying.value = null
    return
  }
  // A Mercado Pago (misma pestaña: al terminar vuelve acá con ?pago=…).
  window.location.href = data.url
}

const formatDate = (iso) =>
  new Date(iso).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' })
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-4xl px-4 pt-4 pb-16 lg:px-8 lg:pt-8">
      <router-link
        :to="{ name: 'admin-dashboard' }"
        class="inline-flex items-center gap-1.5 text-sm font-bold text-obsidian/55 hover:text-obsidian"
      >
        <ArrowLeft :size="15" />
        Inicio
      </router-link>
      <h1 class="admin-display mt-3 text-5xl sm:text-6xl">Tu plan</h1>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>

      <div v-else-if="!event" class="mt-8 rounded-[2rem] bg-limestone p-8">
        <p class="text-obsidian/60">Primero guardá tu invitación y después elegí el plan.</p>
        <router-link :to="{ name: 'admin-salon' }" class="admin-btn-primary mt-4">Crear mi invitación</router-link>
      </div>

      <template v-else>
        <!-- ============ VUELTA DE MERCADO PAGO ============ -->
        <section
          v-if="returned"
          role="status"
          class="mt-6 flex items-start gap-3 rounded-[2rem] p-5 sm:p-6"
          :class="
            returned === 'rechazado' ? 'bg-nogo/15' : confirmed ? 'bg-go/15' : 'bg-sulfur/70'
          "
        >
          <CircleAlert v-if="returned === 'rechazado'" :size="22" class="mt-0.5 shrink-0 text-nogo" />
          <CircleCheck v-else-if="confirmed" :size="22" class="mt-0.5 shrink-0 text-go" />
          <Clock v-else-if="returned === 'pendiente' || waitedTooLong" :size="22" class="mt-0.5 shrink-0" />
          <LoaderCircle v-else :size="22" class="mt-0.5 shrink-0 animate-spin" />
          <div class="min-w-0 flex-1">
            <template v-if="returned === 'rechazado'">
              <p class="font-bold">El pago no se completó</p>
              <p class="mt-1 text-sm text-obsidian/70">No se te cobró nada. Podés probar de nuevo, con otra tarjeta o con otro medio.</p>
            </template>
            <template v-else-if="confirmed">
              <p class="font-bold">¡Listo! Ya tenés el plan {{ PLANS[returnedPago.plan].label }}</p>
              <p class="mt-1 text-sm text-obsidian/70">
                Se levantaron todos los límites. Te vamos a escribir por WhatsApp para lo que haga falta.
              </p>
            </template>
            <template v-else-if="returned === 'pendiente'">
              <p class="font-bold">Tu pago está pendiente</p>
              <p class="mt-1 text-sm text-obsidian/70">
                Si elegiste pagar en efectivo, se acredita cuando lo pagues. Apenas Mercado Pago nos avise, el plan se activa solo.
              </p>
            </template>
            <template v-else-if="waitedTooLong">
              <p class="font-bold">Mercado Pago todavía no nos confirmó el pago</p>
              <p class="mt-1 text-sm text-obsidian/70">
                A veces tarda unos minutos. Cuando llegue, el plan se activa solo; podés seguir usando el panel.
              </p>
            </template>
            <template v-else>
              <p class="font-bold">Confirmando tu pago…</p>
              <p class="mt-1 text-sm text-obsidian/70">Esperamos el aviso de Mercado Pago. Son unos segundos.</p>
            </template>
          </div>
          <button type="button" @click="dismissReturn" class="shrink-0 text-sm font-bold text-obsidian/55 hover:text-obsidian">
            Cerrar
          </button>
        </section>

        <!-- ============ PLAN ACTUAL ============ -->
        <section class="mt-6 rounded-[2rem] bg-limestone p-6 sm:p-8">
          <p class="text-sm font-bold text-obsidian/55">Plan actual</p>
          <p class="admin-display mt-1 text-4xl">{{ PLANS[event.plan]?.label ?? event.plan }}</p>
          <p class="mt-2 text-obsidian/65">
            <template v-if="event.plan === 'gratis'">
              Podés armar y probar todo. Para mandarla a todos tus invitados, elegí un plan: se levantan los límites y los
              mismos links siguen andando.
            </template>
            <template v-else-if="options.length">
              Si querés más, pasate a otro plan pagando solo la diferencia.
            </template>
            <template v-else>Tenés el plan más completo. ¡Que lo disfrutes!</template>
          </p>
        </section>

        <p v-if="viewing" class="mt-6 rounded-[1.5rem] bg-sulfur/70 p-4 text-sm">
          Estás viendo el panel de otro cliente: el pago lo tiene que hacer el dueño desde su cuenta. El plan se puede
          cambiar a mano desde Superadmin.
        </p>

        <!-- ============ PLANES PARA PASARSE ============ -->
        <div v-if="options.length && !viewing" class="mt-6 grid gap-4" :class="options.length >= 3 ? 'md:grid-cols-3' : 'md:grid-cols-2'">
          <article
            v-for="p in options"
            :key="p"
            class="relative flex flex-col gap-4 rounded-[2rem] p-6"
            :class="p === highlighted ? 'bg-chalk ring-[2.5px] ring-accent' : 'bg-limestone'"
          >
            <span
              v-if="p === highlighted && chosenPlan() === p && !route.query.plan"
              class="absolute -top-3 left-6 rounded-full bg-sulfur px-2.5 py-1 text-xs font-bold tracking-wide uppercase"
            >
              El que elegiste
            </span>
            <h2 class="text-lg font-bold">{{ PLANS[p].label }}</h2>
            <div>
              <p class="admin-display text-5xl">{{ formatPrice(upgradePrice(event.plan, p)) }}</p>
              <p class="mt-1 text-sm text-obsidian/55">
                <template v-if="isUpgrade">
                  Pagás solo la diferencia
                  <span class="line-through">{{ formatPrice(PLANS[p].price) }}</span>
                </template>
                <template v-else>Pago único por evento</template>
              </p>
            </div>
            <ul class="flex-1 space-y-2 text-[0.95rem]">
              <li v-if="p === 'plus'" class="flex gap-2"><Check :size="17" class="mt-0.5 shrink-0 text-go" />Todo lo de Invitación</li>
              <li v-for="i in PLANS[p].includes" :key="i" class="flex gap-2">
                <Check :size="17" class="mt-0.5 shrink-0 text-go" />{{ i }}
              </li>
            </ul>
            <button
              type="button"
              @click="pay(p)"
              :disabled="!!paying"
              :class="p === highlighted ? 'admin-btn-primary' : 'admin-btn-secondary'"
              class="w-full"
            >
              <LoaderCircle v-if="paying === p" :size="17" class="animate-spin" />
              <Sparkles v-else :size="17" />
              {{ paying === p ? 'Abriendo Mercado Pago…' : `Pagar ${PLANS[p].label}` }}
            </button>
          </article>
        </div>

        <p v-if="error" role="alert" class="mt-4 rounded-[1.5rem] bg-nogo/15 p-4 text-sm font-medium">{{ error }}</p>

        <p v-if="options.length && !viewing" class="mt-4 text-sm text-obsidian/55">
          Pagás con Mercado Pago: tarjeta de crédito o débito, dinero en cuenta o efectivo. El plan se activa solo apenas
          se acredita el pago.
          <router-link :to="{ name: 'landing', query: { planes: 1 }, hash: '#planes' }" target="_blank" class="font-bold text-accent hover:underline">
            Comparar los planes
          </router-link>
        </p>

        <!-- ============ PAGOS HECHOS ============ -->
        <section v-if="approvedPagos.length" class="mt-10">
          <h2 class="text-lg font-bold">Tus pagos</h2>
          <ul class="mt-3 divide-y divide-obsidian/10 rounded-[1.5rem] bg-chalk">
            <li v-for="p in approvedPagos" :key="p.id" class="flex flex-wrap items-center justify-between gap-2 px-5 py-3.5">
              <span>
                <span class="font-bold">Plan {{ PLANS[p.plan].label }}</span>
                <span v-if="p.plan_anterior !== 'gratis'" class="text-sm text-obsidian/55">
                  (desde {{ PLANS[p.plan_anterior]?.label }})</span
                >
                <span v-if="p.estado === 'devuelto'" class="ml-1 text-sm font-bold text-nogo">Devuelto</span>
              </span>
              <span class="text-sm text-obsidian/65">
                {{ formatPrice(p.monto) }} · {{ formatDate(p.aprobado_en ?? p.creado_en) }}
              </span>
            </li>
          </ul>
        </section>
      </template>
    </div>
  </div>
</template>
