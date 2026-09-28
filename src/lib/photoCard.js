import QRCode from 'qrcode'
import { lighten, darken } from './color'

// Cartel «¡Sacá tus fotos!» para las mesas (A5 vertical, 148 × 210 mm).
//
// Se dibuja en un <canvas> en vez de armarlo con jsPDF directo: así podemos
// usar fuentes manuscritas de Google Fonts, la foto del evento recortada y
// girada tipo polaroid, y los mismos íconos del panel. El canvas después se
// usa para la vista previa (PNG) y para el PDF a imprimir.
//
// Todo el dibujo está en milímetros: el contexto se escala una vez (PX_PER_MM)
// y el resto del código piensa en el tamaño real del papel.

export const CARD_W = 148
export const CARD_H = 210

const TITLE_FONT = 'Caveat Brush'
const BODY_FONT = 'Kalam'
const INK = '#2e2833'
const PAPER = '#fffdf9'

// --- Fuentes ---------------------------------------------------------------------
// Solo se bajan la primera vez que se arma un cartel (no en cada visita al panel).
let fontsReady = null
function loadFonts() {
  if (!fontsReady) {
    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.href = 'https://fonts.googleapis.com/css2?family=Caveat+Brush&family=Kalam:wght@400;700&display=block'
    document.head.appendChild(link)
    fontsReady = new Promise((resolve) => {
      link.onload = resolve
      link.onerror = resolve // sin red: seguimos con las fuentes de respaldo
    }).then(() =>
      Promise.all([
        document.fonts.load(`40px "${TITLE_FONT}"`),
        document.fonts.load(`40px "${BODY_FONT}"`),
        document.fonts.load(`bold 40px "${BODY_FONT}"`),
      ]).catch(() => {}),
    )
  }
  return fontsReady
}

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.crossOrigin = 'anonymous' // sin esto el canvas queda "manchado" y no se puede exportar
    img.onload = () => resolve(img)
    img.onerror = () => reject(new Error('No se pudo cargar la foto'))
    img.src = src
  })
}

