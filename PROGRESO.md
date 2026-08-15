# Asiste — seguimiento del proyecto

App de invitaciones digitales con panel de administrador. Caso de uso inicial: cumpleaños de 15 de la hermana del usuario (fiesta ~octubre 2026). Después se piensa comercializar como producto de TizDigital, también para eventos corporativos.

Plan completo original (modelo de datos, rutas, roadmap): `C:\Users\aleor\.claude\plans\polished-stirring-pie.md`

Modo de trabajo: **aprender haciendo** — explicar el porqué de cada decisión, no solo tirar código hecho. El usuario viene de HTML/CSS/Tailwind fuerte, está aprendiendo JS/Vue.

## Qué hace la app (resumen funcional)

- Panel admin: carga datos del salón/evento, mesas, y grupos/familias de invitados.
- Cada grupo/familia recibe **un link único** (por slug) → landing pública tipo "Hola familia Pérez, tenés 4 invitaciones".
- Al confirmar, cargan el **nombre de cada invitado individual** que asiste (no solo una cantidad).
- El admin ve en tiempo real quién confirmó y quién no.

## Stack

- Vue 3 (Composition API) + Vite + Tailwind v4 (`@tailwindcss/vite`) + Vue Router + `@supabase/supabase-js`.
- Sin Pinia por ahora (composables simples alcanzan).
- Backend: Supabase (proyecto "asiste").
- Hosting: Hostinger (plan Business Web Hosting), subdominio `asiste.tizdigital.com`.

## Estado actual — Hito 1 completo ✅ (2026-08-14)

Setup end-to-end validado: dev local, build de producción, deploy en `asiste.tizdigital.com/admin` conectando correctamente a Supabase.

Estructura creada:
```
src/
├── views/AdminLogin.vue       (placeholder)
├── views/AdminDashboard.vue   (placeholder + chequeo de conexión a Supabase)
├── views/PublicInvite.vue     (placeholder)
├── router/index.js            (/admin/login, /admin, /i/:slug)
├── lib/supabase.js            (cliente Supabase)
public/.htaccess               (SPA fallback para Apache/Hostinger)
.env                           (credenciales Supabase — no se commitea)
```

## Cómo se despliega (manual, por ahora)

