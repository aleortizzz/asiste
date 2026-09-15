<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'
import { ShieldCheck } from '@lucide/vue'

const router = useRouter()
const { setViewingEvent } = useEvent()

const rows = ref([])
const loading = ref(true)
const error = ref('')
const search = ref('')

onMounted(async () => {
  const { data, error: err } = await supabase.rpc('listar_eventos_superadmin')
  if (err) error.value = err.message
  else rows.value = data ?? []
  loading.value = false
})

function formatDate(iso) {
  if (!iso) return '—'
  const [y, m, d] = iso.split('-')
  return `${d}/${m}/${y}`
}

function entrar(row) {
  setViewingEvent({ id: row.event_id, name: row.event_name, owner_email: row.owner_email })
  router.push({ name: 'admin-dashboard' })
}

const filtered = () =>
  rows.value.filter((r) => {
    const q = search.value.trim().toLowerCase()
    if (!q) return true
    return r.owner_email?.toLowerCase().includes(q) || r.event_name?.toLowerCase().includes(q)
  })
</script>

<template>
  <div class="pl-16">
    <AdminNav />
    <div class="mx-auto max-w-3xl p-8">
      <div class="flex items-center gap-2">
        <ShieldCheck :size="22" class="text-rose-700" />
        <h1 class="text-2xl font-semibold">Panel superadmin</h1>
      </div>
      <p class="mt-1 text-sm text-gray-500">
        Entrá al panel de cualquier cliente para ayudarlo. Vas a ver un aviso arriba de todo
        mientras estés dentro de su evento, con un botón para salir.
      </p>

      <input
        v-model="search"
        placeholder="Buscar por email o nombre del evento…"
        class="mt-6 w-full rounded border border-gray-300 px-3 py-2"
      />

      <p v-if="loading" class="mt-6 text-sm text-gray-500">Cargando…</p>
      <p v-else-if="error" class="mt-6 text-sm text-red-600">{{ error }}</p>
      <p v-else-if="!rows.length" class="mt-6 text-sm text-gray-500">
        Todavía no hay ningún evento creado.
      </p>

      <ul v-else class="mt-6 divide-y divide-gray-200 rounded border border-gray-200">
        <li
          v-for="row in filtered()"
          :key="row.event_id"
          class="flex items-center justify-between gap-4 px-4 py-3"
        >
          <div class="min-w-0">
            <p class="truncate font-medium text-gray-900">{{ row.event_name }}</p>
            <p class="truncate text-sm text-gray-500">{{ row.owner_email }}</p>
            <p class="text-xs text-gray-400">
              Evento: {{ formatDate(row.event_date) }} · Creado: {{ formatDate(row.created_at?.slice(0, 10)) }}
            </p>
          </div>
          <button
            type="button"
            @click="entrar(row)"
            class="shrink-0 rounded-full bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:brightness-110"
          >
            Entrar
          </button>
        </li>
      </ul>
    </div>
  </div>
</template>
