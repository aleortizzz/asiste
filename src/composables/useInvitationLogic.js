import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { searchYoutubeVideos } from '../lib/youtube'
import { lighten, darken, contrastText } from '../lib/color'
import { deriveEnvelopePalette, deriveEnvelopeMonogram } from '../lib/envelope'

// Toda la lógica de la invitación pública, compartida entre las distintas
// plantillas visuales (ver src/components/invitation-templates/). Cada
// plantilla solo define su propio <template>/<style> y llama a esto para
// obtener el mismo comportamiento: RSVP, countdown, carruseles, sobre +
// música, pedido de canciones, galería con parallax, etc. Así agregar una
// plantilla nueva no implica reescribir ni duplicar toda esta lógica.
// Datos extra que el evento puede pedir al confirmar (events.rsvp_fields).
// El nombre se pide siempre; las restricciones alimentarias son opcionales
// para el invitado, el resto obligatorio.
export const RSVP_FIELDS = {
  company: { label: 'Empresa', labelEn: 'Company', required: true, autocomplete: 'organization' },
  job_title: { label: 'Cargo', labelEn: 'Job title', required: true, autocomplete: 'organization-title' },
  email: { label: 'Mail', labelEn: 'Email', required: true, type: 'email', autocomplete: 'email' },
  phone: { label: 'Teléfono', labelEn: 'Phone', required: true, type: 'tel', autocomplete: 'tel' },
  dietary: {
    label: 'Restricciones alimentarias',
    labelEn: 'Dietary restrictions',
    required: false,
    placeholder: 'Restricciones alimentarias (opcional)',
    placeholderEn: 'Dietary restrictions (optional)',
  },
}

