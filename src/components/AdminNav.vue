<script setup>
import { ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { useEvent } from '../composables/useEvent'
import {
  LayoutDashboard,
  PenSquare,
  Table2,
  Users,
  LogOut,
  ShieldCheck,
  Camera,
  Music2,
  Menu,
  X,
} from '@lucide/vue'

const route = useRoute()
const router = useRouter()
const { user, logout, isSuperadmin } = useAuth()
const { viewing, setViewingEvent } = useEvent()

// Menú desplegable en celular (en desktop la barra está siempre visible).
const mobileOpen = ref(false)
watch(() => route.name, () => (mobileOpen.value = false))

function salirDeVista() {
  setViewingEvent(null)
  router.push({ name: 'admin-superadmin' })
}

// `match` incluye las rutas "hijas" que tienen que resaltar el mismo item
// (ej. asignar mesas cuelga de Mesas, el detalle de un grupo cuelga de Invitados).
// `hint`: una línea que explica para qué sirve cada sección.
const items = [
  {
    label: 'Inicio',
    hint: 'Resumen de respuestas',
    icon: LayoutDashboard,
    to: { name: 'admin-dashboard' },
    match: ['admin-dashboard', 'admin-actividad'],
  },
  {
    label: 'Creá tu invitación',
    hint: 'Textos, colores y fotos',
    icon: PenSquare,
    to: { name: 'admin-salon' },
    match: ['admin-salon', 'admin-salon-preview'],
  },
  {
    label: 'Invitados',
    hint: 'Links y confirmaciones',
    icon: Users,
    to: { name: 'admin-invitados' },
    match: ['admin-invitados', 'admin-invitados-detalle'],
  },
  {
    label: 'Mesas',
    hint: 'Quién se sienta dónde',
    icon: Table2,
    to: { name: 'admin-mesas' },
    match: ['admin-mesas', 'admin-asignar-mesas'],
  },
  {
    label: 'Fotos del evento',
    hint: 'Las que suben los invitados',
    icon: Camera,
    to: { name: 'admin-fotos-evento' },
    match: ['admin-fotos-evento'],
  },
  {
    label: 'Canciones',
    hint: 'Pedidos para el DJ',
    icon: Music2,
    to: { name: 'admin-canciones' },
    match: ['admin-canciones'],
  },
  {
    label: 'Superadmin',
    hint: 'Todos los eventos',
    icon: ShieldCheck,
    to: { name: 'admin-superadmin' },
    match: ['admin-superadmin'],
    superadminOnly: true,
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
  <!-- Aviso: el superadmin está viendo/editando el panel de otro cliente. -->
  <div
    v-if="viewing"
    class="font-ui fixed inset-x-0 top-0 z-[60] flex h-9 items-center justify-center gap-3 bg-sulfur px-4 text-sm font-medium text-obsidian"
  >
    <ShieldCheck :size="16" class="shrink-0" />
    <span class="truncate">
      Estás viendo el panel de <strong>{{ viewing.owner_email }}</strong> ({{ viewing.name }})
    </span>
    <button
      type="button"
      @click="salirDeVista"
      class="shrink-0 rounded-full border-[1.5px] border-obsidian px-3 py-0.5 text-xs font-bold"
    >
      Salir
    </button>
  </div>

  <!-- Barra de arriba (solo celular) -->
  <header
    :class="viewing ? 'top-9' : 'top-0'"
    class="font-ui fixed inset-x-0 z-40 flex h-16 items-center justify-between bg-pumice px-4 lg:hidden"
  >
    <span class="admin-display text-3xl">Asiste</span>
    <button
      type="button"
      @click="mobileOpen = !mobileOpen"
      :aria-expanded="mobileOpen"
      aria-label="Menú"
      class="grid h-11 w-11 place-items-center rounded-full bg-limestone"
    >
      <X v-if="mobileOpen" :size="20" />
      <Menu v-else :size="20" />
    </button>
  </header>

  <!-- Fondo oscuro detrás del menú abierto en celular -->
  <div
    v-if="mobileOpen"
    @click="mobileOpen = false"
    class="fixed inset-0 z-40 bg-obsidian/30 lg:hidden"
  ></div>

  <nav
    :class="[
      viewing ? 'top-9' : 'top-0',
      mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0',
    ]"
    class="font-ui fixed bottom-0 left-0 z-50 flex w-[16.5rem] flex-col p-3 transition-transform duration-300 ease-[cubic-bezier(0.32,0.72,0,1)] lg:z-40"
  >
    <div class="flex h-full flex-col rounded-[2rem] bg-limestone p-3">
      <div class="px-3 pt-3 pb-5">
        <span class="admin-display block text-[2.5rem]">Asiste</span>
        <span class="mt-1 block text-xs text-obsidian/50">Tu panel de invitaciones</span>
      </div>

      <ul class="flex-1 space-y-1 overflow-y-auto">
        <li v-for="item in items" v-show="!item.superadminOnly || isSuperadmin" :key="item.label">
          <router-link
            :to="item.to"
            class="flex items-center gap-3 rounded-full px-3 py-2.5 transition-colors"
            :class="isActive(item) ? 'bg-accent text-chalk' : 'hover:bg-pumice/60'"
          >
            <span
              class="grid h-9 w-9 shrink-0 place-items-center rounded-full"
              :class="isActive(item) ? 'bg-chalk text-accent' : 'bg-chalk'"
            >
              <component :is="item.icon" :size="17" />
            </span>
            <span class="min-w-0">
              <span class="block truncate text-[0.95rem] font-bold leading-tight">{{ item.label }}</span>
              <span
                class="block truncate text-xs leading-tight"
                :class="isActive(item) ? 'text-chalk/70' : 'text-obsidian/50'"
              >
                {{ item.hint }}
              </span>
            </span>
          </router-link>
        </li>
      </ul>

      <div class="mt-3 border-t-[1.5px] border-dotted border-obsidian/25 px-1 pt-3">
        <p class="truncate px-2 text-xs text-obsidian/50">{{ user?.email }}</p>
        <button
          type="button"
          @click="onLogout"
          class="mt-2 flex w-full items-center gap-3 rounded-full px-3 py-2 text-sm font-bold transition-colors hover:bg-pumice/60"
        >
          <LogOut :size="17" class="shrink-0" />
          Cerrar sesión
        </button>
      </div>
    </div>
  </nav>

  <!-- Ocupa espacio en el flujo normal (a diferencia del nav/banner, que son
       fixed) para empujar hacia abajo el contenido de la página cuando el
       banner está arriba — sin tener que tocar cada vista una por una. -->
  <div v-if="viewing" class="h-9"></div>
</template>
