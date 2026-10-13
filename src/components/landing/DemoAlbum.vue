<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { Heart, Camera } from '@lucide/vue'

// Demo de la portada: van llegando fotos de los invitados (como en /fotos),
// se les puede dar like y «subir» una. Fotos de public/fondos (Unsplash).
const POOL = ['/fondos/cel-1.jpg', '/fondos/cel-2.jpg', '/fondos/cel-3.jpg', '/fondos/cel-4.jpg', '/fondos/pc-4.jpg', '/fondos/pc-5.jpg']
const NAMES = ['Sofía', 'Bruno', 'Lola', 'Facu', 'Pilar', 'Mateo', 'Delfi']

let seq = 0
const photo = (i, likes = 0, by = null) => ({ id: seq++, src: POOL[i % POOL.length], likes, liked: false, by })
const photos = ref([photo(0, 24), photo(1, 17), photo(2, 31), photo(3, 9)])
const total = ref(132)
const people = ref(41)
const toast = ref(null)
let next = 4
let timer = null
let toastTimer = null

function add(by) {
  photos.value = [photo(next++, 0, by), ...photos.value].slice(0, 4)
  total.value++
  toast.value = by === 'vos' ? 'Subiste una foto' : `${by} subió una foto`
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => (toast.value = null), 1600)
}

function like(p) {
  p.liked = !p.liked
  p.likes += p.liked ? 1 : -1
}

// paused: copia invisible que la landing usa solo para medir el alto (sin animar).
const props = defineProps({ paused: Boolean })
onMounted(() => {
  if (props.paused) return
  timer = setInterval(() => add(NAMES[seq % NAMES.length]), 3200)
})
onUnmounted(() => {
  clearInterval(timer)
  clearTimeout(toastTimer)
})
</script>

<template>
  <div class="space-y-3">
    <div class="flex items-center justify-between gap-2">
      <div>
        <p class="font-bold">Fotos de la fiesta</p>
        <p class="text-sm text-obsidian/55 tabular-nums">{{ total }} fotos · {{ people }} invitados</p>
      </div>
      <button type="button" @click="add('vos')" class="flex shrink-0 items-center gap-1.5 rounded-full bg-accent px-3 py-2 text-sm font-bold text-chalk">
        <Camera :size="15" /> Subir foto
      </button>
    </div>
    <TransitionGroup name="pic" tag="div" class="relative grid grid-cols-2 gap-2">
      <div v-for="p in photos" :key="p.id" class="relative aspect-[4/3] overflow-hidden rounded-[1.1rem] bg-pumice">
        <img :src="p.src" alt="" loading="lazy" class="h-full w-full object-cover" />
        <span v-if="p.by" class="absolute top-2 left-2 rounded-full bg-chalk/90 px-2 py-0.5 text-xs font-bold">{{ p.by === 'vos' ? 'Vos' : p.by }}</span>
        <button
          type="button"
          @click="like(p)"
          :aria-pressed="p.liked"
          :aria-label="p.liked ? 'Sacar like' : 'Dar like'"
          class="absolute right-2 bottom-2 flex items-center gap-1 rounded-full bg-chalk/90 px-2 py-0.5 text-xs font-bold"
        >
          <Heart :size="12" class="transition-transform" :class="p.liked ? 'scale-125 fill-nogo text-nogo' : 'text-obsidian'" /> {{ p.likes }}
        </button>
      </div>
    </TransitionGroup>
    <div class="h-5">
      <Transition name="toast">
        <p v-if="toast" class="text-center text-sm font-bold text-accent">{{ toast }}</p>
      </Transition>
    </div>
  </div>
</template>

<style scoped>
.pic-move,
.pic-enter-active,
.pic-leave-active {
  transition: all 0.45s ease;
}
.pic-enter-from {
  opacity: 0;
  transform: scale(0.85);
}
.pic-leave-to {
  opacity: 0;
  transform: scale(0.9);
}
.pic-leave-active {
  position: absolute;
  width: calc(50% - 0.25rem);
}
.toast-enter-active,
.toast-leave-active {
  transition: opacity 0.25s ease;
}
.toast-enter-from,
.toast-leave-to {
  opacity: 0;
}
</style>
