import { createRouter, createWebHistory } from 'vue-router'
import AdminLogin from '../views/AdminLogin.vue'
import AdminSignup from '../views/AdminSignup.vue'
import AdminNuevaContrasena from '../views/AdminNuevaContrasena.vue'
import AdminDashboard from '../views/AdminDashboard.vue'
import AdminSalon from '../views/AdminSalon.vue'
import AdminMesas from '../views/AdminMesas.vue'
import AdminInvitados from '../views/AdminInvitados.vue'
import PreviewInvite from '../views/PreviewInvite.vue'
import AdminSuperadmin from '../views/AdminSuperadmin.vue'
import AdminFotosEvento from '../views/AdminFotosEvento.vue'
import AdminCanciones from '../views/AdminCanciones.vue'
import AdminActividad from '../views/AdminActividad.vue'
import AdminJuego from '../views/AdminJuego.vue'
import AdminRecepcion from '../views/AdminRecepcion.vue'
import Recepcion from '../views/Recepcion.vue'
import GuestPhotos from '../views/GuestPhotos.vue'
import GuestTrivia from '../views/GuestTrivia.vue'
import TriviaProyector from '../views/TriviaProyector.vue'
import PublicInvite from '../views/PublicInvite.vue'
import Landing from '../views/Landing.vue'
import { useAuth } from '../composables/useAuth'
import { isStaffUser } from '../lib/staff'
import { hasDraft, migrateDraft } from '../lib/draft'

const router = createRouter({
  history: createWebHistory(),
  // Anclas de la landing (#planes, #conviene) y de las páginas legales
  // (#arrepentimiento). Solo ahí: el link de recuperar contraseña también trae
  // un hash (#access_token=…) que no es un elemento. En la landing, 88 px para
  // que la barra fija no tape el título.
  scrollBehavior(to, from, saved) {
    if (saved) return saved
    if (['landing', 'terminos', 'privacidad'].includes(to.name) && /^#[a-z-]+$/.test(to.hash)) {
      const smooth = !window.matchMedia('(prefers-reduced-motion: reduce)').matches
      return { el: to.hash, top: to.name === 'landing' ? 88 : 16, behavior: smooth ? 'smooth' : 'auto' }
    }
    return { top: 0 }
  },
  routes: [
    { path: '/admin/login', name: 'admin-login', component: AdminLogin },
    { path: '/admin/registro', name: 'admin-signup', component: AdminSignup },
    { path: '/admin/nueva-contrasena', name: 'admin-nueva-contrasena', component: AdminNuevaContrasena },
    { path: '/admin', name: 'admin-dashboard', component: AdminDashboard, meta: { requiresAuth: true } },
    { path: '/admin/actividad', name: 'admin-actividad', component: AdminActividad, meta: { requiresAuth: true } },
    { path: '/admin/salon', name: 'admin-salon', component: AdminSalon, meta: { requiresAuth: true } },
    // El mismo editor sin cuenta: se guarda en el navegador (lib/draft.js) y
    // pasa a la base al crear la cuenta. Con sesión se va al editor de verdad.
    { path: '/crear', name: 'crear', component: AdminSalon, meta: { draft: true } },
    { path: '/crear/vista', name: 'crear-vista', component: PreviewInvite },
    {
      path: '/admin/salon/preview',
      name: 'admin-salon-preview',
      component: PreviewInvite,
      meta: { requiresAuth: true },
    },
    { path: '/admin/mesas', name: 'admin-mesas', component: AdminMesas, meta: { requiresAuth: true } },
    {
      path: '/admin/mesas/asignar',
      name: 'admin-asignar-mesas',
      // Antes era una pantalla aparte; ahora se asigna desde Mesas.
      redirect: { name: 'admin-mesas' },
    },
    { path: '/admin/invitados', name: 'admin-invitados', component: AdminInvitados, meta: { requiresAuth: true } },
    {
      path: '/admin/invitados/detalle',
      name: 'admin-invitados-detalle',
      // Antes era una pantalla aparte; ahora todo vive en Invitados.
      redirect: { name: 'admin-invitados' },
    },
    {
      path: '/admin/superadmin',
      name: 'admin-superadmin',
      component: AdminSuperadmin,
      meta: { requiresAuth: true, requiresSuperadmin: true },
    },
    {
      path: '/admin/fotos-evento',
      name: 'admin-fotos-evento',
      component: AdminFotosEvento,
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/canciones',
      name: 'admin-canciones',
      component: AdminCanciones,
      meta: { requiresAuth: true },
    },
    { path: '/admin/juego', name: 'admin-juego', component: AdminJuego, meta: { requiresAuth: true } },
    // Planes y pago con Mercado Pago (también es la vuelta de MP: ?pago=…).
    { path: '/admin/plan', name: 'admin-plan', component: () => import('../views/AdminPlan.vue'), meta: { requiresAuth: true } },
    { path: '/admin/recepcion', name: 'admin-recepcion', component: AdminRecepcion, meta: { requiresAuth: true } },
    // Pantalla del personal del salón. Sin :eventId elige entre sus eventos.
    { path: '/recepcion/:eventId?', name: 'recepcion', component: Recepcion, meta: { requiresAuth: true, staff: true } },
    { path: '/i/:slug', name: 'public-invite', component: PublicInvite },
    { path: '/fotos/:eventId', name: 'guest-photos', component: GuestPhotos },
    { path: '/juego/:eventId', name: 'guest-trivia', component: GuestTrivia },
    { path: '/juego/:eventId/ranking', name: 'trivia-proyector', component: TriviaProyector },
    // Página pública con los planes. Con sesión se saltea (ver beforeEach).
    { path: '/', name: 'landing', component: Landing },
    // Páginas legales (las enlaza el pie de la landing). Con o sin sesión.
    { path: '/terminos', name: 'terminos', component: () => import('../views/Legal.vue') },
    { path: '/privacidad', name: 'privacidad', component: () => import('../views/Legal.vue') },
    // La invitación de ejemplo que la landing muestra dentro del celular.
    { path: '/demo/invitacion', name: 'invitacion-demo', component: () => import('../views/InvitacionDemo.vue') },
  ],
})

