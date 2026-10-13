<script setup>
import { computed } from 'vue'
import ClasicoTemplate from './invitation-templates/ClasicoTemplate.vue'
import PartifulTemplate from './invitation-templates/PartifulTemplate.vue'
import CraftTemplate from './invitation-templates/CraftTemplate.vue'
import EjecutivaTemplate from './invitation-templates/EjecutivaTemplate.vue'

// Selector de plantilla visual: `invite.template` decide qué componente
// renderizar. Este archivo no tiene lógica propia ni presentación — solo
// elige entre las plantillas de src/components/invitation-templates/, que
// comparten el mismo contrato de props/emits (y la misma lógica, vía
// useInvitationLogic). Agregar una plantilla nueva es agregarla acá.
// 'craft-v2' queda mapeada a la misma Craft por si algún evento de prueba
// quedó con ese valor guardado (Craft ya es la versión pulida).
const TEMPLATES = {
  clasico: ClasicoTemplate,
  partiful: PartifulTemplate,
  craft: CraftTemplate,
  'craft-v2': CraftTemplate,
  ejecutiva: EjecutivaTemplate,
}

const props = defineProps({
  invite: { type: Object, required: true },
  preview: { type: Boolean, default: false },
  submitting: { type: Boolean, default: false },
  submitted: { type: Boolean, default: false },
  error: { type: String, default: '' },
  songSubmitting: { type: Boolean, default: false },
  songError: { type: String, default: '' },
})

defineEmits(['submit-generic', 'submit-named', 'submit-song'])

const templateComponent = computed(() => TEMPLATES[props.invite?.template] || ClasicoTemplate)

// Prueba gratis: un cartel fijo arriba (también sobre el sobre), en todas las
// plantillas. Se va al elegir un plan. Ver migrations/20261013_planes.sql.
const isTrial = computed(() => props.invite?.plan === 'gratis')
</script>

<template>
  <a
    v-if="isTrial"
    href="https://asiste.tizdigital.com"
    target="_blank"
    rel="noopener"
    class="fixed inset-x-0 top-0 z-[300] block bg-[#4e1f6e] px-4 py-2 text-center text-xs font-bold tracking-wide text-white"
    style="font-family: 'DM Sans', ui-sans-serif, system-ui, sans-serif"
  >
    Invitación de prueba · Creada con Asiste
  </a>
  <component
    :is="templateComponent"
    :invite="invite"
    :preview="preview"
    :submitting="submitting"
    :submitted="submitted"
    :error="error"
    :song-submitting="songSubmitting"
    :song-error="songError"
    @submit-generic="(...args) => $emit('submit-generic', ...args)"
    @submit-named="$emit('submit-named', $event)"
    @submit-song="$emit('submit-song', $event)"
  />
</template>
