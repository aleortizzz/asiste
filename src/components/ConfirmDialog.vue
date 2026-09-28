<script setup>
import { ref, watch, nextTick, onMounted, onUnmounted } from 'vue'
import { useConfirmState } from '../composables/useConfirm'

// Se monta una sola vez en App.vue; se abre con confirmDialog() (ver
// composables/useConfirm.js).
const { state, answer } = useConfirmState()
const confirmBtn = ref(null)

// Foco en el botón principal al abrir: Enter confirma, Escape cancela.
watch(state, async (s) => {
  if (s) {
    await nextTick()
    confirmBtn.value?.focus()
  }
})

function onKey(e) {
  if (state.value && e.key === 'Escape') answer(false)
}
onMounted(() => window.addEventListener('keydown', onKey))
onUnmounted(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <Transition name="cd">
    <div
      v-if="state"
      class="font-ui fixed inset-0 z-[80] flex items-end justify-center bg-obsidian/40 p-4 backdrop-blur-[2px] sm:items-center"
      @click.self="answer(false)"
    >
      <div
        role="alertdialog"
        aria-modal="true"
        :aria-label="state.title"
        class="cd-card w-full max-w-sm rounded-[2rem] bg-limestone p-6 text-obsidian sm:p-7"
      >
        <h2 class="admin-display text-3xl">{{ state.title }}</h2>
        <p v-if="state.message" class="mt-3 text-[0.95rem] leading-relaxed text-obsidian/65">{{ state.message }}</p>
        <div class="mt-6 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <button type="button" @click="answer(false)" class="admin-btn-secondary">
            {{ state.cancelText }}
          </button>
          <button
            ref="confirmBtn"
            type="button"
            @click="answer(true)"
            :class="state.tone === 'danger' ? '!bg-nogo !text-chalk' : ''"
            class="admin-btn-primary"
          >
            {{ state.confirmText }}
          </button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.cd-enter-active,
.cd-leave-active {
  transition: opacity 180ms ease;
}
.cd-enter-active .cd-card,
.cd-leave-active .cd-card {
  transition: transform 220ms cubic-bezier(0.23, 1, 0.32, 1), opacity 180ms ease;
}
.cd-enter-from,
.cd-leave-to {
  opacity: 0;
}
.cd-enter-from .cd-card,
.cd-leave-to .cd-card {
  transform: translateY(12px) scale(0.97);
  opacity: 0;
}
@media (prefers-reduced-motion: reduce) {
  .cd-enter-active .cd-card,
  .cd-leave-active .cd-card {
    transition: opacity 180ms ease;
  }
  .cd-enter-from .cd-card,
  .cd-leave-to .cd-card {
    transform: none;
  }
}
</style>
