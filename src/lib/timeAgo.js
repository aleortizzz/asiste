// "hace 5 min", "hace 2 h", "ayer"… — para listados de actividad del admin.
export function timeAgo(iso) {
  const mins = Math.round((Date.now() - new Date(iso)) / 60000)
  if (mins < 1) return 'recién'
  if (mins < 60) return `hace ${mins} min`
  const hours = Math.round(mins / 60)
  if (hours < 24) return `hace ${hours} h`
  const days = Math.round(hours / 24)
  if (days === 1) return 'ayer'
  if (days < 7) return `hace ${days} días`
  return new Date(iso).toLocaleDateString('es-AR', { day: 'numeric', month: 'short' })
}
