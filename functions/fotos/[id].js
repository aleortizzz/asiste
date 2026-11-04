// /fotos/:eventId — galería de fotos del evento. Ver og/vista-previa.js.
import { vistaPrevia } from '../../og/vista-previa.js'

export const onRequest = (context) => vistaPrevia(context, 'f', context.params.id)
