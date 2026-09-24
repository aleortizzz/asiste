<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import InvitationView from '../components/InvitationView.vue'

const route = useRoute()
const invite = ref(null)
const loading = ref(true)
const notFound = ref(false)
const error = ref('')
const submitting = ref(false)
const submitted = ref(false)
const songSubmitting = ref(false)
const songError = ref('')

onMounted(async () => {
  const { data, error: err } = await supabase.rpc('obtener_invitacion', { p_slug: route.params.slug })
  if (err || !data) {
    notFound.value = true
  } else {
    invite.value = data
  }
  loading.value = false
})

async function enviarGenerico(guestNames) {
  submitting.value = true
  error.value = ''
  const { error: err } = await supabase.rpc('confirmar_asistencia', {
    p_slug: route.params.slug,
    p_guest_names: guestNames,
  })
  if (err) error.value = err.message
  else submitted.value = true
  submitting.value = false
}

async function enviarNominales(respuestas) {
  submitting.value = true
  error.value = ''
  const { error: err } = await supabase.rpc('responder_invitados', {
    p_slug: route.params.slug,
    p_respuestas: respuestas,
  })
  if (err) error.value = err.message
  else submitted.value = true
  submitting.value = false
}

async function enviarCancion(payload) {
  songSubmitting.value = true
  songError.value = ''
  const { error: err } = await supabase.rpc('agregar_cancion_solicitada', {
    p_slug: route.params.slug,
    p_song_title: payload.songTitle,
    p_artist: payload.artist,
    p_youtube_video_id: payload.youtubeVideoId,
    p_requested_by: payload.requestedBy,
  })
  if (err) songError.value = err.message
  songSubmitting.value = false
}
</script>

<template>
  <p
    v-if="loading"
    class="flex min-h-screen items-center justify-center bg-[#fdf7f1] text-rose-900/50"
  >
    Cargando…
  </p>

  <p
    v-else-if="notFound"
    class="flex min-h-screen items-center justify-center bg-[#fdf7f1] px-6 text-center text-lg text-rose-900/70"
  >
    No encontramos esta invitación.
  </p>

  <InvitationView
    v-else
    :invite="invite"
    :submitting="submitting"
    :submitted="submitted"
    :error="error"
    :song-submitting="songSubmitting"
    :song-error="songError"
    @submit-generic="enviarGenerico"
    @submit-named="enviarNominales"
    @submit-song="enviarCancion"
  />
</template>
