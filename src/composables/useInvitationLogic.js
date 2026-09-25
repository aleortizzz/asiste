import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { searchYoutubeVideos } from '../lib/youtube'

// Toda la lógica de la invitación pública, compartida entre las distintas
// plantillas visuales (ver src/components/invitation-templates/). Cada
// plantilla solo define su propio <template>/<style> y llama a esto para
// obtener el mismo comportamiento: RSVP, countdown, carruseles, sobre +
// música, pedido de canciones, galería con parallax, etc. Así agregar una
// plantilla nueva no implica reescribir ni duplicar toda esta lógica.
export function useInvitationLogic(props, emit) {
  const now = ref(new Date())
  let clockTimer = null

  // Modo "genérico" (sin nombres precargados): la familia tipea los nombres.
  const names = ref([''])
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
        }))
      } else if (data.guests?.length) {
        names.value = data.guests.map((g) => g.full_name)
      } else {
        names.value = ['']
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

  // Textos del hero/saludo/cierre: los define cada evento desde el admin.
  const defaultIntro =
    'Hay días que quedan guardados para siempre en el corazón. Nos encantaría compartir este con ustedes.'
  const heroTitle = computed(
    () => props.invite?.hero_title || props.invite?.event_name || 'Nuestro festejo',
  )
  const bgColor = computed(() => props.invite?.bg_color || '#fdf7f1')

  // Sello del sobre: si el host cargó algo en "monogram" desde el editor, se
  // usa tal cual (tope de 3 caracteres — por si el input del navegador no
  // llegó a frenarlo, o vino de otro lado). Si lo dejó vacío, se arma solo a
  // partir de heroTitle: "Sofía & Juan" -> letra de cada lado ("S & J" en la
  // carta, "SJ" en el sello chico); "Antonella" -> "A" en los dos. Esto es a
  // propósito un fallback razonable, no una regla infalible — por eso existe
  // el campo manual, para cuando el texto principal no son nombres de gente
  // (ej. "Fiesta de fin de año").
  const envelopeMonogram = computed(() => {
    const custom = (props.invite?.monogram || '').trim()
    if (custom) {
      const capped = [...custom].slice(0, 3).join('')
      return { short: capped, full: capped }
    }
    const t = (heroTitle.value || '').trim()
    if (!t) return { short: '✦', full: '✦' }
    const byAmp = t.split('&').map((s) => s.trim()).filter(Boolean)
    let initials
    if (byAmp.length >= 2) {
      initials = byAmp.slice(0, 2).map((p) => p[0]?.toUpperCase()).filter(Boolean)
    } else {
      const words = t.split(/\s+/).filter(Boolean)
      initials = words.length >= 2
        ? [words[0][0]?.toUpperCase(), words[1][0]?.toUpperCase()].filter(Boolean)
        : words[0]
          ? [words[0][0].toUpperCase()]
          : []
    }
    if (!initials.length) return { short: '✦', full: '✦' }
    return {
      short: initials.join(''),
      full: initials.length >= 2 ? initials.join(' & ') : initials[0],
    }
  })

  // Secciones de fotos que el cliente ocultó desde el editor.
  const hiddenSections = computed(() =>
    Array.isArray(props.invite?.hidden_sections) ? props.invite.hidden_sections : [],
  )
  const shows = (slot) => !hiddenSections.value.includes(slot)

  // --- Portada (sobre) + música ---------------------------------------------
  // `entered` = ya se abrió el sobre. En preview arranca abierto para no tapar
  // la edición.
  const entered = ref(props.preview)
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
    if (!url) return ''
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
      songSearchError.value = 'No pudimos buscar canciones ahora, probá de nuevo.'
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
      localSongError.value = 'Nos falta tu nombre para saber quién la pidió.'
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
    setTimeout(() => {
      entered.value = true
    }, 950)
    setTimeout(() => {
      closing.value = true
    }, 950)
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

  let touchX = 0
  function onTouchStart(e) {
    touchX = e.changedTouches[0].clientX
    stopMomentosAutoplay()
  }
  function onTouchEnd(e) {
    const dx = e.changedTouches[0].clientX - touchX
    if (dx > 40) nextSlide()
    else if (dx < -40) prevSlide()
    startMomentosAutoplay()
  }

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

  let saludoTouchX = 0
  function onSaludoTouchStart(e) {
    saludoTouchX = e.changedTouches[0].clientX
    stopSaludoAutoplay()
  }
  function onSaludoTouchEnd(e) {
    const dx = e.changedTouches[0].clientX - saludoTouchX
    if (dx > 40) saludoStep(1)
    else if (dx < -40) saludoStep(-1)
    startSaludoAutoplay()
  }

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

  function scrollToRsvp() {
    document
      .getElementById('rsvp')
      ?.scrollIntoView({ behavior: reducedMotion ? 'auto' : 'smooth', block: 'start' })
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
    if (!props.invite?.event_date) return null
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
    }
  }

  function removeName(i) {
    names.value.splice(i, 1)
  }

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
      localError.value = 'Completá el nombre en todos los campos, o quitá los que no vayas a usar.'
      return
    }
    emit('submit-generic', names.value.map((n) => n.trim()))
  }

  function declinarGenerico() {
    localError.value = ''
    if (props.preview) return
    emit('submit-generic', [])
  }

  function enviarRespuestasNominales() {
    localError.value = ''
    if (props.preview) return
    emit(
      'submit-named',
      namedGuests.value.map((g) => ({ id: g.id, attending: g.attending })),
    )
  }

  return {
    now,
    names,
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
    heroTitle,
    bgColor,
    envelopeMonogram,
    hiddenSections,
    shows,
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
    onTouchStart,
    onTouchEnd,
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
    onSaludoTouchStart,
    onSaludoTouchEnd,
    vReveal,
    scrollToRsvp,
    gridItems,
    countdown,
    countdownUnits,
    addName,
    removeName,
    formatDate,
    formatDateLong,
    formatTime,
    confirmarGenerico,
    declinarGenerico,
    enviarRespuestasNominales,
  }
}
