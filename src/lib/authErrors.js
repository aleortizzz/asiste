// Supabase Auth devuelve los errores en inglés ("Invalid login credentials").
// Esto los pasa a un mensaje en castellano que diga qué hacer. Se mira
// primero `code` (estable) y después el texto, por si alguna versión no lo
// manda. Lo que no se reconoce cae en `fallback`.
const BY_CODE = {
  invalid_credentials: 'Mail o contraseña incorrectos.',
  email_not_confirmed: 'Todavía no confirmaste tu mail. Buscá el mail de confirmación (fijate también en spam).',
  user_already_exists: 'Ya hay una cuenta con ese mail. Probá ingresar, o recuperá la contraseña.',
  email_exists: 'Ya hay una cuenta con ese mail. Probá ingresar, o recuperá la contraseña.',
  weak_password: 'La contraseña es muy fácil de adivinar. Probá con una más larga.',
  same_password: 'La contraseña nueva tiene que ser distinta de la anterior.',
  over_email_send_rate_limit: 'Mandamos demasiados mails seguidos. Esperá unos minutos y probá de nuevo.',
  over_request_rate_limit: 'Demasiados intentos seguidos. Esperá unos minutos y probá de nuevo.',
  session_not_found: 'El link venció o ya se usó. Pedí uno nuevo desde «¿Te la olvidaste?», en Ingresar.',
  validation_failed: 'Revisá que el mail esté bien escrito.',
}

const BY_TEXT = [
  [/invalid login credentials/i, 'invalid_credentials'],
  [/email not confirmed/i, 'email_not_confirmed'],
  [/already registered/i, 'user_already_exists'],
  [/should be different/i, 'same_password'],
  [/rate limit/i, 'over_request_rate_limit'],
  [/session missing|session not found/i, 'session_not_found'],
  [/password should be/i, 'weak_password'],
  [/invalid.*email|email.*invalid/i, 'validation_failed'],
]

export function authErrorMessage(err, fallback = 'Algo salió mal. Probá de nuevo en un rato.') {
  if (err?.code && BY_CODE[err.code]) return BY_CODE[err.code]
  const text = err?.message ?? ''
  for (const [re, code] of BY_TEXT) if (re.test(text)) return BY_CODE[code]
  return fallback
}
