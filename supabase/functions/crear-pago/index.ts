// Crea el link de cobro de Mercado Pago (Checkout Pro) para pasarse a un plan.
// La llama el panel («Tu plan») con la sesión del organizador:
//   supabase.functions.invoke('crear-pago', { body: { plan: 'plus' } })
// y devuelve { url } para mandarlo a pagar.
//
// El precio se calcula acá, en el servidor (precio_cambio_plan en la base):
// si lo mandara el navegador, cualquiera podría pagar «Premium a $1».
//
// Secrets (Supabase → Edge Functions → Secrets):
//   MP_ACCESS_TOKEN  la clave privada de MP (TEST-… para probar, APP_USR-… real)
//   SITE_URL         opcional, por defecto https://asiste.tizdigital.com
// SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY ya vienen solos.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const PLAN_LABELS: Record<string, string> = {
  invitacion: 'Invitación',
  plus: 'Plus',
  premium: 'Premium',
}

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Método no permitido' }, 405)

  const accessToken = Deno.env.get('MP_ACCESS_TOKEN')
  if (!accessToken) return json({ error: 'Falta configurar Mercado Pago.' }, 500)
  const siteUrl = (Deno.env.get('SITE_URL') ?? 'https://asiste.tizdigital.com').replace(/\/+$/, '')
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!

  // Cliente con la sesión del que llama: RLS hace que solo vea su evento.
  const authHeader = req.headers.get('Authorization') ?? ''
  const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  })
  const { data: { user } } = await userClient.auth.getUser(authHeader.replace(/^Bearer /, ''))
  if (!user) return json({ error: 'Tenés que iniciar sesión.' }, 401)

  const { plan } = await req.json().catch(() => ({}))
  if (!PLAN_LABELS[plan]) return json({ error: 'Plan inválido.' }, 400)

  // Su propio evento (no el que un superadmin esté mirando).
  const { data: event } = await userClient
    .from('events')
    .select('id, name, plan')
    .eq('owner_user_id', user.id)
    .maybeSingle()
  if (!event) return json({ error: 'Primero guardá tu invitación.' }, 400)

  // Cliente con la service_role: puede escribir en pagos (el navegador no).
  const admin = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

  const { data: monto, error: precioError } = await admin.rpc('precio_cambio_plan', {
    p_actual: event.plan,
    p_nuevo: plan,
  })
  if (precioError) return json({ error: 'No se pudo calcular el precio.' }, 500)
  if (!monto) return json({ error: `Ya tenés el plan ${PLAN_LABELS[event.plan] ?? event.plan} o uno mejor.` }, 400)

  const { data: pago, error: pagoError } = await admin
    .from('pagos')
    .insert({ event_id: event.id, user_id: user.id, plan_anterior: event.plan, plan, monto })
    .select('id')
    .single()
  if (pagoError) return json({ error: 'No se pudo iniciar el pago.' }, 500)

  const esCambio = event.plan !== 'gratis'
  const vuelta = (estado: string) => `${siteUrl}/admin/plan?pago=${estado}&id=${pago.id}`

  const res = await fetch('https://api.mercadopago.com/checkout/preferences', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      // Si por un reintento se manda dos veces, MP crea una sola preferencia.
      'X-Idempotency-Key': pago.id,
    },
    body: JSON.stringify({
      items: [
        {
          id: plan,
          title: `Asiste · Plan ${PLAN_LABELS[plan]}${esCambio ? ' (diferencia)' : ''}`,
          description: event.name ?? undefined,
          quantity: 1,
          currency_id: 'ARS',
          unit_price: monto,
        },
      ],
      // Con esto el aviso sabe a qué pago nuestro corresponde.
      external_reference: pago.id,
      notification_url: `${supabaseUrl}/functions/v1/mp-webhook`,
      back_urls: { success: vuelta('aprobado'), pending: vuelta('pendiente'), failure: vuelta('rechazado') },
      auto_return: 'approved',
      statement_descriptor: 'ASISTE',
    }),
  })
  const pref = await res.json()
  if (!res.ok) {
    console.error('MP preferencia', res.status, pref)
    await admin.from('pagos').update({ estado: 'cancelado' }).eq('id', pago.id)
    return json({ error: 'Mercado Pago no respondió. Probá de nuevo en un rato.' }, 502)
  }

  await admin.from('pagos').update({ mp_preference_id: pref.id }).eq('id', pago.id)
  return json({ url: pref.init_point, pago_id: pago.id })
})
