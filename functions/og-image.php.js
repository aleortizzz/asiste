// /og-image.php — la imagen de la vista previa de los links. Mantiene la URL
// del PHP de Hostinger para que las vistas previas ya compartidas sigan
// andando.
//
// El trabajo pesado (bajar la foto, recortarla, dibujar la tarjeta del logo) lo
// hace la función og-image de Supabase (supabase/functions/og-image): las
// funciones gratis de Cloudflare tienen muy poco procesador para eso. Acá solo
// se guarda el resultado en la caché de Cloudflare, así cada versión (`v`) se
// genera una sola vez.
export async function onRequest({ request, env, waitUntil }) {
  const url = new URL(request.url)
  const cache = caches.default
  const hit = await cache.match(request)
  if (hit) return hit

  const params = new URLSearchParams()
  for (const k of ['t', 's', 'e', 'k']) if (url.searchParams.has(k)) params.set(k, url.searchParams.get(k))
  const res = await fetch(`${env.SUPABASE_URL.replace(/\/+$/, '')}/functions/v1/og-image?${params}`, { redirect: 'manual' })

  // Foto en un formato que no se puede achicar: la original.
  if (res.status === 302) return Response.redirect(res.headers.get('Location'), 302)
  if (!res.ok) return new Response('no', { status: 404 })

  const out = new Response(res.body, {
    headers: { 'Content-Type': 'image/jpeg', 'Cache-Control': 'public, max-age=604800' },
  })
  waitUntil(cache.put(request, out.clone()))
  return out
}
