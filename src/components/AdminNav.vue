<script setup>
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { LayoutDashboard, PenSquare, Table2, Users, UserCircle, LogOut } from '@lucide/vue'

const route = useRoute()
const router = useRouter()
const { user, logout } = useAuth()

// `match` incluye las rutas "hijas" que tienen que resaltar el mismo item
// (ej. asignar mesas cuelga de Mesas, el detalle de un grupo cuelga de Invitados).
const items = [
  { label: 'Dashboard', icon: LayoutDashboard, to: { name: 'admin-dashboard' }, match: ['admin-dashboard'] },
  {
    label: 'Creá tu invitación',
    icon: PenSquare,
    to: { name: 'admin-salon' },
    match: ['admin-salon', 'admin-salon-preview'],
  },
  {
    label: 'Mesas',
    icon: Table2,
    to: { name: 'admin-mesas' },
    match: ['admin-mesas', 'admin-asignar-mesas'],
  },
  {
    label: 'Invitados',
    icon: Users,
    to: { name: 'admin-invitados' },
    match: ['admin-invitados', 'admin-invitados-detalle'],
  },
]

function isActive(item) {
  return item.match.includes(route.name)
}

async function onLogout() {
  await logout()
  router.push({ name: 'admin-login' })
}
</script>

<template>
  <nav
    class="group fixed inset-y-0 left-0 z-40 flex w-16 flex-col overflow-hidden border-r border-gray-200 bg-white shadow-sm transition-[width] duration-200 ease-out hover:w-60"
  >
    <div class="flex h-14 shrink-0 items-center gap-3 px-4">
      <span class="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-gray-900 text-sm font-bold text-white">
        A
      </span>
      <span
        class="whitespace-nowrap text-sm font-semibold text-gray-800 opacity-0 transition-opacity duration-150 group-hover:opacity-100"
      >
        Asiste
      </span>
    </div>

    <ul class="mt-2 flex-1 space-y-1 px-2">
      <li v-for="item in items" :key="item.label">
        <router-link
          :to="item.to"
          class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors"
          :class="isActive(item) ? 'bg-gray-900 text-white' : 'text-gray-600 hover:bg-gray-100'"
        >
          <component :is="item.icon" :size="20" class="shrink-0" />
          <span class="whitespace-nowrap opacity-0 transition-opacity duration-150 group-hover:opacity-100">
            {{ item.label }}
          </span>
        </router-link>
      </li>
    </ul>

    <div class="shrink-0 space-y-1 border-t border-gray-200 px-2 py-3">
      <div class="flex items-center gap-3 px-3 py-2 text-gray-500">
        <UserCircle :size="20" class="shrink-0" />
        <span
          class="truncate whitespace-nowrap text-xs opacity-0 transition-opacity duration-150 group-hover:opacity-100"
        >
          {{ user?.email }}
        </span>
      </div>
      <button
        type="button"
        @click="onLogout"
        class="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-gray-600 transition-colors hover:bg-gray-100"
      >
        <LogOut :size="20" class="shrink-0" />
        <span class="whitespace-nowrap opacity-0 transition-opacity duration-150 group-hover:opacity-100">
          Cerrar sesión
        </span>
      </button>
    </div>
  </nav>
</template>