// --- Íconos (mismos trazos que lucide, en una grilla de 24 × 24) --------------------
const ICONS = {
  smartphone: [
    ['rect', { x: 5, y: 2, width: 14, height: 20, rx: 2 }],
    ['path', { d: 'M12 18h.01' }],
  ],
  imagePlus: [
    ['path', { d: 'M16 5h6' }],
    ['path', { d: 'M19 2v6' }],
    ['path', { d: 'M21 11.5V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7.5' }],
    ['path', { d: 'm21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21' }],
    ['circle', { cx: 9, cy: 9, r: 2 }],
  ],
  users: [
    ['path', { d: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2' }],
    ['path', { d: 'M16 3.128a4 4 0 0 1 0 7.744' }],
    ['path', { d: 'M22 21v-2a4 4 0 0 0-3-3.87' }],
    ['circle', { cx: 9, cy: 7, r: 4 }],
  ],
  camera: [
    ['path', { d: 'M13.997 4a2 2 0 0 1 1.76 1.05l.486.9A2 2 0 0 0 18.003 7H20a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h1.997a2 2 0 0 0 1.759-1.048l.489-.904A2 2 0 0 1 10.004 4z' }],
  ],
}
const HEART_PATH = 'M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5'

function drawIcon(ctx, nodes, cx, cy, size, color, stroke = 2) {
  ctx.save()
  ctx.translate(cx - size / 2, cy - size / 2)
  ctx.scale(size / 24, size / 24)
  ctx.strokeStyle = color
  ctx.lineWidth = stroke
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  for (const [tag, a] of nodes) {
    if (tag === 'path') ctx.stroke(new Path2D(a.d))
    else if (tag === 'circle') {
      ctx.beginPath()
      ctx.arc(a.cx, a.cy, a.r, 0, Math.PI * 2)
      ctx.stroke()
    } else if (tag === 'rect') {
      ctx.beginPath()
      ctx.roundRect(a.x, a.y, a.width, a.height, a.rx ?? 0)
      ctx.stroke()
    }
  }
  ctx.restore()
}

function drawHeart(ctx, cx, cy, size, color, { fill = false, rotate = 0 } = {}) {
  ctx.save()
  ctx.translate(cx, cy)
  ctx.rotate(rotate)
  ctx.translate(-size / 2, -size / 2)
  ctx.scale(size / 24, size / 24)
  const p = new Path2D(HEART_PATH)
  if (fill) {
    ctx.fillStyle = color
    ctx.fill(p)
  } else {
    ctx.strokeStyle = color
    ctx.lineWidth = 2.2
    ctx.lineJoin = 'round'
    ctx.stroke(p)
  }
  ctx.restore()
}

// Estrellita de 5 puntas, solo contorno (como dibujada a mano).
function drawStar(ctx, cx, cy, r, color, rotate = 0) {
  ctx.save()
  ctx.translate(cx, cy)
  ctx.rotate(rotate)
  ctx.beginPath()
  for (let i = 0; i < 10; i++) {
    const rad = i % 2 ? r * 0.45 : r
    const ang = (Math.PI / 5) * i - Math.PI / 2
    ctx.lineTo(Math.cos(ang) * rad, Math.sin(ang) * rad)
  }
  ctx.closePath()
  ctx.strokeStyle = color
  ctx.lineWidth = 0.45
  ctx.lineJoin = 'round'
  ctx.stroke()
  ctx.restore()
}

// Rayitas de "brillo" en abanico (las que salen alrededor del QR y la cámara).
function drawSparkLines(ctx, cx, cy, color, { from = 0, to = Math.PI, count = 3, inner = 2, outer = 4.5 } = {}) {
  ctx.save()
  ctx.strokeStyle = color
  ctx.lineWidth = 0.55
  ctx.lineCap = 'round'
  for (let i = 0; i < count; i++) {
    const ang = from + ((to - from) * i) / Math.max(count - 1, 1)
    ctx.beginPath()
    ctx.moveTo(cx + Math.cos(ang) * inner, cy + Math.sin(ang) * inner)
    ctx.lineTo(cx + Math.cos(ang) * outer, cy + Math.sin(ang) * outer)
    ctx.stroke()
  }
  ctx.restore()
}

function drawArrow(ctx, x1, x2, y, color) {
  ctx.save()
  ctx.strokeStyle = color
  ctx.lineWidth = 0.55
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  ctx.beginPath()
  ctx.moveTo(x1, y)
  ctx.lineTo(x2, y)
  ctx.moveTo(x2 - 1.6, y - 1.5)
  ctx.lineTo(x2, y)
  ctx.lineTo(x2 - 1.6, y + 1.5)
  ctx.stroke()
  ctx.restore()
}

// Franjas diagonales en una esquina, recortadas al borde del cartel.
function drawCornerStripes(ctx, corner, color) {
  ctx.save()
  ctx.beginPath()
  ctx.rect(0, 0, CARD_W, CARD_H)
  ctx.clip()
  ctx.strokeStyle = color
  ctx.lineWidth = 2.6
  ctx.lineCap = 'butt'
  for (const d of [9, 15, 21]) {
    ctx.beginPath()
    if (corner === 'tl') {
      ctx.moveTo(-2, d + 2)
      ctx.lineTo(d + 2, -2)
    } else {
      ctx.moveTo(CARD_W + 2, CARD_H - d - 2)
      ctx.lineTo(CARD_W - d - 2, CARD_H + 2)
    }
    ctx.stroke()
  }
  ctx.restore()
}

// Foto con marco blanco tipo polaroid, girada, con un corazoncito abajo.
function drawPolaroid(ctx, img, cx, cy, color) {
  const w = 50
  const h = 58
  const pad = 3.2
  const photo = w - pad * 2
  ctx.save()
  ctx.translate(cx, cy)
  ctx.rotate((-5 * Math.PI) / 180)
  ctx.shadowColor = 'rgba(40, 30, 50, 0.22)'
  ctx.shadowBlur = 3
  ctx.shadowOffsetY = 0.8
  ctx.fillStyle = '#ffffff'
  ctx.fillRect(-w / 2, -h / 2, w, h)
  ctx.shadowColor = 'transparent'

  // Recorte tipo "cover": llena el cuadrado sin deformar la foto.
  const scale = Math.max(photo / img.width, photo / img.height)
  const sw = photo / scale
  const sh = photo / scale
  const sx = (img.width - sw) / 2
  const sy = Math.max(0, (img.height - sh) * 0.3) // un poco hacia arriba: suele estar la cara
  ctx.drawImage(img, sx, sy, sw, sh, -w / 2 + pad, -h / 2 + pad, photo, photo)

  drawHeart(ctx, -w / 2 + pad + 4, h / 2 - 5.5, 4.2, color)
  ctx.restore()
}

function text(ctx, str, x, y, { font, size, color, weight = '', align = 'center' }) {
  ctx.font = `${weight} ${size}px "${font}", cursive`.trim()
  ctx.fillStyle = color
  ctx.textAlign = align
  ctx.textBaseline = 'alphabetic'
  ctx.fillText(str, x, y)
}

// Texto que achica la letra hasta que entra en `maxWidth`.
function fitText(ctx, str, x, y, maxWidth, opts) {
  let size = opts.size
  ctx.font = `${opts.weight ?? ''} ${size}px "${opts.font}", cursive`.trim()
  while (ctx.measureText(str).width > maxWidth && size > 3) {
    size -= 0.25
    ctx.font = `${opts.weight ?? ''} ${size}px "${opts.font}", cursive`.trim()
  }
  text(ctx, str, x, y, { ...opts, size })
}

const EVENT_WORD = { cumpleanos: 'del cumple', casamiento: 'de la boda' }

/**
 * Dibuja el cartel y devuelve el canvas.
 * @param {object} o
 * @param {string} o.url        link de /fotos/:id que va en el QR
 * @param {string} o.color      color principal de la invitación
 * @param {string} [o.photoUrl] foto para la polaroid (opcional)
 * @param {string} [o.eventType] 'cumpleanos' | 'casamiento' | …
 * @param {number} [o.pxPerMm]  resolución (11.8 ≈ 300 dpi, para imprimir)
 */
export async function renderPhotoCard({ url, color, photoUrl, eventType, pxPerMm = 11.8 }) {
  await loadFonts()
  const accent = /^#[0-9a-f]{6}$/i.test(color || '') ? color : '#7c4dab'
  const tint = lighten(accent, 0.82)
  const soft = lighten(accent, 0.55)
  const deep = darken(accent, 0.15)

  let photo = null
  if (photoUrl) {
    try {
      // Parámetro extra: si el navegador ya tenía la foto en caché de un <img>
      // común (sin CORS), esa copia no sirve para el canvas; así la pide de nuevo.
      photo = await loadImage(`${photoUrl}${photoUrl.includes('?') ? '&' : '?'}card=1`)
    } catch {
      photo = null // sin foto el cartel se arma igual, centrado
    }
  }
  const qr = await loadImage(
    await QRCode.toDataURL(url, { width: 900, margin: 0, errorCorrectionLevel: 'M', color: { dark: '#1f1a24', light: '#ffffff' } }),
  )

  const canvas = document.createElement('canvas')
  canvas.width = Math.round(CARD_W * pxPerMm)
  canvas.height = Math.round(CARD_H * pxPerMm)
  const ctx = canvas.getContext('2d')
  ctx.scale(pxPerMm, pxPerMm)

  // Papel y esquinas.
  ctx.fillStyle = PAPER
  ctx.fillRect(0, 0, CARD_W, CARD_H)
  drawCornerStripes(ctx, 'tl', tint)
  drawCornerStripes(ctx, 'br', tint)

  const subtitle2 = `tus fotos ${EVENT_WORD[eventType] ?? 'del evento'}`

  // --- Encabezado: polaroid + título, o solo título centrado ---
  if (photo) {
    drawPolaroid(ctx, photo, 42, 52, accent)
    const tx = 106
    text(ctx, '¡Sacá tus', tx, 34, { font: TITLE_FONT, size: 13.5, color: accent })
    text(ctx, 'fotos!', tx, 56, { font: TITLE_FONT, size: 25, color: accent })
    fitText(ctx, 'Escaneá el QR y subí', tx, 68, 62, { font: BODY_FONT, weight: 'bold', size: 5.4, color: INK })
    fitText(ctx, subtitle2, tx, 75, 62, { font: BODY_FONT, weight: 'bold', size: 5.4, color: INK })
    drawHeart(ctx, 136, 22, 4, accent, { rotate: 0.2 })
    drawSparkLines(ctx, 140, 44, accent, { from: -0.9, to: 0.5, inner: 2.2, outer: 4.4 })
    drawHeart(ctx, 136, 74, 3, accent, { rotate: -0.2 })
  } else {
    const cx = CARD_W / 2
    text(ctx, '¡Sacá tus fotos!', cx, 42, { font: TITLE_FONT, size: 22, color: accent })
    fitText(ctx, `Escaneá el QR y subí ${subtitle2}`, cx, 56, 120, { font: BODY_FONT, weight: 'bold', size: 5.6, color: INK })
    drawHeart(ctx, 22, 34, 4.5, accent, { rotate: -0.25 })
    drawHeart(ctx, 128, 26, 4, accent, { rotate: 0.2 })
    drawSparkLines(ctx, 132, 46, accent, { from: -0.8, to: 0.6, inner: 2.2, outer: 4.4 })
  }

  // --- QR ---
  const qrTop = photo ? 84 : 70
  const frame = photo ? 54 : 60
  const qrSize = frame - 8
  const qx = CARD_W / 2 - frame / 2
  ctx.fillStyle = '#ffffff'
  ctx.strokeStyle = accent
  ctx.lineWidth = 1.1
  ctx.beginPath()
  ctx.roundRect(qx, qrTop, frame, frame, 3.5)
  ctx.fill()
  ctx.stroke()
  ctx.imageSmoothingEnabled = false // bordes del QR bien nítidos
  ctx.drawImage(qr, qx + 4, qrTop + 4, qrSize, qrSize)
  ctx.imageSmoothingEnabled = true
  drawSparkLines(ctx, qx - 3, qrTop + frame / 2, accent, { from: Math.PI * 0.8, to: Math.PI * 1.2, inner: 1.5, outer: 5 })

  // Camarita con corazón al costado del QR.
  const camX = qx + frame + 15
  const camY = qrTop + frame / 2 - 2
  ctx.save()
  ctx.translate(camX, camY)
  ctx.rotate(0.12)
  drawIcon(ctx, ICONS.camera, 0, 0, 15, accent, 1.5)
  drawHeart(ctx, 0, 0.9, 4, accent, { fill: true })
  ctx.restore()
  drawSparkLines(ctx, camX, camY - 8, accent, { from: -Math.PI * 0.75, to: -Math.PI * 0.25, inner: 1.2, outer: 3.6 })

  // --- Pasos ---
  const stepsY = qrTop + frame + 18
  const steps = [
    { icon: ICONS.smartphone, lines: ['1. Escaneá', 'el QR'] },
    { icon: ICONS.imagePlus, lines: ['2. Subí', 'tus fotos'] },
    { icon: ICONS.users, lines: ['3. ¡Y disfrutá', 'de todas!'] },
  ]
  const xs = [34, 74, 114]
  steps.forEach((s, i) => {
    ctx.fillStyle = tint
    ctx.beginPath()
    ctx.arc(xs[i], stepsY, 9.5, 0, Math.PI * 2)
    ctx.fill()
    drawIcon(ctx, s.icon, xs[i], stepsY, 10, deep, 1.6)
    s.lines.forEach((line, j) => {
      fitText(ctx, line, xs[i], stepsY + 17 + j * 5.6, 36, { font: BODY_FONT, weight: 'bold', size: 4.6, color: INK })
    })
    if (i < 2) drawArrow(ctx, xs[i] + 12.5, xs[i + 1] - 12.5, stepsY, soft)
  })

  // --- Cierre ---
  const thanksY = Math.min(stepsY + 38, CARD_H - 16)
  text(ctx, '¡Gracias!', CARD_W / 2, thanksY, { font: TITLE_FONT, size: 10, color: accent })
  ctx.strokeStyle = accent
  ctx.lineWidth = 0.55
  ctx.lineCap = 'round'
  ctx.beginPath()
  ctx.moveTo(CARD_W / 2 - 26, thanksY - 2.6)
  ctx.lineTo(CARD_W / 2 - 19, thanksY - 2.6)
  ctx.moveTo(CARD_W / 2 + 19, thanksY - 2.6)
  ctx.lineTo(CARD_W / 2 + 26, thanksY - 2.6)
  ctx.stroke()
  drawHeart(ctx, CARD_W / 2, thanksY + 6, 4, accent)

  // Adornos sueltos.
  drawStar(ctx, 16, qrTop + 12, 2.6, accent, 0.2)
  drawHeart(ctx, 20, qrTop + frame - 4, 3.4, accent, { rotate: -0.3 })
  drawStar(ctx, 132, qrTop + frame + 4, 2.4, accent, -0.2)
  drawStar(ctx, 14, stepsY + 30, 2.2, accent, 0.4)
  drawHeart(ctx, 134, stepsY + 30, 3.2, accent, { rotate: 0.25 })
  drawStar(ctx, 40, thanksY + 3, 1.8, accent, 0.1)
  drawStar(ctx, 108, thanksY + 3, 1.8, accent, -0.3)

  // Para avisar en el panel si la foto elegida no se pudo usar.
  canvas.dataset.photo = photo ? 'ok' : photoUrl ? 'failed' : 'none'
  return canvas
}

/** PDF A4 apaisado con dos carteles A5 lado a lado y una línea para cortar. */
export async function photoCardPdf(canvas) {
  const { jsPDF } = await import('jspdf')
  const doc = new jsPDF({ unit: 'mm', format: 'a4', orientation: 'landscape' })
  const img = canvas.toDataURL('image/png')
  doc.addImage(img, 'PNG', 0, 0, CARD_W, CARD_H, 'card', 'FAST')
  doc.addImage(img, 'PNG', CARD_W + 1, 0, CARD_W, CARD_H, 'card', 'FAST') // mismo alias: se guarda una sola vez
  doc.setDrawColor(190)
  doc.setLineWidth(0.2)
  doc.setLineDashPattern([2, 2], 0)
  doc.line(CARD_W + 0.5, 0, CARD_W + 0.5, CARD_H)
  return doc
}
