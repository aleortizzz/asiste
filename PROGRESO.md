# Asiste — seguimiento del proyecto

App de invitaciones digitales con panel de administrador. Caso de uso inicial: los XV de Antonella (hermana del usuario), **sábado 31 de octubre de 2026**. Después se piensa comercializar como producto de TizDigital (ya es multi-cliente: registro público, planes y superadmin).

Plan original (modelo de datos, rutas, roadmap): `C:\Users\aleor\.claude\plans\polished-stirring-pie.md` (en la otra compu).

Modo de trabajo: **aprender haciendo** — explicar el porqué de cada decisión, no solo tirar código hecho. El usuario viene de HTML/CSS/Tailwind fuerte, está aprendiendo JS/Vue. El usuario prueba cada cosa y recién ahí pide commit/push.

_Última actualización: 2026-10-12._

## Stack

- Vue 3 (Composition API, `<script setup>`) + Vite + Tailwind v4 (`@tailwindcss/vite`) + Vue Router + `@supabase/supabase-js`. Sin Pinia: composables singleton (`useAuth`, `useEvent`, `useConfirm`).
- Íconos: `@lucide/vue`. Exportaciones: `jspdf` + `jspdf-autotable`, `write-excel-file`, `qrcode`, `fflate` (todas se cargan con `import()` recién cuando se usan, salvo `qrcode`).
- Backend: Supabase (proyecto "asiste"): Postgres con RLS, Auth, Storage (buckets `event-photos` y `guest-uploads`).
- Hosting: Hostinger (Business), subdominio `asiste.tizdigital.com`, con PHP (se usa para la vista previa de links).
- Repo: `https://github.com/aleortizzz/asiste` (privado).

## Qué hace hoy

### Invitación pública (`/i/:slug`, un link por familia)
- Cuatro plantillas: **Clásica, Partiful, Craft y Ejecutiva** (`src/components/invitation-templates/`), elegidas en el editor. Color principal elegido por el anfitrión; las plantillas derivan tints/shades (`src/lib/color.js`).
- **Ejecutiva** (eventos empresariales; se elige sola al tocar «Empresarial»): tarjeta formal con marco doble, Cormorant Garamond + Inter, sin sobre. 4 paletas (`primary_color` profundo + `accent_color` + papel), claro/oscuro (`theme_mode`), tono usted/vos (`tono`, todas las frases sin género y en plural si la invitación es para varias personas), fecha destacada/discreta/regresiva (`date_style`), logo + sponsors (con «Mostrar en blanco» y tamaño parejo por superficie). Ninguna imagen se recorta (carrusel `EjecutivaCarousel.vue` con foto entera + relleno desenfocado; galería en columnas). Nunca muestra las fotos de demo.
- **Agregar al calendario** (`src/lib/calendar.js`, por ahora solo en la Ejecutiva): Google Calendar (popup en compu) y .ics (ventanita nativa en iPhone). Horas en UTC a partir de hora argentina.
- Sin botón «Confirmar asistencia» en la portada de ninguna plantilla: llevaba al final y la gente se salteaba la invitación.
- Sobre animado como portada (texto de la carta, color y sello/monograma editables), música de YouTube, cuenta regresiva, carruseles y galería de fotos, datos del salón (horario, mapa, vestimenta, alias de regalos, notas).
- RSVP: flujo genérico (la familia escribe los nombres) o con nombres precargados (Asiste / No asiste por persona). Todo vía RPC `security definer` (`obtener_invitacion`, `confirmar_asistencia`, `responder_invitados`): nadie puede listar las familias de un evento.
- Fecha límite de confirmación **orientativa o de cierre** (`rsvp_deadline_strict`; si es de cierre, un trigger rechaza respuestas vencidas).
- Pedido de canciones para el DJ (solo plan **Plus**, validado también en la base).
- **Vista previa al compartir por WhatsApp**: «Antonella · Mi invitación», «Para Familia X · sábado 31 de octubre…» y la portada. Ver «Vista previa de links» abajo.

