// Utilidades de la trivia, compartidas entre el panel (AdminJuego) y la
// pantalla del invitado.

// Mezcla "con semilla": con la misma semilla sale siempre el mismo orden.
// La semilla es el token del intento, así cada invitado ve un orden distinto
// de preguntas y opciones, pero si recarga la página no le cambian de lugar.
function hashString(str) {
  let h = 1779033703 ^ str.length
  for (let i = 0; i < str.length; i++) {
    h = Math.imul(h ^ str.charCodeAt(i), 3432918353)
    h = (h << 13) | (h >>> 19)
  }
  return h >>> 0
}

// mulberry32: generador de números al azar chiquito y suficiente para esto.
function random(seed) {
  let a = seed
  return () => {
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

// Fisher–Yates. Devuelve una copia; no toca el array original.
export function seededShuffle(items, seed) {
  const next = random(hashString(String(seed)))
  const out = [...items]
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(next() * (i + 1))
    ;[out[i], out[j]] = [out[j], out[i]]
  }
  return out
}

// 192345 → «3:12,3». Con décimas, para que se entienda un desempate.
export function formatDuration(ms) {
  if (ms == null) return '—'
  const tenths = Math.floor(ms / 100)
  const min = Math.floor(tenths / 600)
  const sec = Math.floor((tenths % 600) / 10)
  return `${min}:${String(sec).padStart(2, '0')},${tenths % 10}`
}

// Ordena los intentos enviados como el ranking del servidor (ranking_juego):
// más aciertos primero; si empatan, menos tiempo. Mismo puntaje y mismo
// tiempo comparten el puesto.
export function rankAttempts(attempts) {
  const sorted = [...attempts].sort((a, b) => b.correct_count - a.correct_count || a.duration_ms - b.duration_ms)
  let prev = null
  return sorted.map((a, i) => {
    const tied = prev && prev.correct_count === a.correct_count && prev.duration_ms === a.duration_ms
    const position = tied ? prev.position : i + 1
    prev = { ...a, position }
    return prev
  })
}
