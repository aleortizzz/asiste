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
    // No es el link de una familia: puede ser el link único que eligió el
    // organizador (plan Invitación, se confirma por WhatsApp).
    const { data: byLink } = await supabase.rpc('obtener_invitacion_link', { p_link: route.params.slug })
    if (byLink) invite.value = byLink
    else notFound.value = true
  } else {
    // Si el evento cierra las confirmaciones pasada la fecha límite (ver
    // migrations/20260928_cierre_confirmaciones.sql). Si la función no
    // existe o falla, la invitación se muestra igual que siempre.
    const { data: cierre } = await supabase.rpc('estado_confirmaciones', { p_slug: route.params.slug })
    invite.value = cierre ? { ...data, ...cierre } : data
  }
  loading.value = false
})

async function enviarGenerico(guestNames, detalles) {
  submitting.value = true
  error.value = ''
  // p_detalles solo si el evento pide datos extra (20261002_confirmacion_completa.sql):
  // así las invitaciones de siempre llaman a la función igual que antes.
  const { error: err } = await supabase.rpc('confirmar_asistencia', {
    p_slug: route.params.slug,
    p_guest_names: guestNames,
    ...(detalles?.length ? { p_detalles: detalles } : {}),
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

  <!-- Prueba gratis que llegó al tope de visitas o de horas (ver migrations/20261013_planes.sql) -->
  <div
    v-else-if="invite.locked"
    class="flex min-h-screen items-center justify-center px-6 text-center"
    :style="{ background: invite.bg_color || '#fdf7f1' }"
  >
    <div class="max-w-sm">
      <p class="text-sm tracking-[0.2em] uppercase opacity-60" :style="{ color: invite.primary_color || '#7c3aed' }">Invitación</p>
      <h1 class="mt-2 text-4xl" style="font-family: 'Playfair Display', serif" :style="{ color: invite.primary_color || '#7c3aed' }">
        {{ invite.hero_title || invite.event_name }}
      </h1>
      <p class="mt-6 text-lg text-black/70">Esta invitación todavía no está publicada.</p>
      <p class="mt-2 text-sm text-black/50">Si la armaste vos, entrá a tu panel y elegí un plan para mandársela a todos.</p>
    </div>
  </div>

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
