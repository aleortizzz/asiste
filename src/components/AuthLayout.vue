<script>
// Marco común de las pantallas sin sesión (Ingresar, Registro, Nueva
// contraseña): una foto de fiesta a pantalla completa, la marca y la tarjeta
// con el formulario encima. En desktop la marca va abajo a la izquierda y la
// tarjeta a la derecha; en celular, una arriba de la otra.
//
// Fondo: una foto al azar, de dos listas distintas según la pantalla. Una
// foto vertical en una pantalla horizontal (o al revés) hay que recortarla
// tanto que se ve con mucho zoom, así que:
//   - pantalla apaisada (compu, tablet acostada): fotos horizontales, pc-N.jpg
//     (2560 px de ancho, para que se vean nítidas en monitores grandes).
//   - pantalla angosta (celular): fotos verticales, cel-N.jpg (1080 px).
// `position` es el punto de la foto que no se tiene que cortar.
// Están en public/fondos/. Son de Unsplash: libres para uso comercial, sin
// atribución obligatoria. Para sumar una, agregar el archivo y la fila.
const FONDOS_PC = [
  { file: 'pc-1.jpg', position: '50% 50%' }, // salón armado — unsplash.com/photos/qePRtRzOUf0
  { file: 'pc-2.jpg', position: '45% 55%' }, // salón rústico — unsplash.com/photos/lneL5taiyVo
  { file: 'pc-3.jpg', position: '50% 55%' }, // gente bailando — unsplash.com/photos/7KE9owtQCUA
  { file: 'pc-4.jpg', position: '50% 40%' }, // guirnaldas de luces — unsplash.com/photos/UZjBmpaXq_w
  { file: 'pc-5.jpg', position: '50% 60%' }, // pista con tacos — unsplash.com/photos/nFqF3eFj5w4
]
const FONDOS_CEL = [
  { file: 'cel-1.jpg', position: '50% 35%' }, // bolas de espejos — unsplash.com/photos/249DzAuJTqQ
  { file: 'cel-2.jpg', position: '60% 45%' }, // luces de escenario — unsplash.com/photos/WY1AqSH4dUQ
  { file: 'cel-3.jpg', position: '40% 60%' }, // quinceañera de noche — unsplash.com/photos/90V1cNCJtCI
  { file: 'cel-4.jpg', position: '50% 60%' }, // quinceañera entrando — unsplash.com/photos/Yvyu2bhgL9I
]

// Este <script> (el que no es setup) corre una sola vez al cargar la app, no
// cada vez que se muestra la pantalla: pasar de Ingresar a Registro mantiene
// la misma foto, y al recargar la página sale otra.
const azar = (lista) => lista[Math.floor(Math.random() * lista.length)]
const fondoPc = azar(FONDOS_PC)
const fondoCel = azar(FONDOS_CEL)
</script>

<script setup>
defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
})
</script>

<template>
  <div class="font-ui relative min-h-dvh bg-obsidian text-obsidian">
    <!-- Foto de fondo (fija: no se mueve si el formulario es más alto que la pantalla) -->
    <!-- El navegador baja solo una: la horizontal si la pantalla es apaisada. -->
    <picture>
      <source media="(orientation: landscape)" :srcset="`/fondos/${fondoPc.file}`" />
      <img
        :src="`/fondos/${fondoCel.file}`"
        alt=""
        fetchpriority="high"
        :style="{ '--pos-pc': fondoPc.position, '--pos-cel': fondoCel.position }"
        class="fixed inset-0 h-full w-full object-cover [object-position:var(--pos-cel)] landscape:[object-position:var(--pos-pc)]"
      />
    </picture>
    <!-- Oscurecido para que se lean la marca y los links de abajo -->
    <div class="fixed inset-0 bg-linear-to-b from-obsidian/35 via-obsidian/40 to-obsidian/70 lg:bg-linear-to-r lg:from-obsidian/75 lg:via-obsidian/35 lg:to-obsidian/45"></div>

    <div
      class="relative mx-auto flex min-h-dvh max-w-6xl flex-col gap-8 px-4 py-8 sm:py-12 lg:flex-row lg:items-center lg:justify-between lg:gap-16 lg:px-12"
    >
      <!-- Marca -->
      <div class="text-center text-chalk lg:mb-4 lg:self-end lg:text-left">
        <span class="admin-display block text-6xl drop-shadow-sm lg:text-9xl">Asiste</span>
        <span class="mx-auto mt-2 block max-w-xs text-sm text-chalk/85 lg:mx-0 lg:mt-4 lg:max-w-sm lg:text-lg">
          Invitaciones digitales con confirmación de asistencia, mesas y fotos de la fiesta.
        </span>
      </div>

      <!-- Formulario -->
      <div class="mx-auto w-full max-w-md lg:mx-0">
        <div class="rounded-[2rem] bg-limestone p-6 shadow-2xl shadow-obsidian/30 sm:rounded-[2.5rem] sm:p-10">
          <h1 class="admin-display text-4xl sm:text-5xl">{{ title }}</h1>
          <p v-if="subtitle" class="mt-2 text-obsidian/60">{{ subtitle }}</p>
          <div class="mt-8">
            <slot />
          </div>
        </div>

        <div v-if="$slots.footer" class="mt-6 text-center text-sm text-chalk/80">
          <slot name="footer" />
        </div>
      </div>
    </div>
  </div>
</template>
