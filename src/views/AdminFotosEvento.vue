<script setup>
import { ref, onMounted, computed } from 'vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'
import { Copy, Check, Trash2 } from '@lucide/vue'

const { event, loadEvent } = useEvent()
const photos = ref([])
const loading = ref(true)
const copied = ref(false)
const LIMIT = 500

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) await fetchPhotos()
  loading.value = false
})

const guestUrl = computed(() =>
  event.value ? `${window.location.origin}/fotos/${event.value.id}` : '',
)
const qrUrl = computed(() =>
  guestUrl.value
    ? `https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${encodeURIComponent(guestUrl.value)}`
    : '',
)

async function fetchPhotos() {
  const { data, error } = await supabase
    .from('event_photos')
    .select('id, url, path, uploader_name, likes_count, created_at')
    .eq('event_id', event.value.id)
    .order('created_at', { ascending: false })
  if (!error) photos.value = data
}

async function copyLink() {
  await navigator.clipboard.writeText(guestUrl.value)
  copied.value = true
  setTimeout(() => (copied.value = false), 1500)
}

async function removePhoto(photo) {
  await supabase.storage.from('guest-uploads').remove([photo.path])
  await supabase.from('event_photos').delete().eq('id', photo.id)
  photos.value = photos.value.filter((p) => p.id !== photo.id)
}
</script>

<template>
  <div class="pl-16">
    <AdminNav />
    <div class="mx-auto max-w-3xl p-8">
      <h1 class="text-2xl font-semibold">Fotos de los invitados</h1>
      <p class="mt-1 text-sm text-gray-500">
        Poné este QR en las mesas. Cualquiera puede escanearlo y subir fotos durante el evento,
        sin necesidad de registrarse — se van a ver acá abajo. Tope de {{ LIMIT }} fotos por
        evento.
      </p>

      <p v-if="!loading && !event" class="mt-6 text-sm text-red-600">
        Primero cargá los datos del evento en "Creá tu invitación".
      </p>

      <template v-else-if="event">
        <div class="mt-6 flex flex-col items-center gap-4 rounded-xl border border-gray-200 p-6 sm:flex-row">
          <img v-if="qrUrl" :src="qrUrl" alt="Código QR" class="h-40 w-40 shrink-0 rounded-lg" />
          <div class="min-w-0 text-center sm:text-left">
            <p class="text-sm text-gray-500">Link para compartir / imprimir en el QR:</p>
            <p class="mt-1 break-all font-mono text-sm text-gray-800">{{ guestUrl }}</p>
            <button
              type="button"
              @click="copyLink"
              class="mt-3 inline-flex items-center gap-2 rounded-full bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:brightness-110"
            >
              <Check v-if="copied" :size="16" />
              <Copy v-else :size="16" />
              {{ copied ? 'Copiado' : 'Copiar link' }}
            </button>
          </div>
        </div>

        <h2 class="mt-10 text-sm font-semibold uppercase tracking-wide text-gray-500">
          Galería ({{ photos.length }}/{{ LIMIT }})
        </h2>

        <p v-if="!photos.length" class="mt-3 text-sm text-gray-400">
          Todavía no subieron ninguna foto.
        </p>
        <div v-else class="mt-3 grid grid-cols-3 gap-2 sm:grid-cols-4">
          <div
            v-for="photo in photos"
            :key="photo.id"
            class="group relative aspect-square overflow-hidden rounded-lg ring-1 ring-gray-200"
          >
            <img :src="photo.url" alt="" loading="lazy" class="h-full w-full object-cover" />
            <button
              type="button"
              @click="removePhoto(photo)"
              aria-label="Eliminar foto"
              class="absolute right-1 top-1 grid h-7 w-7 place-items-center rounded-full bg-black/60 text-white opacity-0 transition group-hover:opacity-100"
            >
              <Trash2 :size="14" />
            </button>
            <div
              class="absolute inset-x-0 bottom-0 flex items-center justify-between gap-1 bg-linear-to-t from-black/65 to-transparent px-1.5 py-1 text-[10px] text-white/90"
            >
              <span class="truncate">{{ photo.uploader_name || 'Anónimo' }}</span>
              <span v-if="photo.likes_count" class="shrink-0">♥ {{ photo.likes_count }}</span>
            </div>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