// Avisos de la invitación en los dos idiomas (invitaciones bilingües, ver
// `lang`). Las plantillas que no son bilingües siempre usan 'es'.
const MSG = {
  es: {
    names: 'Completá el nombre en todos los campos, o quitá los que no vayas a usar.',
    missing: (field, who) => `Completá ${field.toLowerCase()}${who ? ` de ${who}` : ''}.`,
    email: (who) => `Revisá el mail${who ? ` de ${who}` : ''}: tiene que tener @ y un punto.`,
    songName: 'Nos falta tu nombre para saber quién la pidió.',
    songSearch: 'No pudimos buscar canciones ahora, probá de nuevo.',
  },
  en: {
    names: 'Please fill in every name, or remove the ones you won’t use.',
    missing: (field, who) => `Please fill in ${who ? `${who}’s ` : 'your '}${field.toLowerCase()}.`,
    email: (who) => `Please check ${who ? `${who}’s` : 'the'} email address.`,
    songName: 'Please tell us your name so we know who suggested it.',
    songSearch: 'We couldn’t search for songs right now. Please try again.',
  },
}
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export function useInvitationLogic(props, emit) {
  const now = ref(new Date())
  // Idioma que eligió el invitado (solo en invitaciones bilingües).
  const lang = ref('es')
  const msg = computed(() => MSG[lang.value] ?? MSG.es)
  let clockTimer = null

  // Modo "genérico" (sin nombres precargados): la familia tipea los nombres.
  const names = ref([''])
  // Datos extra de cada nombre, en el mismo orden que `names`.
  const details = ref([{}])
  // Datos extra de un invitado (o vacíos, para uno nuevo).
  const detailsOf = (g = {}) => Object.fromEntries(Object.keys(RSVP_FIELDS).map((k) => [k, g[k] ?? '']))
  // Modo "con nombres" (named_by_host): lista fija de {id, full_name, attending}.
  const namedGuests = ref([])
  const localError = ref('')
  const displayError = computed(() => localError.value || props.error)

  // Rehidrata las listas del RSVP cada vez que cambian los datos (en el preview
  // el `invite` muta mientras se escribe en el formulario).
  watch(
    () => props.invite,
    (data) => {
      if (!data) return
      if (data.named_by_host) {
        namedGuests.value = (data.guests ?? []).map((g) => ({
          id: g.id,
          full_name: g.full_name,
          attending: g.rsvp_status !== 'not_attending',
          ...detailsOf(g),
        }))
      } else if (data.guests?.length) {
        names.value = data.guests.map((g) => g.full_name)
        details.value = data.guests.map(detailsOf)
      } else {
        names.value = ['']
        details.value = [detailsOf()]
      }
    },
    { immediate: true, deep: true },
  )

  // ---------------------------------------------------------------------------
  // FOTOS — vienen de `props.invite.{banner,retrato,detalle,momentos,galeria}`
  // (arrays de { url, path } desde Supabase Storage). Si un slot está vacío se
  // usan las fotos de demo, así la invitación nunca se ve rota.
  // ---------------------------------------------------------------------------
  const DEMO = {
    banner: '/invitaciones-demo/demo-02.jpeg',
    detalle: '/invitaciones-demo/demo-07.jpeg',
    retrato: [
      '/invitaciones-demo/demo-05.jpeg',
      '/invitaciones-demo/demo-01.jpeg',
      '/invitaciones-demo/demo-04.jpeg',
      '/invitaciones-demo/demo-06.jpeg',
      '/invitaciones-demo/demo-08.jpeg',
    ],
    momentos: [
      '/invitaciones-demo/demo-01.jpeg',
      '/invitaciones-demo/demo-03.jpeg',
      '/invitaciones-demo/demo-04.jpeg',
      '/invitaciones-demo/demo-06.jpeg',
      '/invitaciones-demo/demo-08.jpeg',
    ],
    galeria: [
      '/invitaciones-demo/demo-01.jpeg',
      '/invitaciones-demo/demo-02.jpeg',
      '/invitaciones-demo/demo-03.jpeg',
      '/invitaciones-demo/demo-04.jpeg',
      '/invitaciones-demo/demo-05.jpeg',
      '/invitaciones-demo/demo-06.jpeg',
      '/invitaciones-demo/demo-07.jpeg',
      '/invitaciones-demo/demo-08.jpeg',
    ],
  }
  function slotUrls(slot) {
    const a = props.invite?.[slot]
    return Array.isArray(a) ? a.map((p) => p?.url).filter(Boolean) : []
  }
  const bannerFoto = computed(() => slotUrls('banner')[0] || DEMO.banner)
  const detalleFoto = computed(() => slotUrls('detalle')[0] || DEMO.detalle)
  const saludoFotos = computed(() => {
    const u = slotUrls('retrato')
    return u.length ? u : DEMO.retrato
  })
  const momentosFotos = computed(() => {
    const u = slotUrls('momentos')
    return u.length ? u : DEMO.momentos
  })
  const galeriaGrid = computed(() => {
    const u = slotUrls('galeria')
    return u.length ? u : DEMO.galeria
  })

  const reducedMotion =
    typeof window !== 'undefined' &&
    window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true

  // Textos del hero/saludo/cierre: los define cada evento desde el admin. Si
  // quedan vacíos se usa uno de ejemplo según el tipo de evento (y, en los
  // empresariales, el tono). Sin tipo (eventos viejos): los de cumpleaños.
  const usted = computed(() => props.invite?.tono === 'usted')
  const defaultIntro = computed(() => {
    switch (props.invite?.event_type) {
      case 'casamiento':
        return 'Con toda la ilusión queremos compartir con ustedes el día en que unimos nuestras vidas.'
      case 'empresarial':
        return usted.value
          ? 'Será un honor contar con su presencia en una noche dedicada a lo que viene.'
          : 'Va a ser un honor que nos acompañes en una noche dedicada a lo que viene.'
      default:
        return 'Hay días que quedan guardados para siempre en el corazón. Nos encantaría compartir este con ustedes.'
    }
  })
  // Cumpleaños y casamiento quedan con el de siempre: cambiarlo alteraría
  // invitaciones ya mandadas que tenían el cierre vacío.
  const defaultClosing = computed(() => {
    if (props.invite?.event_type === 'empresarial') {
      return usted.value ? 'Esperamos contar con su presencia.' : 'Los esperamos.'
    }
    return '¡Los esperamos!'
  })
  const heroTitle = computed(
    () => props.invite?.hero_title || props.invite?.event_name || 'Nuestro festejo',
  )
  const bgColor = computed(() => props.invite?.bg_color || '#fdf7f1')

  // Color principal: la única perilla de "acento" que elige el host — mueve
  // botones, rayitas/anillos decorativos, y el sobre. Las plantillas ya NO
  // hardcodean su propio color; son diseño/tipografía, el color es de acá.
  const primaryColor = computed(() => props.invite?.primary_color || '#9f1239')
  const primaryDark = computed(() => darken(primaryColor.value, 0.28))
  const primaryTint = computed(() => lighten(primaryColor.value, 0.7))
  const primaryLight = computed(() => lighten(primaryColor.value, 0.88))
  const onPrimary = computed(() => contrastText(primaryColor.value))

  // Paleta y sello del sobre: lógica compartida con la vista previa en vivo
  // de AdminSalon (ver src/lib/envelope.js) para no duplicarla en dos lugares.
  const envelopePalette = computed(() =>
    deriveEnvelopePalette(bgColor.value, primaryColor.value, props.invite?.envelope_color),
  )
  const envelopeMonogram = computed(() =>
    deriveEnvelopeMonogram(props.invite?.monogram, heroTitle.value),
  )

  // Secciones que el cliente ocultó desde el editor: las de fotos (por su
  // slot) y además 'musica', 'cuenta' (cuenta regresiva), 'regalos' y
  // 'canciones'. Todo en la misma columna hidden_sections.
  const hiddenSections = computed(() =>
    Array.isArray(props.invite?.hidden_sections) ? props.invite.hidden_sections : [],
  )
  const shows = (slot) => !hiddenSections.value.includes(slot)
  const showGifts = computed(() => !!props.invite?.gift_alias && shows('regalos'))
  // Saludo, frase de cierre y (Ejecutiva) «Invitación personal e intransferible».
  const showIntro = computed(() => shows('saludo'))
  const showClosing = computed(() => shows('cierre'))
  const showFinePrint = computed(() => shows('intransferible'))
  const showSongs = computed(() => props.invite?.plan === 'plus' && shows('canciones'))

  // --- Portada (sobre) + música ---------------------------------------------
  // `entered` = ya se abrió el sobre. En preview arranca abierto para no tapar
  // la edición.
  // El sobre es opcional. Clásica, Partiful y Craft lo traen salvo que lo
  // apaguen ('sobre' en hidden_sections); la Ejecutiva no lo trae salvo que
  // lo prendan ('con-sobre'). Así ninguna invitación existente cambia.
  const useEnvelope = computed(() =>
    props.invite?.template === 'ejecutiva'
      ? hiddenSections.value.includes('con-sobre')
      : !hiddenSections.value.includes('sobre'),
  )
  // Sin sobre, la invitación ya está «abierta» (la música no arranca sola:
  // sin el toque del sobre, el navegador no deja reproducir; queda el botón).
  const entered = ref(props.preview || !useEnvelope.value)
  const musicPlaying = ref(false)
  const ytFrame = ref(null)

  // Animación del sobre: `opening` dispara el flip de la solapa + la carta
  // asomando; `closing` recién arranca el fade del overlay completo un poco
  // después, así el sobre termina de "abrirse" antes de desaparecer.
  // `envelopeGone` saca el overlay del DOM al terminar el fade.
  const opening = ref(false)
  const closing = ref(false)
  const envelopeGone = ref(false)

  // Saca el id del video de cualquier forma de link de YouTube.
  const musicId = computed(() => {
    const url = props.invite?.music_url?.trim()
    if (!url || !shows('musica')) return ''
    const m = url.match(
      /(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([\w-]{11})/,
    )
    return m ? m[1] : /^[\w-]{11}$/.test(url) ? url : ''
  })

  const ytSrc = computed(() =>
    musicId.value
      ? `https://www.youtube.com/embed/${musicId.value}?enablejsapi=1&playsinline=1&controls=0&loop=1&playlist=${musicId.value}&modestbranding=1`
      : '',
  )

  function ytCommand(func) {
    ytFrame.value?.contentWindow?.postMessage(
      JSON.stringify({ event: 'command', func, args: [] }),
      '*',
    )
  }

  function toggleMusic() {
    if (musicPlaying.value) {
      ytCommand('pauseVideo')
      musicPlaying.value = false
    } else {
      ytCommand('playVideo')
      musicPlaying.value = true
    }
  }

  function playMusic() {
    if (!musicId.value) return
    // Reintento por si el iframe todavía no terminó de cargar cuando se toca.
    ytCommand('playVideo')
    setTimeout(() => ytCommand('playVideo'), 400)
    setTimeout(() => ytCommand('playVideo'), 1200)
    musicPlaying.value = true
  }

  // Mientras la portada está arriba, bloqueamos el scroll de la página para que
  // no se pueda "scrollear a ciegas" y aparecer abajo de todo al abrir.
  watch(
    entered,
    (v) => {
      if (typeof document === 'undefined') return
      document.body.style.overflow = v ? '' : 'hidden'
      if (v) window.scrollTo(0, 0)
    },
    { immediate: true },
  )

  // Los carruseles recién arrancan a moverse solos una vez abierto el sobre.
  watch(entered, (v) => {
    if (v) {
      startMomentosAutoplay()
      startSaludoAutoplay()
    } else {
      stopMomentosAutoplay()
      stopSaludoAutoplay()
    }
  })

  const aliasCopied = ref(false)
  async function copyAlias() {
    try {
      await navigator.clipboard.writeText(props.invite.gift_alias)
      aliasCopied.value = true
      setTimeout(() => (aliasCopied.value = false), 1800)
    } catch {
      /* portapapeles bloqueado */
    }
  }

  // --- Pedido de canciones (plan "plus") -------------------------------------
  const songQuery = ref('')
  const songResults = ref([])
  const songSearching = ref(false)
  const songSearchError = ref('')
  const selectedSong = ref(null)
  const songRequesterName = ref('')
  const localSongError = ref('')
  const displaySongError = computed(() => localSongError.value || props.songError)
  // Se prende solo después de un envío exitoso (ver watch de songSubmitting
  // más abajo): a diferencia del RSVP, acá se puede mandar más de una canción,
  // así que no es un estado final sino un cartel temporal entre pedidos.
  const justAddedSong = ref(false)

  let songDebounce = null
  function onSongQueryInput() {
    clearTimeout(songDebounce)
    selectedSong.value = null
    if (songQuery.value.trim().length < 3) {
      songResults.value = []
      songSearchError.value = ''
      return
    }
    songDebounce = setTimeout(runSongSearch, 450)
  }

  async function runSongSearch() {
    const q = songQuery.value.trim()
    if (q.length < 3) return
    songSearching.value = true
    songSearchError.value = ''
    try {
      songResults.value = await searchYoutubeVideos(q)
    } catch {
      songSearchError.value = msg.value.songSearch
    } finally {
      songSearching.value = false
    }
  }

  function selectSong(result) {
    selectedSong.value = result
    songResults.value = []
    songQuery.value = result.title
  }

  function clearSelectedSong() {
    selectedSong.value = null
    songQuery.value = ''
  }

  function submitSong() {
    localSongError.value = ''
    if (props.preview) return
    if (!songRequesterName.value.trim()) {
      localSongError.value = msg.value.songName
      return
    }
    emit('submit-song', {
      songTitle: selectedSong.value.title,
      artist: selectedSong.value.channel,
      youtubeVideoId: selectedSong.value.videoId,
      requestedBy: songRequesterName.value.trim(),
    })
  }

  // Al terminar un envío sin error, mostramos el cartelito de "gracias" y
  // dejamos listo el buscador para la próxima (mantenemos el nombre cargado,
  // es común que la misma persona pida varias canciones seguidas).
  watch(
    () => props.songSubmitting,
    (submitting, wasSubmitting) => {
      if (wasSubmitting && !submitting && !props.songError) {
        justAddedSong.value = true
        songQuery.value = ''
        songResults.value = []
        selectedSong.value = null
      }
    },
  )

  // Tocar el sobre: arranca la música ya (gesto del usuario, para que el
  // autoplay no se bloquee) y encadena la animación de apertura antes de
  // mostrar el contenido de la invitación.
  function openEnvelope() {
    if (opening.value) return
    opening.value = true
    playMusic()
    if (reducedMotion) {
      entered.value = true
      envelopeGone.value = true
      return
    }
    // Con texto en la carta (envelope_text) esperamos más antes del fade: la
    // carta termina de subir a los ~1130ms, y sin esta pausa el overlay se
    // desvanecía antes de que se llegara a leer.
    const delay = props.invite?.envelope_text?.trim() ? 2300 : 950
    setTimeout(() => {
      entered.value = true
    }, delay)
    setTimeout(() => {
      closing.value = true
    }, delay)
  }

  function onEnvelopeFadeEnd() {
    envelopeGone.value = true
  }

  // --- Carrusel --------------------------------------------------------------
  const slide = ref(0)
  let momentosTimer = null

  function goTo(i) {
    const n = momentosFotos.value.length
    slide.value = ((i % n) + n) % n
  }
  function nextSlide() {
    goTo(slide.value + 1)
  }
  function prevSlide() {
    goTo(slide.value - 1)
  }
  function startMomentosAutoplay() {
    if (reducedMotion) return
    stopMomentosAutoplay()
    momentosTimer = setInterval(nextSlide, 3000)
  }
  function stopMomentosAutoplay() {
    if (momentosTimer) {
      clearInterval(momentosTimer)
      momentosTimer = null
    }
  }

  const momentosSwipe = useSwipe({
    next: nextSlide,
    prev: prevSlide,
    pause: stopMomentosAutoplay,
    resume: startMomentosAutoplay,
  })

  // --- Carrusel centrado del saludo (infinito) ------------------------------
  // Repetimos las fotos 3 veces y arrancamos en la copia del medio: así siempre
  // hay fotos asomando a ambos lados. Al llegar a una copia del borde, saltamos
  // sin transición a la posición equivalente del medio.
  const saludoLen = computed(() => saludoFotos.value.length)
  const saludoLoop = computed(() => [
    ...saludoFotos.value,
    ...saludoFotos.value,
    ...saludoFotos.value,
  ])
  const saludoSlide = ref(saludoLen.value)
  const saludoNoTransition = ref(false)
  const saludoActive = computed(() => {
    const n = saludoLen.value
    return n ? ((saludoSlide.value % n) + n) % n : 0
  })

  function saludoStep(delta) {
    saludoSlide.value += delta
  }
  function saludoSet(realIndex) {
    saludoSlide.value = saludoLen.value + realIndex
  }

  let saludoTimer = null
  function startSaludoAutoplay() {
    if (reducedMotion || saludoLen.value < 2) return
    stopSaludoAutoplay()
    saludoTimer = setInterval(() => saludoStep(1), 3000)
  }
  function stopSaludoAutoplay() {
    if (saludoTimer) {
      clearInterval(saludoTimer)
      saludoTimer = null
    }
  }
  function onSaludoTransitionEnd(e) {
    if (e.propertyName !== 'transform' || e.target !== e.currentTarget) return
    const n = saludoLen.value
    if (saludoSlide.value < n || saludoSlide.value >= n * 2) {
      saludoNoTransition.value = true
      saludoSlide.value = n + saludoActive.value
      requestAnimationFrame(() =>
        requestAnimationFrame(() => {
          saludoNoTransition.value = false
        }),
      )
    }
  }
  // Si cambia la cantidad de fotos (se agregan/quitan en el editor), reencuadrar.
  watch(saludoLen, (n) => {
    saludoSlide.value = n + Math.min(saludoActive.value, Math.max(0, n - 1))
  })

  const saludoSwipe = useSwipe({
    next: () => saludoStep(1),
    prev: () => saludoStep(-1),
    pause: stopSaludoAutoplay,
    resume: startSaludoAutoplay,
  })

  // --- Reveal al hacer scroll (directiva local v-reveal) -------------------
  const vReveal = {
    mounted(el) {
      if (reducedMotion || typeof IntersectionObserver === 'undefined') {
        el.classList.add('reveal-in')
        return
      }
      el.classList.add('reveal')
      const io = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              entry.target.classList.add('reveal-in')
              io.unobserve(entry.target)
            }
          })
        },
        { threshold: 0.15 },
      )
      io.observe(el)
      el._revealObserver = io
    },
    unmounted(el) {
      el._revealObserver?.disconnect()
    },
  }

  // --- Galería: las fotos convergen al centro a medida que se scrollea --------
  const gridItems = ref([])
  let gridRaf = null

  function updateGridParallax() {
    if (reducedMotion) return
    const vh = window.innerHeight
    const vw = window.innerWidth
    for (const el of gridItems.value) {
      if (!el) continue
      const r = el.getBoundingClientRect()
      // p: 0 cuando la foto está en el centro vertical de la pantalla, ±1 lejos.
      let p = ((r.top + r.height / 2 - vh / 2) / vh) * 1.7
      p = Math.max(-1, Math.min(1, p))
      const k = Math.abs(p)
      const side = r.left + r.width / 2 < vw / 2 ? -1 : 1
      el.style.transform = `translateX(${(side * k * 44).toFixed(1)}px) scale(${(1 - k * 0.05).toFixed(3)})`
      el.style.opacity = (1 - k * 0.3).toFixed(2)
    }
  }

  function onGridScroll() {
    if (gridRaf) return
    gridRaf = requestAnimationFrame(() => {
      gridRaf = null
      updateGridParallax()
    })
  }

  onMounted(() => {
    clockTimer = setInterval(() => {
      now.value = new Date()
    }, 1000)
    // El autoplay arranca recién cuando se abre el sobre (ver watch de `entered`
    // más arriba), no acá: si arrancara al montar, los carruseles ya llevarían
    // varios pasos avanzados —o el reloj a mitad de ciclo— para cuando el
    // invitado los llega a ver, y el primer cambio se siente errático.
    if (entered.value) {
      startMomentosAutoplay()
      startSaludoAutoplay()
    }
    window.addEventListener('scroll', onGridScroll, { passive: true })
    window.addEventListener('resize', onGridScroll)
    setTimeout(updateGridParallax, 60)
  })

  onUnmounted(() => {
    if (clockTimer) clearInterval(clockTimer)
    stopMomentosAutoplay()
    stopSaludoAutoplay()
    window.removeEventListener('scroll', onGridScroll)
    window.removeEventListener('resize', onGridScroll)
    if (gridRaf) cancelAnimationFrame(gridRaf)
    if (typeof document !== 'undefined') document.body.style.overflow = ''
  })

  // Al cerrar la portada cambia el layout: recalcular posiciones.
  watch(entered, () => setTimeout(updateGridParallax, 60))

  // Cuenta regresiva hasta la fecha/hora del evento.
  const countdown = computed(() => {
    if (!props.invite?.event_date || !shows('cuenta')) return null
    const time = props.invite.reception_time ?? '00:00:00'
    const target = new Date(`${props.invite.event_date}T${time}`)
    const diff = target.getTime() - now.value.getTime()
    if (diff <= 0) return null
    return {
      days: Math.floor(diff / (1000 * 60 * 60 * 24)),
      hours: Math.floor((diff / (1000 * 60 * 60)) % 24),
      minutes: Math.floor((diff / (1000 * 60)) % 60),
      seconds: Math.floor((diff / 1000) % 60),
    }
  })

  const countdownUnits = computed(() => {
    const c = countdown.value
    if (!c) return []
    return [
      { label: 'días', value: c.days },
      { label: 'hs', value: c.hours },
      { label: 'min', value: c.minutes },
      { label: 'seg', value: c.seconds },
    ]
  })

  function addName() {
    if (names.value.length < props.invite.allowed_guests) {
      names.value.push('')
      details.value.push(detailsOf())
    }
  }

  function removeName(i) {
    names.value.splice(i, 1)
    details.value.splice(i, 1)
  }

  // --- Datos extra al confirmar -------------------------------------------------
  const rsvpFields = computed(() =>
    (Array.isArray(props.invite?.rsvp_fields) ? props.invite.rsvp_fields : [])
      .filter((key) => RSVP_FIELDS[key])
      .map((key) => {
        const f = RSVP_FIELDS[key]
        const en = lang.value === 'en'
        return { key, ...f, label: en ? f.labelEn : f.label, placeholder: en ? f.placeholderEn : f.placeholder }
      }),
  )

  // Solo los datos que pide el evento, sin espacios de más.
  const pick = (row) => Object.fromEntries(rsvpFields.value.map(({ key }) => [key, (row?.[key] ?? '').trim()]))

  // Primer dato que falta o está mal, con el nombre de la persona, o ''.
  function detailsError(row, who) {
    for (const f of rsvpFields.value) {
      const v = (row?.[f.key] ?? '').trim()
      if (f.required && !v) return msg.value.missing(f.label, who)
      if (f.key === 'email' && v && !EMAIL_RE.test(v)) return msg.value.email(who)
    }
    return ''
  }

  // Fecha límite para confirmar. `rsvpDeadlinePassed`: ya pasó (hoy en
  // Argentina es posterior a la fecha). `rsvpClosed`: además el evento
  // eligió cerrar las confirmaciones — el servidor rechaza respuestas nuevas,
  // así que se oculta el formulario. Si solo es informativa, al pasar la
  // fecha se deja de mostrar «Confirmá antes del…» y se puede responder igual.
  const todayAR = () =>
    new Date().toLocaleDateString('en-CA', { timeZone: 'America/Argentina/Buenos_Aires' })
  const rsvpDeadlinePassed = computed(
    () => !!props.invite.rsvp_deadline && todayAR() > props.invite.rsvp_deadline,
  )
  const rsvpClosed = computed(
    () => props.invite.rsvp_closed ?? (!!props.invite.rsvp_deadline_strict && rsvpDeadlinePassed.value),
  )

  function formatDate(isoDate) {
    if (!isoDate) return ''
    const [year, month, day] = isoDate.split('-')
    return `${day}/${month}/${year}`
  }

  function formatDateLong(isoDate) {
    if (!isoDate) return ''
    const [y, m, d] = isoDate.split('-').map(Number)
    try {
      const s = new Date(y, m - 1, d).toLocaleDateString('es-AR', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      })
      return s.charAt(0).toUpperCase() + s.slice(1)
    } catch {
      return formatDate(isoDate)
    }
  }

  function formatTime(time) {
    if (!time) return ''
    return time.slice(0, 5)
  }

  function confirmarGenerico() {
    localError.value = ''
    if (props.preview) return
    const hasBlank = names.value.some((n) => n.trim() === '')
    if (hasBlank) {
      localError.value = msg.value.names
      return
    }
    // Sin datos extra pedidos: igual que siempre (solo los nombres).
    if (!rsvpFields.value.length) {
      emit('submit-generic', names.value.map((n) => n.trim()))
      return
    }
    for (let i = 0; i < names.value.length; i++) {
      const err = detailsError(details.value[i], names.value.length > 1 ? names.value[i].trim() : '')
      if (err) return void (localError.value = err)
    }
    emit(
      'submit-generic',
      names.value.map((n) => n.trim()),
      details.value.slice(0, names.value.length).map(pick),
    )
  }

  function declinarGenerico() {
    localError.value = ''
    if (props.preview) return
    emit('submit-generic', [])
  }

  function enviarRespuestasNominales() {
    localError.value = ''
    if (props.preview) return
    // Los datos extra se piden solo a quienes asisten.
    const many = namedGuests.value.filter((g) => g.attending).length > 1
    for (const g of namedGuests.value) {
      if (!g.attending) continue
      const err = detailsError(g, many ? g.full_name : '')
      if (err) return void (localError.value = err)
    }
    emit(
      'submit-named',
      namedGuests.value.map((g) => ({
        id: g.id,
        attending: g.attending,
        ...(g.attending && rsvpFields.value.length ? pick(g) : {}),
      })),
    )
  }

  return {
    now,
    lang,
    names,
    details,
    rsvpFields,
    namedGuests,
    localError,
    displayError,
    slotUrls,
    bannerFoto,
    detalleFoto,
    saludoFotos,
    momentosFotos,
    galeriaGrid,
    reducedMotion,
    defaultIntro,
    defaultClosing,
    heroTitle,
    bgColor,
    primaryColor,
    primaryDark,
    primaryTint,
    primaryLight,
    onPrimary,
    envelopePalette,
    envelopeMonogram,
    hiddenSections,
    shows,
    useEnvelope,
    showGifts,
    showSongs,
    showIntro,
    showClosing,
    showFinePrint,
    entered,
    musicPlaying,
    ytFrame,
    opening,
    closing,
    envelopeGone,
    musicId,
    ytSrc,
    toggleMusic,
    openEnvelope,
    onEnvelopeFadeEnd,
    aliasCopied,
    copyAlias,
    songQuery,
    songResults,
    songSearching,
    songSearchError,
    selectedSong,
    songRequesterName,
    displaySongError,
    justAddedSong,
    onSongQueryInput,
    selectSong,
    clearSelectedSong,
    submitSong,
    slide,
    goTo,
    nextSlide,
    prevSlide,
    startMomentosAutoplay,
    stopMomentosAutoplay,
    onTouchStart: momentosSwipe.onStart,
    onTouchMove: momentosSwipe.onMove,
    onTouchEnd: momentosSwipe.onEnd,
    momentosDrag: momentosSwipe.offset,
    momentosDragging: momentosSwipe.dragging,
    saludoLen,
    saludoLoop,
    saludoSlide,
    saludoNoTransition,
    saludoActive,
    saludoStep,
    saludoSet,
    startSaludoAutoplay,
    stopSaludoAutoplay,
    onSaludoTransitionEnd,
    onSaludoTouchStart: saludoSwipe.onStart,
    onSaludoTouchMove: saludoSwipe.onMove,
    onSaludoTouchEnd: saludoSwipe.onEnd,
    saludoDrag: saludoSwipe.offset,
    saludoDragging: saludoSwipe.dragging,
    vReveal,
    gridItems,
    countdown,
    countdownUnits,
    addName,
    removeName,
    formatDate,
    formatDateLong,
    formatTime,
    rsvpDeadlinePassed,
    rsvpClosed,
    confirmarGenerico,
    declinarGenerico,
    enviarRespuestasNominales,
  }
}

