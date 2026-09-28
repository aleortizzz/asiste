import { ref } from 'vue'

// Diálogo de confirmación propio (reemplaza al confirm() del navegador, que
// no se puede estilizar). Estado singleton — mismo patrón que useAuth — y un
// solo <ConfirmDialog /> montado en App.vue.
//
//   const ok = await confirmDialog({ title: '¿Eliminar?', message: '…', tone: 'danger' })
//   if (!ok) return
const state = ref(null) // { title, message, confirmText, cancelText, tone, resolve } | null

export function confirmDialog({ title, message = '', confirmText = 'Confirmar', cancelText = 'Cancelar', tone = 'default' }) {
  // Si había uno abierto (no debería), lo damos por cancelado.
  state.value?.resolve(false)
  return new Promise((resolve) => {
    state.value = { title, message, confirmText, cancelText, tone, resolve }
  })
}

export function useConfirmState() {
  function answer(value) {
    const s = state.value
    state.value = null
    s?.resolve(value)
  }
  return { state, answer }
}
