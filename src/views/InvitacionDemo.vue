<script setup>
import { ref, nextTick, onMounted, onUnmounted } from 'vue'
import InvitationView from '../components/InvitationView.vue'
import { supabase } from '../lib/supabase'

// La invitación de ejemplo que se ve dentro del celular de la landing (en un
// <iframe>). Es la del evento marcado con `landing_demo`, con una familia de
// ejemplo. No va en modo vista previa, para que se vean el sobre y la música:
// las respuestas y las canciones se «envían» acá mismo, sin tocar la base
// (a diferencia de PublicInvite). Ver migrations/20261013_invitacion_demo.sql.
const invite = ref(null)
const failed = ref(false)
const submitting = ref(false)
const submitted = ref(false)
const songSubmitting = ref(false)

// ?plantilla=craft: la misma invitación con otra plantilla (la sección
// «Plantillas» de la landing muestra las cuatro).
const PLANTILLAS = ['clasico', 'partiful', 'craft', 'ejecutiva']
const params = new URLSearchParams(window.location.search)
const plantilla = params.get('plantilla')
// ?auto=1: la landing (DemoInvitacion) le pide por postMessage que abra el
// sobre sola cuando el celular aparece en pantalla. Sin música: no tiene
// que sonar nada que la persona no pidió.
const auto = params.has('auto')

onMounted(async () => {
  window.addEventListener('message', onMessage)
  const { data, error } = await supabase.rpc('invitacion_demo')
  if (error || !data) failed.value = true
  else {
    const withTemplate = PLANTILLAS.includes(plantilla) ? { ...data, template: plantilla } : data
    invite.value = auto ? { ...withTemplate, music_url: '' } : withTemplate
    if (openRequested) openEnvelope()
  }
})
onUnmounted(() => window.removeEventListener('message', onMessage))

let openRequested = false
function onMessage(e) {
  if (e.origin !== window.location.origin || e.data !== 'asiste:abrir-sobre') return
  openRequested = true
  if (invite.value) openEnvelope()
}
// Toca el sobre como lo haría la persona (si la plantilla no tiene sobre, ya
// está abierta) y avisa cuándo terminó de abrirse, para que la landing
// muestre que se puede deslizar.
async function openEnvelope() {
  await nextTick()
  document.querySelector('.ec-envelope')?.click()
  // Avisa recién cuando el sobre desapareció del todo (se saca del DOM al
  // terminar su animación), así el deslizado no se pisa con el sobre.
  const notify = () => window.parent.postMessage('asiste:sobre-abierto', window.location.origin)
  const waitGone = (tries = 0) =>
    !document.querySelector('.ec-envelope') || tries > 40 ? notify() : setTimeout(() => waitGone(tries + 1), 150)
  waitGone()
}

const wait = (ms) => new Promise((r) => setTimeout(r, ms))

async function fakeRsvp() {
  submitting.value = true
  await wait(700)
  submitting.value = false
  submitted.value = true
}

async function fakeSong() {
  songSubmitting.value = true
  await wait(700)
  songSubmitting.value = false
}
</script>

<template>
  <InvitationView
    v-if="invite"
    :invite="invite"
    :submitting="submitting"
    :submitted="submitted"
    :song-submitting="songSubmitting"
    @submit-generic="fakeRsvp"
    @submit-named="fakeRsvp"
    @submit-song="fakeSong"
  />
  <div v-else class="font-ui grid min-h-dvh place-items-center bg-limestone p-6 text-center text-sm text-obsidian/55">
    {{ failed ? 'No se pudo cargar la invitación de ejemplo.' : 'Cargando…' }}
  </div>
</template>
