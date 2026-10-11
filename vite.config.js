import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

// Marca de este build en los nombres de TODOS los archivos de assets/ (no
// solo en el hash del JS): así un deploy nunca pisa un archivo que ya existe.
// Pisarlo dejaba un momento sin el archivo, el servidor respondía con la
// página y el CDN guardaba esa respuesta: el sitio quedaba sin estilos o en
// blanco por horas.
const stamp = Date.now().toString(36)

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue(), tailwindcss()],
  define: {
    // Timestamp embebido en el bundle: hace que el hash de salida cambie en
    // cada build aunque el código no cambie (útil para forzar un purge de
    // CDN atascado sin depender de un cambio "real").
    __BUILD_ID__: JSON.stringify(new Date().toISOString()),
  },
  build: {
    rollupOptions: {
      output: {
        entryFileNames: `assets/[name]-[hash]-${stamp}.js`,
        chunkFileNames: `assets/[name]-[hash]-${stamp}.js`,
        assetFileNames: `assets/[name]-[hash]-${stamp}[extname]`,
      },
    },
  },
})
