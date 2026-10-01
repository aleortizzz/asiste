import { ref, reactive, computed } from 'vue'

// Validación de formularios con mensajes propios (en vez de los globitos del
// navegador, que cambian según el navegador y a veces salen en inglés).
//
// rules: { campo: { id, check } }
//   - id: el id del <input>, para llevar el cursor al primer error.
//   - check(): devuelve el mensaje de error, o '' si está bien.
//
// Cuándo se muestra cada error:
//   - Al tocar el botón (validate()): todos los que haya.
//   - Al salir de un campo ya escrito (touch()): solo el de ese campo. Si
//     el campo está vacío no se marca todavía, para no retar a alguien que
//     solo pasó por ahí con el Tab.
// Como los mensajes son computed, se borran solos apenas el dato se corrige.
export function useFormValidation(rules) {
  const submitted = ref(false)
  const touched = reactive({})

  const errors = computed(() => Object.fromEntries(Object.entries(rules).map(([key, r]) => [key, r.check()])))

  const errorFor = (key) => (submitted.value || touched[key] ? errors.value[key] : '')

  function touch(key, value) {
    if (value) touched[key] = true
  }

  function validate() {
    submitted.value = true
    const firstInvalid = Object.keys(rules).find((key) => errors.value[key])
    if (firstInvalid) document.getElementById(rules[firstInvalid].id)?.focus()
    return !firstInvalid
  }

  function reset() {
    submitted.value = false
    for (const key of Object.keys(touched)) delete touched[key]
  }

  return { errorFor, touch, validate, reset }
}

// --- Reglas comunes ---------------------------------------------------------------
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
export const MIN_PASSWORD = 6

export function emailError(value) {
  const v = value.trim()
  if (!v) return 'Escribí tu mail.'
  if (!EMAIL_RE.test(v)) return 'Ese mail no parece válido. Revisá que tenga @ y un punto (ej. nombre@gmail.com).'
  return ''
}

export function newPasswordError(value) {
  if (!value) return 'Elegí una contraseña.'
  if (value.length < MIN_PASSWORD) {
    const missing = MIN_PASSWORD - value.length
    return `Tiene que tener al menos ${MIN_PASSWORD} caracteres (te ${missing === 1 ? 'falta 1' : `faltan ${missing}`}).`
  }
  return ''
}

export function confirmPasswordError(password, confirm) {
  if (!confirm) return 'Repetí la contraseña para confirmarla.'
  if (confirm !== password) return 'No coincide con la contraseña de arriba.'
  return ''
}
