<script setup>
import { computed } from 'vue'
import { CircleAlert } from '@lucide/vue'

// Etiqueta + ayuda + campo + mensaje de error. El campo va por slot y recibe
// los atributos de accesibilidad ya armados: `<template #default="{ a11y }">
// <input v-bind="a11y" …>`. Así el lector de pantalla lee el error junto
// con el campo, y el borde se pone rojo (ver .admin-input[aria-invalid]).
const props = defineProps({
  id: { type: String, required: true },
  label: { type: String, required: true },
  help: { type: String, default: '' },
  error: { type: String, default: '' },
})

const errorId = computed(() => `${props.id}-error`)
const helpId = computed(() => `${props.id}-help`)
const a11y = computed(() => ({
  id: props.id,
  'aria-invalid': props.error ? 'true' : 'false',
  'aria-describedby': [props.help && helpId.value, props.error && errorId.value].filter(Boolean).join(' ') || undefined,
}))
</script>

<template>
  <div>
    <div class="flex items-baseline justify-between gap-3">
      <label class="admin-label" :for="id">{{ label }}</label>
      <slot name="aside" />
    </div>
    <p v-if="help" :id="helpId" class="admin-help">{{ help }}</p>
    <slot :a11y="a11y" />
    <p v-if="error" :id="errorId" class="mt-2 flex items-start gap-1.5 px-1 text-sm font-bold text-nogo-ink" role="alert">
      <CircleAlert :size="15" class="mt-0.5 shrink-0" />
      {{ error }}
    </p>
  </div>
</template>
