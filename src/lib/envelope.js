// Derivaciones puras para el sobre (paleta de colores + sello/monograma),
// compartidas entre useInvitationLogic() (la invitación real) y AdminSalon
// (la vista previa en vivo del editor) — un solo lugar para no repetir la
// misma lógica en dos archivos y que se desincronicen con el tiempo.
import { lighten, darken, contrastText, isDark, relativeLuminance } from './color'

// Paleta del sobre, derivada de bgColor + primaryColor en vez de hardcodeada
// por plantilla. `letterInk` siempre es oscuro (la carta es sobre papel
// claro sí o sí); `ink`/`inkMuted` se adaptan según si el fondo elegido es
// claro u oscuro, así el texto de las leyendas siempre se lee bien.
//
// `envelopeColor` (opcional): color propio del sobre, independiente de la
// invitación (ej. sobre negro con invitación lila). Si viene, el papel y la
// solapa usan ese color tal cual (con leves variaciones para que se note el
// volumen); si no, se deriva un tono claro del color principal como antes.
// El sello acompaña al sobre: con color propio es una versión más oscura
// de ese mismo color (verde → verde oscuro); sin color propio, el principal.
export function deriveEnvelopePalette(bgColor, primaryColor, envelopeColor) {
  const bgIsDark = isDark(bgColor)
  const seal = sealBase(primaryColor, envelopeColor)
  return {
    bg: bgColor,
    ...envelopePaper(primaryColor, envelopeColor),
    sealFrom: lighten(seal, 0.08),
    sealTo: darken(seal, 0.18),
    sealText: contrastText(seal),
    ink: bgIsDark ? lighten(primaryColor, 0.75) : darken(primaryColor, 0.35),
    inkMuted: bgIsDark ? lighten(primaryColor, 0.5) : darken(primaryColor, 0.15),
    // Negro fijo (no un tono del color principal): se lee bien sobre el
    // papel claro de la carta con cualquier color que elija el host.
    letterInk: '#111111',
  }
}

const isHex = (c) => /^#[0-9a-fA-F]{6}$/.test(c || '')

function sealBase(primaryColor, envelopeColor) {
  if (!isHex(envelopeColor)) return primaryColor
  // Un sobre casi negro no tiene "más oscuro" visible: ahí el sello va más
  // claro (gris grafito) para que no desaparezca.
  return relativeLuminance(envelopeColor) < 0.02
    ? lighten(envelopeColor, 0.3)
    : darken(envelopeColor, 0.35)
}

function envelopePaper(primaryColor, envelopeColor) {
  if (!isHex(envelopeColor)) {
    return {
      paperFrom: lighten(primaryColor, 0.94),
      paperTo: lighten(primaryColor, 0.8),
      flapFrom: lighten(primaryColor, 0.72),
      flapTo: lighten(primaryColor, 0.55),
      seam: 'rgba(0, 0, 0, 0.07)',
    }
  }
  // En sobres oscuros la solapa va un poco más clara que el frente (si no,
  // negro sobre negro no se distingue); en claros, un poco más oscura.
  const dark = isDark(envelopeColor)
  return {
    paperFrom: lighten(envelopeColor, dark ? 0.1 : 0.25),
    paperTo: envelopeColor,
    flapFrom: dark ? lighten(envelopeColor, 0.18) : lighten(envelopeColor, 0.1),
    flapTo: dark ? lighten(envelopeColor, 0.06) : darken(envelopeColor, 0.08),
    seam: dark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.07)',
  }
}

// Sello del sobre: si el host cargó algo en "monogram" desde el editor, se
// usa tal cual (tope de 3 caracteres — por si el input del navegador no
// llegó a frenarlo, o vino de otro lado). Si lo dejó vacío, se arma solo a
// partir de heroTitle: "Sofía & Juan" -> letra de cada lado ("S & J" en la
// carta, "SJ" en el sello chico); "Antonella" -> "A" en los dos. Esto es a
// propósito un fallback razonable, no una regla infalible — por eso existe
// el campo manual, para cuando el texto principal no son nombres de gente
// (ej. "Fiesta de fin de año").
export function deriveEnvelopeMonogram(monogram, heroTitle) {
  const custom = (monogram || '').trim()
  if (custom) {
    const capped = [...custom].slice(0, 3).join('')
    return { short: capped, full: capped }
  }
  const t = (heroTitle || '').trim()
  if (!t) return { short: '✦', full: '✦' }
  const byAmp = t.split('&').map((s) => s.trim()).filter(Boolean)
  let initials
  if (byAmp.length >= 2) {
    initials = byAmp.slice(0, 2).map((p) => p[0]?.toUpperCase()).filter(Boolean)
  } else {
    const words = t.split(/\s+/).filter(Boolean)
    initials = words.length >= 2
      ? [words[0][0]?.toUpperCase(), words[1][0]?.toUpperCase()].filter(Boolean)
      : words[0]
        ? [words[0][0].toUpperCase()]
        : []
  }
  if (!initials.length) return { short: '✦', full: '✦' }
  return {
    short: initials.join(''),
    full: initials.length >= 2 ? initials.join(' & ') : initials[0],
  }
}
