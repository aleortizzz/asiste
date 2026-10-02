import { computed } from 'vue'
import { useEvent } from './useEvent'

// Palabras del panel según el tipo de evento. En cumpleaños y casamientos
// cada invitación (un link) suele ser una familia; en los empresariales, una
// persona, un equipo o una empresa: ahí «familia» queda raro.
export function useWording() {
  const { event } = useEvent()
  const business = computed(() => event.value?.event_type === 'empresarial')

  const w = computed(() =>
    business.value
      ? {
          // Una invitación (grupo con un link), en singular y plural.
          unit: 'invitación',
          units: 'invitaciones',
          Units: 'Invitaciones',
          // Campo «a qué grupo se suma» de una persona sin link.
          groupLabel: 'Empresa o grupo',
          noGroup: 'Sin grupo (invitado individual)',
          namePlaceholder: 'Ej. Juan Pérez · Equipo Ventas · Empresa XYZ',
          linkFor: 'Se crea un link para mandarle a esta persona, equipo o empresa.',
          searchPeople: 'Buscar persona o empresa',
          searchGroup: 'Buscar invitado o empresa',
          groupMovesAll: 'El nombre del grupo mueve a todos.',
          thisGroupHas: 'Esta invitación tiene',
          openedOne: 'invitado la abrió',
          openedMany: 'invitados la abrieron',
          enteredLink: 'invitados que entraron al link al menos una vez.',
        }
      : {
          unit: 'familia',
          units: 'familias',
          Units: 'Familias',
          groupLabel: 'Familia',
          noGroup: 'Sin familia (invitado individual)',
          namePlaceholder: 'Ej. Familia Pérez · Juan y Ana · Sofía',
          linkFor: 'Se crea un link para mandarle a esta familia o persona.',
          searchPeople: 'Buscar persona o familia',
          searchGroup: 'Buscar familia',
          groupMovesAll: 'El nombre de la familia mueve a todos.',
          thisGroupHas: 'Esta familia tiene',
          openedOne: 'familia la abrió',
          openedMany: 'familias la abrieron',
          enteredLink: 'familias que entraron al link al menos una vez.',
        },
  )

  return { w, business }
}
