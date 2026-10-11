<script setup>
import { ref, computed, onMounted } from 'vue'
import { Trophy, Plus, Pencil, Trash2, Check, CircleCheck, Circle, Timer, Shuffle } from '@lucide/vue'
import AdminNav from '../components/AdminNav.vue'
import QuestionEditor from '../components/trivia/QuestionEditor.vue'
import TriviaLive from '../components/trivia/TriviaLive.vue'
import { useEvent } from '../composables/useEvent'
import { supabase } from '../lib/supabase'
import { confirmDialog } from '../composables/useConfirm'

// Trivia para jugar durante la fiesta: acá se arma (título, tiempo límite y
// preguntas de multiple choice). Los invitados lo encuentran en la página de
// fotos del QR cuando el juego está abierto. Ver migrations/20261011_trivia.sql.
const { event, loadEvent } = useEvent()
const game = ref(null) // { id, title, time_limit_seconds, status } | null si todavía no se creó
const questions = ref([])
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  if (!event.value) await loadEvent()
  if (event.value) await fetchGame()
  if (!game.value) syncSettings()
  loading.value = false
})

async function fetchGame() {
  const { data, error: err } = await supabase
    .from('trivia_games')
    .select('id, event_id, title, time_limit_seconds, status')
    .eq('event_id', event.value.id)
    .maybeSingle()
  if (err) {
    error.value = `No se pudo cargar el juego: ${err.message}`
    return
  }
  game.value = data
  if (data) {
    syncSettings()
    await fetchQuestions()
  }
}

async function fetchQuestions() {
  const { data, error: err } = await supabase
    .from('trivia_questions')
    .select('id, position, question, options, correct_index')
    .eq('game_id', game.value.id)
    .order('position')
    .order('created_at')
  if (err) error.value = `No se pudieron cargar las preguntas: ${err.message}`
  else questions.value = data
}

// El juego se crea recién con el primer cambio, no al entrar a la pantalla.
const defaultTitle = computed(() => {
  if (event.value?.event_type === 'empresarial') return 'Trivia'
  const name = (event.value?.hero_title || '').trim()
  return name ? `¿Cuánto conocés a ${name}?` : 'Trivia'
})

async function ensureGame() {
  if (game.value) return
  const { data, error: err } = await supabase
    .from('trivia_games')
    .insert({ event_id: event.value.id, title: title.value.trim() || defaultTitle.value, time_limit_seconds: minutes.value * 60 })
    .select('id, event_id, title, time_limit_seconds, status')
    .single()
  if (err) throw err
  game.value = data
}

const STATUS = {
  borrador: { label: 'Sin abrir', hint: 'Los invitados todavía no lo ven.', cls: 'bg-chalk text-obsidian/70' },
  abierto: { label: 'Abierto', hint: 'Los invitados están jugando.', cls: 'bg-go/25 text-obsidian' },
  cerrado: { label: 'Cerrado', hint: 'Ya no se puede jugar.', cls: 'bg-obsidian text-chalk' },
}
const status = computed(() => STATUS[game.value?.status ?? 'borrador'])

// --- Título y tiempo ----------------------------------------------------------------
// Se guardan solos al salir del campo / elegir el tiempo.
const title = ref('')
const minutes = ref(5)
const MINUTES = [1, 2, 3, 4, 5, 6, 7, 8, 10, 15]
const settingsSaved = ref(false)
let savedTimer = null

function syncSettings() {
  title.value = game.value?.title ?? defaultTitle.value
  minutes.value = game.value ? Math.round(game.value.time_limit_seconds / 60) : 5
}
async function saveSettings() {
  if (!event.value) return
  error.value = ''
  const fields = { title: title.value.trim() || defaultTitle.value, time_limit_seconds: minutes.value * 60 }
  try {
    if (!game.value) await ensureGame()
    else if (fields.title !== game.value.title || fields.time_limit_seconds !== game.value.time_limit_seconds) {
      const { data, error: err } = await supabase
        .from('trivia_games')
        .update(fields)
        .eq('id', game.value.id)
        .select('id, event_id, title, time_limit_seconds, status')
        .single()
      if (err) throw err
      game.value = data
    } else return
    title.value = game.value.title
    settingsSaved.value = true
    clearTimeout(savedTimer)
    savedTimer = setTimeout(() => (settingsSaved.value = false), 1800)
  } catch (err) {
    error.value = `No se pudo guardar: ${err.message}`
  }
}

// Unos 10 segundos por pregunta es un ritmo cómodo para leer y elegir.
const suggestedMinutes = computed(() => Math.max(1, Math.round((questions.value.length * 10) / 60)))

// --- Editor de una pregunta ----------------------------------------------------------
// Una sola a la vez: la que se edita (id) o una nueva (id null). `editorKey`
// vuelve a montar el formulario para que arranque con el foco en la pregunta.
const editing = ref(null) // { id: uuid | null, question, options: string[], correct_index }
const editorKey = ref(0)
const editorError = ref('')
const saving = ref(false)

