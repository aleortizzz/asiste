import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import router from './router'
import { loadPlanPrices } from './lib/plans'
import { vReveal } from './lib/reveal'

console.info('asiste build', __BUILD_ID__)

// Los precios de los planes vienen de la base (se editan en Superadmin).
loadPlanPrices()

// v-reveal: aparición suave al scrollear (landing). Las plantillas de
// invitación tienen su propia v-reveal local, que manda sobre esta.
createApp(App).use(router).directive('reveal', vReveal).mount('#app')

// Splash de la app instalada (index.html): se va cuando la primera pantalla
// está lista, y queda al menos 1 s para que el logo se llegue a ver.
const splash = document.getElementById('splash')
if (splash) {
  router.isReady().then(() => {
    setTimeout(() => {
      splash.classList.add('fuera')
      setTimeout(() => splash.remove(), 400)
    }, Math.max(0, 1000 - performance.now()))
  })
}
