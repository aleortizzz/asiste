<script setup>
import { computed } from 'vue'
import ClasicoTemplate from './invitation-templates/ClasicoTemplate.vue'
import PartifulTemplate from './invitation-templates/PartifulTemplate.vue'
import CraftTemplate from './invitation-templates/CraftTemplate.vue'

// Selector de plantilla visual: `invite.template` decide qué componente
// renderizar. Este archivo no tiene lógica propia ni presentación — solo
// elige entre las plantillas de src/components/invitation-templates/, que
// comparten el mismo contrato de props/emits (y la misma lógica, vía
// useInvitationLogic). Agregar una plantilla nueva es agregarla acá.
const TEMPLATES = {
  clasico: ClasicoTemplate,
  partiful: PartifulTemplate,
  craft: CraftTemplate,
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
</script>

<template>
  <component
    :is="templateComponent"
    :invite="invite"
    :preview="preview"
    :submitting="submitting"
    :submitted="submitted"
    :error="error"
    :song-submitting="songSubmitting"
    :song-error="songError"
    @submit-generic="$emit('submit-generic', $event)"
    @submit-named="$emit('submit-named', $event)"
    @submit-song="$emit('submit-song', $event)"
  />
</template>