function openEditor(value) {
  editorError.value = ''
  editing.value = value
  editorKey.value++
}

const startNew = () => openEditor({ id: null, question: '', options: ['', '', ''], correct_index: 0 })
const startEdit = (q) => openEditor({ id: q.id, question: q.question, options: [...q.options], correct_index: q.correct_index })

function cancelEdit() {
  editing.value = null
  editorError.value = ''
}

async function saveQuestion() {
  const e = editing.value
  const question = e.question.trim()
  const options = e.options.map((o) => o.trim())
  if (!question) return (editorError.value = 'Escribí la pregunta.')
  if (options.some((o) => !o)) return (editorError.value = 'Completá todas las opciones o borrá las que sobran.')
  if (new Set(options.map((o) => o.toLowerCase())).size !== options.length) {
    return (editorError.value = 'Hay dos opciones iguales.')
  }

  editorError.value = ''
  saving.value = true
  try {
    await ensureGame()
    const fields = { question, options, correct_index: e.correct_index }
    if (e.id) {
      const { data, error: err } = await supabase
        .from('trivia_questions')
        .update(fields)
        .eq('id', e.id)
        .select('id, position, question, options, correct_index')
        .single()
      if (err) throw err
      questions.value = questions.value.map((q) => (q.id === e.id ? data : q))
      editing.value = null
    } else {
      const position = questions.value.length ? Math.max(...questions.value.map((q) => q.position)) + 1 : 0
      const { data, error: err } = await supabase
        .from('trivia_questions')
        .insert({ ...fields, game_id: game.value.id, position })
        .select('id, position, question, options, correct_index')
        .single()
      if (err) throw err
      questions.value = [...questions.value, data]
      // Queda abierto en blanco para cargar la siguiente de corrido.
      startNew()
    }
  } catch (err) {
    editorError.value = `No se pudo guardar: ${err.message}`
  } finally {
    saving.value = false
  }
}

// --- Borrar -----------------------------------------------------------------
const busyId = ref(null)

async function removeQuestion(q) {
  const ok = await confirmDialog({
    title: '¿Eliminar esta pregunta?',
    message: `«${q.question}» deja de aparecer en el juego. No se puede deshacer.`,
    confirmText: 'Eliminar',
    tone: 'danger',
  })
  if (!ok) return
  error.value = ''
  busyId.value = q.id
  const { error: err } = await supabase.from('trivia_questions').delete().eq('id', q.id)
  if (err) error.value = `No se pudo eliminar: ${err.message}`
  else {
    questions.value = questions.value.filter((x) => x.id !== q.id)
    if (editing.value?.id === q.id) editing.value = null
  }
  busyId.value = null
}
</script>

