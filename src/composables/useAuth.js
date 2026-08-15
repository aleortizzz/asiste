import { ref } from 'vue'
import { supabase } from '../lib/supabase'

// Definidos fuera de useAuth() a propósito: así son "singleton" y todos los
// componentes que llamen useAuth() comparten el mismo estado de sesión.
// Si estuvieran adentro de la función, cada componente tendría su propia copia.
const user = ref(null)
const loading = ref(true)

supabase.auth.getSession().then(({ data }) => {
  user.value = data.session?.user ?? null
  loading.value = false
})

supabase.auth.onAuthStateChange((_event, session) => {
  user.value = session?.user ?? null
})

async function login(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw error
  user.value = data.user
}

async function logout() {
  await supabase.auth.signOut()
  user.value = null
}

export function useAuth() {
  return { user, loading, login, logout }
}
