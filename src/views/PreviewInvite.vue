<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import InvitationView from '../components/InvitationView.vue'

// Vista que vive dentro del <iframe> del panel de edición. Recibe el borrador
// del evento por postMessage (en vivo mientras se edita) y también lo lee de
// sessionStorage por si se abre la ruta directamente en una pestaña.
const STORAGE_KEY = 'invite-preview-draft'
const draft = ref(null)

function readStorage() {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY)
    if (raw) draft.value = JSON.parse(raw)
  } catch {
    /* sessionStorage puede fallar en modo privado / iframe restringido */
  }
}

const prefersReducedMotion =
  window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true

function scrollToAnchor(anchor) {
  const el = document.querySelector(`[data-anchor="${anchor}"]`)
  if (!el) return
  // scrollIntoView() también desplaza los contenedores ancestros —incluida la
  // página que contiene el iframe— y hace saltar el formulario de la izquierda.
  // Movemos solo el scroll de este documento (el del iframe).
  const offset = anchor === 'rsvp' ? window.innerHeight * 0.2 : 0
  const top = el.getBoundingClientRect().top + window.scrollY - offset
  window.scrollTo({ top: Math.max(0, top), behavior: prefersReducedMotion ? 'auto' : 'smooth' })
}

function onMessage(e) {
  if (e.origin !== window.location.origin) return
  if (e.data?.type === 'invite-preview' && e.data.invite) {
    draft.value = e.data.invite
  }
  if (e.data?.type === 'invite-preview-scroll' && e.data.anchor) {
    scrollToAnchor(e.data.anchor)
  }
}

function onStorage(e) {
  if (e.key === STORAGE_KEY) readStorage()
}

onMounted(() => {
  readStorage()
  window.addEventListener('message', onMessage)
  window.addEventListener('storage', onStorage)
  // Avisa al panel que el iframe ya está listo para recibir el borrador.
  try {
    window.parent?.postMessage({ type: 'invite-preview-ready' }, window.location.origin)
  } catch {
    /* noop */
  }
})

onUnmounted(() => {
  window.removeEventListener('message', onMessage)
  window.removeEventListener('storage', onStorage)
})
</script>

<template>
  <InvitationView v-if="draft" :invite="draft" preview />
  <p v-else class="flex min-h-screen items-center justify-center bg-[#fdf7f1] text-sm text-stone-400">
    Cargando vista previa…
  </p>
</template>
