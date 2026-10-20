<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ShieldCheck, Users, UserPlus, Receipt, Tag } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import SuperClientes from '../components/superadmin/SuperClientes.vue'
import SuperRegistros from '../components/superadmin/SuperRegistros.vue'
import SuperPagos from '../components/superadmin/SuperPagos.vue'
import SuperPrecios from '../components/superadmin/SuperPrecios.vue'
import SuperPushButton from '../components/superadmin/SuperPushButton.vue'
import { useSuperadmin } from '../composables/useSuperadmin'

// Superadmin, en pestañas. La pestaña va en la URL (?seccion=pagos): sobrevive
// a una recarga y se puede guardar el link. Cada una es un componente de
// components/superadmin/; los eventos los comparten (useSuperadmin).
const route = useRoute()
const router = useRouter()
const { rows, pendingAccounts, error, load } = useSuperadmin()

const SECTIONS = [
  { id: 'clientes', label: 'Clientes', icon: Users, component: SuperClientes },
  { id: 'registros', label: 'Registros', icon: UserPlus, component: SuperRegistros },
  { id: 'pagos', label: 'Pagos', icon: Receipt, component: SuperPagos },
  { id: 'precios', label: 'Precios', icon: Tag, component: SuperPrecios },
]
const current = computed(() => SECTIONS.find((s) => s.id === route.query.seccion) ?? SECTIONS[0])
const counts = computed(() => ({ clientes: rows.value.length, registros: pendingAccounts.value.length }))

function go(id, event) {
  router.replace({ query: id === SECTIONS[0].id ? {} : { seccion: id } })
  // Si la pestaña quedó cortada contra el borde, que se acomode a la vista.
  event?.currentTarget?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' })
}

// Difuminado en los bordes de las pestañas: solo del lado que tiene más para deslizar.
const tabsEl = ref(null)
const fades = ref({ left: false, right: false })
function updateFades() {
  const el = tabsEl.value
  if (!el) return
  fades.value = {
    left: el.scrollLeft > 2,
    right: el.scrollLeft + el.clientWidth < el.scrollWidth - 2,
  }
}
const fadeMask = computed(() => {
  const { left, right } = fades.value
  if (!left && !right) return {}
  const mask = `linear-gradient(to right, ${left ? 'transparent' : 'black'}, black 28px, black calc(100% - 28px), ${right ? 'transparent' : 'black'})`
  return { maskImage: mask, WebkitMaskImage: mask }
})

// Cada vez que se entra a Superadmin, la lista fresca (puede haber clientes nuevos).
onMounted(() => {
  load(true)
  updateFades()
  window.addEventListener('resize', updateFades)
})
onUnmounted(() => window.removeEventListener('resize', updateFades))
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-3xl px-4 pt-4 pb-16 lg:px-8 lg:pt-8">
      <div class="flex flex-wrap items-start justify-between gap-2">
        <p class="inline-flex items-center gap-1.5 rounded-full bg-obsidian px-3 py-1 text-xs font-bold text-chalk">
          <ShieldCheck :size="13" /> Superadmin
        </p>
        <SuperPushButton />
      </div>
      <h1 class="admin-display mt-3 text-5xl sm:text-6xl">{{ current.label }}</h1>

      <!-- Pestañas: la pastilla queda quieta y en celular se deslizan las pestañas adentro.
           El borde se difumina del lado donde quedan pestañas escondidas. -->
      <nav class="mt-5 mb-6 overflow-hidden rounded-full bg-limestone p-1 lg:w-fit">
        <div
          ref="tabsEl"
          role="tablist"
          aria-label="Secciones de Superadmin"
          @scroll="updateFades"
          :style="fadeMask"
          class="flex gap-1 overflow-x-auto rounded-full [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        >
          <button
            v-for="s in SECTIONS"
            :key="s.id"
            type="button"
            role="tab"
            :aria-selected="current.id === s.id"
            @click="go(s.id, $event)"
            class="flex shrink-0 items-center gap-2 rounded-full px-4 py-2 text-sm font-bold transition-colors"
            :class="current.id === s.id ? 'bg-accent text-chalk' : 'text-obsidian/60 hover:bg-chalk hover:text-obsidian'"
          >
            <component :is="s.icon" :size="15" />
            {{ s.label }}
            <span
              v-if="counts[s.id]"
              class="tabular-nums"
              :class="current.id === s.id ? 'text-chalk/70' : 'text-obsidian/40'"
            >
              {{ counts[s.id] }}
            </span>
          </button>
        </div>
      </nav>

      <p v-if="error" class="mb-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ error }}</p>

      <component :is="current.component" :key="current.id" />
    </div>
  </div>
</template>
