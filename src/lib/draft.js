import { supabase } from './supabase'

// Borrador de invitación sin cuenta (/crear): la persona prueba el editor sin
// registrarse y todo queda en SU navegador, no en la base. Así quien prueba y
// no compra no ocupa lugar en Supabase. Al crear la cuenta (o ingresar),
// migrateDraft() lo pasa a la base: crea el evento, sube las fotos y borra el
// borrador.
//
// - Textos, colores y demás columnas: localStorage (DRAFT_KEY), como
//   { fields: {...} } con lo mismo que el editor le pasaría a la base.
// - Fotos: IndexedDB (localStorage no alcanza para imágenes). En las columnas
//   de fotos quedan como { path: 'local:<id>' }; al abrir el borrador se les
//   arma una url temporal (blob:) para verlas.
//
// Si la persona arma el borrador en un navegador y se registra en otro, el
// borrador no viaja: sin cuenta no hay forma de saber de quién es.
const DRAFT_KEY = 'asiste-borrador'
const DB_NAME = 'asiste-borrador'
const STORE = 'fotos'
const LOCAL = 'local:'
const BUCKET = 'event-photos'
const PHOTO_COLUMNS = ['banner', 'retrato', 'detalle', 'momentos', 'galeria', 'logo', 'sponsors']

// Las columnas que el editor usa para saber qué secciones mostrar ('agenda'
// in event, etc.): en el borrador están desde el principio, como en un evento
// nuevo de la base. No se mandan a la base: solo `fields`.
const COLUMN_DEFAULTS = {
  id: 'borrador',
  plan: 'gratis',
  rsvp_deadline_strict: false,
  tono: null,
  logo_white: false,
  sponsors_white: false,
  agenda: null,
  rsvp_fields: null,
  bilingual: false,
}

// --- localStorage ---------------------------------------------------------
function readDraft() {
  try {
    const raw = localStorage.getItem(DRAFT_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}
function writeDraft(draft) {
  try {
    localStorage.setItem(DRAFT_KEY, JSON.stringify(draft))
  } catch {
    /* modo privado o lleno: el borrador vive solo mientras la página esté abierta */
  }
}
export const hasDraft = () => !!readDraft()

// --- IndexedDB (fotos) ------------------------------------------------------
let dbPromise = null
function db() {
  if (!dbPromise) {
    dbPromise = new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, 1)
      req.onupgradeneeded = () => req.result.createObjectStore(STORE)
      req.onsuccess = () => resolve(req.result)
      req.onerror = () => reject(req.error)
    })
  }
  return dbPromise
}
async function idb(mode, fn) {
  const d = await db()
  return new Promise((resolve, reject) => {
    const tx = d.transaction(STORE, mode)
    const req = fn(tx.objectStore(STORE))
    tx.oncomplete = () => resolve(req?.result)
    tx.onerror = () => reject(tx.error)
  })
}
const idbGet = (id) => idb('readonly', (s) => s.get(id))

// --- Lo que usa el editor (vía useEvent / useEventPhotos) ---------------------

// El «evento» del borrador, con urls temporales para las fotos guardadas.
export async function loadDraftEvent() {
  const fields = { ...(readDraft()?.fields ?? {}) }
  for (const col of PHOTO_COLUMNS) {
    if (!Array.isArray(fields[col])) continue
    const items = []
    for (const item of fields[col]) {
      if (!item?.path?.startsWith(LOCAL)) {
        items.push(item)
        continue
      }
      const blob = await idbGet(item.path.slice(LOCAL.length)).catch(() => null)
      if (blob) items.push({ ...item, url: URL.createObjectURL(blob) })
    }
    fields[col] = items
  }
  return { ...COLUMN_DEFAULTS, ...fields }
}

// Guarda columnas en el borrador (lo que el editor le mandaría a la base).
// Las fotos se guardan sin la url temporal: se rearma al abrir.
export function saveDraftFields(cols) {
  const draft = readDraft() ?? { fields: {} }
  const clean = { ...cols }
  for (const col of PHOTO_COLUMNS) {
    if (Array.isArray(clean[col])) {
      clean[col] = clean[col].map((it) => (it?.path?.startsWith(LOCAL) ? { ...it, url: undefined } : it))
    }
  }
  draft.fields = { ...draft.fields, ...clean }
  draft.updatedAt = new Date().toISOString()
  writeDraft(draft)
}

export async function saveDraftPhoto(file) {
  const id = crypto.randomUUID()
  await idb('readwrite', (s) => s.put(file, id))
  return { url: URL.createObjectURL(file), path: `${LOCAL}${id}` }
}

export async function removeDraftPhoto(path) {
  if (!path?.startsWith(LOCAL)) return
  await idb('readwrite', (s) => s.delete(path.slice(LOCAL.length))).catch(() => {})
}

export async function clearDraft() {
  try {
    localStorage.removeItem(DRAFT_KEY)
  } catch {
    /* nada */
  }
  await idb('readwrite', (s) => s.clear()).catch(() => {})
}

// --- Al crear la cuenta / ingresar ---------------------------------------------
// Pasa el borrador a la base: sube las fotos a la carpeta del usuario, crea el
// evento con todo y borra el borrador. Si la cuenta ya tiene una invitación,
// no la pisa (el borrador se descarta). Una sola vez aunque se llame varias.
let migrating = null
export function migrateDraft(user) {
  if (!migrating) migrating = doMigrate(user).finally(() => (migrating = null))
  return migrating
}

async function doMigrate(user) {
  const draft = readDraft()
  if (!draft?.fields || !user) return false

  const { data: existing } = await supabase.from('events').select('id').eq('owner_user_id', user.id).maybeSingle()
  if (existing) {
    await clearDraft()
    return false
  }

  const fields = { ...draft.fields }
  for (const col of PHOTO_COLUMNS) {
    if (!Array.isArray(fields[col])) continue
    const items = []
    for (const item of fields[col]) {
      if (!item?.path?.startsWith(LOCAL)) {
        items.push(item)
        continue
      }
      const blob = await idbGet(item.path.slice(LOCAL.length)).catch(() => null)
      if (!blob) continue
      const ext = (blob.type.split('/')[1] || 'jpg').replace('jpeg', 'jpg').replace('svg+xml', 'svg')
      const path = `${user.id}/${col}/${crypto.randomUUID()}.${ext}`
      const { error } = await supabase.storage.from(BUCKET).upload(path, blob, { cacheControl: '3600', contentType: blob.type })
      if (error) continue
      const { data } = supabase.storage.from(BUCKET).getPublicUrl(path)
      items.push({ ...item, url: data.publicUrl, path })
    }
    fields[col] = items
  }

  const { error } = await supabase.from('events').insert({
    ...fields,
    name: fields.name || fields.hero_title || 'Mi evento',
    owner_user_id: user.id,
  })
  if (error) {
    // No se borra el borrador: se puede reintentar al volver a entrar.
    console.error('No se pudo pasar el borrador a la cuenta', error)
    return false
  }
  await clearDraft()
  return true
}
