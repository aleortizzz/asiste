<script setup>
// «Continuar con Google»: sirve igual para ingresar y para crear la cuenta
// (si el mail no tiene cuenta, Supabase la crea sola).
//
// Dos caminos:
//  1. Con VITE_GOOGLE_CLIENT_ID (el normal): el botón oficial de Google
//     («Sign in with Google»). Google abre su ventanita desde asiste.tizdigital.com
//     y muestra «Asiste» y este dominio. Nos da un token y se lo pasamos a
//     Supabase (signInWithIdToken). Sin pasar por xxxx.supabase.co, que en la
//     pantalla de Google daba desconfianza.
//  2. Sin esa variable (respaldo): signInWithOAuth, que va a Google pasando por
//     Supabase. Funciona, pero Google muestra «yxcw….supabase.co».
//
// Configuración:
//   - Google Cloud → Clientes → «Asiste web»: el sitio en «Orígenes de JavaScript autorizados».
//   - Supabase → Authentication → Sign In / Providers → Google: el mismo Client ID.
//   - VITE_GOOGLE_CLIENT_ID en .env y en los secrets de GitHub (deploy.yml).
//   - Para el camino 2: Supabase → URL Configuration → Redirect URLs con el sitio y /**.
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { authErrorMessage } from '../lib/authErrors'

const props = defineProps({
  // A dónde va después de entrar (ruta del sitio, ej. '/admin').
  redirectPath: { type: String, default: '/admin' },
})

const CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID
const router = useRouter()
const loading = ref(false)
const error = ref('')
const googleSlot = ref(null) // acá dibuja Google su botón
const official = ref(false) // true cuando el botón oficial ya está dibujado

// --- Camino 1: botón oficial ---------------------------------------------------------
let gisPromise
function loadGis() {
  gisPromise ??= new Promise((resolve, reject) => {
    if (window.google?.accounts?.id) return resolve()
    const s = document.createElement('script')
    s.src = 'https://accounts.google.com/gsi/client'
    s.async = true
    s.onload = resolve
    s.onerror = reject
    document.head.appendChild(s)
  })
  return gisPromise
}

// El nonce viaja hasheado a Google y en crudo a Supabase, que compara los dos:
// así nadie puede reusar un token robado.
async function makeNonce() {
  const raw = crypto.randomUUID()
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(raw))
  const hashed = [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('')
  return { raw, hashed }
}

async function onCredential(response, rawNonce) {
  error.value = ''
  loading.value = true
  const { error: err } = await supabase.auth.signInWithIdToken({
    provider: 'google',
    token: response.credential,
    nonce: rawNonce,
  })
  loading.value = false
  if (err) {
    error.value = authErrorMessage(err, 'No se pudo entrar con Google. Probá de nuevo en un rato.')
    return
  }
  router.push(props.redirectPath)
}

onMounted(async () => {
  if (!CLIENT_ID) return
  try {
    await loadGis()
    const { raw, hashed } = await makeNonce()
    window.google.accounts.id.initialize({
      client_id: CLIENT_ID,
      nonce: hashed,
      callback: (r) => onCredential(r, raw),
      ux_mode: 'popup',
      use_fedcm_for_button: true,
    })
    window.google.accounts.id.renderButton(googleSlot.value, {
      type: 'standard',
      theme: 'outline',
      size: 'large',
      shape: 'pill',
      text: 'continue_with',
      logo_alignment: 'center',
      locale: 'es-419',
      width: Math.min(400, googleSlot.value.clientWidth || 320),
    })
    official.value = true
  } catch {
    // Si no carga el script de Google (bloqueador, sin red), queda el botón de respaldo.
  }
})

// --- Camino 2: respaldo por Supabase ------------------------------------------------
async function onFallbackClick() {
  error.value = ''
  loading.value = true
  const { error: err } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: `${window.location.origin}${props.redirectPath}` },
  })
  // Si salió bien, el navegador ya se está yendo a Google: no se apaga el «cargando».
  if (err) {
    error.value = authErrorMessage(err, 'No se pudo abrir Google. Probá de nuevo en un rato.')
    loading.value = false
  }
}
</script>

<template>
  <div>
    <!-- Botón oficial de Google (lo dibuja Google adentro de este div) -->
    <div v-show="official" ref="googleSlot" class="flex min-h-[44px] w-full justify-center" :class="{ 'opacity-60': loading }"></div>

    <button
      v-if="!official"
      type="button"
      :disabled="loading"
      @click="onFallbackClick"
      class="flex w-full items-center justify-center gap-3 rounded-full border border-obsidian/15 bg-white px-5 py-3.5 font-bold text-obsidian transition-colors hover:bg-chalk disabled:opacity-60"
    >
      <!-- La «G» de Google va con sus colores: lo piden sus normas de marca -->
      <svg viewBox="0 0 48 48" class="h-5 w-5 shrink-0" aria-hidden="true">
        <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z" />
        <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z" />
        <path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-8l-6.5 5C9.5 39.6 16.2 44 24 44z" />
        <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z" />
      </svg>
      {{ loading ? 'Abriendo Google…' : 'Continuar con Google' }}
    </button>
    <p v-if="loading && official" class="mt-2 text-center text-sm text-obsidian/55">Entrando…</p>
    <p v-if="error" class="mt-3 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold" role="alert">{{ error }}</p>

    <!-- Separador con el formulario de mail -->
    <div class="my-6 flex items-center gap-3 text-sm text-obsidian/45" aria-hidden="true">
      <span class="h-px flex-1 bg-obsidian/10"></span>
      o con tu mail
      <span class="h-px flex-1 bg-obsidian/10"></span>
    </div>
  </div>
</template>
