<script setup>
import { ref, watch } from 'vue'

// Selector de color del admin: círculos con colores sugeridos + campo para
// pegar un hex. El campo tiene su propio buffer para poder escribir
// libremente y solo aplica cuando el valor es un color válido (#rrggbb).
const props = defineProps({
  modelValue: { type: String, default: '' },
  presets: { type: Array, required: true },
  // Sección de la vista previa a la que se desliza al tocarlo (data-preview).
  preview: { type: String, default: undefined },
  name: { type: String, default: 'Color' },
})
const emit = defineEmits(['update:modelValue'])

const hex = ref(props.modelValue)
watch(
  () => props.modelValue,
  (v) => {
    if (v !== hex.value) hex.value = v
  },
)
watch(hex, (v) => {
  if (/^#[0-9a-fA-F]{6}$/.test(v)) emit('update:modelValue', v.toLowerCase())
})
</script>

<template>
  <div>
    <div class="flex flex-wrap gap-2.5">
      <button
        v-for="c in presets"
        :key="c"
        type="button"
        :data-preview="preview"
        @click="emit('update:modelValue', c)"
        :style="{ backgroundColor: c }"
        :class="
          modelValue?.toLowerCase() === c
            ? 'ring-2 ring-obsidian ring-offset-2 ring-offset-limestone'
            : 'ring-1 ring-obsidian/15'
        "
        :aria-label="`${name} ${c}`"
        class="h-9 w-9 rounded-full transition-transform active:scale-90"
      ></button>
    </div>
    <div class="mt-3 flex items-center gap-2">
      <span class="h-10 w-10 shrink-0 rounded-full ring-1 ring-obsidian/15" :style="{ backgroundColor: modelValue }"></span>
      <input
        v-model="hex"
        :data-preview="preview"
        maxlength="7"
        spellcheck="false"
        :aria-label="`${name} (código hex)`"
        placeholder="#000000"
        class="admin-input !w-36 font-mono uppercase"
      />
      <slot />
    </div>
  </div>
</template>
