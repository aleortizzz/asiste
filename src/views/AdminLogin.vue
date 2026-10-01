<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { MailCheck, ArrowLeft } from '@lucide/vue'
import AuthLayout from '../components/AuthLayout.vue'
import FormField from '../components/FormField.vue'
import PasswordInput from '../components/PasswordInput.vue'
import { useAuth } from '../composables/useAuth'
import { useFormValidation, emailError } from '../composables/useFormValidation'
import { authErrorMessage } from '../lib/authErrors'

const router = useRouter()
const { login, sendPasswordReset } = useAuth()

const mode = ref('login') // 'login' | 'reset'
const email = ref('')
const password = ref('')
const error = ref('') // errores del servidor (mail o contraseña incorrectos, etc.)
const loading = ref(false)
const resetSent = ref(false)

// Ingresar: la contraseña solo tiene que estar; el largo mínimo se valida al
// crearla, no acá (si no, alguien con una contraseña vieja no podría entrar).
const loginForm = useFormValidation({
  email: { id: 'login-email', check: () => emailError(email.value) },
  password: { id: 'login-password', check: () => (password.value ? '' : 'Escribí tu contraseña.') },
})

const resetForm = useFormValidation({
  email: { id: 'reset-email', check: () => emailError(email.value) },
})

async function onSubmit() {
  error.value = ''
  if (!loginForm.validate()) return
  loading.value = true
  try {
    await login(email.value.trim(), password.value)
    router.push({ name: 'admin-dashboard' })
  } catch (err) {
    error.value = authErrorMessage(err, 'Mail o contraseña incorrectos.')
  } finally {
    loading.value = false
  }
}

async function onReset() {
  error.value = ''
  if (!resetForm.validate()) return
  loading.value = true
  try {
    await sendPasswordReset(email.value.trim())
    resetSent.value = true
  } catch (err) {
    error.value = authErrorMessage(err, 'No se pudo mandar el mail. Probá de nuevo en un rato.')
  } finally {
    loading.value = false
  }
}

function showReset() {
  mode.value = 'reset'
  error.value = ''
  resetSent.value = false
  resetForm.reset()
}

function showLogin() {
  mode.value = 'login'
  error.value = ''
  loginForm.reset()
}
</script>

<template>
  <!-- Ingresar -->
  <AuthLayout v-if="mode === 'login'" title="Ingresar" subtitle="Entrá para armar tu invitación y ver quién confirma.">
    <form @submit.prevent="onSubmit" novalidate class="space-y-5">
      <FormField id="login-email" label="Mail" :error="loginForm.errorFor('email')" v-slot="{ a11y }">
        <input
          v-bind="a11y"
          v-model="email"
          type="email"
          inputmode="email"
          autocomplete="email"
          placeholder="nombre@gmail.com"
          @blur="loginForm.touch('email', email)"
          class="admin-input"
        />
      </FormField>

      <FormField id="login-password" label="Contraseña" :error="loginForm.errorFor('password')">
        <template #aside>
          <button type="button" @click="showReset" class="text-sm font-bold text-accent underline-offset-4 hover:underline">
            ¿Te la olvidaste?
          </button>
        </template>
        <template #default="{ a11y }">
          <PasswordInput v-bind="a11y" v-model="password" autocomplete="current-password" />
        </template>
      </FormField>

      <p v-if="error" class="rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold" role="alert">{{ error }}</p>

      <button type="submit" :disabled="loading" class="admin-btn-primary w-full">
        {{ loading ? 'Ingresando…' : 'Ingresar' }}
      </button>
    </form>

    <template #footer>
      ¿No tenés cuenta?
      <router-link :to="{ name: 'admin-signup' }" class="font-bold text-chalk underline underline-offset-4">Registrate</router-link>
    </template>
  </AuthLayout>

  <!-- Recuperar contraseña -->
  <AuthLayout
    v-else
    title="Recuperar contraseña"
    :subtitle="resetSent ? '' : 'Escribí tu mail y te mandamos un link para crear una contraseña nueva.'"
  >
    <div v-if="resetSent" class="flex items-start gap-4 rounded-[1.5rem] bg-chalk p-5">
      <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-go/25">
        <MailCheck :size="20" />
      </span>
      <p class="text-sm leading-relaxed">
        Si <strong>{{ email.trim() }}</strong> tiene una cuenta, te llega un mail con el link. Revisá también la carpeta de
        spam.
      </p>
    </div>

    <form v-else @submit.prevent="onReset" novalidate class="space-y-5">
      <FormField id="reset-email" label="Mail" :error="resetForm.errorFor('email')" v-slot="{ a11y }">
        <input
          v-bind="a11y"
          v-model="email"
          type="email"
          inputmode="email"
          autocomplete="email"
          placeholder="nombre@gmail.com"
          @blur="resetForm.touch('email', email)"
          class="admin-input"
        />
      </FormField>

      <p v-if="error" class="rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold" role="alert">{{ error }}</p>

      <button type="submit" :disabled="loading" class="admin-btn-primary w-full">
        {{ loading ? 'Enviando…' : 'Mandarme el link' }}
      </button>
    </form>

    <template #footer>
      <button type="button" @click="showLogin" class="inline-flex items-center gap-1.5 font-bold text-chalk">
        <ArrowLeft :size="15" /> Volver a ingresar
      </button>
    </template>
  </AuthLayout>
</template>
