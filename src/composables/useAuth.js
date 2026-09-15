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
// Si la cuenta está en la tabla `superadmins`, puede entrar al panel de
// soporte y ver/gestionar el evento de cualquier cliente.
const isSuperadmin = ref(false)

async function refreshSuperadmin() {
  if (!user.value) {
    isSuperadmin.value = false
    return
  }
  const { data } = await supabase.rpc('soy_superadmin')
  isSuperadmin.value = !!data
}

// El router espera esto en vez de llamar a supabase.auth.getSession() por su
// cuenta en cada navegación: dos llamadas casi simultáneas en una carga en
// frío (entrar directo por URL) hacían que el cliente de Supabase se colgara
// a veces, dejando la página en blanco. Con un solo chequeo inicial acá, el
// router solo espera a que termine y lee el estado ya resuelto.
let resolveReady
const ready = new Promise((resolve) => {
  resolveReady = resolve
})

supabase.auth.getSession().then(async ({ data }) => {
  user.value = data.session?.user ?? null
  loading.value = false
  await refreshSuperadmin()
  resolveReady()
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
  if (event === 'SIGNED_IN' || event === 'SIGNED_OUT') {
    refreshSuperadmin()
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
  return {
    user,
    loading,
    recovering,
    isSuperadmin,
    ready,
    login,
    logout,
    sendPasswordReset,
    updatePassword,
  }
}
