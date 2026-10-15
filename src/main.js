import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import router from './router'
import { loadPlanPrices } from './lib/plans'

console.info('asiste build', __BUILD_ID__)

// Los precios de los planes vienen de la base (se editan en Superadmin).
loadPlanPrices()

createApp(App).use(router).mount('#app')
