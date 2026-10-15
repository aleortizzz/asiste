import { ref } from 'vue'
import { supabase } from '../lib/supabase'

// Datos que comparten las pestañas de Superadmin: todos los eventos (Clientes
// los lista; Pagos los usa para mostrar mail y evento de cada pago) y las
// cuentas que se registraron sin armar la invitación (Registros).
// Singleton como useEvent: cambiar de pestaña no los vuelve a pedir.
const rows = ref([])
const pendingAccounts = ref([])
const loading = ref(false)
const error = ref('')
let loaded = null

function load(force = false) {
  if (!loaded || force) {
    loading.value = true
    loaded = Promise.all([
      supabase.rpc('listar_eventos_superadmin'),
      supabase.rpc('listar_cuentas_sin_evento_superadmin'),
    ]).then(([ev, acc]) => {
      error.value = ev.error?.message ?? ''
      if (!ev.error) rows.value = ev.data ?? []
      if (!acc.error) pendingAccounts.value = acc.data ?? []
      loading.value = false
    })
  }
  return loaded
}

export function useSuperadmin() {
  return { rows, pendingAccounts, loading, error, load }
}
