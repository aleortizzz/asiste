<script setup>
import { ref, onMounted } from 'vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'

const { event, loadEvent, saveEvent } = useEvent()

const form = ref({ name: '', event_date: '', venue_name: '', venue_address: '' })
const saving = ref(false)
const message = ref('')

onMounted(async () => {
  await loadEvent()
  if (event.value) {
    form.value = {
      name: event.value.name ?? '',
      event_date: event.value.event_date ?? '',
      venue_name: event.value.venue_name ?? '',
      venue_address: event.value.venue_address ?? '',
    }
  }
})

async function onSubmit() {
  saving.value = true
  message.value = ''
  try {
    await saveEvent(form.value)
    message.value = 'Guardado ✅'
  } catch (err) {
    message.value = `Error: ${err.message}`
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div>
    <AdminNav />
    <div class="mx-auto max-w-lg p-8">
      <h1 class="text-2xl font-semibold">Datos del salón / evento</h1>
      <form @submit.prevent="onSubmit" class="mt-6 space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Nombre del evento</label>
          <input v-model="form.name" required class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Fecha</label>
          <input v-model="form.event_date" type="date" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Nombre del salón</label>
          <input v-model="form.venue_name" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Dirección</label>
          <input v-model="form.venue_address" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
        </div>
        <p v-if="message" class="text-sm">{{ message }}</p>
        <button
          type="submit"
          :disabled="saving"
          class="rounded bg-gray-900 px-4 py-2 text-white disabled:opacity-50"
        >
          {{ saving ? 'Guardando...' : 'Guardar' }}
        </button>
      </form>
    </div>
  </div>
</template>
