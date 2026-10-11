<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { Play, Square, RotateCcw, Trash2, Trophy, Users, Hourglass, MonitorPlay } from '@lucide/vue'
import { supabase } from '../../lib/supabase'
import { confirmDialog } from '../../composables/useConfirm'
import { formatDuration, rankAttempts } from '../../lib/trivia'

// El juego en vivo (AdminJuego.vue): abrir / cerrar, cuántos están jugando y
// el ranking completo. Mientras está abierto se actualiza solo cada 5 s.
const props = defineProps({
  game: { type: Object, required: true }, // { id, status, … }
  total: { type: Number, required: true }, // cantidad de preguntas
})
const emit = defineEmits(['update:game'])

const attempts = ref([])
const error = ref('')
const busy = ref(false)

async function fetchAttempts() {
  const { data, error: err } = await supabase
    .from('trivia_attempts')
    .select('id, player_name, started_at, submitted_at, correct_count, duration_ms')
    .eq('game_id', props.game.id)
  if (err) error.value = `No se pudo cargar el ranking: ${err.message}`
  else attempts.value = data
}

const playing = computed(() => attempts.value.filter((a) => !a.submitted_at))
const ranking = computed(() => rankAttempts(attempts.value.filter((a) => a.submitted_at)))

let timer = null
function startPolling() {
  stopPolling()
  timer = setInterval(() => {
    if (document.visibilityState === 'visible') fetchAttempts()
  }, 5000)
}
function stopPolling() {
  clearInterval(timer)
  timer = null
}

onMounted(fetchAttempts)
onUnmounted(stopPolling)
watch(
  () => props.game.status,
  (s) => (s === 'abierto' ? startPolling() : stopPolling()),
  { immediate: true },
)

async function setStatus(status) {
  error.value = ''
  busy.value = true
  const { data, error: err } = await supabase
    .from('trivia_games')
    .update({ status })
    .eq('id', props.game.id)
    .select('id, event_id, title, time_limit_seconds, status')
    .single()
  if (err) error.value = `No se pudo cambiar el estado: ${err.message}`
  else {
    emit('update:game', data)
    // Al cerrar, el servidor corrige a los que estaban jugando.
    await fetchAttempts()
  }
  busy.value = false
}

async function openGame() {
  const reopening = props.game.status === 'cerrado'
  const ok = await confirmDialog({
    title: reopening ? '¿Reabrir el juego?' : '¿Abrir el juego?',
    message: reopening
      ? 'Se puede volver a jugar. Los que ya jugaron siguen en el ranking.'
      : 'Aparece el botón «Jugar» en la página de fotos del QR y los invitados ya pueden empezar.',
    confirmText: reopening ? 'Reabrir' : 'Abrir juego',
  })
  if (ok) setStatus('abierto')
}

async function closeGame() {
  await fetchAttempts()
  const n = playing.value.length
  const ok = await confirmDialog({
    title: '¿Cerrar el juego?',
    message:
      (n
        ? `${n === 1 ? 'Hay 1 persona jugando' : `Hay ${n} personas jugando`} todavía: se corrige lo que hayan respondido hasta ahora. `
        : '') + 'Nadie más puede jugar y cada invitado ve las respuestas correctas.',
    confirmText: 'Cerrar juego',
    tone: 'danger',
  })
  if (ok) setStatus('cerrado')
}

async function resetGame() {
  const ok = await confirmDialog({
    title: '¿Reiniciar el juego?',
    message: `Se borran los ${attempts.value.length} intentos y el ranking, y el juego vuelve a quedar sin abrir. Las preguntas no se tocan. Sirve para probarlo antes de la fiesta.`,
    confirmText: 'Reiniciar',
    tone: 'danger',
  })
  if (!ok) return
  error.value = ''
  busy.value = true
  const { error: err } = await supabase.from('trivia_attempts').delete().eq('game_id', props.game.id)
  if (err) {
    error.value = `No se pudo reiniciar: ${err.message}`
    busy.value = false
    return
  }
  attempts.value = []
  await setStatus('borrador')
}

async function removeAttempt(a) {
  const ok = await confirmDialog({
    title: `¿Borrar a ${a.player_name}?`,
    message: 'Sale del ranking. Si tiene el juego abierto en el celular, ya no puede seguir jugando ni enviar.',
    confirmText: 'Borrar',
    tone: 'danger',
  })
  if (!ok) return
  error.value = ''
  const { error: err } = await supabase.from('trivia_attempts').delete().eq('id', a.id)
  if (err) error.value = `No se pudo borrar: ${err.message}`
  else attempts.value = attempts.value.filter((x) => x.id !== a.id)
}

