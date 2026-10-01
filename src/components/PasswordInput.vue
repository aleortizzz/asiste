<script setup>
import { ref } from 'vue'
import { Eye, EyeOff } from '@lucide/vue'

// Campo de contraseña con botón para mostrarla: en el celular es fácil
// equivocarse tipeando sin ver. Los atributos (id, aria-*, autocomplete,
// @blur…) van al <input>, no al div de afuera.
defineOptions({ inheritAttrs: false })
const model = defineModel({ type: String, default: '' })
const visible = ref(false)
</script>

<template>
  <div class="relative">
    <input v-bind="$attrs" v-model="model" :type="visible ? 'text' : 'password'" class="admin-input !pr-14" />
    <button
      type="button"
      @click="visible = !visible"
      :aria-label="visible ? 'Ocultar contraseña' : 'Mostrar contraseña'"
      :aria-pressed="visible"
      class="absolute top-1/2 right-2 grid h-9 w-9 -translate-y-1/2 place-items-center rounded-full text-obsidian/50 transition-colors hover:bg-limestone hover:text-obsidian"
    >
      <EyeOff v-if="visible" :size="17" />
      <Eye v-else :size="17" />
    </button>
  </div>
</template>
