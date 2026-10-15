// Planes (decididos el 2026-10-13; ver PROGRESO.md y la landing). Lo mismo
// está en la base, en plan_incluye() (migrations/20261013_planes.sql): la
// base es la que manda, esto es para mostrar u ocultar cosas en pantalla.
// `includes`: lo que se muestra en la landing y en «Tu plan».
export const PLANS = {
  gratis: { label: 'Prueba gratis', price: null, includes: [] },
  invitacion: {
    label: 'Invitación',
    price: 35000,
    includes: ['Invitación completa con música, fotos, mapa y regalos', 'Un solo link para todos', 'Confirmaciones por WhatsApp', 'Soporte por WhatsApp'],
  },
  plus: {
    label: 'Plus',
    price: 70000,
    includes: ['Un link por familia y panel de confirmaciones', 'Mesas y lista de la entrada', 'Reunión de 1 hora para armar todo juntos', 'Soporte por WhatsApp'],
  },
  premium: {
    label: 'Premium',
    price: 120000,
    includes: ['Todo lo del Plus', 'Canciones para el DJ y álbum de fotos', 'Trivia en vivo el día de la fiesta', 'Recepción en la puerta con tu personal', 'Cargamos los invitados y armamos la invitación', 'Soporte prioritario'],
  },
}
export const PLAN_IDS = Object.keys(PLANS)

// El gratis es «el full» con límites: tiene todo lo del premium.
const FEATURES = {
  invitados_ilimitados: ['invitacion', 'plus', 'premium'],
  panel: ['gratis', 'plus', 'premium'],
  mesas: ['gratis', 'plus', 'premium'],
  lista_entrada: ['gratis', 'plus', 'premium'],
  canciones: ['gratis', 'premium'],
  fotos: ['gratis', 'premium'],
  trivia: ['gratis', 'premium'],
  recepcion: ['gratis', 'premium'],
}

export const hasFeature = (plan, feature) => FEATURES[feature]?.includes(plan) ?? false

// El plan pago más barato que trae una función (id, o el nombre con planFor).
export const cheapestPlanWith = (feature) => ['invitacion', 'plus', 'premium'].find((p) => hasFeature(p, feature)) ?? null
export function planFor(feature) {
  const id = cheapestPlanWith(feature)
  return id ? PLANS[id].label : null
}

// Límites de la prueba gratis (los controla la base).
export const FREE_LIMITS = { invitations: 5, views: 15, hours: 24 }

// Lo que cuesta pasarse de un plan a otro: la diferencia (igual que
// precio_cambio_plan en la base, que es la que cobra). Null si no es una mejora.
export function upgradePrice(current, next) {
  const from = PLANS[current]?.price ?? 0
  const to = PLANS[next]?.price
  return to && to > from ? to - from : null
}

export const formatPrice = (n) => `$${n.toLocaleString('es-AR')}`

export const planLabel = (plan) => PLANS[plan]?.label ?? plan

// El plan que eligió en la landing antes de tener cuenta. Se guarda en el
// navegador porque entre el registro y el panel está el mail de confirmación.
const CHOSEN_KEY = 'asiste-plan-elegido'
export function rememberChosenPlan(plan) {
  if (!PLANS[plan]?.price) return
  try {
    localStorage.setItem(CHOSEN_KEY, plan)
  } catch {
    /* modo privado */
  }
}
export function chosenPlan() {
  try {
    const plan = localStorage.getItem(CHOSEN_KEY)
    return PLANS[plan]?.price ? plan : null
  } catch {
    return null
  }
}
export function forgetChosenPlan() {
  try {
    localStorage.removeItem(CHOSEN_KEY)
  } catch {
    /* modo privado */
  }
}