### Panel admin (`/admin`, barra lateral en `AdminNav.vue`)
- **Inicio**: resumen de respuestas, checklist de la invitación, actividad reciente; **Movimientos** (`/admin/actividad`) con el historial `rsvp_log`.
- **Creá tu invitación** (`AdminSalon.vue`): editor por pasos (el paso Sobre se oculta con la Ejecutiva; logos se recortan solos al subir, `lib/trimImage.js`) con vista previa en vivo (tipo de evento: cumpleaños / casamiento / empresarial; plantilla, colores, textos, sobre, fotos por sección, datos del salón, fecha límite).
- **Invitados** (una sola pantalla): crear invitaciones (cantidad o con nombres), persona sin link, copiar link, editar mientras no respondieron, eliminar, corregir respuestas, filtros y buscador, cupo del evento (`guest_limit`) que se libera con las cancelaciones, «entró hoy a las…» (`invitation_views`).
- **Invitaciones sorpresa** (solo superadmin, ícono del ojo en Invitados): la cuenta del evento no las ve en ningún lado (RLS: invitados, actividad, canciones, lista de la entrada). En Mesas figuran como «N lugares reservados», sin nombres (RPC `lugares_reservados`). Caso: Familia Salto Ruiz, sorpresa para Anto. La lista de la entrada con ellos la tiene que exportar el superadmin.
- **Mesas** (una sola pantalla): crear una o varias mesas de una, editar/eliminar, columna «Sin mesa» con los confirmados; sentar tocando personas + «Sentar acá», o **arrastrando** (una persona, la selección o la familia entera). Tope de capacidad al sentar y al achicar una mesa.
- **Exportar lista para la entrada** (en Invitados y Mesas): confirmados con su mesa y casillero de llegada, ordenados por nombre o por mesa, en **PDF** o **Excel**.
- **Fotos del evento**:
  - **Cartel «¡Sacá tus fotos!»** para las mesas (`src/lib/photoCard.js`): A5 dibujado en canvas con foto tipo polaroid elegible, QR, pasos y el color de la invitación; vista previa en el panel, descarga en PDF (2 por A4) o PNG a 300 dpi. El QR se genera en el navegador y no vence: apunta a `/fotos/<id del evento>`.
  - Galería: recientes / más votadas, se actualiza sola cada 30 s, visor a pantalla completa, selección múltiple para descargar o borrar, «Descargar todas» en .zip. Tope de 500 fotos por evento.
- **Canciones**: pedidos de los invitados (plan Plus), del más reciente al más viejo, con buscador y miniatura de YouTube. «Lista para el DJ»: copiar (para WhatsApp), PDF o Excel.
- **Superadmin** («Clientes»): todos los eventos con filtro por plan, cuánto falta para cada uno, selector Básico | Plus y «Entrar» al panel de un cliente (cartel amarillo arriba).
- Ingresar / Registro público (`/admin/registro`) / recuperar y nueva contraseña: foto de fiesta a pantalla completa al azar (`public/fondos/`: `pc-N` horizontales para compu, `cel-N` verticales para celular; lista en `AuthLayout.vue`). Validación propia por campo (`useFormValidation.js` + `FormField.vue`) y errores de Supabase traducidos (`lib/authErrors.js`).

### Página de fotos para invitados (`/fotos/:eventId`, la del QR)
Sin login. Toma el estilo de la invitación (plantilla, color, nombre) vía `info_fotos_evento` y permite subir (el navegador comprime cada foto antes), dar like y descargar.

## Deploy (automático)

Cada `git push` a `main` dispara `.github/workflows/deploy.yml`: `npm ci` → `npm run build` → genera `dist/og-config.php` → sube `dist/` por FTPS con **lftp** (config conservadora: una conexión, PASV, reintentos; el FTP de Hostinger corta la conexión seguido).

