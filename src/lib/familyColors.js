// Colores de familia para el plano de mesas: fuertes, bien distintos entre sí
// y legibles con letra blanca.
export const FAMILY_COLORS = ['#d4537e', '#2f8fd4', '#e08a1e', '#3fa36b', '#8a4fd8', '#0f8b8d', '#b4532a', '#475569']

// Un color por familia, en el orden en que vienen (AdminMesas las ordena por
// nombre): las primeras 8 nunca se repiten y cada familia tiene el mismo color
// en todas las mesas. { [family_id]: color }
export function familyColorMap(guests) {
  const map = {}
  for (const g of guests) {
    const id = g.invitation_groups.id
    if (!(id in map)) map[id] = FAMILY_COLORS[Object.keys(map).length % FAMILY_COLORS.length]
  }
  return map
}
