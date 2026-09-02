<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'

const router = useRouter()
const { updatePassword } = useAuth()

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
  try {
    await updatePassword(password.value)
    done.value = true
    setTimeout(() => router.push({ name: 'admin-dashboard' }), 1500)
  } catch (err) {
    error.value =
      err.message ||
      'No se pudo cambiar la contraseña. Pedí un link nuevo desde "¿Olvidaste tu contraseña?".'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="flex min-h-screen items-center justify-center bg-gray-50">
    <div class="w-full max-w-sm rounded-lg bg-white p-8 shadow">
      <h1 class="text-2xl font-semibold">Nueva contraseña</h1>

      <div v-if="done" class="mt-6 text-sm text-gray-700">
        Listo, tu contraseña quedó actualizada. Te llevamos al panel...
      </div>

      <form v-else @submit.prevent="onSubmit" class="mt-6 space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Contraseña nueva</label>
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
          {{ loading ? 'Guardando...' : 'Guardar contraseña' }}
        </button>
      </form>

      <p class="mt-4 text-center text-sm text-gray-500">
        <router-link :to="{ name: 'admin-login' }" class="text-blue-600 underline">Volver a ingresar</router-link>
      </p>
    </div>
  </div>
</template>
