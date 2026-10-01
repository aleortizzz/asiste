<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { MailCheck } from '@lucide/vue'
import AuthLayout from '../components/AuthLayout.vue'
import FormField from '../components/FormField.vue'
import PasswordInput from '../components/PasswordInput.vue'
import { supabase } from '../lib/supabase'
import { authErrorMessage } from '../lib/authErrors'
import {
  useFormValidation,
  emailError,
  newPasswordError,
  confirmPasswordError,
  MIN_PASSWORD,
} from '../composables/useFormValidation'

const router = useRouter()
const email = ref('')
const password = ref('')
const confirmPassword = ref('')
const error = ref('') // errores del servidor (mail ya registrado, etc.)
const loading = ref(false)
const done = ref(false)

const form = useFormValidation({
  email: { id: 'signup-email', check: () => emailError(email.value) },
  password: { id: 'signup-password', check: () => newPasswordError(password.value) },
  confirm: { id: 'signup-confirm', check: () => confirmPasswordError(password.value, confirmPassword.value) },
})

async function onSubmit() {
  error.value = ''
  if (!form.validate()) return

  loading.value = true
  const { data, error: err } = await supabase.auth.signUp({
    email: email.value.trim(),
    password: password.value,
  })
  if (err) {
    error.value = authErrorMessage(err, 'No se pudo crear la cuenta. Probá de nuevo en un rato.')
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
  <AuthLayout title="Creá tu cuenta" :subtitle="done ? '' : 'En unos minutos tenés tu invitación lista para mandar.'">
    <div v-if="done" class="flex items-start gap-4 rounded-[1.5rem] bg-chalk p-5">
      <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-go/25">
        <MailCheck :size="20" />
      </span>
      <p class="text-sm leading-relaxed">
        Te mandamos un mail a <strong>{{ email.trim() }}</strong> para confirmar tu cuenta. Tocá el link del mail y
        después ingresá. Si no lo ves, fijate en spam.
      </p>
    </div>

    <form v-else @submit.prevent="onSubmit" novalidate class="space-y-5">
      <FormField id="signup-email" label="Mail" :error="form.errorFor('email')" v-slot="{ a11y }">
        <input
          v-bind="a11y"
          v-model="email"
          type="email"
          inputmode="email"
          autocomplete="email"
          placeholder="nombre@gmail.com"
          @blur="form.touch('email', email)"
          class="admin-input"
        />
      </FormField>

      <FormField
        id="signup-password"
        label="Contraseña"
        :help="`Al menos ${MIN_PASSWORD} caracteres.`"
        :error="form.errorFor('password')"
        v-slot="{ a11y }"
      >
        <PasswordInput v-bind="a11y" v-model="password" autocomplete="new-password" @blur="form.touch('password', password)" />
      </FormField>

      <FormField id="signup-confirm" label="Repetir contraseña" :error="form.errorFor('confirm')" v-slot="{ a11y }">
        <PasswordInput
          v-bind="a11y"
          v-model="confirmPassword"
          autocomplete="new-password"
          @blur="form.touch('confirm', confirmPassword)"
        />
      </FormField>

      <p v-if="error" class="rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold" role="alert">{{ error }}</p>

      <button type="submit" :disabled="loading" class="admin-btn-primary w-full">
        {{ loading ? 'Creando cuenta…' : 'Crear cuenta' }}
      </button>
    </form>

    <template #footer>
      <template v-if="done">
        <router-link :to="{ name: 'admin-login' }" class="font-bold text-chalk underline underline-offset-4">Ir a ingresar</router-link>
      </template>
      <template v-else>
        ¿Ya tenés cuenta?
        <router-link :to="{ name: 'admin-login' }" class="font-bold text-chalk underline underline-offset-4">Ingresá</router-link>
      </template>
    </template>
  </AuthLayout>
</template>
