// Avisa por push al superadmin que se registró una cuenta nueva.
// La llama el trigger `avisar_registro` de auth.users (migrations/20261020_aviso_registros.sql).
// Se despliega SIN «Verify JWT»: la llama la base, no alguien con sesión.
//
// No le creemos al pedido: solo trae el id de la cuenta. Con ese id buscamos
// la cuenta nosotros, solo avisamos si se creó hace un rato, y una sola vez
// por cuenta (tabla avisos_registro). Así, llamarla a mano no sirve para
// mandar avisos inventados ni repetidos.
//
// Secrets:
//   VAPID_PUBLIC_KEY   la misma que VITE_VAPID_PUBLIC_KEY del front
//   VAPID_PRIVATE_KEY
//   VAPID_SUBJECT      opcional: mailto de contacto para los servicios de push
import { createClient } from 'jsr:@supabase/supabase-js@2'
import webpush from 'npm:web-push@3.6.7'

const ok = (msg = 'ok') => new Response(msg, { status: 200 })

// Más viejo que esto, no es un registro recién hecho.
const MAX_EDAD_MS = 10 * 60 * 1000

Deno.serve(async (req) => {
  const body = await req.json().catch(() => ({}))
  const userId = String(body.user_id ?? '')
  if (!/^[0-9a-f-]{36}$/i.test(userId)) return new Response('falta user_id', { status: 400 })

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

  const { data: found, error: userErr } = await admin.auth.admin.getUserById(userId)
  const user = found?.user
  if (userErr || !user) return ok('no existe')
  if (Date.now() - new Date(user.created_at).getTime() > MAX_EDAD_MS) return ok('no es nueva')
  if (user.email?.endsWith('@recepcion.tizdigital.com')) return ok('recepción')

  // Una sola vez por cuenta: si ya estaba anotada, el insert choca (23505).
  const { error: dupErr } = await admin.from('avisos_registro').insert({ user_id: userId })
  if (dupErr?.code === '23505') return ok('ya avisado')
  if (dupErr) {
    console.error('avisos_registro', dupErr)
    return ok('error al anotar')
  }

  const { data: subs, error: subsErr } = await admin.from('push_subscriptions').select('endpoint, p256dh, auth')
  if (subsErr) {
    console.error('push_subscriptions', subsErr)
    return new Response('error', { status: 500 })
  }
  if (!subs?.length) return ok('sin suscripciones')

  webpush.setVapidDetails(
    Deno.env.get('VAPID_SUBJECT') ?? 'mailto:aleortizjusto3@gmail.com',
    Deno.env.get('VAPID_PUBLIC_KEY')!,
    Deno.env.get('VAPID_PRIVATE_KEY')!,
  )

  const nombre = user.user_metadata?.full_name ?? user.user_metadata?.name
  const conGoogle = user.app_metadata?.provider === 'google'
  const payload = JSON.stringify({
    title: 'Nuevo registro en Asiste',
    body: [nombre, user.email].filter(Boolean).join(' · ') + (conGoogle ? ' (con Google)' : ''),
    url: '/admin/superadmin?seccion=registros',
  })

  await Promise.all(
    subs.map(async (s) => {
      try {
        // urgency 'high': si no, Android la retiene con el celular en reposo (Doze) hasta que lo usás.
        // TTL: si el dispositivo está apagado, el servicio de push la guarda hasta 1 día.
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, {
          urgency: 'high',
          TTL: 24 * 60 * 60,
        })
      } catch (err) {
        // 404/410: el navegador dio de baja la suscripción (se desinstaló, se borraron los datos…).
        const status = (err as { statusCode?: number }).statusCode
        if (status === 404 || status === 410) await admin.from('push_subscriptions').delete().eq('endpoint', s.endpoint)
        else console.error('push', status, err)
      }
    }),
  )

  console.log('Aviso de registro', user.email, subs.length)
  return ok('ok urgente')
})
