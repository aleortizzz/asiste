// Prueba de colores (/colores): cambia el fondo (pumice + limestone) y el
// color de los detalles (sulfur) pisando las variables de @theme en <html>.
// La elección dura la pestaña (sessionStorage) para poder recorrer la
// landing entera con ella; ?fondo=…&detalle=… en la URL también la aplica.
// Es solo para elegir: cuando se decida, se cambian los valores en style.css
// y esto se borra.

// Tono claro de las tarjetas para un fondo: el fondo mezclado con blanco.
const toWhite = (hex, t = 0.7) =>
  '#' +
  [1, 3, 5]
    .map((i) => Math.round(parseInt(hex.slice(i, i + 2), 16) * (1 - t) + 255 * t).toString(16).padStart(2, '0'))
    .join('')
const fondo = (id, label, pumice, limestone = toWhite(pumice)) => ({ id, label, pumice, limestone })
const detalle = (id, label, sulfur) => ({ id, label, sulfur })

export const FONDOS = [
  fondo('piedra', 'Gris piedra (actual)', '#e2e2df', '#f7f6f2'),
  fondo('hueso', 'Hueso', '#f1efe9'),
  fondo('gris-calido', 'Gris cálido', '#e6e1dc'),
  fondo('crema', 'Crema', '#efe7d8'),
  fondo('manteca', 'Manteca', '#f3ecd2'),
  fondo('arena', 'Arena', '#e8dcc6'),
  fondo('durazno', 'Durazno', '#f4e3d7'),
  fondo('terracota', 'Terracota claro', '#efd9cc'),
  fondo('empolvado', 'Rosa empolvado', '#f2dfe1'),
  fondo('palo-rosa', 'Palo de rosa', '#ead3d6'),
  fondo('lila', 'Lila', '#e8e1f0'),
  fondo('glicina', 'Glicina', '#e3d9f2'),
  fondo('lavanda-gris', 'Lavanda gris', '#dedbea'),
  fondo('niebla', 'Celeste niebla', '#dfe7ee'),
  fondo('agua', 'Celeste agua', '#d9ecef'),
  fondo('menta', 'Menta suave', '#d8ede4'),
  fondo('salvia', 'Salvia', '#dfe7dc'),
  fondo('pistacho', 'Pistacho', '#e6edd5'),
]

export const DETALLES = [
  detalle('amarillo', 'Amarillo (actual)', '#f5f28e'),
  detalle('manteca', 'Manteca', '#ffe58a'),
  detalle('oro', 'Oro', '#ffcf4d'),
  detalle('mandarina', 'Mandarina', '#ffb46b'),
  detalle('naranja', 'Naranja', '#ff9a3d'),
  detalle('durazno', 'Durazno', '#ffc4a3'),
  detalle('coral', 'Coral', '#ff9478'),
  detalle('salmon', 'Salmón', '#ff8a8a'),
  detalle('sandia', 'Sandía', '#ff6b6b'),
  detalle('frambuesa', 'Frambuesa', '#ff6fa3'),
  detalle('fucsia', 'Fucsia', '#ff5fc8'),
  detalle('chicle', 'Rosa chicle', '#ff9fd0'),
  detalle('rosa', 'Rosa pastel', '#ffc2dd'),
  detalle('lavanda', 'Lavanda', '#d9c2ff'),
  detalle('lila', 'Lila', '#c6a8ff'),
  detalle('violeta', 'Violeta eléctrico', '#a98bff'),
  detalle('celeste', 'Celeste', '#9ad7ff'),
  detalle('cielo', 'Cielo', '#6fc3ff'),
  detalle('turquesa', 'Turquesa', '#5fe0d6'),
  detalle('aqua', 'Aqua', '#a6f0ea'),
  detalle('menta', 'Menta', '#8ce8c6'),
  detalle('verde-agua', 'Verde agua', '#6fdfa8'),
  detalle('pistacho', 'Pistacho', '#d6ee9b'),
  detalle('lima', 'Lima', '#cdf56e'),
  detalle('fluo', 'Amarillo flúor', '#e4ff5c'),
]

// Un color libre viene como id «#rrggbb».
const isHex = (id) => /^#[0-9a-f]{6}$/i.test(id ?? '')
export const findFondo = (id) => FONDOS.find((x) => x.id === id) ?? (isHex(id) ? fondo(id, 'Otro', id) : FONDOS[0])
export const findDetalle = (id) => DETALLES.find((x) => x.id === id) ?? (isHex(id) ? detalle(id, 'Otro', id) : DETALLES[0])

const KEY = 'asiste-paleta'

export function applyPalette({ fondo, detalle }) {
  const f = findFondo(fondo)
  const d = findDetalle(detalle)
  const root = document.documentElement.style
  const isDefault = f.id === FONDOS[0].id && d.id === DETALLES[0].id
  for (const [name, value] of [
    ['--color-pumice', f.pumice],
    ['--color-limestone', f.limestone],
    ['--color-sulfur', d.sulfur],
  ]) {
    if (isDefault) root.removeProperty(name)
    else root.setProperty(name, value)
  }
  try {
    if (isDefault) sessionStorage.removeItem(KEY)
    else sessionStorage.setItem(KEY, JSON.stringify({ fondo: f.id, detalle: d.id }))
  } catch {
    /* modo privado */
  }
  return { fondo: f.id, detalle: d.id }
}

export function currentPalette() {
  try {
    return JSON.parse(sessionStorage.getItem(KEY)) ?? { fondo: FONDOS[0].id, detalle: DETALLES[0].id }
  } catch {
    return { fondo: FONDOS[0].id, detalle: DETALLES[0].id }
  }
}

// Al arrancar la app (main.js).
export function applyPaletteFromUrl() {
  const q = new URLSearchParams(location.search)
  if (q.has('fondo') || q.has('detalle')) {
    const saved = currentPalette()
    applyPalette({ fondo: q.get('fondo') ?? saved.fondo, detalle: q.get('detalle') ?? saved.detalle })
  } else if (currentPalette().fondo !== FONDOS[0].id || currentPalette().detalle !== DETALLES[0].id) {
    applyPalette(currentPalette())
  }
}
