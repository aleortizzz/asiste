// Planes (decididos el 2026-10-13; ver PROGRESO.md y la landing). Lo mismo
// está en la base, en plan_incluye() (migrations/20261013_planes.sql): la
// base es la que manda, esto es para mostrar u ocultar cosas en pantalla.
export const PLANS = {
  gratis: { label: 'Prueba gratis', price: null },
  invitacion: { label: 'Invitación', price: 35000 },
  plus: { label: 'Plus', price: 70000 },
  premium: { label: 'Premium', price: 120000 },
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

export const planLabel = (plan) => PLANS[plan]?.label ?? plan
