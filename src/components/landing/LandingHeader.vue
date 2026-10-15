<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { Menu, X } from '@lucide/vue'

// Barra de la landing: queda fija arriba al bajar. En desktop, el menú con las
// secciones; en celular, un botón que lo despliega. Las secciones llevan
// scroll-mt-24 para que la barra no tape el título al saltar a un ancla.
const LINKS = [
  { href: '#como-funciona', label: 'Cómo funciona' },
  { href: '#funciones', label: 'Funciones' },
  { href: '#plantillas', label: 'Plantillas' },
  { href: '#salones', label: 'Salones' },
  { href: '#planes', label: 'Planes' },
  { href: '#preguntas', label: 'Preguntas' },
]

const open = ref(false)
// Con sombra apenas se baja un poco: arriba de todo se funde con la portada.
const scrolled = ref(false)
const onScroll = () => (scrolled.value = window.scrollY > 8)
onMounted(() => {
  onScroll()
  window.addEventListener('scroll', onScroll, { passive: true })
})
onUnmounted(() => window.removeEventListener('scroll', onScroll))
</script>

<template>
  <header
    class="sticky top-0 z-40 transition-[background-color,box-shadow] duration-300"
    :class="scrolled || open ? 'bg-pumice/90 shadow-[0_1px_0_rgb(7_6_7/0.08)] backdrop-blur-md' : 'bg-pumice'"
  >
    <div class="mx-auto flex h-16 max-w-6xl items-center justify-between gap-4 px-4 sm:h-[4.5rem]">
      <a href="#inicio" class="admin-display text-4xl" @click="open = false">Asiste</a>

      <nav aria-label="Secciones" class="hidden lg:block">
        <ul class="flex items-center gap-1">
          <li v-for="l in LINKS" :key="l.href">
            <a :href="l.href" class="rounded-full px-3 py-2 text-[0.95rem] font-bold text-obsidian/70 transition-colors hover:bg-limestone hover:text-obsidian">
              {{ l.label }}
            </a>
          </li>
        </ul>
      </nav>

      <div class="flex items-center gap-1 sm:gap-2">
        <router-link :to="{ name: 'admin-login' }" class="rounded-full px-3 py-2 font-bold">Ingresar</router-link>
        <a href="#planes" class="admin-btn-primary hidden !px-4 !py-2 text-sm sm:inline-flex">Ver planes</a>
        <button
          type="button"
          @click="open = !open"
          :aria-expanded="open"
          aria-controls="landing-menu"
          aria-label="Menú"
          class="grid h-11 w-11 place-items-center rounded-full bg-limestone lg:hidden"
        >
          <X v-if="open" :size="20" />
          <Menu v-else :size="20" />
        </button>
      </div>
    </div>

    <!-- Menú en celular -->
    <Transition name="menu">
      <nav v-if="open" id="landing-menu" aria-label="Secciones" class="border-t border-obsidian/5 px-4 pb-5 lg:hidden">
        <ul class="mx-auto max-w-6xl divide-y divide-obsidian/5">
          <li v-for="l in LINKS" :key="l.href">
            <a :href="l.href" @click="open = false" class="block py-3.5 text-lg font-bold">{{ l.label }}</a>
          </li>
        </ul>
        <div class="mx-auto mt-3 grid max-w-6xl gap-2 sm:grid-cols-2">
          <a href="#planes" @click="open = false" class="admin-btn-primary">Ver planes</a>
          <router-link :to="{ name: 'admin-signup' }" class="admin-btn-secondary">Probar gratis</router-link>
        </div>
      </nav>
    </Transition>
  </header>
</template>

<style scoped>
.menu-enter-active,
.menu-leave-active {
  transition:
    opacity 0.2s ease,
    transform 0.25s cubic-bezier(0.32, 0.72, 0, 1);
}
.menu-enter-from,
.menu-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}
</style>
