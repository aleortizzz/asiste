import { supabase } from './supabase'

// Notificaciones push de este navegador (hoy: el aviso de registros del
// superadmin). El navegador da una «suscripción» (endpoint + claves) y se
// guarda en push_subscriptions; la Edge Function aviso-registro manda ahí.
// La base solo acepta suscripciones de un superadmin.

const VAPID_PUBLIC_KEY = import.meta.env.VITE_VAPID_PUBLIC_KEY

// En iPhone/iPad, push solo funciona con Asiste instalada en la pantalla de
// inicio (Compartir → Agregar a inicio) y abierta desde ese ícono.
export const isIos = /iphone|ipad|ipod/i.test(navigator.userAgent)
export const isInstalled =
  window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true

export const pushSupported =
  !!VAPID_PUBLIC_KEY && 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window

// La clave pública viene en base64url; PushManager la quiere en bytes.
function keyToBytes(base64url) {
  const base64 = (base64url + '='.repeat((4 - (base64url.length % 4)) % 4)).replace(/-/g, '+').replace(/_/g, '/')
  return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0))
}

async function registration() {
  return (await navigator.serviceWorker.getRegistration('/')) ?? navigator.serviceWorker.register('/sw.js')
}

// ¿Este navegador ya tiene los avisos activados?
export async function pushActive() {
  if (!pushSupported || Notification.permission !== 'granted') return false
  const reg = await navigator.serviceWorker.getRegistration('/')
  return !!(await reg?.pushManager.getSubscription())
}

// Pide permiso, se suscribe y guarda la suscripción. Devuelve un mensaje de error o ''.
export async function enablePush(userId) {
  const permission = await Notification.requestPermission()
  if (permission !== 'granted') {
    return 'El navegador no dio permiso. Habilitá las notificaciones para este sitio en la configuración y volvé a probar.'
  }
  const reg = await registration()
  await navigator.serviceWorker.ready
  const sub =
    (await reg.pushManager.getSubscription()) ??
    (await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyToBytes(VAPID_PUBLIC_KEY) }))

  const { endpoint, keys } = sub.toJSON()
  const { error } = await supabase
    .from('push_subscriptions')
    .upsert({ endpoint, user_id: userId, p256dh: keys.p256dh, auth: keys.auth })
  if (error) {
    await sub.unsubscribe()
    return `No se pudo guardar: ${error.message}`
  }
  return ''
}

export async function disablePush() {
  const reg = await navigator.serviceWorker.getRegistration('/')
  const sub = await reg?.pushManager.getSubscription()
  if (!sub) return ''
  const { error } = await supabase.from('push_subscriptions').delete().eq('endpoint', sub.endpoint)
  await sub.unsubscribe()
  return error ? `No se pudo borrar: ${error.message}` : ''
}
