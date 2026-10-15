// v-reveal para la landing: el elemento aparece suave cuando entra en
// pantalla (estilos .lr / .lr-in en style.css). Variantes con el valor de la
// directiva: v-reveal (sube), v-reveal="'left'", "'right'", "'scale'".
// Demora en ms con data-delay (para escalonar una lista).
//
// El estado oculto lo pone el JS al montar: si el script falla, todo se ve.
// Con «reducir movimiento» del sistema, solo un fundido corto (ver CSS).
export const vReveal = {
  mounted(el, binding) {
    if (typeof IntersectionObserver === 'undefined') return
    el.classList.add('lr')
    if (binding.value) el.dataset.reveal = binding.value
    if (el.dataset.delay) el.style.setProperty('--d', `${el.dataset.delay}ms`)
    const io = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            entry.target.classList.add('lr-in')
            io.unobserve(entry.target)
          }
        }
      },
      { threshold: 0.12, rootMargin: '0px 0px -6% 0px' },
    )
    io.observe(el)
    el._lr = io
  },
  unmounted(el) {
    el._lr?.disconnect()
  },
}
