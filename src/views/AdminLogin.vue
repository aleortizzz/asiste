<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'

const router = useRouter()
const { login, sendPasswordReset } = useAuth()

const mode = ref('login') // 'login' | 'reset'
const email = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)
const resetSent = ref(false)

async function onSubmit() {
  error.value = ''
  loading.value = true
  try {
    await login(email.value, password.value)
    router.push({ name: 'admin-dashboard' })
  } catch (err) {
    error.value = 'Email o contraseña incorrectos'
  } finally {
    loading.value = false
  }
}

async function onReset() {
  error.value = ''
  loading.value = true
  try {
    await sendPasswordReset(email.value)
    resetSent.value = true
  } catch (err) {
    error.value = err.message || 'No se pudo enviar el email'
  } finally {
    loading.value = false
  }
}

function showReset() {
  mode.value = 'reset'
  error.value = ''
  resetSent.value = false
}

function showLogin() {
  mode.value = 'login'
  error.value = ''
}
</script>

<template>
  <div class="flex min-h-screen items-center justify-center bg-gray-50">
    <form
      v-if="mode === 'login'"
      @submit.prevent="onSubmit"
      class="w-full max-w-sm space-y-4 rounded-lg bg-white p-8 shadow"
    >
      <h1 class="text-2xl font-semibold">Ingresar</h1>

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

      <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

      <button
        type="submit"
        :disabled="loading"
        class="w-full rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50"
      >
        {{ loading ? 'Ingresando...' : 'Ingresar' }}
      </button>

      <button
        type="button"
        @click="showReset"
        class="w-full text-center text-sm text-blue-600 underline"
      >
        ¿Olvidaste tu contraseña?
      </button>

      <p class="text-center text-sm text-gray-500">
        ¿No tenés cuenta?
        <router-link :to="{ name: 'admin-signup' }" class="text-blue-600 underline">Registrate</router-link>
      </p>
    </form>

    <div v-else class="w-full max-w-sm space-y-4 rounded-lg bg-white p-8 shadow">
      <h1 class="text-2xl font-semibold">Recuperar contraseña</h1>

      <div v-if="resetSent" class="text-sm text-gray-700">
        Si el email está registrado, te mandamos un link para restablecer la contraseña.
        Revisá tu casilla (y el spam).
      </div>

      <form v-else @submit.prevent="onReset" class="space-y-4">
        <p class="text-sm text-gray-500">
          Ingresá tu email y te mandamos un link para crear una contraseña nueva.
        </p>

        <div>
          <label class="block text-sm font-medium text-gray-700">Email</label>
          <input
            v-model="email"
            type="email"
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
          {{ loading ? 'Enviando...' : 'Enviar link' }}
        </button>
      </form>

      <button
        type="button"
        @click="showLogin"
        class="w-full text-center text-sm text-blue-600 underline"
      >
        Volver a ingresar
      </button>
    </div>
  </div>
</template>
