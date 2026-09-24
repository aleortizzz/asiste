<script setup>
import { ref, onMounted } from 'vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'
import { Trash2, Music2 } from '@lucide/vue'

const { event, loadEvent } = useEvent()
const songs = ref([])
const loading = ref(true)

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) await fetchSongs()
  loading.value = false
})

async function fetchSongs() {
  const { data, error } = await supabase
    .from('song_requests')
    .select('id, song_title, artist, youtube_video_id, requested_by, created_at')
    .eq('event_id', event.value.id)
    .order('created_at', { ascending: false })
  if (!error) songs.value = data
}

async function removeSong(song) {
  await supabase.from('song_requests').delete().eq('id', song.id)
  songs.value = songs.value.filter((s) => s.id !== song.id)
}

function formatDateTime(iso) {
  return new Date(iso).toLocaleString('es-AR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
}
</script>

<template>
  <div class="pl-16">
    <AdminNav />
    <div class="mx-auto max-w-3xl p-8">
      <h1 class="text-2xl font-semibold">Canciones para la fiesta</h1>
      <p class="mt-1 text-sm text-gray-500">
        Lo que van pidiendo tus invitados desde la invitación, con quién lo pidió.
      </p>

      <p v-if="!loading && !event" class="mt-6 text-sm text-red-600">
        Primero cargá los datos del evento en "Creá tu invitación".
      </p>

      <template v-else-if="event">
        <p
          v-if="event.plan !== 'plus'"
          class="mt-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800"
        >
          Esta función es parte del plan Plus y todavía no está activada para tu evento. Mientras
          tanto tus invitados no ven la sección en la invitación.
        </p>

        <p v-if="!loading && !songs.length" class="mt-6 text-sm text-gray-400">
          Todavía no pidieron ninguna canción.
        </p>

        <ul v-else class="mt-6 divide-y divide-gray-200 rounded border border-gray-200">
          <li v-for="song in songs" :key="song.id" class="flex items-center gap-3 px-4 py-3">
            <span class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-gray-100 text-gray-500">
              <Music2 :size="16" />
            </span>
            <div class="min-w-0 flex-1">
              <a
                v-if="song.youtube_video_id"
                :href="`https://www.youtube.com/watch?v=${song.youtube_video_id}`"
                target="_blank"
                rel="noopener"
                class="truncate font-medium text-gray-900 hover:underline"
              >
                {{ song.song_title }}
              </a>
              <p v-else class="truncate font-medium text-gray-900">{{ song.song_title }}</p>
              <p class="truncate text-sm text-gray-500">
                {{ song.artist }}<span v-if="song.artist"> · </span>Pedida por {{ song.requested_by }}
              </p>
            </div>
            <span class="shrink-0 text-xs text-gray-400">{{ formatDateTime(song.created_at) }}</span>
            <button
              type="button"
              @click="removeSong(song)"
              aria-label="Eliminar canción"
              class="shrink-0 rounded-full p-2 text-gray-400 transition hover:bg-gray-100 hover:text-red-600"
            >
              <Trash2 :size="16" />
            </button>
          </li>
        </ul>
      </template>
    </div>
  </div>
</template>
