import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'

// Mismo patrón singleton que useAuth: el evento "actual" del admin,
// compartido entre Salón / Mesas / Invitados sin tener que recargarlo cada vez.
const event = ref(null)
const loading = ref(false)

async function loadEvent() {
  loading.value = true
  const { user } = useAuth()
  const { data, error } = await supabase
    .from('events')
    .select('*')
    .eq('owner_user_id', user.value.id)
    .maybeSingle()
  if (!error) event.value = data
  loading.value = false
  if (error) throw error
}

async function saveEvent(fields) {
  const { user } = useAuth()
  if (event.value) {
    const { data, error } = await supabase
      .from('events')
      .update(fields)
      .eq('id', event.value.id)
      .select()
      .single()
    if (error) throw error
    event.value = data
  } else {
    const { data, error } = await supabase
      .from('events')
      .insert({ ...fields, owner_user_id: user.value.id })
      .select()
      .single()
    if (error) throw error
    event.value = data
  }
}

export function useEvent() {
  return { event, loading, loadEvent, saveEvent }
}
