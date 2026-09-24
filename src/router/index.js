import { createRouter, createWebHistory } from 'vue-router'
import AdminLogin from '../views/AdminLogin.vue'
import AdminSignup from '../views/AdminSignup.vue'
import AdminNuevaContrasena from '../views/AdminNuevaContrasena.vue'
import AdminDashboard from '../views/AdminDashboard.vue'
import AdminSalon from '../views/AdminSalon.vue'
import AdminMesas from '../views/AdminMesas.vue'
import AdminAsignarMesas from '../views/AdminAsignarMesas.vue'
import AdminInvitados from '../views/AdminInvitados.vue'
import AdminInvitadosDetalle from '../views/AdminInvitadosDetalle.vue'
import PreviewInvite from '../views/PreviewInvite.vue'
import AdminSuperadmin from '../views/AdminSuperadmin.vue'
import AdminFotosEvento from '../views/AdminFotosEvento.vue'
import AdminCanciones from '../views/AdminCanciones.vue'
import GuestPhotos from '../views/GuestPhotos.vue'
import PublicInvite from '../views/PublicInvite.vue'
import { useAuth } from '../composables/useAuth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/admin/login', name: 'admin-login', component: AdminLogin },
    { path: '/admin/registro', name: 'admin-signup', component: AdminSignup },
    { path: '/admin/nueva-contrasena', name: 'admin-nueva-contrasena', component: AdminNuevaContrasena },
    { path: '/admin', name: 'admin-dashboard', component: AdminDashboard, meta: { requiresAuth: true } },
    { path: '/admin/salon', name: 'admin-salon', component: AdminSalon, meta: { requiresAuth: true } },
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
      component: AdminAsignarMesas,
      meta: { requiresAuth: true },
    },
    { path: '/admin/invitados', name: 'admin-invitados', component: AdminInvitados, meta: { requiresAuth: true } },
    {
      path: '/admin/invitados/detalle',
      name: 'admin-invitados-detalle',
      component: AdminInvitadosDetalle,
      meta: { requiresAuth: true },
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
    { path: '/i/:slug', name: 'public-invite', component: PublicInvite },
    { path: '/fotos/:eventId', name: 'guest-photos', component: GuestPhotos },
    { path: '/', redirect: '/admin/login' },
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

  if (to.meta.requiresAuth && !isLoggedIn) {
    return { name: 'admin-login' }
  }
  if ((to.name === 'admin-login' || to.name === 'admin-signup') && isLoggedIn) {
    return { name: 'admin-dashboard' }
  }
  if (to.meta.requiresSuperadmin && !isSuperadmin.value) {
    return { name: 'admin-dashboard' }
  }
})

export default router
