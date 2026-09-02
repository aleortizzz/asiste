import { ref } from 'vue'
import { supabase } from '../lib/supabase'

// Definidos fuera de useAuth() a propósito: así son "singleton" y todos los
// componentes que llamen useAuth() comparten el mismo estado de sesión.
// Si estuvieran adentro de la función, cada componente tendría su propia copia.
const user = ref(null)
const loading = ref(true)
// Se pone en true cuando el usuario entra desde el link de "recuperar contraseña".
// App.vue lo observa y lo manda a la pantalla de nueva contraseña, sin importar
// a qué ruta lo haya redirigido Supabase.
const recovering = ref(false)

supabase.auth.getSession().then(({ data }) => {
  user.value = data.session?.user ?? null
  loading.value = false
})

// El token de recuperación llega en el hash de la URL (#type=recovery&...).
// Lo detectamos apenas carga la app, antes de que onAuthStateChange lo limpie.
if (typeof window !== 'undefined' && window.location.hash.includes('type=recovery')) {
  recovering.value = true
}

supabase.auth.onAuthStateChange((event, session) => {
  user.value = session?.user ?? null
  if (event === 'PASSWORD_RECOVERY') {
    recovering.value = true
  }
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

// Manda el email con el link para restablecer la contraseña. El link lleva
// a /admin/nueva-contrasena, donde el usuario define la contraseña nueva.
async function sendPasswordReset(email) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/admin/nueva-contrasena`,
  })
  if (error) throw error
}

async function updatePassword(newPassword) {
  const { error } = await supabase.auth.updateUser({ password: newPassword })
  if (error) throw error
  recovering.value = false
}

export function useAuth() {
  return { user, loading, recovering, login, logout, sendPasswordReset, updatePassword }
}