<template>
  <div class="admin-page">
    <AdminNav />
    <div class="mx-auto max-w-3xl px-4 pt-4 pb-16 lg:px-8 lg:pt-8">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 class="admin-display text-5xl sm:text-6xl">Juego</h1>
          <p class="mt-3 max-w-lg text-obsidian/60">
            Una trivia para jugar en la fiesta: tus invitados la encuentran escaneando el QR de las mesas. Gana quien más
            acierta y, si empatan, quien tardó menos.
          </p>
        </div>
        <span v-if="game" :class="status.cls" class="rounded-full px-3 py-1 text-sm font-bold" :title="status.hint">
          {{ status.label }}
        </span>
      </div>

      <p v-if="loading" class="mt-10 text-obsidian/55">Cargando…</p>

      <div v-else-if="!event" class="mt-8 rounded-[2rem] bg-limestone p-8">
        <p class="text-obsidian/60">Primero creá tu invitación, después vas a poder armar el juego.</p>
        <router-link :to="{ name: 'admin-salon' }" class="admin-btn-primary mt-5">Creá tu invitación</router-link>
      </div>

      <template v-else>
        <p v-if="error" class="mt-4 rounded-[1.25rem] bg-nogo/15 px-4 py-3 text-sm font-bold">{{ error }}</p>

        <p
          v-if="game?.status === 'abierto'"
          class="mt-4 rounded-[1.25rem] bg-sulfur px-4 py-3 text-sm font-bold"
        >
          El juego está abierto: si cambiás una pregunta ahora, afecta a los que están jugando.
        </p>

        <TriviaLive
          v-if="game"
          :game="game"
          :total="questions.length"
          class="mt-6"
          @update:game="game = $event"
        />

        <!-- Título y tiempo -->
        <section class="mt-6 rounded-[2rem] bg-limestone p-6 sm:p-8">
          <div class="grid gap-5 sm:grid-cols-[1fr_auto]">
            <label class="block">
              <span class="admin-label">Título del juego</span>
              <input v-model="title" @change="saveSettings" type="text" maxlength="80" class="admin-input" />
            </label>
            <label class="block">
              <span class="admin-label">Tiempo para jugar</span>
              <select v-model.number="minutes" @change="saveSettings" class="admin-input pr-10 sm:w-40">
                <option v-for="m in MINUTES" :key="m" :value="m">{{ m }} {{ m === 1 ? 'minuto' : 'minutos' }}</option>
              </select>
            </label>
          </div>
          <p class="admin-help mt-3 mb-0 flex items-center gap-1.5">
            <Check v-if="settingsSaved" :size="14" class="text-accent" />
            <Timer v-else :size="14" />
            <template v-if="settingsSaved">Guardado</template>
            <template v-else-if="questions.length">
              Con {{ questions.length }} {{ questions.length === 1 ? 'pregunta' : 'preguntas' }}, unos
              {{ suggestedMinutes }} {{ suggestedMinutes === 1 ? 'minuto' : 'minutos' }} alcanzan para leerlas con calma.
            </template>
            <template v-else>El reloj arranca cuando cada invitado toca «Empezar».</template>
          </p>
        </section>

        <!-- Preguntas -->
        <div class="mt-8 flex items-end justify-between gap-4">
          <h2 class="text-xl font-bold">
            Preguntas
            <span v-if="questions.length" class="font-medium text-obsidian/50">· {{ questions.length }}</span>
          </h2>
          <p class="text-sm text-obsidian/50">Sugerido: entre 20 y 30</p>
        </div>
        <p class="mt-2 flex items-start gap-1.5 text-sm text-obsidian/55">
          <Shuffle :size="15" class="mt-0.5 shrink-0" />
          Cada invitado ve las preguntas y las opciones en otro orden, así que podés poner la correcta siempre primera.
        </p>

        <div
          v-if="!questions.length && !editing"
          class="mt-4 rounded-[2rem] bg-limestone p-8 text-center"
        >
          <span class="mx-auto grid h-12 w-12 place-items-center rounded-full bg-chalk">
            <Trophy :size="20" />
          </span>
          <p class="mt-4 font-bold">Todavía no hay preguntas</p>
          <p class="mt-1 text-sm text-obsidian/60">
            Cada una tiene de 2 a 4 opciones y una sola correcta.
          </p>
          <button type="button" @click="startNew" class="admin-btn-primary mt-5">
            <Plus :size="18" />
            Agregar la primera
          </button>
        </div>

        <ol class="mt-4 space-y-2">
          <li v-for="(q, i) in questions" :key="q.id">
            <!-- Editando esta pregunta -->
            <QuestionEditor
              v-if="editing?.id === q.id"
              :key="editorKey"
              v-model="editing"
              :number="i + 1"
              :error="editorError"
              :saving="saving"
              @save="saveQuestion"
              @cancel="cancelEdit"
            />

            <!-- Vista normal -->
            <div v-else class="flex gap-3 rounded-[1.5rem] bg-limestone p-4">
              <span class="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-chalk text-sm font-bold">{{ i + 1 }}</span>
              <div class="min-w-0 flex-1">
                <p class="font-bold">{{ q.question }}</p>
                <ul class="mt-2 grid gap-1 sm:grid-cols-2">
                  <li
                    v-for="(opt, j) in q.options"
                    :key="j"
                    class="flex items-center gap-1.5 text-sm"
                    :class="j === q.correct_index ? 'font-bold' : 'text-obsidian/60'"
                  >
                    <CircleCheck v-if="j === q.correct_index" :size="15" class="shrink-0 text-go" />
                    <Circle v-else :size="15" class="shrink-0 text-obsidian/25" />
                    <span class="min-w-0 break-words">{{ opt }}</span>
                  </li>
                </ul>
              </div>
              <div class="flex shrink-0 items-start gap-0.5">
                <button
                  type="button"
                  @click="startEdit(q)"
                  aria-label="Editar"
                  class="grid h-8 w-8 place-items-center rounded-full text-obsidian/55 hover:bg-chalk"
                >
                  <Pencil :size="15" />
                </button>
                <button
                  type="button"
                  @click="removeQuestion(q)"
                  :disabled="busyId === q.id"
                  aria-label="Eliminar"
                  class="grid h-8 w-8 place-items-center rounded-full text-obsidian/55 hover:bg-nogo/15 hover:text-nogo"
                >
                  <Trash2 :size="15" />
                </button>
              </div>
            </div>
          </li>
        </ol>

        <!-- Pregunta nueva -->
        <QuestionEditor
          v-if="editing && !editing.id"
          :key="editorKey"
          v-model="editing"
          :number="questions.length + 1"
          :error="editorError"
          :saving="saving"
          :submit-text="'Guardar y agregar otra'"
          :cancel-text="questions.length ? 'Listo' : 'Cancelar'"
          class="mt-2"
          @save="saveQuestion"
          @cancel="cancelEdit"
        />

        <button
          v-if="questions.length && !editing"
          type="button"
          @click="startNew"
          class="mt-3 flex w-full items-center justify-center gap-2 rounded-[1.5rem] border-2 border-dashed border-obsidian/15 p-4 font-bold text-obsidian/60 transition-colors hover:border-accent hover:text-accent"
        >
          <Plus :size="18" />
          Agregar pregunta
        </button>
      </template>
    </div>
  </div>
</template>
