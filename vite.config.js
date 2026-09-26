import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue(), tailwindcss()],
  define: {
    // Timestamp embebido en el bundle: hace que el hash de salida cambie en
    // cada build aunque el código no cambie (útil para forzar un purge de
    // CDN atascado sin depender de un cambio "real").
    __BUILD_ID__: JSON.stringify(new Date().toISOString()),
  },
})
