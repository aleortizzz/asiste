import { createApp } from 'vue'
import './style.css'
import App from './App.vue'
import router from './router'

console.info('asiste build', __BUILD_ID__)

createApp(App).use(router).mount('#app')
