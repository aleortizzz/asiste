<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { compressImage } from '../lib/compressImage'
import { Camera } from '@lucide/vue'

// Página pública sin login: la abre quien escanea el QR de las mesas.
const route = useRoute()
const eventId = route.params.eventId

const photos = ref([])
const loading = ref(true)
const uploading = ref(false)
const uploadedCount = ref(0)
const totalToUpload = ref(0)
const error = ref('')
const full = ref(false)
const fileInput = ref(null)

async function loadPhotos() {
  const { data, error: err } = await supabase.rpc('listar_fotos_invitados', {
    p_event_id: eventId,
  })
  if (!err) photos.value = data ?? []
  loading.value = false
}

onMounted(loadPhotos)

function pick() {
  fileInput.value?.click()
}

async function onFilesPicked(e) {
  const files = Array.from(e.target.files || [])
  e.target.value = ''
  if (!files.length) return

  error.value = ''
  uploading.value = true
  totalToUpload.value = files.length
  uploadedCount.value = 0

  for (const file of files) {
    try {
      const blob = await compressImage(file)
      const path = `${eventId}/${crypto.randomUUID()}.jpg`
      const { error: upErr } = await supabase.storage
        .from('guest-uploads')
        .upload(path, blob, { contentType: 'image/jpeg', cacheControl: '3600' })
      if (upErr) throw upErr

      const { data: pub } = supabase.storage.from('guest-uploads').getPublicUrl(path)
      const { error: rpcErr } = await supabase.rpc('agregar_foto_invitados', {
        p_event_id: eventId,
        p_url: pub.publicUrl,
        p_path: path,
      })
      if (rpcErr) {
        if (rpcErr.message?.includes('máximo')) full.value = true
        throw rpcErr
      }

      photos.value = [
        { id: crypto.randomUUID(), url: pub.publicUrl, created_at: new Date().toISOString() },
        ...photos.value,
      ]
    } catch (err) {
      error.value = err.message || 'No se pudo subir una de las fotos.'
    } finally {
      uploadedCount.value++
    }
  }

  uploading.value = false
}
</script>

<template>
  <div class="min-h-screen bg-[#fdf7f1] pb-24 text-stone-700">
    <header class="px-6 pb-8 pt-14 text-center">
      <p class="text-xs uppercase tracking-[0.35em] text-amber-700">Momentos de la fiesta</p>
      <h1
        class="mt-2 text-4xl text-rose-800"
        style="font-family: 'Dancing Script', cursive"
      >
        Compartí tus fotos
      </h1>
      <p class="mx-auto mt-3 max-w-sm text-sm text-stone-500">
        Subí las fotos que saques durante el evento y quedan acá para que las vean todos.
      </p>
    </header>

    <div class="px-6">
      <button
        type="button"
        @click="pick"
        :disabled="uploading || full"
        class="mx-auto flex w-full max-w-sm items-center justify-center gap-2 rounded-full bg-linear-to-r from-rose-700 to-rose-800 px-6 py-4 font-medium text-white shadow-lg transition hover:brightness-110 disabled:opacity-50"
      >
        <Camera :size="20" />
        {{ uploading ? `Subiendo ${uploadedCount}/${totalToUpload}…` : 'Subir fotos' }}
      </button>
      <input
        ref="fileInput"
        type="file"
        accept="image/*"
        multiple
        class="hidden"
        @change="onFilesPicked"
      />

      <p v-if="full" class="mt-3 text-center text-sm text-amber-700">
        La galería llegó al máximo de fotos. ¡Gracias por compartir tantos momentos!
      </p>
      <p v-if="error" class="mt-3 text-center text-sm text-red-600">{{ error }}</p>
    </div>

    <div class="mt-10 px-4">
      <p v-if="loading" class="text-center text-sm text-stone-400">Cargando…</p>
      <p v-else-if="!photos.length" class="text-center text-sm text-stone-400">
        Todavía no hay fotos. ¡Subí la primera!
      </p>
      <div v-else class="columns-2 gap-2 sm:columns-3">
        <div
          v-for="photo in photos"
          :key="photo.id"
          class="mb-2 overflow-hidden rounded-xl shadow"
          style="break-inside: avoid"
        >
          <img
            :src="photo.url"
            alt=""
            loading="lazy"
            decoding="async"
            class="block w-full object-cover"
          />
        </div>
      </div>
    </div>
  </div>
</template>
