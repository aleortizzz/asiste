<script setup>
import { ref, computed } from 'vue'
import { Link2, Check, ExternalLink, MessageCircle, PenSquare } from '@lucide/vue'
import { useEvent } from '../composables/useEvent'
import { formatWhatsapp } from '../lib/whatsapp'

// Plan Invitación: el link único para mandar a todos y el WhatsApp donde le
// llegan las confirmaciones. Va arriba en Inicio e Invitados.
const { event } = useEvent()
const url = computed(() => (event.value?.link_slug ? `${window.location.origin}/i/${event.value.link_slug}` : ''))
const copied = ref(false)

async function copy() {
  try {
    await navigator.clipboard.writeText(url.value)
    copied.value = true
    setTimeout(() => (copied.value = false), 1500)
  } catch {
    /* sin permiso de portapapeles: el link igual se ve y se puede seleccionar */
  }
}
</script>

<template>
  <section class="rounded-[2rem] bg-accent p-6 text-chalk sm:p-7">
    <p class="text-sm font-bold text-chalk/70">Tu invitación</p>
    <template v-if="url">
      <p class="mt-1 text-xl font-bold break-all select-all sm:text-2xl">{{ url.replace(/^https?:\/\//, '') }}</p>
      <div class="mt-4 flex flex-wrap gap-2">
        <button type="button" @click="copy" class="flex items-center gap-2 rounded-full bg-chalk px-4 py-2 text-sm font-bold text-accent">
          <Check v-if="copied" :size="16" />
          <Link2 v-else :size="16" />
          {{ copied ? '¡Copiado!' : 'Copiar link' }}
        </button>
        <a :href="url" target="_blank" rel="noopener" class="flex items-center gap-2 rounded-full border-[1.5px] border-chalk/60 px-4 py-2 text-sm font-bold">
          <ExternalLink :size="16" /> Ver invitación
        </a>
      </div>
      <p class="mt-4 flex items-start gap-2 text-sm text-chalk/80">
        <MessageCircle :size="16" class="mt-0.5 shrink-0" />
        <span v-if="event.whatsapp_rsvp">Las confirmaciones te llegan por WhatsApp al {{ formatWhatsapp(event.whatsapp_rsvp) }}.</span>
        <span v-else>Todavía no cargaste tu WhatsApp: sin él, tus invitados no pueden confirmar.</span>
      </p>
    </template>
    <template v-else>
      <p class="mt-1 text-lg font-bold">Elegí tu link para mandarle a todos</p>
      <p class="mt-1 text-sm text-chalk/75">Y cargá el WhatsApp donde te van a llegar las confirmaciones.</p>
      <router-link
        :to="{ name: 'admin-salon', query: { paso: 'confirmacion' } }"
        class="mt-4 inline-flex items-center gap-2 rounded-full bg-chalk px-4 py-2 text-sm font-bold text-accent"
      >
        <PenSquare :size="16" /> Elegir mi link
      </router-link>
    </template>
  </section>
</template>
