import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'

const BUCKET = 'event-photos'
export const PHOTO_SLOTS = ['banner', 'retrato', 'detalle', 'momentos', 'galeria']
export const SINGLE_SLOTS = ['banner', 'detalle']
export const MAX_GALERIA = 8

// Sube un archivo al bucket y devuelve { url, path }.
async function uploadFile(slot, file) {
  const { user } = useAuth()
  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase()
  const path = `${user.value.id}/${slot}/${crypto.randomUUID()}.${ext}`
  const { error } = await supabase.storage.from(BUCKET).upload(path, file, {
    cacheControl: '3600',
    upsert: false,
    contentType: file.type,
  })
  if (error) throw error
  const { data } = supabase.storage.from(BUCKET).getPublicUrl(path)
  return { url: data.publicUrl, path }
}

async function removeFile(path) {
  if (!path) return
  await supabase.storage.from(BUCKET).remove([path])
}

// Persiste solo las columnas de fotos del evento (update parcial).
async function savePhotoColumns(eventId, cols) {
  const { error } = await supabase.from('events').update(cols).eq('id', eventId)
  if (error) throw error
}

export function useEventPhotos() {
  return { uploadFile, removeFile, savePhotoColumns, PHOTO_SLOTS, SINGLE_SLOTS, MAX_GALERIA }
}
