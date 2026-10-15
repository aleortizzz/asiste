<script setup>
import { ref, onMounted } from 'vue'
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
const plantilla = new URLSearchParams(window.location.search).get('plantilla')

onMounted(async () => {
  const { data, error } = await supabase.rpc('invitacion_demo')
  if (error || !data) failed.value = true
  else invite.value = PLANTILLAS.includes(plantilla) ? { ...data, template: plantilla } : data
})

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
