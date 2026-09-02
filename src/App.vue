<script setup>
import { watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from './composables/useAuth'

const router = useRouter()
const { recovering } = useAuth()

// Si el usuario entró desde el link de recuperar contraseña, lo mandamos a la
// pantalla para definirla, sin importar a qué ruta lo haya redirigido Supabase.
watch(
  recovering,
  (isRecovering) => {
    if (isRecovering && router.currentRoute.value.name !== 'admin-nueva-contrasena') {
      router.replace({ name: 'admin-nueva-contrasena' })
    }
  },
  { immediate: true },
)
</script>

<template>
  <router-view />
</template>