- Secrets en GitHub: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_YOUTUBE_API_KEY`, `FTP_SERVER`, `FTP_USERNAME`, `FTP_PASSWORD` y `SUPA_*` (para el backup).
- **Cuenta FTP dedicada** (`u452496377.asiste`), con raíz directo en `.../domains/tizdigital.com/public_html/asiste`. La cuenta FTP "genérica" del hosting **no** está conectada a ese sitio: ningún `server-dir` funcionaba con ella.
- `public/.htaccess`: fallback de SPA a `index.html` + reglas de la vista previa de links.
- Otros workflows: `keepalive.yml` (evita que Supabase pause el proyecto por inactividad) y `backup.yml` (pg_dump diario al repo privado `tizdigital-backups`).
- **Sitio en blanco o sin estilos después de un deploy** (pasó tres veces, la última el 2026-10-11): el index.html nuevo pedía un .js/.css que en ese momento no estaba (todavía subiendo, o re-subiéndose), el servidor respondía con la página y el CDN (Cloudflare, cuenta propia, y en ese momento también el hCDN de Hostinger) guardaba esa respuesta 4 h con el nombre del archivo. Arreglo: todos los archivos de `assets/` llevan una marca única por build (`vite.config.js`), el deploy sube `assets/` primero y sin re-subir lo que ya está (`--ignore-time`), y `.htaccess` da 404 en vez de la página para un asset que no existe. Si igual pasa: Cloudflare → Caching → Purge Everything.
- **HTTP 429 en todo tizdigital.com** (2026-10-11, 17:44–17:48; también dos el 8/10): lo cortó el hCDN de Hostinger con el servidor en cero. Causa probable: **dos CDN en cadena** (Cloudflare con nube naranja → hCDN → servidor); el hCDN veía todo el tráfico llegar desde pocas IPs de Cloudflare. **Arreglado el 2026-10-12**: en Cloudflare, tizdigital.com, www, asiste, gstock, portfolio y pruebas pasaron a un registro **A → 147.93.39.226** (Proxied), sin los AAAA ni los CNAME a `*.cdn.hstgr.net`, y el soporte desactivó el hCDN para esos sitios. Ahora la única CDN es Cloudflare (verificar: `curl -sIL https://asiste.tizdigital.com` no tiene que traer `x-hcdn-cache-status`). Quedan con el hCDN, a propósito por ahora: **website-jc** (doble CDN igual que antes: para arreglarlo, primero su registro en Cloudflare y después pedir que apaguen el hCDN) y **sinfila** (DNS only, va directo al servidor).

### Vista previa de links (WhatsApp, Telegram, etc.)
Esos robots no ejecutan JS, así que `.htaccess` manda **solo a los robots** (por User-Agent) a `public/og.php`, que agrega título, descripción y foto al `index.html`. La foto pasa por `og-image.php` (recorte 1200×630 en JPG liviano, con caché en `og-cache/`). Usa las RPC de solo lectura `vista_previa_invitacion` / `vista_previa_fotos` — **no** `obtener_invitacion`, que registra una visita. Las personas reciben la app directo. WhatsApp cachea la vista previa por link: para probar cambios, agregar `?v=2` al link.

## Base de datos y migraciones

- `supabase/schema.sql`: el esquema completo al día. `supabase/migrations/`: cada cambio con fecha, para correr en orden.
- Se corren **pegando el archivo en Supabase → SQL Editor** (proyecto "asiste"). Alternativa: `run-sql.mjs` / `query.mjs` (en `.gitignore`) con las variables `SUPA_HOST`, `SUPA_PORT`, `SUPA_USER`, `SUPA_PASSWORD`.
- Tablas: `events`, `tables`, `invitation_groups` (un link = un grupo/familia), `guests` (la mesa se asigna por persona: `guests.table_id`), `invitation_views`, `rsvp_log`, `event_photos`, `song_requests`, `superadmins`.

### Aprendizajes que conviene no olvidar
- **GRANT**: las tablas creadas por SQL no les dan permisos a `authenticated`. Sin `grant select/insert/update/delete ... to authenticated` da "permission denied" aunque las policies de RLS estén bien.
- **Funciones `language sql`**: nombrar las tablas con schema (`public.events`). Postgres valida el cuerpo al crearlas y en el SQL Editor da «relation does not exist» aunque la función tenga `set search_path = public`.
- **Cambiar parámetros de una RPC** crea una sobrecarga nueva: hay que hacer `drop function` de la firma vieja antes de recrearla.
- Lo público va siempre por RPC `security definer` que devuelve solo lo necesario, nunca con policies abiertas sobre las tablas.

