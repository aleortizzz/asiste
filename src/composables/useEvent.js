import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'

// Mismo patrón singleton que useAuth: el evento "actual" del admin,
// compartido entre Salón / Mesas / Invitados sin tener que recargarlo cada vez.
const event = ref(null)
const loading = ref(false)

// --- Modo superadmin: "estoy viendo el evento de otro cliente" -----------
// Se guarda en sessionStorage para que sobreviva a una recarga de página,
// pero se pierde solo al cerrar la pestaña (no queda "pegado" para siempre).
const VIEW_KEY = 'superadmin-viewing-event'
function readViewing() {
  try {
    const raw = sessionStorage.getItem(VIEW_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}
const viewing = ref(readViewing()) // { id, name, owner_email } | null

function setViewingEvent(target) {
  viewing.value = target
  try {
    if (target) sessionStorage.setItem(VIEW_KEY, JSON.stringify(target))
    else sessionStorage.removeItem(VIEW_KEY)
  } catch {
    /* modo privado */
  }
  event.value = null // fuerza a releer en el próximo loadEvent()
}

async function loadEvent() {
  loading.value = true
  const { user } = useAuth()
  const query = supabase.from('events').select('*')
  const { data, error } = viewing.value
    ? await query.eq('id', viewing.value.id).maybeSingle()
    : await query.eq('owner_user_id', user.value.id).maybeSingle()
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
    // Un superadmin "viendo" a alguien nunca debería llegar acá (el evento
    // ya existe si lo eligió de la lista) — por las dudas, no lo adueñamos.
    if (viewing.value) throw new Error('No hay evento para editar en este modo.')
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
  return { event, loading, loadEvent, saveEvent, viewing, setViewingEvent }
}
