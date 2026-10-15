<script setup>
import { useSuperadmin } from '../../composables/useSuperadmin'

// Superadmin › Registros: cuentas que se registraron pero todavía no
// guardaron su invitación (no tienen evento, así que no están en Clientes).
// A quiénes conviene escribirles.
const { pendingAccounts, loading } = useSuperadmin()

const registeredOn = (iso) => new Date(iso).toLocaleDateString('es-AR', { day: 'numeric', month: 'short', year: 'numeric' })
</script>

<template>
  <div>
    <p class="max-w-lg text-obsidian/60">
      Se registraron pero nunca guardaron su invitación, así que todavía no tienen evento ni plan. Son a quienes conviene
      escribirles.
    </p>
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
        <span
          class="shrink-0 rounded-full px-2.5 py-1 text-xs font-bold"
          :class="a.email_confirmado ? 'bg-chalk' : 'bg-sulfur'"
        >
          {{ a.email_confirmado ? 'Confirmó el mail, no armó la invitación' : 'Falta que confirme el mail' }}
        </span>
      </li>
    </ul>
  </div>
</template>

