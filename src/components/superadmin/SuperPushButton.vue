<script setup>
import { ref, onMounted } from 'vue'
import { Bell, BellOff } from '@lucide/vue'
import { useAuth } from '../../composables/useAuth'
import { pushSupported, pushActive, enablePush, disablePush, isIos, isInstalled } from '../../lib/push'

// Botón del encabezado de Superadmin: activa en ESTE dispositivo el aviso push
// de cada registro nuevo (lib/push.js). Cada dispositivo se activa aparte.
const { user } = useAuth()

const needsInstall = isIos && !isInstalled
const on = ref(false)
const busy = ref(false)
const message = ref('')

onMounted(async () => {
  on.value = await pushActive()
})

async function toggle() {
  if (needsInstall) {
    message.value = 'En iPhone hace falta instalar Asiste: Compartir → «Agregar a inicio», y activarlas desde el ícono.'
    return
  }
  if (!pushSupported) {
    message.value = 'Este navegador no admite notificaciones.'
    return
  }
  busy.value = true
  message.value = ''
  try {
    message.value = on.value ? await disablePush() : await enablePush(user.value.id)
  } catch (err) {
    message.value = `No se pudo: ${err.message}`
  }
  on.value = await pushActive()
  busy.value = false
}
</script>

<template>
  <div>
    <button
      type="button"
      :disabled="busy"
      @click="toggle"
      :title="on ? 'Te avisamos en este dispositivo cada vez que alguien se registra' : 'Recibí un aviso cada vez que alguien se registra'"
      class="inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-bold transition-colors disabled:opacity-50"
      :class="on ? 'bg-limestone text-obsidian/70 hover:bg-pumice' : 'bg-accent text-chalk'"
    >
      <component :is="on ? Bell : BellOff" :size="13" />
      {{ on ? 'Notificaciones activadas' : 'Activar notificaciones' }}
    </button>
    <p v-if="message" class="mt-2 max-w-sm rounded-[1.25rem] bg-nogo/15 px-4 py-2 text-xs font-bold">{{ message }}</p>
  </div>
</template>
