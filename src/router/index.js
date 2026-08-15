import { createRouter, createWebHistory } from 'vue-router'
import AdminLogin from '../views/AdminLogin.vue'
import AdminSignup from '../views/AdminSignup.vue'
import AdminDashboard from '../views/AdminDashboard.vue'
import AdminSalon from '../views/AdminSalon.vue'
import AdminMesas from '../views/AdminMesas.vue'
import AdminAsignarMesas from '../views/AdminAsignarMesas.vue'
import AdminInvitados from '../views/AdminInvitados.vue'
import AdminInvitadosDetalle from '../views/AdminInvitadosDetalle.vue'
import PublicInvite from '../views/PublicInvite.vue'
import { supabase } from '../lib/supabase'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/admin/login', name: 'admin-login', component: AdminLogin },
    { path: '/admin/registro', name: 'admin-signup', component: AdminSignup },
    { path: '/admin', name: 'admin-dashboard', component: AdminDashboard, meta: { requiresAuth: true } },
    { path: '/admin/salon', name: 'admin-salon', component: AdminSalon, meta: { requiresAuth: true } },
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
    { path: '/i/:slug', name: 'public-invite', component: PublicInvite },
    { path: '/', redirect: '/admin/login' },
  ],
})

router.beforeEach(async (to) => {
  const { data } = await supabase.auth.getSession()
  const isLoggedIn = !!data.session

  if (to.meta.requiresAuth && !isLoggedIn) {
    return { name: 'admin-login' }
  }
  if ((to.name === 'admin-login' || to.name === 'admin-signup') && isLoggedIn) {
    return { name: 'admin-dashboard' }
  }
})

export default router
