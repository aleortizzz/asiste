<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { ArrowLeft, Heart, Download, Share2 } from '@lucide/vue'
import { timeAgo } from '../../lib/timeAgo'

// Feed vertical tipo Instagram: se abre al tocar una foto de la grilla y
// arranca en esa foto. Doble tap sobre la foto = like (con el corazón grande).
// Vive dentro de GuestPhotos, así hereda las variables de color del tema.
const props = defineProps({
  photos: { type: Array, required: true }, // ya ordenadas como la pestaña
  startIndex: { type: Number, default: 0 },
  title: { type: String, default: '' },
  likedIds: { type: Object, required: true }, // Set
  mineUrls: { type: Object, required: true }, // Set
  showRank: { type: Boolean, default: false },
})
const emit = defineEmits(['close', 'like', 'unlike'])

const scroller = ref(null)

onMounted(async () => {
  document.body.style.overflow = 'hidden'
  window.addEventListener('keydown', onKeydown)
  await nextTick()
  scroller.value?.querySelector(`[data-index="${props.startIndex}"]`)?.scrollIntoView({ block: 'start' })
})
onUnmounted(() => {
  document.body.style.overflow = ''
  window.removeEventListener('keydown', onKeydown)
})

function onKeydown(e) {
  if (e.key === 'Escape') emit('close')
}

// --- Doble tap -----------------------------------------------------------------
// Dos toques en menos de 300 ms sobre la misma foto. `touch-action:
// manipulation` en la imagen evita que el celular lo tome como zoom.
const burstId = ref(null)
let lastTap = { id: null, at: 0 }
let burstTimer = null

function onImageTap(photo) {
  const now = Date.now()
  if (lastTap.id === photo.id && now - lastTap.at < 300) {
    lastTap = { id: null, at: 0 }
    if (!props.likedIds.has(photo.id)) emit('like', photo)
    burstId.value = null
    // Reinicia la animación aunque se haga doble tap varias veces seguidas.
    requestAnimationFrame(() => (burstId.value = photo.id))
    clearTimeout(burstTimer)
    burstTimer = setTimeout(() => (burstId.value = null), 900)
  } else {
    lastTap = { id: photo.id, at: now }
  }
}

function toggleLike(photo) {
  if (props.likedIds.has(photo.id)) emit('unlike', photo)
  else emit('like', photo)
}

// --- Descargar / compartir -----------------------------------------------------------
async function fetchFile(photo) {
  const res = await fetch(photo.url)
  const blob = await res.blob()
  return new File([blob], `foto-${photo.id.slice(0, 8)}.jpg`, { type: blob.type || 'image/jpeg' })
}

async function download(photo) {
  try {
    const file = await fetchFile(photo)
    const url = URL.createObjectURL(file)
    const a = document.createElement('a')
    a.href = url
    a.download = file.name
    document.body.appendChild(a)
    a.click()
    a.remove()
    setTimeout(() => URL.revokeObjectURL(url), 1000)
  } catch {
    window.open(photo.url, '_blank', 'noopener')
  }
}

const canShare = typeof navigator !== 'undefined' && !!navigator.share
async function share(photo) {
  try {
    const file = await fetchFile(photo)
    if (navigator.canShare?.({ files: [file] })) await navigator.share({ files: [file] })
    else await navigator.share({ url: window.location.href })
  } catch {
    /* el usuario canceló o el navegador no pudo: no hay nada que avisar */
  }
}

const MEDALS = ['🥇', '🥈', '🥉']
const initial = (name) => (name?.trim()?.[0] ?? '?').toUpperCase()
</script>

