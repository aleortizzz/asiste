// Mercado Pago avisa acá cada vez que un pago cambia (aprobado, pendiente,
// rechazado, devuelto…). La URL se la pasa crear-pago en `notification_url`.
// Se despliega SIN «Verify JWT»: MP no tiene sesión de Supabase.
//
// No le creemos al aviso: solo trae el id del pago. Con ese id le preguntamos
// a MP con nuestra clave (eso no se puede falsificar) y aplicar_pago() sube el
// plan si está aprobado y el monto coincide.
//
// Secrets:
//   MP_ACCESS_TOKEN    la misma que usa crear-pago
//   MP_WEBHOOK_SECRET  opcional: la «clave secreta» de Webhooks en el panel de
//                      MP. Si está, se rechazan los avisos sin firma válida.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const ok = (msg = 'ok') => new Response(msg, { status: 200 })

// Firma de MP: header x-signature = "ts=…,v1=…", HMAC-SHA256 en hex de
// "id:<data.id>;request-id:<x-request-id>;ts:<ts>;" con la clave secreta.
async function firmaValida(req: Request, dataId: string, secret: string) {
  const sig = req.headers.get('x-signature') ?? ''
  const parts = Object.fromEntries(sig.split(',').map((p) => p.trim().split('=') as [string, string]))
  if (!parts.ts || !parts.v1) return false
  const requestId = req.headers.get('x-request-id') ?? ''
  const manifest = `id:${dataId.toLowerCase()};request-id:${requestId};ts:${parts.ts};`
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(manifest))
  const hex = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, '0')).join('')
  return hex === parts.v1
}

Deno.serve(async (req) => {
  const url = new URL(req.url)
  const body = await req.json().catch(() => ({}))

  // Formato nuevo (Webhooks): ?data.id=…&type=payment y el body igual.
  // Formato viejo (IPN): ?id=…&topic=payment.
  const tipo = url.searchParams.get('type') ?? body.type ?? url.searchParams.get('topic') ?? body.topic
  const paymentId = String(url.searchParams.get('data.id') ?? body.data?.id ?? url.searchParams.get('id') ?? '')

  // Avisos de otras cosas (merchant_order, etc.): se responde 200 para que MP no reintente.
  if (tipo !== 'payment' || !paymentId) return ok('ignorado')

  const secret = Deno.env.get('MP_WEBHOOK_SECRET')
  if (secret && url.searchParams.has('data.id') && !(await firmaValida(req, paymentId, secret))) {
    console.warn('Firma inválida', paymentId)
    return new Response('firma inválida', { status: 401 })
  }

  const res = await fetch(`https://api.mercadopago.com/v1/payments/${encodeURIComponent(paymentId)}`, {
    headers: { Authorization: `Bearer ${Deno.env.get('MP_ACCESS_TOKEN')}` },
  })
  if (!res.ok) {
    // 500: que MP vuelva a intentar más tarde.
    console.error('MP pago', paymentId, res.status, await res.text())
    return new Response('no se pudo consultar el pago', { status: 500 })
  }
  const pago = await res.json()

  // Un pago que no salió de crear-pago (otra venta de la misma cuenta de MP).
  const pagoId = pago.external_reference
  if (!pagoId || !/^[0-9a-f-]{36}$/i.test(pagoId) || pago.currency_id !== 'ARS') return ok('no es de Asiste')

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const { data, error } = await admin.rpc('aplicar_pago', {
    p_pago_id: pagoId,
    p_mp_payment_id: String(pago.id),
    p_mp_status: pago.status,
    p_monto: pago.transaction_amount,
  })
  if (error) {
    console.error('aplicar_pago', pagoId, error)
    return new Response('error', { status: 500 })
  }
  console.log('Pago', paymentId, pago.status, data)
  return ok()
})
