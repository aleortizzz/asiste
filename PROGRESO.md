# Asiste — seguimiento del proyecto

App de invitaciones digitales con panel de administrador. Caso de uso inicial: los XV de Antonella (hermana del usuario), **sábado 31 de octubre de 2026**. Después se piensa comercializar como producto de TizDigital (ya es multi-cliente: registro público, planes y superadmin).

Plan original (modelo de datos, rutas, roadmap): `C:\Users\aleor\.claude\plans\polished-stirring-pie.md` (en la otra compu).

Modo de trabajo: **aprender haciendo** — explicar el porqué de cada decisión, no solo tirar código hecho. El usuario viene de HTML/CSS/Tailwind fuerte, está aprendiendo JS/Vue. El usuario prueba cada cosa y recién ahí pide commit/push.

_Última actualización: 2026-10-02._

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
- Si Cloudflare/el CDN se queda con un build viejo, forzar un hash nuevo de build (pasó una vez).

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
- [ ] Parte 2 · Secciones opcionales en todas las plantillas (ocultar canciones, regalos, cuenta regresiva, música).
- [ ] Parte 3 · Itinerario y «Agregar al calendario» en todas las plantillas (también los 15).
- [ ] Parte 4 · Secciones empresariales: oradores, cómo llegar (estacionamiento/acceso), vestimenta con opciones, contacto del organizador, programa en PDF, cupo visible, redes y hashtag.
- [ ] Parte 5 · Confirmación completa (empresa, cargo, mail, teléfono, restricciones alimentarias, acompañante) + panel con «Invitado / Empresa» y lista de la entrada con empresa y cargo.
- [ ] Parte 6 · Bilingüe ES/EN (botón para el invitado).
- [ ] Parte 7 · Vista previa de WhatsApp con el logo de la empresa.

Otros:

- [ ] Prueba real antes del 31/10: imprimir el cartel y escanearlo con varios celulares, mandar links reales y revisar la vista previa, probar la lista de la entrada impresa.
- [ ] Revisar de punta a punta en celular (la mayoría abre los links desde ahí).
- [ ] Cuando alguien cambia a «No asiste», hoy conserva su `table_id` (no ocupa lugar ni aparece, pero si vuelve a confirmar reaparece en esa mesa). Decidir si se libera la mesa automáticamente.
- [ ] (Opcional) Limpiar las carpetas `asiste` sueltas que quedaron de los intentos con la cuenta FTP genérica.