<template>
  <div class="feed fixed inset-0 z-50 flex flex-col">
    <header class="feed-bar flex shrink-0 items-center gap-3 px-3 py-2.5">
      <button type="button" @click="emit('close')" aria-label="Volver a la galería" class="grid h-10 w-10 place-items-center rounded-full">
        <ArrowLeft :size="22" />
      </button>
      <p class="truncate font-semibold">{{ title }}</p>
    </header>

    <div ref="scroller" class="flex-1 overflow-y-auto overscroll-contain pb-16">
      <article v-for="(photo, i) in photos" :key="photo.id" :data-index="i" class="feed-post mx-auto max-w-xl">
        <!-- Quién la subió -->
        <div class="flex items-center gap-3 px-3 py-2.5">
          <span class="avatar grid h-9 w-9 shrink-0 place-items-center rounded-full text-sm font-bold">
            {{ initial(photo.uploader_name) }}
          </span>
          <div class="min-w-0 flex-1 leading-tight">
            <p class="truncate text-sm font-semibold">
              {{ photo.uploader_name || 'Anónimo' }}
              <span v-if="mineUrls.has(photo.url)" class="mine-chip ml-1 rounded-full px-1.5 py-0.5 text-[10px] font-bold">Tuya</span>
            </p>
            <p class="text-xs opacity-60">{{ timeAgo(photo.created_at) }}</p>
          </div>
          <span v-if="showRank && i < 3 && photo.likes_count > 0" class="text-xl" :title="`Puesto ${i + 1}`">{{ MEDALS[i] }}</span>
        </div>

        <!-- Foto (doble tap = like) -->
        <div class="relative select-none" @click="onImageTap(photo)">
          <img :src="photo.url" alt="" loading="lazy" decoding="async" draggable="false" class="feed-img block w-full" />
          <Heart
            v-if="burstId === photo.id"
            :size="110"
            fill="currentColor"
            :stroke-width="0"
            class="burst pointer-events-none absolute top-1/2 left-1/2 text-white"
          />
        </div>

        <!-- Acciones -->
        <div class="flex items-center gap-1 px-1.5 pt-1.5">
          <button
            type="button"
            @click="toggleLike(photo)"
            :aria-pressed="likedIds.has(photo.id)"
            aria-label="Me gusta"
            class="grid h-11 w-11 place-items-center rounded-full"
          >
            <Heart
              :key="likedIds.has(photo.id) ? 'on' : 'off'"
              :size="26"
              :fill="likedIds.has(photo.id) ? 'currentColor' : 'none'"
              :class="likedIds.has(photo.id) ? 'liked pop' : ''"
            />
          </button>
          <button v-if="canShare" type="button" @click="share(photo)" aria-label="Compartir" class="grid h-11 w-11 place-items-center rounded-full">
            <Share2 :size="23" />
          </button>
          <button type="button" @click="download(photo)" aria-label="Descargar" class="ml-auto grid h-11 w-11 place-items-center rounded-full">
            <Download :size="23" />
          </button>
        </div>
        <p class="px-3.5 pb-6 text-sm font-semibold">
          {{ photo.likes_count === 1 ? '1 Me gusta' : `${photo.likes_count || 0} Me gusta` }}
        </p>
      </article>
    </div>
  </div>
</template>

<style scoped>
.feed {
  background: var(--page-bg);
  color: var(--ink);
}
.feed-bar {
  background: var(--page-bg);
  border-bottom: 1px solid var(--line);
}
.feed-img {
  touch-action: manipulation;
  -webkit-user-drag: none;
  background: var(--tint);
  min-height: 12rem;
}
.avatar {
  background: var(--tint);
  color: var(--accent-text);
}
.mine-chip {
  background: var(--accent);
  color: var(--accent-on);
  vertical-align: 1px;
}
.liked {
  color: var(--heart);
}

/* Corazón grande del doble tap */
.burst {
  transform: translate(-50%, -50%);
  filter: drop-shadow(0 4px 18px rgb(0 0 0 / 0.35));
  animation: burst 0.9s cubic-bezier(0.17, 0.89, 0.32, 1.28) forwards;
}
@keyframes burst {
  0% {
    transform: translate(-50%, -50%) scale(0);
    opacity: 0;
  }
  15% {
    transform: translate(-50%, -50%) scale(1.2);
    opacity: 1;
  }
  30% {
    transform: translate(-50%, -50%) scale(0.95);
  }
  45%,
  75% {
    transform: translate(-50%, -50%) scale(1);
    opacity: 1;
  }
  100% {
    transform: translate(-50%, -50%) scale(0.9) translateY(-30%);
    opacity: 0;
  }
}

/* Corazón chico al dar like */
.pop {
  animation: pop 0.35s ease-out;
}
@keyframes pop {
  0% {
    transform: scale(1);
  }
  40% {
    transform: scale(1.3);
  }
  100% {
    transform: scale(1);
  }
}
</style>