## Próximos pasos

Plan de la invitación empresarial (acordado el 2026-10-02; la Parte 1, plantilla Ejecutiva, está hecha):
- [x] Parte 2 · Secciones opcionales en todas las plantillas: interruptores para cuenta regresiva, música, regalos, canciones, saludo, cierre y (Ejecutiva) «personal e intransferible». Van en `hidden_sections` (`shows()` / `showGifts` / `showSongs`… en useInvitationLogic). Saludo y cierre vacíos usan textos de ejemplo según el tipo de evento.
- [x] Parte 4 · Secciones empresariales (Ejecutiva): programa (`agenda`, paso «Programa»), acceso y estacionamiento (`access_info`), vestimenta con opciones, contacto del organizador (mail/WhatsApp) y redes (`social_links`), en el paso «Contacto». Todo apagable (`hidden_sections`: agenda, acceso, contacto, redes) y oculto si está vacío. Quedaron afuera por decisión: oradores, cupo visible, PDF y hashtag. `supabase/herramientas/ejemplo-empresarial.sql` carga contenido de ejemplo en un evento.
- [x] Parte 5 (invitado) · Confirmación completa en la Ejecutiva: el evento elige qué pedir (`events.rsvp_fields`: empresa, cargo, mail, teléfono, restricciones) y se guarda por invitado (`guests.company`, `job_title`, `email`, `phone`, `dietary`). `confirmar_asistencia` suma `p_detalles` (opcional) y `responder_invitados` acepta los datos en cada respuesta. Acompañante = 2 lugares en la invitación. En Invitados se ven los datos debajo del nombre.
- [x] Parte 5 (panel) · Palabras según el tipo de evento (`composables/useWording.js`: «invitación/empresa» en empresariales, «familia» en el resto) en Inicio, Invitados, Mesas y Movimientos. Lista de la entrada con los datos extra: empresa y cargo en el PDF; todo en el Excel (solo columnas con datos).
- [x] Parte 6 · Bilingüe ES/EN en la Ejecutiva (`bilingual`, `texts_en`): botón ES | EN (arranca en inglés si el teléfono está en inglés), textos fijos traducidos solos y los principales escritos por el organizador. Programa, notas y acceso se muestran como se escribieron.
- [x] Extras: 8 paletas bien distintas (también en claro), líneas finas que se ven en la vista previa achicada (`--hair`), pie con logo + redes separado de los sponsors, sobre opcional en todas las plantillas (`useEnvelope`: 'sobre' / 'con-sobre' en hidden_sections; sin sobre la música no arranca sola).
- [x] Parte 7 · Vista previa de WhatsApp para la Ejecutiva: «Título · Invitación», «Para X · fecha, hora · lugar» y, si hay logo, una tarjeta 1200×630 con el logo sobre el color de la invitación (`og-image.php?k=logo`, cacheada en og-cache/). Se probó con PHP portable contra datos reales.
- [ ] **Al final, junto con los 15** · Parte 3: itinerario y «Agregar al calendario» en Clásica, Partiful y Craft (`lib/calendar.js` ya está hecho; la Ejecutiva ya lo tiene). Prioridad ahora: terminar la empresarial para Cinthia.

### Hito · Trivia en la fiesta (acordado el 2026-10-11)

Durante la comida se anuncia con el micrófono: escaneando el QR de la mesa aparece un botón «Jugar» en la página de fotos. Preguntas de multiple choice armadas por Anto (20–30), tiempo máximo (ej. 5 min). Gana quien más acierta; si empatan, quien tardó menos. Al enviar se ve el top en vivo.