// Deslizar en los carruseles: la foto sigue al dedo mientras se arrastra
// (`offset` en px, para sumar al translateX del track) y al soltar pasa de
// foto si se arrastró más de 40px O si fue un "flick" rápido aunque corto
// (velocidad > 0.11 px/ms). Dirección natural del celular: deslizar a la
// izquierda = siguiente. Si el gesto arranca vertical se ignora, para no
// trabar el scroll de la página (el track además usa touch-action: pan-y).
function useSwipe({ next, prev, pause, resume }) {
  const offset = ref(0)
  const dragging = ref(false)
  let x0 = 0
  let y0 = 0
  let t0 = 0
  let axis = null

  function onStart(e) {
    const t = e.changedTouches[0]
    x0 = t.clientX
    y0 = t.clientY
    t0 = Date.now()
    axis = null
    pause()
  }
  function onMove(e) {
    const t = e.changedTouches[0]
    const dx = t.clientX - x0
    const dy = t.clientY - y0
    if (!axis) {
      if (Math.abs(dx) < 6 && Math.abs(dy) < 6) return
      axis = Math.abs(dx) > Math.abs(dy) ? 'x' : 'y'
    }
    if (axis !== 'x') return
    dragging.value = true
    offset.value = dx
  }
  function onEnd(e) {
    const dx = e.changedTouches[0].clientX - x0
    const velocity = Math.abs(dx) / Math.max(1, Date.now() - t0)
    const horizontal = axis !== 'y'
    dragging.value = false
    offset.value = 0
    if (horizontal && (Math.abs(dx) > 40 || (velocity > 0.11 && Math.abs(dx) > 10))) {
      if (dx < 0) next()
      else prev()
    }
    resume()
  }

  return { offset, dragging, onStart, onMove, onEnd }
}
