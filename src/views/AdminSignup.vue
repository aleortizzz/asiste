<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'

const router = useRouter()
const email = ref('')
const password = ref('')
const confirmPassword = ref('')
const error = ref('')
const loading = ref(false)
const done = ref(false)

async function onSubmit() {
  error.value = ''

  if (password.value !== confirmPassword.value) {
    error.value = 'Las contraseñas no coinciden.'
    return
  }
  if (password.value.length < 6) {
    error.value = 'La contraseña debe tener al menos 6 caracteres.'
    return
  }

  loading.value = true
  const { data, error: err } = await supabase.auth.signUp({
    email: email.value,
    password: password.value,
  })
  if (err) {
    error.value = err.message
  } else if (data.session) {
    // Si el proyecto tiene desactivada la confirmación por email,
    // signUp ya devuelve una sesión activa — no hace falta esperar nada.
    router.push({ name: 'admin-dashboard' })
  } else {
    done.value = true
  }
  loading.value = false
}
</script>

<template>
  <div class="flex min-h-screen items-center justify-center bg-gray-50">
    <div class="w-full max-w-sm rounded-lg bg-white p-8 shadow">
      <h1 class="text-2xl font-semibold">Creá tu cuenta</h1>

      <div v-if="done" class="mt-6 text-sm text-gray-700">
        Te mandamos un email para confirmar tu cuenta. Una vez confirmada, ya podés
        <router-link :to="{ name: 'admin-login' }" class="text-blue-600 underline">iniciar sesión</router-link>.
      </div>

      <form v-else @submit.prevent="onSubmit" class="mt-6 space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Email</label>
          <input
            v-model="email"
            type="email"
            required
            class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Contraseña</label>
          <input
            v-model="password"
            type="password"
            required
            class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Repetir contraseña</label>
          <input
            v-model="confirmPassword"
            type="password"
            required
            class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
          />
        </div>

        <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

        <button
          type="submit"
          :disabled="loading"
          class="w-full rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50"
        >
          {{ loading ? 'Creando cuenta...' : 'Crear cuenta' }}
        </button>
      </form>

      <p class="mt-4 text-center text-sm text-gray-500">
        ¿Ya tenés cuenta?
        <router-link :to="{ name: 'admin-login' }" class="text-blue-600 underline">Iniciar sesión</router-link>
      </p>
    </div>
  </div>
</template>
