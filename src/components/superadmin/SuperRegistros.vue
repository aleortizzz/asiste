<script setup>
import { ref } from 'vue'
import { Trash2 } from '@lucide/vue'
import { useSuperadmin } from '../../composables/useSuperadmin'
import { confirmDialog } from '../../composables/useConfirm'
import { supabase } from '../../lib/supabase'

// Superadmin › Registros: cuentas que se registraron pero todavía no
// guardaron su invitación (no tienen evento, así que no están en Clientes).
// A quiénes conviene escribirles, o eliminarlas (pruebas, registrarse de nuevo).
const { pendingAccounts, loading } = useSuperadmin()

const error = ref('')
const deletingId = ref(null)

async function eliminar(a) {
  const ok = await confirmDialog({
    title: '¿Eliminar esta cuenta?',
    message: `Se borra la cuenta ${a.email}. Va a poder registrarse de nuevo con el mismo mail. No se puede deshacer.`,
    confirmText: 'Eliminar',
    tone: 'danger',
  })
  if (!ok) return
  error.value = ''
  deletingId.value = a.user_id
  const { error: err } = await supabase.rpc('eliminar_cuenta_superadmin', { p_user_id: a.user_id })
  if (err) error.value = `No se pudo eliminar ${a.email}: ${err.message}`
  else pendingAccounts.value = pendingAccounts.value.filter((x) => x.user_id !== a.user_id)
  deletingId.value = null
}

const registeredOn = (iso) => new Date(iso).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
</script>

<template>
  <div>
    <p class="max-w-lg text-obsidian/60">
      Se registraron pero nunca guardaron su invitación, así que todavía no tienen evento ni plan. Son a quienes conviene
      escribirles.
    </p>
    <p v-if="error" class="mt-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ error }}</p>
    <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>
    <p v-else-if="!pendingAccounts.length" class="mt-6 rounded-[2rem] bg-limestone p-8 text-center text-obsidian/60">
      No hay cuentas sin invitación. Todos los que se registraron ya la armaron.
    </p>
    <ul v-else class="mt-6 space-y-2">
      <li
        v-for="a in pendingAccounts"
        :key="a.user_id"
        class="flex flex-wrap items-center justify-between gap-x-4 gap-y-1 rounded-[1.5rem] bg-limestone px-5 py-3"
      >
        <div class="min-w-0">
          <p class="truncate font-bold select-all">{{ a.email }}</p>
          <p class="text-xs text-obsidian/55">Se registró el {{ registeredOn(a.created_at) }}</p>
        </div>
        <div class="flex max-w-full items-center gap-1">
          <span
            class="max-w-full rounded-full px-2.5 py-1 text-xs font-bold"
            :class="a.email_confirmado ? 'bg-chalk' : 'bg-sulfur'"
          >
            {{ a.email_confirmado ? 'Confirmó el mail, no armó la invitación' : 'Falta que confirme el mail' }}
          </span>
          <button
            type="button"
            @click="eliminar(a)"
            :disabled="deletingId === a.user_id"
            :aria-label="`Eliminar la cuenta ${a.email}`"
            title="Eliminar cuenta"
            class="grid h-9 w-9 shrink-0 place-items-center rounded-full text-obsidian/45 transition-colors hover:bg-nogo/15 hover:text-nogo disabled:opacity-40"
          >
            <Trash2 :size="16" />
          </button>
        </div>
      </li>
    </ul>
  </div>
</template>