1. `npm run build` (genera `dist/`).
2. Armar un zip de `dist/` **fuera** de la carpeta del proyecto (ej. directo en el Escritorio) — nunca dentro, porque Vite lo vigila como archivo del proyecto y choca con la sincronización de OneDrive (error `EBUSY`, tira abajo el `npm run dev`).
3. **Ojo con `Compress-Archive` de PowerShell**: arma los zips con `\` en vez de `/` en las rutas internas (bug conocido de Windows), y eso rompe la extracción en hPanel — el archivo `assets/index.js` termina siendo un archivo llamado literalmente `assets\index.js` en vez de una carpeta. Hay que armar el zip a mano reemplazando el separador por `/` (hay un approach que funciona con `System.IO.Compression.ZipArchive` iterando archivo por archivo).
4. Subir el zip por el Administrador de Archivos de hPanel a `public_html/asiste`, extraer, y mover el contenido para que quede directo en esa carpeta (no en una subcarpeta).

Pendiente como mejora futura (no bloqueante): deploy automático vía la función "Git" de hPanel (Avanzado → Git), que necesitaría un script post-pull para correr el build.

## Estado actual — Hito 2 completo ✅ (2026-08-14)

Tablas creadas en Supabase (`events`, `tables`, `invitation_groups`, `guests`) + políticas RLS del admin (scope `owner_user_id` vía joins). SQL versionado en `supabase/schema.sql`. Políticas públicas (para `/i/:slug`) quedan pendientes para el Hito 5 — a propósito, se van a resolver vía función RPC en vez de policy directa, para que nadie pueda listar todas las familias de un evento.

Pendiente de validar con datos reales: las policies usan `auth.uid()`, así que la prueba de fuego (que un evento no pueda leer datos de otro) se hace recién cuando exista al menos un usuario admin logueado — eso es el Hito 3.

## Estado actual — Hito 3 completo ✅ (2026-08-14)

Login admin funcionando de punta a punta: usuario admin creado en Supabase Auth (Authentication → Users, con "Auto Confirm User" para saltar la confirmación por mail), composable `src/composables/useAuth.js` con estado de sesión compartido (singleton, refs fuera de la función), formulario en `AdminLogin.vue`, dashboard placeholder en `AdminDashboard.vue` con email + logout, y guard `beforeEach` en `src/router/index.js` que protege `/admin` (meta `requiresAuth`) y redirige lo lógico en ambas direcciones. Probado en el navegador: login real exitoso.

## Estado actual — Hito 4 en curso (2026-08-14)

CRUD admin funcionando: Salón (crear/editar evento), Mesas (alta/baja), Invitados (alta de grupos/familias con slug via `nanoid` + botón copiar link). Nav compartido (`AdminNav.vue`) y composable `useEvent.js` (mismo patrón singleton que `useAuth`).

Dos baches encontrados y resueltos en el camino:
- **GRANT faltante**: crear tablas por SQL Editor no les da permisos a `authenticated` automáticamente (a diferencia del Table Editor de la UI). Sin `grant select/insert/update/delete ... to authenticated`, daba "permission denied for table events" aunque las policies de RLS estuvieran bien. Agregado a `supabase/schema.sql`.
- **Decisión de modelo**: `table_id` se movió de `invitation_groups` a `guests` — la mesa se asigna por invitado individual, no por familia entera, porque una familia se puede repartir entre varias mesas. La pantalla para asignar mesas queda pendiente para el Hito 5+ (recién ahí van a existir invitados reales cargados vía RSVP público).

## Estado actual — Hito 5 completo ✅ (2026-08-14)

RSVP público funcionando de punta a punta: `PublicInvite.vue` (`/i/:slug`) lee vía `obtener_invitacion(slug)` y confirma/declina vía `confirmar_asistencia(slug, nombres[])`, ambas funciones RPC `SECURITY DEFINER` (acceso público sin exponer las tablas directamente — evita que cualquiera pueda listar todas las familias del evento). Probado de punta a punta: link copiado desde el admin, abierto en incógnito, confirmado, y reflejado de vuelta en el admin.

Ajuste post-prueba: la pantalla de Invitados solo mostraba el máximo de invitaciones (`allowed_guests`) y el estado, pero no cuántos habían confirmado realmente cuando no era el grupo completo (ej. 6 invitados, solo 5 confirman). Se resolvió agregando `guests(count)` a la query — ahora muestra "Confirmados 5/6" en vez de solo "Confirmado".

## Estado actual — Hito 6 completo ✅ (2026-08-15)

Dashboard admin (`/admin`) con totales agregados: familias confirmadas/pendientes/declinadas, invitados confirmados vs total de invitaciones repartidas, y ocupación de mesas (usa `guests(count)` agrupado por `table_id`, mismo patrón que el conteo por familia del Hito 5). No necesitó cambios de SQL. Nota: las mesas muestran 0/capacidad todavía porque falta la pantalla de asignación de invitado→mesa (pendiente, ver abajo).

## Estado actual — Invitaciones con nombres precargados + detalle (2026-08-15)

Feature nueva pedida por el usuario, pensando en el uso real: el anfitrión puede, al crear un grupo, tildar "Cargar los nombres de los invitados ahora" y escribir cada nombre de antemano. Si lo hace, el invitado que abre el link ve la lista fija con botones **Asiste/No asiste** por persona (sin tipear nada); si no, sigue el flujo genérico de siempre (formulario para escribir nombres).

Cambios de modelo (documentados en `supabase/schema.sql`):
- `invitation_groups.named_by_host boolean` — marca si el grupo tiene nombres precargados.
- `guests.attending boolean` → reemplazado por `guests.rsvp_status text` (`invited` / `attending` / `not_attending`) — más expresivo, distingue "nombre precargado sin responder" de "confirmó que asiste". Migración corrida con backfill de los datos reales que ya existían (no se perdió el estado de la Familia Pérez de las pruebas).
- Función RPC nueva `responder_invitados(slug, respuestas jsonb)` para el flujo con nombres precargados (además de `confirmar_asistencia` que sigue sirviendo al flujo genérico).

Sobre esto se agregaron dos vistas de detalle:
- En **Invitados**, cada familia tiene un link "ver nombres" que despliega la lista con el estado de cada persona.
- Pantalla nueva **`/admin/invitados/detalle`**: tabla de todos los invitados del evento (nombre, familia, estado) con filtros Todos/Asisten/No asisten/Pendientes. Accesible desde el Dashboard con el link "ver detalle" al lado de "Invitados confirmados X/Y".

## Estado actual — ajustes de detalle/dashboard (2026-08-15)

Tras probar con datos reales, se hicieron tres ajustes de UX/consistencia numérica:
- **Validación de nombres en blanco**: en el RSVP genérico, si la familia deja un input vacío junto a otros completos, ya no se descarta en silencio — bloquea el envío con "Completá el nombre en todos los campos, o quitá los que no vayas a usar."
- **Detalle de invitados no perdía familias sin nombre**: `/admin/invitados/detalle` armaba la lista desde `guests`, pero las familias del flujo genérico que no respondieron (o declinaron sin llegar a escribir nombres) no tienen filas ahí. Se cambió a armar la lista desde `invitation_groups`, agregando una fila resumen por familia cuando no hay nombres cargados. Los contadores de arriba (Todos/Asisten/No asisten/Pendientes) pesan esa fila resumen por su `allowed_guests` real, no como 1, para que cierren con el total del evento.
- **Dashboard pasado de familias a invitados**: las 4 tarjetas de arriba mostraban conteos de *familias* (confirmadas/pendientes/etc.); ahora muestran conteos de *personas* (invitados totales/asisten/pendientes/no asisten), con la misma lógica de "pesos" que el detalle, para que ambas pantallas sean consistentes entre sí.

## Estado actual — Asignación de invitado → mesa completa ✅ (2026-08-15)

Pantalla nueva `/admin/mesas/asignar` (link desde Mesas y desde Dashboard): lista invitados ya confirmados, agrupados por familia, con selector de mesa por persona. Ocupación en vivo en cada opción del selector. Tope de capacidad: las mesas llenas aparecen deshabilitadas ("— completa") en el selector, y hay validación al guardar por las dudas (si igual se fuerza, no lo guarda y avisa). La pantalla de **Mesas** también muestra ahora ocupación real por mesa ("Mesa 1 — 3/5 lugares"), no solo la capacidad. No requirió cambios de SQL — usa la columna `guests.table_id` que ya existía.

Con esto, el núcleo funcional completo de la app está andando: setup, datos con RLS, login, CRUD admin, RSVP público (genérico y con nombres precargados), dashboard con totales por invitado, y asignación de mesas.

## Estado actual — Hito 8 (deploy) en curso, pausado (2026-08-15)

Se decidió saltar el pulido (Hito 7) por ahora e ir directo al deploy para probar en el dominio real.

Hecho:
- `npm run build` corrido, `dist/` generado con la versión que incluye todo lo de hoy (RSVP con nombres precargados, dashboard por invitado, asignación de mesas).
- Zip armado a mano con `System.IO.Compression.ZipArchive` (evita el bug de `Compress-Archive`) en `c:\Users\aleor\OneDrive\Desktop\asiste-deploy.zip` — confirmado que las rutas internas usan `/` correctamente (`assets/index-....js`, no `assets\index-....js`).

## Estado actual — Deploy automático (CI/CD) funcionando ✅ (2026-08-15)

Se reemplazó el proceso manual de zip por un pipeline automático: **cada `git push` a `main` en GitHub dispara un workflow que compila (`npm run build`) y sube el resultado por FTPS a Hostinger**, sin intervención manual.

- Repo: `https://github.com/aleortizzz/asiste` (privado).
- Workflow: `.github/workflows/deploy.yml` (usa `actions/checkout`, `actions/setup-node`, y `SamKirkland/FTP-Deploy-Action@v4.3.5`).
- Secrets configurados en GitHub (Settings → Secrets and variables → Actions): `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `FTP_SERVER`, `FTP_USERNAME`, `FTP_PASSWORD`.

**Gotcha importante que costó varias corridas fallidas resolver**: la cuenta FTP "genérica" del hosting (usuario `u452496377`, la que aparece primero en hPanel) **no está conectada al sitio `tizdigital.com` en absoluto** — su raíz apunta a otro lugar del hosting, ajeno a `public_html` de ese dominio. Ningún valor de `server-dir` (se probaron `/public_html/asiste/`, `/asiste/`) lograba que los archivos aparecieran en el `public_html/asiste` real (verificado repetidas veces desde hPanel → Sitios web → tizdigital.com → Archivos).

**Solución**: crear una **cuenta FTP dedicada** en hPanel (Archivos → Cuentas FTP → Crear una nueva cuenta FTP), con el campo Directorio apuntando exactamente a `.../domains/tizdigital.com/public_html/asiste`. Hostinger le puso de usuario `u452496377.asiste` (con prefijo del usuario principal + punto). Con esta cuenta, la raíz del FTP ya arranca directo en la carpeta correcta, así que `server-dir` en el workflow queda simplemente en `/`.

**Nota para el futuro**: si Hostinger tira "Timeout (control socket)" al conectar, probar de nuevo — puede ser que una cuenta FTP recién creada tarde un minuto en activarse.

## Próximos pasos

- [ ] **(Opcional, cuando haya tiempo)** Limpiar las carpetas `asiste` sueltas que quedaron de los intentos fallidos con la cuenta FTP genérica (no afectan el sitio real, son solo basura en otra parte del hosting).
- [ ] **Hito 7**: pulido — mobile-first (la mayoría va a abrir el link desde el celular), estados de carga/error, validaciones.
- [ ] **Hito 5**: página pública de RSVP (`/i/:slug`) + función RPC `confirmar_asistencia` con políticas RLS públicas acotadas.
- [ ] **Hito 6**: dashboard con totales (confirmados/pendientes, ocupación de mesas).
- [ ] **Hito 7**: pulido — mobile-first, estados de carga/error, validaciones.
- [ ] **Hito 8**: deploy final + prueba real con links de prueba antes del evento.

Ver el plan completo (`polished-stirring-pie.md`) para el detalle del modelo de datos SQL y el enfoque de seguridad RLS.
