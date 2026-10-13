<script setup>
import { ref, computed } from 'vue'

// Confirmación del plan Invitación: no se guarda nada, el invitado le manda
// un WhatsApp armado al organizador (invite.whatsapp). Va dentro de la
// sección «Confirmá tu asistencia» de cada plantilla, con el color de la
// invitación. Ver migrations/20261013_plan_invitacion.sql.
const props = defineProps({ invite: { type: Object, required: true } })

const name = ref('')
const count = ref(1)
const touched = ref(false)

const color = computed(() => props.invite.primary_color || '#7c3aed')
const evento = computed(() => {
  const titulo = (props.invite.hero_title || props.invite.event_name || '').trim()
  return props.invite.event_type === 'empresarial' ? titulo || 'el evento' : titulo ? `la fiesta de ${titulo}` : 'la fiesta'
})

function waLink(text) {
  return `https://wa.me/${props.invite.whatsapp}?text=${encodeURIComponent(text)}`
}
const yesText = computed(() => {
  const quien = name.value.trim()
  const cuantos = count.value === 1 ? 'voy' : `vamos ${count.value}`
  return `¡Hola! Soy ${quien} y confirmo que ${cuantos} a ${evento.value} 🎉`
})
const noText = computed(
  () => `¡Hola! Soy ${name.value.trim()}. No ${count.value === 1 ? 'voy' : 'vamos'} a poder ir a ${evento.value}, ¡gracias por la invitación!`,
)

// Sin nombre no abrimos WhatsApp: el organizador no sabría quién es.
function go(e) {
  touched.value = true
  if (!name.value.trim()) e.preventDefault()
}
</script>

<template>
  <div v-if="!invite.whatsapp" class="py-4 text-center text-sm opacity-70">
    Pronto vas a poder confirmar desde acá.
  </div>
  <div v-else class="mt-4 space-y-4 text-left">
    <div>
      <label for="rsvp-wa-name" class="mb-1 block text-sm font-semibold opacity-80">Tu nombre y apellido</label>
      <input
        id="rsvp-wa-name"
        v-model="name"
        autocomplete="name"
        placeholder="Ej. Lucas Romero"
        class="w-full rounded-xl border border-black/15 bg-white px-4 py-3 text-base text-black outline-none focus:border-black/40"
      />
      <p v-if="touched && !name.trim()" class="mt-1 text-sm text-red-600">Escribí tu nombre así saben quién confirma.</p>
    </div>

    <div class="flex items-center justify-between gap-3">
      <span class="text-sm font-semibold opacity-80">¿Cuántos van?</span>
      <div class="flex items-center gap-3">
        <button
          type="button"
          @click="count = Math.max(1, count - 1)"
          :disabled="count <= 1"
          aria-label="Uno menos"
          class="grid h-10 w-10 place-items-center rounded-full border border-black/15 bg-white text-lg font-bold text-black disabled:opacity-30"
        >
          −
        </button>
        <span class="w-6 text-center text-lg font-bold tabular-nums" aria-live="polite">{{ count }}</span>
        <button
          type="button"
          @click="count = Math.min(20, count + 1)"
          aria-label="Uno más"
          class="grid h-10 w-10 place-items-center rounded-full border border-black/15 bg-white text-lg font-bold text-black"
        >
          +
        </button>
      </div>
    </div>

    <a
      :href="waLink(yesText)"
      target="_blank"
      rel="noopener"
      @click="go"
      class="flex w-full items-center justify-center gap-2 rounded-full px-5 py-3.5 font-bold text-white"
      :style="{ background: color }"
    >
      <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" aria-hidden="true">
        <path d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2Zm5.4 14.2c-.2.6-1.3 1.2-1.8 1.2-.5.1-1 .2-3.4-.7-2.8-1.1-4.6-4-4.8-4.2-.1-.2-1.1-1.5-1.1-2.9 0-1.4.7-2 1-2.3.2-.3.5-.3.7-.3h.5c.2 0 .4 0 .6.5l.8 2c.1.2.1.4 0 .6l-.4.6-.4.4c-.1.2-.3.3-.1.6.2.3.8 1.3 1.7 2.1 1.2 1 2.1 1.4 2.4 1.5.3.1.5.1.6-.1l.9-1c.2-.3.4-.2.6-.1l1.9.9c.3.1.5.2.5.3.1.2.1.7-.1 1.2Z" />
      </svg>
      Confirmar por WhatsApp
    </a>
    <a
      :href="waLink(noText)"
      target="_blank"
      rel="noopener"
      @click="go"
      class="block w-full rounded-full border border-black/15 px-5 py-3 text-center text-sm font-semibold opacity-80"
    >
      No {{ count === 1 ? 'voy' : 'vamos' }} a poder ir
    </a>
    <p class="text-center text-xs opacity-60">Se abre WhatsApp con el mensaje listo para mandar.</p>
  </div>
</template>
