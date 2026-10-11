<script setup>
import { ref, onMounted } from 'vue'
import { Plus, X, CircleCheck, Circle } from '@lucide/vue'

// Formulario de una pregunta de la trivia (AdminJuego.vue): el texto, de 2 a
// 4 opciones y cuál es la correcta. Edita el objeto que recibe en `model`
// ({ question, options, correct_index }); guardar lo resuelve la pantalla.
const model = defineModel({ type: Object, required: true })
defineProps({
  number: { type: Number, required: true },
  error: { type: String, default: '' },
  saving: { type: Boolean, default: false },
  submitText: { type: String, default: 'Guardar' },
  cancelText: { type: String, default: 'Cancelar' },
})
const emit = defineEmits(['save', 'cancel'])

const LETTERS = ['A', 'B', 'C', 'D']
const questionInput = ref(null)
onMounted(() => questionInput.value?.focus())

function addOption() {
  if (model.value.options.length < 4) model.value.options.push('')
}

function removeOption(i) {
  const m = model.value
  if (m.options.length <= 2) return
  m.options.splice(i, 1)
  if (m.correct_index === i) m.correct_index = 0
  else if (m.correct_index > i) m.correct_index--
}
</script>

<template>
  <form @submit.prevent="emit('save')" class="rounded-[1.5rem] bg-chalk p-4 ring-2 ring-accent sm:p-5">
    <p class="mb-2 text-sm font-bold text-obsidian/50">Pregunta {{ number }}</p>
    <textarea
      ref="questionInput"
      v-model="model.question"
      rows="2"
      maxlength="300"
      placeholder="¿Cuál es la comida favorita de Anto?"
      class="admin-input !bg-limestone"
    ></textarea>
    <p class="admin-help mt-3">Tocá el círculo de la opción correcta.</p>
    <div class="space-y-2">
      <div v-for="(_, j) in model.options" :key="j" class="flex items-center gap-2">
        <button
          type="button"
          @click="model.correct_index = j"
          :aria-label="`Marcar la opción ${LETTERS[j]} como correcta`"
          :aria-pressed="model.correct_index === j"
          class="grid h-9 w-9 shrink-0 place-items-center rounded-full transition-colors"
          :class="model.correct_index === j ? 'bg-go text-obsidian' : 'text-obsidian/35 hover:bg-limestone'"
        >
          <CircleCheck v-if="model.correct_index === j" :size="20" />
          <Circle v-else :size="20" />
        </button>
        <input
          v-model="model.options[j]"
          type="text"
          maxlength="120"
          :placeholder="`Opción ${LETTERS[j]}`"
          class="admin-input !bg-limestone !py-2"
        />
        <button
          v-if="model.options.length > 2"
          type="button"
          @click="removeOption(j)"
          :aria-label="`Quitar la opción ${LETTERS[j]}`"
          class="grid h-9 w-9 shrink-0 place-items-center rounded-full text-obsidian/45 hover:bg-limestone"
        >
          <X :size="16" />
        </button>
      </div>
    </div>
    <button
      v-if="model.options.length < 4"
      type="button"
      @click="addOption"
      class="mt-2 ml-11 inline-flex items-center gap-1 text-sm font-bold text-accent"
    >
      <Plus :size="15" /> Agregar opción
    </button>
    <p v-if="error" class="mt-3 rounded-[1rem] bg-nogo/15 px-3 py-2 text-sm font-bold">{{ error }}</p>
    <div class="mt-4 flex flex-wrap justify-end gap-2">
      <button type="button" @click="emit('cancel')" class="admin-btn-secondary !py-2">{{ cancelText }}</button>
      <button type="submit" :disabled="saving" class="admin-btn-primary !py-2">
        {{ saving ? 'Guardando…' : submitText }}
      </button>
    </div>
  </form>
</template>