// Si venimos del link de recuperar contraseña, el token llega en el hash de la
// URL. Forzamos la pantalla de nueva contraseña sin importar a dónde apunte el
// link (Supabase puede redirigir al Site URL en vez de a redirectTo).
const isRecovery = () =>
  typeof window !== 'undefined' && window.location.hash.includes('type=recovery')

router.beforeEach(async (to) => {
  if (isRecovery() && to.name !== 'admin-nueva-contrasena') {
    return { name: 'admin-nueva-contrasena' }
  }

  // Un solo chequeo de sesión para toda la app (ver el comentario en
  // useAuth.js): el router espera a que termine y lee el estado ya resuelto,
  // en vez de volver a pedirle la sesión a Supabase en cada navegación.
  const { user, isSuperadmin, ready } = useAuth()
  await ready
  const isLoggedIn = !!user.value

  // Ya tiene sesión: /crear es el editor de su cuenta.
  if (to.name === 'crear' && isLoggedIn) return { name: 'admin-salon' }
  // Armó una invitación sin cuenta en este navegador y ya entró: se pasa a
  // su cuenta antes de mostrar el panel (si ya tenía una, no se pisa).
  if (isLoggedIn && to.meta.requiresAuth && !isStaffUser(user.value) && hasDraft()) {
    const moved = await migrateDraft(user.value)
    if (moved) {
      const { useEvent } = await import('../composables/useEvent')
      useEvent().event.value = null // que el panel lea el evento recién creado
      if (to.name === 'admin-dashboard') return { name: 'admin-salon' }
    }
  }

  if (to.meta.requiresAuth && !isLoggedIn) {
    return { name: 'admin-login' }
  }
  // El personal de recepción solo tiene su pantalla: el panel no le sirve (no
  // tiene evento propio) y los permisos igual se validan en la base.
  if (isStaffUser(user.value) && to.meta.requiresAuth && !to.meta.staff) {
    return { name: 'recepcion' }
  }
  // ?planes: el «Enterate de todo lo que incluye» del panel (PlanGate) abre la
  // landing en los planes aunque haya sesión.
  const landingParaVerPlanes = to.name === 'landing' && 'planes' in to.query
  if ((to.name === 'landing' || to.name === 'admin-login' || to.name === 'admin-signup') && isLoggedIn && !landingParaVerPlanes) {
    return { name: 'admin-dashboard' }
  }
  if (to.meta.requiresSuperadmin && !isSuperadmin.value) {
    return { name: 'admin-dashboard' }
  }
})

export default router
