import { computed } from 'vue'
import { lighten, contrastText, isDark } from '../lib/color'

// Estilo de las páginas públicas del QR (fotos y juego) según la plantilla de
// la invitación. `info` es el ref con lo que devuelve info_fotos_evento().
// Las fuentes ya las carga index.html (son las mismas de las invitaciones).
const THEMES = {
  clasico: {
    display: "'Dancing Script', cursive",
    displayWeight: 700,
    displaySize: '2.6rem',
    body: "'Playfair Display', serif",
  },
  partiful: {
    display: "'Space Grotesk', ui-sans-serif, sans-serif",
    displayWeight: 700,
    displaySize: '2.1rem',
    body: "'Inter', ui-sans-serif, sans-serif",
    bg: '#ffffff',
  },
  craft: {
    display: "'DM Serif Text', ui-serif, Georgia, serif",
    displayWeight: 400,
    displaySize: '2.3rem',
    body: "'Inter', ui-sans-serif, sans-serif",
    bg: '#f7f3ea',
  },
}

export function useGuestTheme(info) {
  const theme = computed(() => {
    const t = THEMES[info.value?.template] ?? THEMES.clasico
    const accent = /^#[0-9a-f]{6}$/i.test(info.value?.primary_color || '') ? info.value.primary_color : '#9f1239'
    const bg = t.bg ?? info.value?.bg_color ?? '#fdf7f1'
    const dark = isDark(bg)
    return {
      ...t,
      vars: {
        '--accent': accent,
        '--accent-on': contrastText(accent),
        // Sobre fondo oscuro el color principal puede no leerse: lo aclaramos.
        '--accent-text': dark ? lighten(accent, 0.45) : accent,
        '--tint': dark ? 'rgba(255,255,255,0.08)' : lighten(accent, 0.86),
        '--page-bg': bg,
        '--ink': dark ? '#f5f3f0' : '#2b2527',
        '--muted': dark ? 'rgba(245,243,240,0.6)' : 'rgba(43,37,39,0.58)',
        '--line': dark ? 'rgba(255,255,255,0.12)' : 'rgba(43,37,39,0.1)',
        '--field': dark ? 'rgba(255,255,255,0.08)' : '#ffffff',
        '--heart': '#ff3040',
      },
    }
  })

  const pageStyle = computed(() => ({
    ...theme.value.vars,
    background: 'var(--page-bg)',
    color: 'var(--ink)',
    fontFamily: theme.value.body,
  }))

  return { theme, pageStyle }
}
