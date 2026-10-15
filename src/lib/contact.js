// Contacto de Asiste (TizDigital): lo usan la landing, el botón flotante y
// las páginas legales. Cambiarlo acá lo cambia en todos lados.
export const WHATSAPP = '5491153855217'
export const WHATSAPP_DISPLAY = '11 5385-5217'
export const COMPANY = 'TizDigital'
export const SITE = 'asiste.tizdigital.com'

// Link de WhatsApp con el mensaje ya escrito.
export const waLink = (text = 'Hola! Quiero saber más sobre Asiste.') =>
  `https://wa.me/${WHATSAPP}?text=${encodeURIComponent(text)}`
