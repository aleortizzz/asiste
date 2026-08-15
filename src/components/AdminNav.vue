<script setup>
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'

const router = useRouter()
const { user, logout } = useAuth()

async function onLogout() {
  await logout()
  router.push({ name: 'admin-login' })
}
</script>

<template>
  <nav class="flex items-center justify-between border-b border-gray-200 bg-white px-6 py-3">
    <div class="flex gap-4 text-sm font-medium text-gray-700">
      <router-link to="/admin" class="hover:underline">Dashboard</router-link>
      <router-link to="/admin/salon" class="hover:underline">Creá tu invitación</router-link>
      <router-link to="/admin/mesas" class="hover:underline">Mesas</router-link>
      <router-link to="/admin/invitados" class="hover:underline">Invitados</router-link>
    </div>
    <div class="flex items-center gap-3 text-sm text-gray-600">
      <span>{{ user?.email }}</span>
      <button @click="onLogout" class="underline">Cerrar sesión</button>
    </div>
  </nav>
</template>
