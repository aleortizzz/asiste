// Número de WhatsApp para wa.me: solo dígitos, con código de país, sin 0 ni 15.
// Acepta lo que escribe la gente en Argentina («11 2233-4455», «011 15 2233
// 4455», «+54 9 11 2233 4455») y devuelve «5491122334455». null si no se puede.
export function normalizeWhatsapp(value) {
  let d = String(value ?? '').replace(/\D/g, '')
  if (!d) return null
  if (d.startsWith('00')) d = d.slice(2) // 0054…
  if (d.startsWith('54')) {
    d = d.slice(2)
    if (d.startsWith('9')) d = d.slice(1)
  }
  if (d.startsWith('0')) d = d.slice(1) // 011…
  // «15» después del código de área (2 a 4 dígitos): 11 15 2233 4455 → 11 2233 4455
  if (d.length === 12) {
    for (const area of [2, 3, 4]) {
      if (d.slice(area, area + 2) === '15') {
        d = d.slice(0, area) + d.slice(area + 2)
        break
      }
    }
  }
  return d.length === 10 ? `549${d}` : null
}

// Para mostrarlo lindo: 5491122334455 → +54 9 11 2233-4455 (aprox., por área de 2).
export const formatWhatsapp = (n) => (n ? `+${n.slice(0, 2)} ${n.slice(2, 3)} ${n.slice(3)}` : '')
