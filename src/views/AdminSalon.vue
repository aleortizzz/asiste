<script setup>
import { ref, onMounted } from 'vue'
import AdminNav from '../components/AdminNav.vue'
import { useEvent } from '../composables/useEvent'

const { event, loadEvent, saveEvent } = useEvent()

const form = ref({
  name: '',
  event_date: '',
  reception_time: '',
  end_time: '',
  venue_name: '',
  venue_address: '',
  maps_url: '',
  dress_code: '',
  rsvp_deadline: '',
  notes: '',
  gift_alias: '',
})
const hasGuestLimit = ref(false)
const guestLimit = ref(1)
const saving = ref(false)
const message = ref('')

onMounted(async () => {
  await loadEvent()
  if (event.value) {
    form.value = {
      name: event.value.name ?? '',
      event_date: event.value.event_date ?? '',
      reception_time: event.value.reception_time ?? '',
      end_time: event.value.end_time ?? '',
      venue_name: event.value.venue_name ?? '',
      venue_address: event.value.venue_address ?? '',
      maps_url: event.value.maps_url ?? '',
      dress_code: event.value.dress_code ?? '',
      rsvp_deadline: event.value.rsvp_deadline ?? '',
      notes: event.value.notes ?? '',
      gift_alias: event.value.gift_alias ?? '',
    }
    hasGuestLimit.value = event.value.guest_limit != null
    guestLimit.value = event.value.guest_limit ?? 1
  }
})

// Postgres no acepta '' para columnas date/time — hay que mandar null
// cuando el campo quedó vacío.
const emptyAsNull = (value) => (value === '' ? null : value)

async function onSubmit() {
  saving.value = true
  message.value = ''
  try {
    await saveEvent({
      ...form.value,
      event_date: emptyAsNull(form.value.event_date),
      reception_time: emptyAsNull(form.value.reception_time),
      end_time: emptyAsNull(form.value.end_time),
      rsvp_deadline: emptyAsNull(form.value.rsvp_deadline),
      guest_limit: hasGuestLimit.value ? guestLimit.value : null,
    })
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
      <h1 class="text-2xl font-semibold">Creá tu invitación</h1>
      <form @submit.prevent="onSubmit" class="mt-6 space-y-6">
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Nombre del evento</label>
            <input v-model="form.name" required class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Fecha</label>
            <input v-model="form.event_date" type="date" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
          </div>
          <div class="flex gap-4">
            <div class="flex-1">
              <label class="block text-sm font-medium text-gray-700">Hora de recepción</label>
              <input v-model="form.reception_time" type="time" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
            </div>
            <div class="flex-1">
              <label class="block text-sm font-medium text-gray-700">Hora de fin</label>
              <input v-model="form.end_time" type="time" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
            </div>
          </div>
        </div>

        <div class="space-y-4 border-t border-gray-200 pt-4">
          <h2 class="text-sm font-semibold text-gray-500 uppercase">Ubicación</h2>
          <div>
            <label class="block text-sm font-medium text-gray-700">Nombre del salón</label>
            <input v-model="form.venue_name" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Dirección</label>
            <input v-model="form.venue_address" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Link de Google Maps</label>
            <input
              v-model="form.maps_url"
              type="url"
              placeholder="https://maps.app.goo.gl/..."
              class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
            />
          </div>
        </div>

        <div class="space-y-4 border-t border-gray-200 pt-4">
          <h2 class="text-sm font-semibold text-gray-500 uppercase">Detalles para los invitados</h2>
          <div>
            <label class="block text-sm font-medium text-gray-700">Código de vestimenta</label>
            <input
              v-model="form.dress_code"
              placeholder="Ej. Elegante sport"
              class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Fecha límite para confirmar</label>
            <input v-model="form.rsvp_deadline" type="date" class="mt-1 w-full rounded border border-gray-300 px-3 py-2" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Notas adicionales</label>
            <textarea
              v-model="form.notes"
              rows="3"
              placeholder="Ej. hay estacionamiento, evento sin niños, etc."
              class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
            ></textarea>
          </div>
        </div>

        <div class="space-y-4 border-t border-gray-200 pt-4">
          <h2 class="text-sm font-semibold text-gray-500 uppercase">Regalos</h2>
          <div>
            <label class="block text-sm font-medium text-gray-700">Alias para regalos</label>
            <input
              v-model="form.gift_alias"
              placeholder="Ej. antonella.15"
              class="mt-1 w-full rounded border border-gray-300 px-3 py-2"
            />
          </div>
        </div>

        <div class="space-y-2 border-t border-gray-200 pt-4">
          <label class="block text-sm font-medium text-gray-700">Cantidad de invitados</label>
          <div class="flex gap-4 text-sm text-gray-700">
            <label class="flex items-center gap-1">
              <input type="radio" :value="false" v-model="hasGuestLimit" />
              Ilimitado
            </label>
            <label class="flex items-center gap-1">
              <input type="radio" :value="true" v-model="hasGuestLimit" />
              Con tope
            </label>
          </div>
          <input
            v-if="hasGuestLimit"
            v-model.number="guestLimit"
            type="number"
            min="1"
            placeholder="Cantidad máxima de invitados"
            class="w-48 rounded border border-gray-300 px-3 py-2"
          />
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
