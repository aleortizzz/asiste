// Vista previa de los links al compartirlos (WhatsApp, Telegram, Facebook…).
// Es la traducción de public/og.php, que corría en Hostinger.
//
// Esos robots no ejecutan JavaScript: leen las etiquetas <meta property="og:…">
// del HTML tal cual llega. Como la app es una SPA, sin esto todos los links
// mostrarían lo mismo («asiste»). Acá tomamos el index.html de siempre y le
// agregamos título, descripción y foto de esa invitación.
//
// Solo pasan por acá los robots de vista previa (por User-Agent); las personas
// reciben el index.html directo, sin esperar a Supabase. Si algo falla, se
// sirve el index.html sin cambios: nunca rompe el link.
//
// La usan functions/i/[slug].js y functions/fotos/[id].js. La imagen la arma
// functions/og-image.php.js.

const BOTS = /whatsapp|facebookexternalhit|facebot|meta-externalagent|twitterbot|telegrambot|slackbot|discordbot|linkedinbot|pinterest|skypeuripreview|viber|applebot|googlebot|bingbot|redditbot|embedly|iframely|vkshare|mastodon|signal/i

// Llama a una función RPC de Supabase. Devuelve el objeto o null ante
// cualquier problema (sin config, sin red, función inexistente…).
async function rpc(env, fn, params) {
  if (!env.SUPABASE_URL || !env.SUPABASE_KEY) return null
  try {
    const res = await fetch(`${env.SUPABASE_URL.replace(/\/+$/, '')}/rest/v1/rpc/${fn}`, {
      method: 'POST',
      headers: { apikey: env.SUPABASE_KEY, Authorization: `Bearer ${env.SUPABASE_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(params),
      signal: AbortSignal.timeout(4000),
    })
    if (!res.ok) return null
    const data = await res.json()
    return data && typeof data === 'object' ? data : null
  } catch {
    return null
  }
}

// t=i → invitación de una familia (/i/:slug); t=f → galería de fotos (/fotos/:eventId)
export function fetchData(env, type, key) {
  if (type === 'i' && /^[A-Za-z0-9_-]{1,64}$/.test(key)) return rpc(env, 'vista_previa_invitacion', { p_slug: key })
  if (type === 'f' && /^[0-9a-fA-F-]{36}$/.test(key)) return rpc(env, 'vista_previa_fotos', { p_event_id: key })
  return null
}

const DIAS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']

// "sábado 17 de octubre" sin depender del locale.
function fecha(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso ?? '')
  if (!m) return ''
  const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], 12))
  return `${DIAS[d.getUTCDay()]} ${+m[3]} de ${MESES[+m[2] - 1]}`
}

const ucfirst = (s) => s.charAt(0).toUpperCase() + s.slice(1)
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' })[c])

async function sha1(s) {
  const buf = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(s))
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

// Cambia si cambia el logo o algo de cómo se dibuja la tarjeta (mismo criterio
// que og_logo_card_key() de og-lib.php, para que `v` no cambie con la mudanza).
function logoCardKey(data) {
  const hex = (c, def) => (typeof c === 'string' && /^#[0-9a-fA-F]{6}$/.test(c) ? c.toLowerCase() : def)
  const dark = data.theme_mode === 'oscuro'
  const primary = hex(data.primary_color, '#0f1b2d')
  const style = {
    dark,
    bg: dark ? primary : hex(data.bg_color, '#f7f4ee'),
    ink: dark ? '#f3efe6' : primary,
    accent: hex(data.accent_color, '#c8a96a'),
    white: dark && !!data.logo_white,
  }
  return `${data.logo ?? ''}|${JSON.stringify(style)}`
}

async function metaTags(type, key, data, base) {
  const name = (data.hero_title ?? '').trim() || (data.event_name ?? '').trim() || 'Asiste'
  const f = fecha(data.event_date)
  const fechaTxt = f ? `${ucfirst(f)} · ` : ''

  // Plantilla Ejecutiva: textos sobrios y, si hay logo, la tarjeta con el logo
  // como imagen en vez de una foto.
  const ejecutiva = type === 'i' && data.template === 'ejecutiva'
  const logoCard = ejecutiva && !!data.logo
  let title, description, path

  if (ejecutiva) {
    title = `${name} · Invitación`
    const family = (data.family_name ?? '').trim()
    const hora = data.reception_time ? `${data.reception_time.slice(0, 5)} hs` : ''
    const cuando = f ? ucfirst(f) + (hora ? `, ${hora}` : '') : ''
    description = [family ? `Para ${family}` : '', cuando, (data.venue_name ?? '').trim()].filter(Boolean).join(' · ')
      || 'Tocá para ver la invitación y confirmar tu asistencia.'
    path = `/i/${key}`
  } else if (type === 'i') {
    const suffix = { cumpleanos: 'Mi invitación', casamiento: 'Nuestra invitación', empresarial: 'Invitación' }[data.event_type] ?? 'Invitación'
    title = `${name} · ${suffix}`
    const family = (data.family_name ?? '').trim()
    description = (family ? `Para ${family} · ` : '') + fechaTxt + 'Tocá para ver la invitación y confirmar tu asistencia.'
    path = `/i/${key}`
  } else {
    title = `Compartí tus fotos · ${name}`
    const lugar = data.event_type === 'empresarial' ? 'en el evento' : 'en la fiesta'
    description = `${fechaTxt}Subí las fotos que saques ${lugar} y mirá las de todos.`
    path = `/fotos/${key}`
  }

  const meta = [
    `<title>${esc(title)}</title>`,
    `<meta name="description" content="${esc(description)}" />`,
    '<meta property="og:type" content="website" />',
    '<meta property="og:site_name" content="Asiste" />',
    '<meta property="og:locale" content="es_AR" />',
    `<meta property="og:url" content="${esc(base + path)}" />`,
    `<meta property="og:title" content="${esc(title)}" />`,
    `<meta property="og:description" content="${esc(description)}" />`,
  ]
  if (logoCard || data.image) {
    // La imagen pasa por og-image.php: la achica a 1200×630 (WhatsApp no
    // muestra imágenes pesadas). `v` cambia si cambia la foto (o el logo y sus
    // colores), así WhatsApp no se queda con la vieja.
    const version = logoCard ? logoCardKey(data) : data.image
    const img = `${base}/og-image.php?t=${type}&${type === 'i' ? 's' : 'e'}=${encodeURIComponent(key)}`
      + (logoCard ? '&k=logo' : '') + `&v=${(await sha1(version)).slice(0, 10)}`
    meta.push(
      `<meta property="og:image" content="${esc(img)}" />`,
      '<meta property="og:image:width" content="1200" />',
      '<meta property="og:image:height" content="630" />',
      '<meta property="og:image:type" content="image/jpeg" />',
      '<meta name="twitter:card" content="summary_large_image" />',
    )
  } else {
    // Sin foto: la tarjeta de Asiste, así el link nunca llega sin imagen.
    meta.push(
      `<meta property="og:image" content="${esc(base)}/brand/og-asiste.png?v=2" />`,
      '<meta property="og:image:width" content="1200" />',
      '<meta property="og:image:height" content="630" />',
      '<meta property="og:image:type" content="image/png" />',
      '<meta name="twitter:card" content="summary_large_image" />',
    )
  }
  return meta.join('\n    ')
}

// Para las rutas /i/:slug y /fotos/:id.
export async function vistaPrevia(context, type, key) {
  const { request, env } = context
  if (!BOTS.test(request.headers.get('User-Agent') ?? '')) return env.ASSETS.fetch(request)

  const url = new URL(request.url)
  const index = await env.ASSETS.fetch(new URL('/', url))
  const data = await fetchData(env, type, key)
  if (!data || !index.ok) return index

  let html = await index.text()
  // El index.html trae la vista previa de la home (bloque og:default): se saca
  // para que no queden dos og:title u og:image y el robot elija el equivocado.
  html = html.replace(/\s*<!-- og:default[\s\S]*?<!-- \/og:default -->/, '')
  const block = await metaTags(type, key, data, url.origin)
  html = /<title>[\s\S]*?<\/title>/.test(html)
    ? html.replace(/<title>[\s\S]*?<\/title>/, () => block)
    : html.replace('</head>', () => `${block}\n  </head>`)

  return new Response(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache', Vary: 'User-Agent' },
  })
}