Decisiones:
- **Lo abre Anto en vivo**: el juego tiene estado `borrador → abierto → cerrado`, con botones en el panel. Antes de abrirlo el botón no aparece en `/fotos`.
- **Una pregunta por pantalla, con verde / rojo al responder** (cambiado el 2026-10-12; antes era sin feedback): el servidor dice si acertó y la respuesta **queda fija** (si no, se probarían opciones hasta que dé verde). Si erró, no se muestra cuál era la correcta. Al final, «Enviar», o se envía sola cuando se acaba el tiempo.
- **«Ver mis respuestas» recién cuando se cierra el juego**: mientras está abierto, el resultado dice «Te vamos a mostrar tus respuestas cuando termine el juego» (mostrar rojos sin la correcta al lado parecía «todo mal»). Cerrado: cada pregunta con bien / mal, lo que eligió y la correcta de las que erró.
- **Ranking solo en el celular** (sin pantalla para proyector).
- **El tiempo lo mide el servidor**, no el celular: `empezar_juego` guarda la hora de inicio y `enviar_juego` calcula puntaje y duración. Las respuestas correctas nunca viajan al navegador mientras el juego está abierto (si no, se podrían ver con las herramientas del navegador).
- **Un intento por celular**: el navegador guarda un token del intento (localStorage). Si se cierra la página o se queda sin batería, vuelve y sigue donde estaba, con el reloj que siguió corriendo. Anto puede borrar un intento sospechoso desde el panel.
- **Ranking «en vivo» por consulta cada ~5 s** (como la galería), no con Supabase Realtime: Realtime pediría abrir la tabla a `anon`, y lo público va siempre por RPC.

