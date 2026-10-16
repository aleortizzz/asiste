import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import router from './router'
import { loadPlanPrices } from './lib/plans'
import { vReveal } from './lib/reveal'
import { applyPaletteFromUrl } from './lib/paleta'

console.info('asiste build', __BUILD_ID__)

// Los precios de los planes vienen de la base (se editan en Superadmin).
loadPlanPrices()

// Prueba de colores (/colores): si se eligió otra paleta en esta pestaña.
applyPaletteFromUrl()

// v-reveal: aparición suave al scrollear (landing). Las plantillas de
// invitación tienen su propia v-reveal local, que manda sobre esta.
createApp(App).use(router).directive('reveal', vReveal).mount('#app')

