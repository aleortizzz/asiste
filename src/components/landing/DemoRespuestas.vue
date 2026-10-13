<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { UserCheck, UserX, MailQuestion, Eye, Link2, Check, RotateCcw } from '@lucide/vue'

// Demo de la portada: las familias que faltan van respondiendo solas y los
// números se actualizan, como en el Inicio del panel.
const START = () => [
  { name: 'Familia Quiroga', people: 4, seen: 'todavía no abrió el link', answer: 'si' },
  { name: 'Familia Medina', people: 3, seen: 'entró ayer a las 21:40', answer: 'si' },
  { name: 'Martina Sosa', people: 1, seen: 'entró hoy a las 10:12', answer: 'no' },
  { name: 'Familia Toledo', people: 5, seen: 'todavía no abrió el link', answer: 'si' },
  { name: 'Ignacio Vera', people: 2, seen: 'entró hoy a las 09:30', answer: 'si' },
]

const yes = ref(80)
const no = ref(9)
const pending = ref(START())
const toast = ref(null)
const copied = ref(null)
let timer = null
let toastTimer = null

function tick() {
  const next = pending.value[0]
  if (!next) return
  pending.value = pending.value.slice(1)
  if (next.answer === 'si') yes.value += next.people
  else no.value += next.people
  toast.value = next.answer === 'si'
    ? { ok: true, text: `${next.name} confirmó ${next.people === 1 ? '1 persona' : `${next.people} personas`}` }
    : { ok: false, text: `${next.name} no va a poder ir` }
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => (toast.value = null), 1800)
}

function restart() {
  yes.value = 80
  no.value = 9
  pending.value = START()
}

function copy(f) {
  copied.value = f.name
  setTimeout(() => copied.value === f.name && (copied.value = null), 1300)
}

onMounted(() => (timer = setInterval(tick, 2200)))
onUnmounted(() => {
  clearInterval(timer)
  clearTimeout(toastTimer)
})
</script>

<template>
  <div class="space-y-3">
    <div class="grid grid-cols-3 gap-2 text-center">
      <div class="rounded-[1.1rem] bg-chalk p-3">
        <UserCheck :size="18" class="mx-auto text-go" />
        <p class="mt-1 text-2xl font-bold tabular-nums">{{ yes }}</p>
        <p class="text-xs text-obsidian/55">vienen</p>
      </div>
      <div class="rounded-[1.1rem] bg-chalk p-3">
        <UserX :size="18" class="mx-auto text-nogo" />
        <p class="mt-1 text-2xl font-bold tabular-nums">{{ no }}</p>
        <p class="text-xs text-obsidian/55">no vienen</p>
      </div>
      <div class="rounded-[1.1rem] p-3 transition-colors" :class="pending.length ? 'bg-sulfur/70' : 'bg-go/25'">
        <MailQuestion :size="18" class="mx-auto" />
        <p class="mt-1 text-2xl font-bold tabular-nums">{{ pending.length }}</p>
        <p class="text-xs text-obsidian/70">falta que respondan</p>
      </div>
    </div>

    <div class="relative h-9">
      <Transition name="toast">
        <p
          v-if="toast"
          :key="toast.text"
          class="absolute inset-0 flex items-center justify-center gap-1.5 rounded-full text-sm font-bold"
          :class="toast.ok ? 'bg-go/25' : 'bg-nogo/15'"
        >
          <Check v-if="toast.ok" :size="15" /> {{ toast.text }}
        </p>
        <p v-else-if="pending.length" class="absolute inset-0 flex items-center px-1 text-xs font-bold tracking-wide text-obsidian/50 uppercase">
          Falta que respondan
        </p>
      </Transition>
    </div>

    <TransitionGroup name="row" tag="div" class="relative space-y-2">
      <div v-for="f in pending.slice(0, 3)" :key="f.name" class="flex items-center gap-3 rounded-[1.1rem] bg-chalk p-2 pl-3">
        <span class="min-w-0 flex-1">
          <span class="block truncate font-bold">{{ f.name }}</span>
          <span class="flex items-center gap-1 text-xs text-obsidian/55"><Eye :size="12" /> {{ f.seen }}</span>
        </span>
        <button
          type="button"
          @click="copy(f)"
          class="flex shrink-0 items-center gap-1 rounded-full border-[1.5px] px-2.5 py-1 text-xs font-bold transition-colors"
          :class="copied === f.name ? 'border-accent bg-accent text-chalk' : 'border-obsidian'"
        >
          <Check v-if="copied === f.name" :size="13" />
          <Link2 v-else :size="13" />
          {{ copied === f.name ? 'Copiado' : 'Copiar link' }}
        </button>
      </div>
    </TransitionGroup>

    <div v-if="!pending.length" class="flex items-center justify-between gap-3 rounded-[1.1rem] bg-chalk p-3">
      <p class="font-bold">¡Respondieron todos!</p>
      <button type="button" @click="restart" class="flex items-center gap-1 text-sm font-bold text-accent"><RotateCcw :size="14" /> Ver de nuevo</button>
    </div>
  </div>
</template>

<style scoped>
.row-move,
.row-enter-active,
.row-leave-active {
  transition: all 0.35s ease;
}
.row-enter-from {
  opacity: 0;
  transform: translateY(8px);
}
.row-leave-to {
  opacity: 0;
  transform: translateX(24px);
}
.row-leave-active {
  position: absolute;
  left: 0;
  right: 0;
}
.toast-enter-active,
.toast-leave-active {
  transition: all 0.25s ease;
}
.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}
</style>