Pasos:
- [x] **1 · Base de datos** (`migrations/20261011_trivia.sql`): `trivia_games` (uno por evento: título, tiempo límite, estado), `trivia_questions` (2 a 4 opciones + índice de la correcta) y `trivia_attempts` (nombre, token, respuestas, aciertos, duración). El panel usa las tablas con RLS; los invitados, RPC: `info_juego` (estado, sin preguntas), `empezar_juego` (recién ahí manda las preguntas, **sin** la correcta), `mi_intento_juego` (retomar), `responder_pregunta` (guarda cada respuesta al elegirla), `enviar_juego` y `ranking_juego` (top 10 + mi puesto; cerrado, también mis correctas). Fuera de tiempo (+15 s de gracia) se corrige con lo ya guardado; al cerrar el juego, un trigger corrige a los que estaban jugando. Probado con PGlite (36 casos).
- [x] **2 · Panel: armar las preguntas** (`AdminJuego.vue` + `components/trivia/QuestionEditor.vue`, ítem «Juego» en la barra lateral): título (por defecto «¿Cuánto conocés a {hero_title}?») y tiempo, que se guardan solos; agregar de corrido («Guardar y agregar otra»), editar y borrar preguntas con 2 a 4 opciones y la correcta marcada. El juego se crea en la base recién con el primer cambio. La vista previa del invitado queda para cuando exista la pantalla del juego (paso 5).
- [x] **3 · Panel: en vivo** (`components/trivia/TriviaLive.vue`): Abrir / Cerrar (avisa cuántos siguen jugando, que se corrigen con lo que llevan) / Reabrir, «N terminaron · N jugando ahora», ranking completo con aciertos y tiempo (m:ss,d), borrar un intento y «Reiniciar» (borra intentos y vuelve a «sin abrir»; para probar antes de la fiesta). Se actualiza cada 5 s mientras está abierto.
- [x] **4 · Invitados: botón en `/fotos`**: tarjeta con el título del juego debajo del encabezado, solo con el juego abierto (o cerrado si se jugó desde ese celular: «Ver los resultados»). Se revisa con el refresco de 20 s de la galería. El estilo por plantilla pasó a `composables/useGuestTheme.js` (fotos y juego).
- [x] **5 · Invitados: jugar** (`views/GuestTrivia.vue`, `/juego/:eventId`): espera («todavía no empezó», pasa sola al inicio cuando se abre), inicio (nombre precargado del de fotos + reglas), una pregunta por pantalla con reloj (rojo los últimos 30 s) y barra de progreso, pasa sola a la próxima sin responder, Anterior/Siguiente para cambiar, resumen con las que faltan y «Enviar»; envío automático en 0. Preguntas y opciones mezcladas por invitado (`seededShuffle` con el token: distinto para cada uno, igual si recarga). Reloj con la hora del servidor (corrige el desfase del celular). Si se recarga, sigue donde estaba; si lo borran desde el panel, «Tu partida ya no está».
- [x] **6 · Invitados: resultado y top en vivo**: «X/30 correctas en m:ss,d · Vas N.º de M», top 10 que se actualiza cada 5 s (mi fila resaltada, y si no estoy en el top, abajo aparte). Cerrado: «¡Ganaste!» o el ganador destacado, y «Tus respuestas» con la correcta y la mía tachada si le erré.
- [x] **6b · Feedback** (`migrations/20261012_trivia_feedback.sql`): `responder_pregunta` devuelve `{ ok, correct }` y no deja cambiar una respuesta; `enviar_juego` ya no pisa lo guardado; `mi_intento_juego` trae `results` (colores al recargar); `ranking_juego` trae `review` apenas se envía (`is_correct`, `chosen`; `correct_index` solo cerrado). En la pantalla: borde verde / rojo con «¡Correcto!» / «Incorrecto», números del resumen en verde / rojo y hoja «Ver mis respuestas» (solo con el juego cerrado). Probado con PGlite (14 casos).
- [ ] **7 · Prueba de punta a punta** con varios celulares a la vez (empates, se acaba el tiempo, cerrar la pestaña a la mitad, juego cerrado mientras alguien juega).
  - [x] En familia con 4–5 celulares (2026-10-12): anduvo bien.
  - [x] **Prueba de carga** (2026-10-12, script de Node con la clave pública contra el juego de Antonella, 30 preguntas): 300 jugadores entrando en 20 s, 12.964 llamadas en 3,5 min, pico de ~85 pedidos/s, **0 errores**, mediana ~185 ms y p95 ~220 ms en todas las RPC (casi todo es la latencia de red; no subió con la carga). Para 110–120 invitados sobra margen. El script no se guardó.
  - [x] Demo en vivo con los 103 confirmados jugando al azar, para ver el proyector y el festejo.
  - [ ] Jugar una partida con Chrome en «Slow 3G» y cortar la conexión a la mitad. Ojo: cada respuesta espera al servidor antes de pasar a la próxima, así que con muy mala señal se pierde tiempo en cada pregunta (cuenta para el desempate). Si molesta: avanzar enseguida y pintar el color cuando llegue la respuesta.
  - [ ] Revisar la señal de datos móviles adentro del salón (los invitados juegan con sus datos, no con WiFi).
  - [ ] Antes del 31: «Reiniciar» y dejar el juego cerrado.
- [ ] (A decidir para cuando se venda) ¿El juego es del plan Plus como las canciones?

### Hito · Comercializar: salones (B2B) y particulares (B2C) (acordado el 2026-10-12)

