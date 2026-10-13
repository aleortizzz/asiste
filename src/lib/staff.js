// Cuentas de recepción: el personal del salón entra con usuario y contraseña,
// sin mail. Supabase igual pide un mail, así que el usuario se guarda como
// «<usuario>@recepcion.tizdigital.com». La cuenta la crea la base ya
// confirmada y sin mandar nada (crear_recepcionista, ver
// migrations/20261012_recepcion_cuentas.sql, que usa el mismo dominio).
export const STAFF_DOMAIN = 'recepcion.tizdigital.com'

export const usernameToEmail = (username) => `${username.trim().toLowerCase()}@${STAFF_DOMAIN}`
export const isStaffUser = (user) => user?.user_metadata?.role === 'recepcion'

// Letras, números, punto y guion; de 3 a 30. Así entra en un mail sin escapar nada.
export function usernameError(value) {
  const v = value.trim()
  if (!v) return 'Escribí un usuario.'
  if (!/^[a-zA-Z0-9.-]{3,30}$/.test(v)) return 'De 3 a 30 letras o números, sin espacios ni acentos.'
  return ''
}
