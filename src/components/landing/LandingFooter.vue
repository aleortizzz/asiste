<script setup>
import { MessageCircle } from '@lucide/vue'
import { COMPANY, WHATSAPP_DISPLAY, waLink } from '../../lib/contact'

// Pie de la landing (y de las páginas legales). Los links con # son anclas
// de la landing: desde otra página se arman como /#seccion.
const props = defineProps({ onLanding: { type: Boolean, default: true } })
const a = (hash) => (props.onLanding ? hash : `/${hash}`)

const year = new Date().getFullYear()
const COLUMNS = [
  {
    title: 'Producto',
    links: [
      { label: 'Cómo funciona', href: '#como-funciona' },
      { label: 'Funciones', href: '#funciones' },
      { label: 'Plantillas', href: '#plantillas' },
      { label: 'Planes y precios', href: '#planes' },
      { label: 'Preguntas', href: '#preguntas' },
    ],
  },
  {
    title: 'Para quién',
    links: [
      { label: 'XV años', href: '#eventos' },
      { label: 'Casamientos', href: '#eventos' },
      { label: 'Cumpleaños', href: '#eventos' },
      { label: 'Eventos de empresa', href: '#eventos' },
      { label: 'Salones', href: '#salones' },
    ],
  },
]
</script>

<template>
  <footer class="mt-6 border-t border-obsidian/10 py-12">
    <div class="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.4fr_1fr_1fr_1fr]">
      <div>
        <a :href="a('#inicio')" class="admin-display text-5xl">Asiste</a>
        <p class="mt-3 max-w-xs text-obsidian/60">Invitaciones digitales y organización de fiestas, de punta a punta.</p>
        <p class="mt-4 text-sm text-obsidian/50">Un producto de {{ COMPANY }}, hecho en Argentina.</p>
      </div>

      <nav v-for="col in COLUMNS" :key="col.title" :aria-label="col.title">
        <p class="font-bold">{{ col.title }}</p>
        <ul class="mt-3 space-y-2 text-obsidian/65">
          <li v-for="l in col.links" :key="l.label">
            <a :href="a(l.href)" class="hover:text-obsidian hover:underline">{{ l.label }}</a>
          </li>
        </ul>
      </nav>

      <div>
        <p class="font-bold">Contacto</p>
        <ul class="mt-3 space-y-2 text-obsidian/65">
          <li>
            <a :href="waLink()" target="_blank" rel="noopener" class="inline-flex items-center gap-1.5 hover:text-obsidian hover:underline">
              <MessageCircle :size="15" /> WhatsApp {{ WHATSAPP_DISPLAY }}
            </a>
          </li>
          <li><router-link :to="{ name: 'admin-login' }" class="hover:text-obsidian hover:underline">Ingresar a mi cuenta</router-link></li>
          <li><router-link :to="{ name: 'terminos' }" class="hover:text-obsidian hover:underline">Términos y condiciones</router-link></li>
          <li><router-link :to="{ name: 'privacidad' }" class="hover:text-obsidian hover:underline">Política de privacidad</router-link></li>
          <li>
            <router-link :to="{ name: 'terminos', hash: '#arrepentimiento' }" class="hover:text-obsidian hover:underline">
              Botón de arrepentimiento
            </router-link>
          </li>
        </ul>
      </div>
    </div>

    <div class="mt-10 flex flex-wrap items-center justify-between gap-3 border-t border-obsidian/10 pt-6 text-sm text-obsidian/50">
      <span>© {{ year }} Asiste · {{ COMPANY }}</span>
      <span>Precios finales en pesos argentinos.</span>
    </div>
  </footer>
</template>
