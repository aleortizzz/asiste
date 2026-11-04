// Foto de la vista previa de los links (WhatsApp, Telegram…): la portada del
// evento recortada a 1200×630 y comprimida en JPG, o en la plantilla Ejecutiva
// con logo, una tarjeta con el logo. Es la traducción de public/og-image.php,
// que corría en Hostinger: Cloudflare Pages no tiene PHP y sus funciones
// gratis no tienen procesador para achicar fotos de varios MB.
//
// La llama functions/og-image.php.js (Cloudflare), que guarda el resultado en
// caché: cada imagen se genera una sola vez por versión (`v`).
// Se despliega SIN «Verify JWT»: la piden robots, sin sesión.
//
// Solo acepta un slug o un id de evento, nunca una URL: busca la foto en la
// base, así no sirve para achicar imágenes de cualquier sitio.
import { Image } from 'https://deno.land/x/imagescript@1.3.0/mod.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!.replace(/\/+$/, '')
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const W = 1200
const H = 630

const notFound = () => new Response('no', { status: 404 })
const jpeg = (bytes: Uint8Array) =>
  new Response(bytes, { headers: { 'Content-Type': 'image/jpeg', 'Cache-Control': 'public, max-age=604800' } })

async function rpc(fn: string, params: Record<string, string>) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${ANON_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(params),
    signal: AbortSignal.timeout(4000),
  }).catch(() => null)
  if (!res?.ok) return null
  const data = await res.json().catch(() => null)
  return data && typeof data === 'object' ? data : null
}

// t=i → invitación de una familia (/i/:slug); t=f → galería de fotos (/fotos/:eventId)
function fetchData(type: string, key: string) {
  if (type === 'i' && /^[A-Za-z0-9_-]{1,64}$/.test(key)) return rpc('vista_previa_invitacion', { p_slug: key })
  if (type === 'f' && /^[0-9a-fA-F-]{36}$/.test(key)) return rpc('vista_previa_fotos', { p_event_id: key })
  return null
}

// Solo archivos del storage de nuestro proyecto.
const ownStorage = (src: unknown): src is string =>
  typeof src === 'string' && src.startsWith(`${SUPABASE_URL}/storage/`)

async function download(src: string) {
  const res = await fetch(src, { signal: AbortSignal.timeout(12000) }).catch(() => null)
  if (!res?.ok) return null
  const bytes = new Uint8Array(await res.arrayBuffer())
  if (bytes.length > 20 * 1024 * 1024) return null
  return await Image.decode(bytes).catch(() => null)
}

// Recorte tipo "cover" a 1200×630, un poco hacia arriba (suelen estar las caras).
function cover(img: Image) {
  const scale = Math.max(W / img.width, H / img.height)
  const cw = Math.round(W / scale)
  const ch = Math.round(H / scale)
  const cx = Math.round((img.width - cw) / 2)
  const cy = Math.round((img.height - ch) * 0.3)
  return img.crop(cx, cy, cw, ch).resize(W, H)
}

// --- Tarjeta con el logo (plantilla Ejecutiva) --------------------------------
// Mismos colores que og_logo_card_style() de og-lib.php: en claro, el papel de
// la invitación; en oscuro, el color principal. El logo se pasa a blanco solo
// en oscuro y si lo pidieron.
type Rgb = [number, number, number]
const hex = (c: unknown, def: string) => (typeof c === 'string' && /^#[0-9a-fA-F]{6}$/.test(c) ? c.toLowerCase() : def)
const rgb = (h: string): Rgb => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16)) as Rgb
// t de a y el resto de b (como color-mix en CSS).
const mix = (a: string, b: string, t: number): Rgb => {
  const [x, y] = [rgb(a), rgb(b)]
  return x.map((v, i) => Math.round(v * t + y[i] * (1 - t))) as Rgb
}
const color = ([r, g, b]: Rgb) => Image.rgbaToColor(r, g, b, 255)

// deno-lint-ignore no-explicit-any
function logoCardStyle(data: any) {
  const dark = data?.theme_mode === 'oscuro'
  const primary = hex(data?.primary_color, '#0f1b2d')
  return {
    dark,
    bg: dark ? primary : hex(data?.bg_color, '#f7f4ee'),
    ink: dark ? '#f3efe6' : primary,
    accent: hex(data?.accent_color, '#c8a96a'),
    white: dark && !!data?.logo_white,
  }
}

// 1200×630 con el fondo de la invitación, el marco fino doble, el logo
// centrado y una línea fina en el color de detalles debajo, como la portada.
function logoCard(logo: Image, st: ReturnType<typeof logoCardStyle>) {
  const out = new Image(W, H).fill(color(rgb(st.bg)))

  // Marco fino doble (2 px).
  const frame = color(st.dark ? mix(st.accent, st.bg, 0.35) : mix(st.ink, st.bg, 0.18))
  for (const m of [36, 50]) {
    out.drawBox(m, m, W - 2 * m, 2, frame)
    out.drawBox(m, H - m - 2, W - 2 * m, 2, frame)
    out.drawBox(m, m, 2, H - 2 * m, frame)
    out.drawBox(W - m - 2, m, 2, H - 2 * m, frame)
  }

  // Logo en blanco: conserva la transparencia.
  if (st.white) {
    const px = logo.bitmap
    for (let i = 0; i < px.length; i += 4) px[i] = px[i + 1] = px[i + 2] = 255
  }

  // Logo: entero, lo más grande que entre en 640×220.
  const scale = Math.min(640 / logo.width, 220 / logo.height, 4)
  const dw = Math.round(logo.width * scale)
  const dh = Math.round(logo.height * scale)
  const dx = Math.round((W - dw) / 2)
  const dy = Math.round((H - dh) / 2 - 24)
  out.composite(logo.resize(dw, dh), dx, dy)

  // Línea fina debajo, en el color de detalles.
  const line = color(st.dark ? rgb(st.accent) : mix(st.accent, st.ink, 0.85))
  out.drawBox(W / 2 - 90, dy + dh + 44, 181, 2, line)
  return out
}

Deno.serve(async (req) => {
  const q = new URL(req.url).searchParams
  const type = q.get('t') ?? ''
  const key = (type === 'i' ? q.get('s') : q.get('e')) ?? ''
  const data = await fetchData(type, key)

  if (q.get('k') === 'logo') {
    if (!ownStorage(data?.logo)) return notFound()
    const logo = await download(data.logo)
    // Sin logo, og.php igual muestra título y descripción.
    if (!logo) return notFound()
    return jpeg(await logoCard(logo, logoCardStyle(data)).encodeJPEG(88))
  }

  if (!ownStorage(data?.image)) return notFound()
  const img = await download(data.image)
  // Un formato que no sabemos leer: mandamos la original.
  if (!img) return Response.redirect(data.image, 302)
  return jpeg(await cover(img).encodeJPEG(82))
})