Hay una reunión con el salón de los 15 unos días antes del 31/10 para ofrecerles el sistema. Orden acordado:
- [ ] **1 · Recepción en vivo** (para usarla el 31 y mostrarla funcionando): el personal del salón entra con **usuario y contraseña**, busca al invitado, ve su mesa y marca «Llegó»; la familia ve las llegadas en vivo desde el panel. Las sorpresas aparecen con nombre en Recepción (también en el panel del dueño: el día del evento lo mira la familia, no Anto); en Invitados, Mesas, etc. siguen ocultas. **Hecho el código (2026-10-12), falta correr la migración y probarlo:**
  - Base (`migrations/20261012_recepcion.sql`): `guests.arrived_at` / `arrived_by`, tabla `event_staff` (personal por evento), `acceso_recepcion()` ('personal' / 'superadmin' / 'duenio' / null) y RPC `agregar_recepcionista`, `mis_eventos_recepcion`, `recepcion_lista`, `recepcion_marcar` (conserva la primera hora si dos marcan a la vez) y `reiniciar_llegadas`. Al principio el dueño no veía las sorpresas (`llegadas_reservadas` las contaba sin nombre); se cambió en `migrations/20261012_recepcion_sorpresas.sql`.
  - Cuentas sin mail (`lib/staff.js`): el usuario se guarda como `<usuario>@recepcion.tizdigital.com` y `user_metadata.role = 'recepcion'`. El login acepta «Mail o usuario»; el router manda a esas cuentas siempre a `/recepcion`.
  - **Las cuentas las crea la base** (`migrations/20261012_recepcion_cuentas.sql`): `crear_recepcionista` inserta en `auth.users` + `auth.identities` ya confirmada (tokens en `''`, no null, o el login falla) con `extensions.crypt`. Primero se probó con `signUp` desde el navegador, pero **el proyecto tiene «Confirm email» activado**: Supabase mandó un mail de confirmación a la dirección inventada (rebota, y muchos rebotes pueden hacer que Supabase frene los mails del proyecto) y la cuenta quedó sin poder entrar. También `quitar_recepcionista` (borra la cuenta, el usuario queda libre) y `cambiar_clave_recepcionista` (el personal no tiene mail para recuperarla; cierra sus sesiones). Probado con PGlite (39 casos en total).
  - Panel (`AdminRecepcion.vue`, ítem «Recepción»): llegadas en vivo cada 15 s con `recepcion_lista` (total, últimos en llegar, por mesa), «Reiniciar llegadas», alta/baja de personal con «Copiar para WhatsApp».
  - Recepción (`Recepcion.vue`, `/recepcion/:eventId?`): buscador sin acentos, filtros Todos / Faltan / Llegaron, por familia con «Llegaron todos», mesa bien visible, desmarcar con confirmación, se refresca cada 10 s.
  - Para después: cuando exista la cuenta de salón (paso 3), el personal pasa a ser del salón y no de cada evento. Invitados que llegan sin estar en la lista: por ahora no se pueden agregar desde recepción.
- [ ] **2 · Planes**: B2C (Básico / Plus / Premium) para quien contrata su fiesta directo, y B2B (Salón) para un salón que compra el sistema y lo usan sus empleados. Estudio de mercado (2026-10-13, competidores, precios y links): https://claude.ai/artifact/GVToFWVqKBZoBje4ETZjQE
  - **B2C decidido el 2026-10-13** (pago único por evento; «cualquier cosa se cambia»):
    - **Gratis para armar y probar** (decidido el 2026-10-13, después de descartar un «Básico gratis» con 20 invitados): todas las funciones, pero con 4 límites juntos para que no se pueda mandar a todos sin pagar: **hasta 5 invitaciones** (links de familia); **cartel «Invitación de prueba · Creada con Asiste»** en la invitación; el link **se cierra a las 15 visitas o a las 24 h desde la primera apertura** (lo que pase primero; las visitas ya se registran en `invitation_views`), y muestra «Esta invitación todavía no está publicada»; la vista previa del panel sigue andando siempre. Al pagar se levanta todo y el mismo link vuelve a andar.
    - **Invitación, $35.000**: invitación completa con un solo link para todos; confirman **por WhatsApp** (mensaje armado al organizador), sin panel ni mesas. Para competir con los baratos (Koinos, Fiestly, NosCasamos). Soporte por WhatsApp.
    - **Plus, $70.000** (el más elegido): link por familia, panel de confirmaciones, mesas, lista de la entrada y **reunión de 1 hora** para armar todo juntos («si se complica, se cambia»).
    - **Premium, $120.000**: + canciones para el DJ, fotos de los invitados, trivia, recepción en vivo, «te cargamos los invitados y armamos la invitación» y soporte prioritario.
    - Las invitaciones sorpresa no van en ningún plan (fueron solo para lo de Anto). Idea: precio de lanzamiento ~20% menos para los primeros clientes.
  - Para programar: hoy `events.plan` es 'basico' | 'plus' y solo canciones mira el plan. Faltan el estado gratis con sus 4 límites (ver arriba; se controla en la base, en `obtener_invitacion` y al crear invitaciones), los planes 'invitacion' / 'plus' / 'premium', la confirmación por WhatsApp del plan Invitación (un solo link + botón que abre WhatsApp con el mensaje armado al teléfono del organizador) y bloquear cada función según el plan (en la pantalla y en la base).
  - **B2B decidido el 2026-10-13**: al salón siempre se le da el **Premium completo** + su logo + usuarios para su personal.
    - **$70.000 por fiesta**, o **abono $250.000/mes con fiestas ilimitadas, sin permanencia** (mes a mes: en temporada baja vuelve a pagar por fiesta). Le conviene desde 4 fiestas por mes.
    - Precio al público de referencia $120.000; el salón decide cuánto le cobra a su cliente (lo revende, lo regala o lo incluye en su paquete).
    - Para salones, la carga de invitados y el armado los hacen ellos o sus clientes (no el servicio a mano del Premium).
    - Incentivos: primera fiesta gratis; al pasarse al abono, lo pagado por fiesta el último mes se descuenta. Más adelante: abono con permanencia de 6 meses más barato (~$220.000).
