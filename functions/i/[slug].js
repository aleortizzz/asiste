// /i/:slug — invitación de una familia. Ver og/vista-previa.js.
import { vistaPrevia } from '../../og/vista-previa.js'

export const onRequest = (context) => vistaPrevia(context, 'i', context.params.slug)
