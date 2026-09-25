// Utilidades de color en JS puro (sin librería) para derivar variantes de un
// color elegido por el host — mezclar hacia blanco/negro para tints/shades, y
// decidir si el texto sobre ese color debe ser claro u oscuro. Usado para que
// "color principal" alcance para themear botones, sello del sobre, etc. sin
// pedirle al host que elija 5 colores distintos.

function hexToRgb(hex) {
  const clean = hex.replace('#', '')
  const full = clean.length === 3 ? clean.split('').map((c) => c + c).join('') : clean
  const num = parseInt(full, 16)
  return [(num >> 16) & 255, (num >> 8) & 255, num & 255]
}

function rgbToHex([r, g, b]) {
  const clamp = (v) => Math.max(0, Math.min(255, Math.round(v)))
  return '#' + [r, g, b].map((v) => clamp(v).toString(16).padStart(2, '0')).join('')
}

// Mezcla `hex` hacia `target` ("#ffffff" o "#000000") en la proporción `amount` (0-1).
function mix(hex, target, amount) {
  const a = hexToRgb(hex)
  const b = hexToRgb(target)
  return rgbToHex(a.map((v, i) => v + (b[i] - v) * amount))
}

export function lighten(hex, amount) {
  return mix(hex, '#ffffff', amount)
}

export function darken(hex, amount) {
  return mix(hex, '#000000', amount)
}

// Luminancia relativa (WCAG) — para decidir contraste de texto.
export function relativeLuminance(hex) {
  const [r, g, b] = hexToRgb(hex).map((v) => {
    const c = v / 255
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
  })
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

// Texto legible (blanco o casi-negro) sobre un fondo `hex` dado.
export function contrastText(hex) {
  return relativeLuminance(hex) > 0.5 ? '#1a1a1a' : '#ffffff'
}

export function isDark(hex) {
  return relativeLuminance(hex) <= 0.5
}
