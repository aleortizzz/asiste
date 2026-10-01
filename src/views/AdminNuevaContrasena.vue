<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Check } from '@lucide/vue'
import AuthLayout from '../components/AuthLayout.vue'
import FormField from '../components/FormField.vue'
import PasswordInput from '../components/PasswordInput.vue'
import { useAuth } from '../composables/useAuth'
import { authErrorMessage } from '../lib/authErrors'
import {
  useFormValidation,
  newPasswordError,
  confirmPasswordError,
  MIN_PASSWORD,
} from '../composables/useFormValidation'

const router = useRouter()
const { updatePassword } = useAuth()

const password = ref('')
const confirmPassword = ref('')
const error = ref('') // errores del servidor (link vencido, etc.)
const loading = ref(false)
const done = ref(false)

const form = useFormValidation({
  password: { id: 'new-password', check: () => newPasswordError(password.value) },
  confirm: { id: 'new-password-confirm', check: () => confirmPasswordError(password.value, confirmPassword.value) },
})

async function onSubmit() {
  error.value = ''
  if (!form.validate()) return

  loading.value = true
  try {
    await updatePassword(password.value)
    done.value = true
    setTimeout(() => router.push({ name: 'admin-dashboard' }), 1500)
  } catch (err) {
    error.value = authErrorMessage(err, 'No se pudo cambiar la contraseña. Pedí un link nuevo desde «¿Te la olvidaste?».')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthLayout title="Nueva contraseña" :subtitle="done ? '' : 'Elegí la contraseña que vas a usar de ahora en más.'">
    <div v-if="done" class="flex items-center gap-4 rounded-[1.5rem] bg-chalk p-5">
      <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-go/25">
        <Check :size="20" />
      </span>
      <p class="text-sm leading-relaxed">Listo, tu contraseña quedó cambiada. Te llevamos al panel…</p>
    </div>

    <form v-else @submit.prevent="onSubmit" novalidate class="space-y-5">
      <FormField
        id="new-password"
        label="Contraseña nueva"
        :help="`Al menos ${MIN_PASSWORD} caracteres.`"
        :error="form.errorFor('password')"
        v-slot="{ a11y }"
      >
        <PasswordInput v-bind="a11y" v-model="password" autocomplete="new-password" @blur="form.touch('password', password)" />
      </FormField>

      <FormField id="new-password-confirm" label="Repetir contraseña" :error="form.errorFor('confirm')" v-slot="{ a11y }">
        <PasswordInput
          v-bind="a11y"
          v-model="confirmPassword"
          autocomplete="new-password"
          @blur="form.touch('confirm', confirmPassword)"
        />
      </FormField>

      <p v-if="error" class="rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold" role="alert">{{ error }}</p>

      <button type="submit" :disabled="loading" class="admin-btn-primary w-full">
        {{ loading ? 'Guardando…' : 'Guardar contraseña' }}
      </button>
    </form>

    <template v-if="!done" #footer>
      <router-link :to="{ name: 'admin-login' }" class="font-bold text-chalk underline underline-offset-4">Volver a ingresar</router-link>
    </template>
  </AuthLayout>
</template>
