<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { MailCheck, Sparkles, PenSquare } from '@lucide/vue'
import AuthLayout from '../components/AuthLayout.vue'
import FormField from '../components/FormField.vue'
import PasswordInput from '../components/PasswordInput.vue'
import GoogleButton from '../components/GoogleButton.vue'
import { supabase } from '../lib/supabase'
import { authErrorMessage } from '../lib/authErrors'
import { PLANS, rememberChosenPlan, formatPrice } from '../lib/plans'
import { hasDraft } from '../lib/draft'
import {
  useFormValidation,
  emailError,
  newPasswordError,
  confirmPasswordError,
  MIN_PASSWORD,
} from '../composables/useFormValidation'

const router = useRouter()
// Viene de «Elegir Plus» en la landing: registrarse es el paso previo a
// pagar. Se muestra el plan, y al crear la cuenta va directo a Mercado Pago
// (se puede pagar antes de armar la invitación). Sin plan: prueba gratis.
const route = useRoute()
const plan = computed(() => (PLANS[route.query.plan]?.price ? route.query.plan : null))
rememberChosenPlan(plan.value)
// «Tu plan» con pagar=1 abre Mercado Pago sola.
const payRoute = computed(() => ({ name: 'admin-plan', query: { plan: plan.value, pagar: 1 } }))
// Armó una invitación sin cuenta (/crear): al entrar se pasa a la cuenta
// (lo hace el router, ver lib/draft.js). Acá solo se avisa.
const withDraft = hasDraft()
const email = ref('')
const password = ref('')
const confirmPassword = ref('') // la misma contraseña otra vez, para no crear la cuenta con un error de tipeo
const error = ref('') // errores del servidor (mail ya registrado, etc.)
const loading = ref(false)
const done = ref(false)

const form = useFormValidation({
  email: { id: 'signup-email', check: () => emailError(email.value) },
  password: { id: 'signup-password', check: () => newPasswordError(password.value) },
  confirm: { id: 'signup-password-confirm', check: () => confirmPasswordError(password.value, confirmPassword.value) },
})

async function onSubmit() {
  error.value = ''
  if (!form.validate()) return

  loading.value = true
  const { data, error: err } = await supabase.auth.signUp({
    email: email.value.trim(),
    password: password.value,
    // El link del mail de confirmación lo trae logueado directo a pagar.
    // (La URL tiene que estar en Supabase → Authentication → URL Configuration → Redirect URLs.)
    options: plan.value ? { emailRedirectTo: `${window.location.origin}${router.resolve(payRoute.value).fullPath}` } : {},
  })
  if (err) {
    error.value = authErrorMessage(err, 'No se pudo crear la cuenta. Probá de nuevo en un rato.')
  } else if (data.user && data.user.identities?.length === 0) {
    // Ese mail ya tiene cuenta. Supabase no lo dice con un error (para no
    // revelar qué mails están registrados) ni manda mail de confirmación:
    // devuelve un usuario sin identidades. Antes acá decíamos «te mandamos
    // un mail» y nunca llegaba nada.
    error.value = 'Ya hay una cuenta con ese mail. Ingresá, o si no te acordás la contraseña, recuperala desde «¿Te la olvidaste?».'
  } else if (data.session) {
    // Si el proyecto tiene desactivada la confirmación por email,
    // signUp ya devuelve una sesión activa — no hace falta esperar nada.
    router.push(plan.value ? payRoute.value : { name: 'admin-dashboard' })
  } else {
    done.value = true
  }
  loading.value = false
}
</script>

<template>
  <AuthLayout
    title="Creá tu cuenta"
    :subtitle="done ? '' : plan ? 'Con tu mail y una contraseña. Después pagás y armás la invitación cuando quieras.' : 'Gratis, sin tarjeta. En unos minutos tenés tu invitación armada.'"
  >
    <!-- El plan que eligió en la landing -->
    <div v-if="plan" class="mb-5 flex items-center gap-3 rounded-[1.5rem] bg-chalk p-4">
      <span class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-accent-soft text-accent">
        <Sparkles :size="18" />
      </span>
      <div class="min-w-0 flex-1">
        <p class="font-bold">Plan {{ PLANS[plan].label }} · {{ formatPrice(PLANS[plan].price) }}</p>
        <p class="text-xs text-obsidian/55">Pago único por evento, con Mercado Pago</p>
      </div>
      <router-link :to="{ name: 'landing', hash: '#planes' }" class="shrink-0 text-xs font-bold text-accent hover:underline">
        Cambiar
      </router-link>
    </div>

    <!-- La invitación que armó sin cuenta -->
    <div v-if="withDraft && !done" class="mb-5 flex items-center gap-3 rounded-[1.5rem] bg-chalk p-4">
      <span class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-accent-soft text-accent">
        <PenSquare :size="18" />
      </span>
      <p class="text-sm">
        <strong>Tu invitación queda guardada.</strong>
        <span class="text-obsidian/60"> Al crear la cuenta la pasamos a tu panel, con fotos y todo.</span>
      </p>
    </div>

    <div v-if="done" class="flex items-start gap-4 rounded-[1.5rem] bg-chalk p-5">
      <span class="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-go/25">
        <MailCheck :size="20" />
      </span>
      <p class="text-sm leading-relaxed">
        Te mandamos un mail a <strong>{{ email.trim() }}</strong> para confirmar tu cuenta.
        <template v-if="plan">Tocá el link del mail y pasás directo a pagar el plan {{ PLANS[plan].label }}.</template>
        <template v-else-if="withDraft">Abrí el link del mail <strong>en este mismo navegador</strong> y tu invitación queda guardada en tu cuenta.</template>
        <template v-else>Tocá el link del mail y ya entrás a armar tu invitación.</template>
        Si no lo ves, fijate en spam.
      </p>
    </div>

    <!-- Con Google vuelve ya logueado: con plan, directo a pagarlo -->
    <GoogleButton v-if="!done" :redirect-path="plan ? router.resolve(payRoute).fullPath : '/admin'" />

    <form v-if="!done" @submit.prevent="onSubmit" novalidate class="space-y-5">
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

      <FormField id="signup-password-confirm" label="Repetí la contraseña" :error="form.errorFor('confirm')" v-slot="{ a11y }">
        <PasswordInput
          v-bind="a11y"
          v-model="confirmPassword"
          autocomplete="new-password"
          @blur="form.touch('confirm', confirmPassword)"
        />
      </FormField>

      <p v-if="error" class="rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold" role="alert">{{ error }}</p>

      <button type="submit" :disabled="loading" class="admin-btn-primary w-full">
        {{ loading ? 'Creando cuenta…' : plan ? 'Crear cuenta y pagar' : 'Crear cuenta gratis' }}
      </button>
    </form>

    <template #footer>
      <template v-if="done">
        <router-link :to="{ name: 'admin-login' }" class="font-bold text-chalk underline underline-offset-4">Ir a ingresar</router-link>
      </template>
      <template v-else>
        ¿Ya tenés cuenta?
        <router-link :to="{ name: 'admin-login', query: plan ? { plan } : {} }" class="font-bold text-chalk underline underline-offset-4">Ingresá</router-link>
      </template>
    </template>
  </AuthLayout>
</template>
