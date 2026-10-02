<script setup>
// Interruptor «mostrar / ocultar esta sección en la invitación» del editor.
// Mismo diseño que los de las secciones de fotos.
defineProps({
  label: { type: String, required: true },
  help: { type: String, default: '' },
  on: { type: Boolean, required: true },
  disabled: { type: Boolean, default: false },
})
defineEmits(['toggle'])
</script>

<template>
  <div class="flex items-center justify-between gap-4 rounded-[1.5rem] bg-chalk px-4 py-3.5" :class="{ 'opacity-60': disabled }">
    <div class="min-w-0">
      <p class="text-sm font-bold">{{ label }}</p>
      <p v-if="help" class="text-xs leading-snug text-obsidian/55">{{ help }}</p>
    </div>
    <button
      type="button"
      role="switch"
      :aria-checked="on"
      :aria-label="label"
      :disabled="disabled"
      @click="$emit('toggle')"
      :class="on ? 'bg-accent' : 'bg-obsidian/20'"
      class="relative h-7 w-12 shrink-0 rounded-full transition-colors"
    >
      <span class="absolute top-1 left-1 h-5 w-5 rounded-full bg-chalk transition-transform" :class="on ? 'translate-x-5' : ''"></span>
    </button>
  </div>
</template>