- [ ] **3 · Cuenta de salón**: hoy una cuenta = un evento (`useEvent` busca por `owner_user_id`). Hace falta un salón con varios eventos, sus empleados y acceso del cliente a su fiesta.
- [ ] **4 · Landing + Mercado Pago**: página pública con los planes y compra; el pago aprobado activa el plan solo. Necesita Edge Functions de Supabase (las claves de MP no pueden ir en el navegador) y una cuenta de vendedor de MP.
  - [x] Landing (`views/Landing.vue`, ruta `/`; con sesión manda al panel): carrusel de funciones en la portada con **demos que se pueden tocar** (`components/landing/Demo*.vue`, en este orden: invitación de ejemplo en un celular con scroll, cuenta regresiva, música y confirmación; luego recepción con buscador y «Llegó», familias que responden solas, movimientos en vivo con filtros, álbum con likes y «Subir foto», trivia que arma el ranking y festeja al ganador, mesas arrastrando o tocando; nombres inventados, fotos de `public/fondos`). Pasa sola según lo que dura cada demo y se frena cuando la persona toca algo, planes con pestañas particulares / salones, cuadro comparativo, «¿Cuál me conviene?», calculadora del abono para salones, con / sin Asiste y preguntas. Los botones de compra por ahora llevan al registro. Ojo: los planes que muestra todavía no están programados (ver paso 2): hoy cualquiera que se registra puede usar casi todo.

Ideas a futuro (no ahora; se anotaron para no perderlas):
- Lista para cocina: menús especiales por mesa (celíacos, vegetarianos, infantiles). La Ejecutiva ya pide restricciones (`guests.dietary`).
- «Buscá tu mesa»: pantalla/tablet en la entrada donde el invitado escribe su nombre y ve su mesa.
- Fotos de los invitados en la pantalla grande (presentación automática de la galería).
- Cronograma de la noche para el personal (entrada, vals, torta, carioca).
- Invitaciones con el logo del salón (white label) como argumento de venta B2B.
- Pie «Invitación creada por» + logo al final de cada invitación (visto en una invitación de «SAINZ Invitación digital», 2026-10-13): publicidad gratis en cada fiesta. Para salones, que diga «creada por» el salón (se cruza con el white label).

Otros:

- [ ] Prueba real antes del 31/10: imprimir el cartel y escanearlo con varios celulares, mandar links reales y revisar la vista previa, probar la lista de la entrada impresa.
- [ ] Revisar de punta a punta en celular (la mayoría abre los links desde ahí).
- [ ] Cuando alguien cambia a «No asiste», hoy conserva su `table_id` (no ocupa lugar ni aparece, pero si vuelve a confirmar reaparece en esa mesa). Decidir si se libera la mesa automáticamente.
- [ ] (Opcional) Limpiar las carpetas `asiste` sueltas que quedaron de los intentos con la cuenta FTP genérica.