const medal = (pos) => ({ 1: 'bg-sulfur', 2: 'bg-pumice', 3: 'bg-[#f3d6b8]' })[pos] ?? 'bg-chalk'
</script>

<template>
  <section class="rounded-[2rem] bg-limestone p-6 sm:p-8">
    <div class="flex flex-wrap items-center justify-between gap-4">
      <div>
        <h2 class="text-xl font-bold">En vivo</h2>
        <p class="mt-1 text-sm text-obsidian/60">
          <template v-if="game.status === 'borrador'">Abrilo cuando lo anuncies: recién ahí aparece el botón «Jugar».</template>
          <template v-else-if="game.status === 'abierto'">Los invitados están jugando. El ranking se actualiza solo.</template>
          <template v-else>Juego cerrado. Cada invitado ve las respuestas correctas en su celular.</template>
        </p>
      </div>
      <div class="flex flex-wrap gap-2">
        <!-- Ranking grande para el proyector de la fiesta (TriviaProyector.vue). -->
        <a
          :href="`/juego/${game.event_id}/ranking`"
          target="_blank"
          rel="noopener"
          class="admin-btn-secondary !py-2"
        >
          <MonitorPlay :size="16" /> Pantalla para proyector
        </a>
        <button
          v-if="attempts.length && game.status !== 'abierto'"
          type="button"
          @click="resetGame"
          :disabled="busy"
          class="admin-btn-secondary !py-2"
        >
          <RotateCcw :size="16" /> Reiniciar
        </button>
        <button
          v-if="game.status === 'abierto'"
          type="button"
          @click="closeGame"
          :disabled="busy"
          class="admin-btn-primary !bg-obsidian !py-2"
        >
          <Square :size="15" /> Cerrar juego
        </button>
        <button v-else type="button" @click="openGame" :disabled="busy || !total" class="admin-btn-primary !py-2">
          <Play :size="16" /> {{ game.status === 'cerrado' ? 'Reabrir' : 'Abrir juego' }}
        </button>
      </div>
    </div>

    <p v-if="!total" class="admin-help mt-3 mb-0">Cargá al menos una pregunta para poder abrirlo.</p>
    <p v-if="error" class="mt-4 rounded-[1rem] bg-nogo/15 px-3 py-2 text-sm font-bold">{{ error }}</p>

    <div v-if="attempts.length" class="mt-5 flex flex-wrap gap-2 text-sm">
      <span class="inline-flex items-center gap-1.5 rounded-full bg-chalk px-3 py-1.5">
        <Users :size="15" /> <strong>{{ ranking.length }}</strong> {{ ranking.length === 1 ? 'terminó' : 'terminaron' }}
      </span>
      <span v-if="playing.length" class="inline-flex items-center gap-1.5 rounded-full bg-go/25 px-3 py-1.5">
        <Hourglass :size="15" /> <strong>{{ playing.length }}</strong> jugando ahora
      </span>
    </div>

    <div v-if="ranking.length" class="mt-4 flex items-center gap-3 pr-2 pl-2 text-xs font-bold text-obsidian/50">
      <span class="w-8 shrink-0 text-center">#</span>
      <span class="flex-1">Jugador</span>
      <span class="w-20 shrink-0 text-right">Correctas</span>
      <span class="w-16 shrink-0 text-right">Tiempo</span>
      <span class="w-8 shrink-0"></span>
    </div>
    <ol v-if="ranking.length" class="mt-1.5 space-y-1.5">
      <li
        v-for="a in ranking"
        :key="a.id"
        class="flex items-center gap-3 rounded-[1.25rem] bg-chalk py-2 pr-2 pl-2"
      >
        <span :class="medal(a.position)" class="grid h-8 w-8 shrink-0 place-items-center rounded-full text-sm font-bold">
          <Trophy v-if="a.position === 1" :size="15" />
          <template v-else>{{ a.position }}</template>
        </span>
        <span class="min-w-0 flex-1 truncate font-bold">{{ a.player_name }}</span>
        <span class="w-20 shrink-0 text-right text-sm">
          <strong>{{ a.correct_count }}</strong><span class="text-obsidian/45">/{{ total }}</span>
        </span>
        <span class="w-16 shrink-0 text-right text-sm text-obsidian/55 tabular-nums">{{ formatDuration(a.duration_ms) }}</span>
        <button
          type="button"
          @click="removeAttempt(a)"
          :aria-label="`Borrar a ${a.player_name}`"
          class="grid h-8 w-8 shrink-0 place-items-center rounded-full text-obsidian/40 hover:bg-nogo/15 hover:text-nogo"
        >
          <Trash2 :size="14" />
        </button>
      </li>
    </ol>
  </section>
</template>
