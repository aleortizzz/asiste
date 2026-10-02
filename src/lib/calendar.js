// «Agregar al calendario»: arma el link de Google Calendar y el archivo .ics
// (el que abren el calendario del iPhone, Outlook y casi todos los demás) a
// partir de los datos del evento.
//
// Las fechas y horas del evento están en hora argentina. Argentina no tiene
// horario de verano, así que alcanza con sumar las 3 horas de diferencia y
// mandarlas en UTC: así se ven bien aunque el invitado esté en otro país.

const AR_OFFSET_HOURS = 3

// 'YYYY-MM-DD' + 'HH:MM[:SS]' (hora argentina) → Date en UTC.
function arToDate(ymd, time) {
  const [y, m, d] = ymd.split('-').map(Number)
  const [hh, mm] = (time || '00:00').split(':').map(Number)
  return new Date(Date.UTC(y, m - 1, d, hh + AR_OFFSET_HOURS, mm))
}

// Formato de calendario: 20271118T220000Z
const stamp = (date) => date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')

// Inicio y fin del evento. Sin hora de inicio: evento de día completo.
// Sin hora de fin: 3 horas. Si termina «antes» de empezar (ej. 21 a 4 h),
// es que termina al día siguiente.
export function eventRange(invite) {
  if (!invite?.event_date) return null
  if (!invite.reception_time) {
    const [y, m, d] = invite.event_date.split('-').map(Number)
    const next = new Date(Date.UTC(y, m - 1, d + 1))
    return { allDay: true, start: invite.event_date.replace(/-/g, ''), end: next.toISOString().slice(0, 10).replace(/-/g, '') }
  }
  const start = arToDate(invite.event_date, invite.reception_time)
  let end = invite.end_time ? arToDate(invite.event_date, invite.end_time) : new Date(start.getTime() + 3 * 3600000)
  if (end <= start) end = new Date(end.getTime() + 24 * 3600000)
  return { allDay: false, start: stamp(start), end: stamp(end) }
}

function details(invite) {
  return {
    title: invite.hero_title || invite.event_name || 'Evento',
    location: [invite.venue_name, invite.venue_address].filter(Boolean).join(', '),
    description: [invite.hero_subtitle, typeof window !== 'undefined' ? window.location.href : ''].filter(Boolean).join('\n\n'),
  }
}

export function googleCalendarUrl(invite) {
  const range = eventRange(invite)
  if (!range) return ''
  const { title, location, description } = details(invite)
  const params = new URLSearchParams({ action: 'TEMPLATE', text: title, dates: `${range.start}/${range.end}` })
  if (location) params.set('location', location)
  if (description) params.set('details', description)
  return `https://calendar.google.com/calendar/render?${params}`
}

// iPhone / iPad (los iPad nuevos se presentan como Mac, pero con pantalla táctil).
export function isIOS() {
  if (typeof navigator === 'undefined') return false
  return /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
}

// Google Calendar sin perder la invitación: en compu se abre en una ventana
// chica aparte (la invitación queda detrás, en su pestaña); en el celular, en
// otra pestaña o directo en la app de Calendario, y con «atrás» se vuelve.
// Agregarlo sin salir de la página no se puede sin pedirle al invitado acceso
// a su cuenta de Google.
export function openGoogleCalendar(invite) {
  const url = googleCalendarUrl(invite)
  if (!url) return
  const desktop = window.matchMedia?.('(pointer: fine)').matches && window.innerWidth >= 768
  if (desktop) {
    const w = 720
    const h = 760
    const left = Math.max(0, window.screenX + (window.outerWidth - w) / 2)
    const top = Math.max(0, window.screenY + (window.outerHeight - h) / 2)
    const popup = window.open(url, 'agregar-al-calendario', `popup,width=${w},height=${h},left=${left},top=${top}`)
    if (popup) return
  }
  // Celular, o el navegador bloqueó la ventanita: pestaña nueva.
  window.open(url, '_blank', 'noopener')
}

// Texto dentro del .ics: comas, punto y coma y saltos de línea van escapados.
const icsText = (s) => s.replace(/\\/g, '\\\\').replace(/[,;]/g, (c) => `\\${c}`).replace(/\n/g, '\\n')

export function downloadIcs(invite) {
  const range = eventRange(invite)
  if (!range) return
  const { title, location, description } = details(invite)
  const when = range.allDay
    ? [`DTSTART;VALUE=DATE:${range.start}`, `DTEND;VALUE=DATE:${range.end}`]
    : [`DTSTART:${range.start}`, `DTEND:${range.end}`]
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Asiste//Invitaciones//ES',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${Date.now()}-${Math.random().toString(36).slice(2)}@asiste.tizdigital.com`,
    `DTSTAMP:${stamp(new Date())}`,
    ...when,
    `SUMMARY:${icsText(title)}`,
    location && `LOCATION:${icsText(location)}`,
    description && `DESCRIPTION:${icsText(description)}`,
    'END:VEVENT',
    'END:VCALENDAR',
  ].filter(Boolean)
  const blob = new Blob([lines.join('\r\n')], { type: 'text/calendar;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${title.replace(/[^\p{L}\p{N}]+/gu, '-').replace(/^-|-$/g, '').toLowerCase() || 'evento'}.ics`
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}
