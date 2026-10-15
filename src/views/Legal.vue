<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { ArrowLeft, MessageCircle } from '@lucide/vue'
import LandingFooter from '../components/landing/LandingFooter.vue'
import BrandLogo from '../components/BrandLogo.vue'
import { COMPANY, SITE, WHATSAPP_DISPLAY, waLink } from '../lib/contact'

// Términos y condiciones (/terminos) y Política de privacidad (/privacidad).
// Borrador del 2026-10-15: revisarlo con un abogado o contador y sumar los
// datos fiscales de TizDigital (razón social, CUIT, domicilio) antes de
// darlo por definitivo. El «Botón de arrepentimiento» (Res. 424/2020) es el
// ancla #arrepentimiento de Términos, enlazada desde el pie de la landing.
const route = useRoute()
const UPDATED = '15 de octubre de 2026'

const DOCS = {
  terminos: {
    title: 'Términos y condiciones',
    intro: `Estos términos regulan el uso de Asiste (${SITE}), un servicio de ${COMPANY} para crear invitaciones digitales y organizar eventos. Al crear una cuenta o contratar un plan, aceptás estos términos.`,
    sections: [
      {
        title: 'El servicio',
        body: [
          'Asiste permite armar una invitación digital, enviarla por link, recibir confirmaciones y, según el plan, organizar mesas, la recepción, el álbum de fotos, la trivia y los pedidos de canciones de un evento.',
          'El organizador (quien crea la cuenta) es responsable del contenido que carga: textos, fotos, datos de sus invitados y todo lo que publica en su invitación.',
        ],
      },
      {
        title: 'Cuenta',
        body: [
          'Para usar Asiste necesitás una cuenta con un mail válido y una contraseña. Sos responsable de mantener tu contraseña en reserva y de lo que se haga con tu cuenta.',
          'Podés pedirnos que eliminemos tu cuenta y tus datos en cualquier momento escribiéndonos por WhatsApp.',
        ],
      },
      {
        title: 'Planes, precios y pagos',
        body: [
          'Los planes para particulares son un pago único por evento. Los precios vigentes se publican en la página de inicio, en pesos argentinos, y pueden cambiar; el precio que pagás es el que figura al momento de la compra.',
          'Los pagos se procesan a través de Mercado Pago. Asiste no ve ni guarda los datos de tu tarjeta.',
          'Si ya tenés un plan y te pasás a uno superior, pagás solo la diferencia entre ambos según los precios vigentes. El plan se activa automáticamente cuando Mercado Pago confirma el pago.',
          'La prueba gratis permite armar la invitación completa con límites (cantidad de invitaciones, visitas y tiempo) y un cartel que indica que es de prueba. Al contratar un plan se levantan los límites.',
        ],
      },
      {
        id: 'arrepentimiento',
        title: 'Botón de arrepentimiento',
        body: [
          'Conforme al artículo 34 de la Ley 24.240 de Defensa del Consumidor y la Resolución 424/2020, podés revocar la compra dentro de los 10 (diez) días corridos desde que la hiciste, sin costo ni necesidad de dar explicaciones.',
          'Para hacerlo, escribinos por WhatsApp con el mail de tu cuenta. Te confirmamos la recepción del pedido y te devolvemos el importe por el mismo medio de pago.',
        ],
        action: { label: 'Quiero arrepentirme de mi compra', text: 'Hola! Quiero arrepentirme de mi compra en Asiste. El mail de mi cuenta es: ' },
      },
      {
        title: 'Uso aceptable',
        body: [
          'No se puede usar Asiste para publicar contenido ilegal, ofensivo o que infrinja derechos de terceros (por ejemplo, fotos de otras personas sin su permiso), ni para enviar mensajes no deseados.',
          'Podemos suspender una cuenta que no respete estos términos.',
        ],
      },
      {
        title: 'Disponibilidad y responsabilidad',
        body: [
          'Hacemos todo lo posible para que Asiste funcione sin interrupciones, pero puede haber cortes por mantenimiento o por fallas de proveedores (servidores, conexión a internet, Mercado Pago). Durante el evento, el servicio depende también de la señal de los celulares.',
          'Asiste es una herramienta de organización: las decisiones del evento (catering, cantidad de invitados, ubicación) son del organizador.',
        ],
      },
      {
        title: 'Cambios',
        body: ['Podemos actualizar estos términos. Si el cambio es importante, te avisamos por mail o en el panel.'],
      },
      {
        title: 'Ley aplicable',
        body: ['Estos términos se rigen por las leyes de la República Argentina.'],
      },
    ],
  },
  privacidad: {
    title: 'Política de privacidad',
    intro: `En ${COMPANY} cuidamos los datos que cargás en Asiste y los de tus invitados. Acá te contamos qué datos usamos, para qué y cuáles son tus derechos, según la Ley 25.326 de Protección de los Datos Personales.`,
    sections: [
      {
        title: 'Qué datos usamos',
        body: [
          'De tu cuenta: tu mail y tu contraseña (guardada cifrada; nadie puede verla).',
          'De tu evento: lo que cargás en la invitación (textos, fechas, lugares, fotos) y los nombres de tus invitados. En eventos de empresa, los datos que pidas en la confirmación (empresa, cargo, mail, teléfono, restricciones alimentarias).',
          'De tus invitados: sus respuestas, cuándo abren la invitación, las fotos que suben, los nombres que usan en la trivia y las canciones que piden.',
          'De los pagos: el plan, el monto, el estado y el número de operación de Mercado Pago. No vemos ni guardamos datos de tarjetas.',
        ],
      },
      {
        title: 'Para qué',
        body: [
          'Solo para prestar el servicio: mostrar la invitación, registrar confirmaciones y llegadas, armar el álbum y la trivia, activar tu plan y darte soporte. No vendemos ni compartimos tus datos con fines publicitarios.',
        ],
      },
      {
        title: 'Con quién los compartimos',
        body: [
          'Con los proveedores que necesitamos para funcionar: Supabase (base de datos y archivos), Hostinger (el sitio), Mercado Pago (pagos), Resend (mails de la cuenta) y YouTube (la búsqueda de canciones).',
          'La invitación y el álbum los ve quien tenga el link: compartilo solo con tus invitados.',
        ],
      },
      {
        title: 'Cuánto tiempo los guardamos',
        body: [
          'Mientras tengas tu cuenta. Si nos pedís eliminar tu evento o tu cuenta, borramos los datos y las fotos asociadas, salvo los registros de pagos que la ley nos obliga a conservar.',
        ],
      },
      {
        title: 'Almacenamiento en tu navegador',
        body: [
          'Usamos el almacenamiento del navegador para mantener tu sesión iniciada y recordar algunas preferencias (por ejemplo, el plan que elegiste o tu partida en la trivia). No usamos cookies de publicidad.',
        ],
      },
      {
        title: 'Tus derechos',
        body: [
          'Podés pedirnos acceder a tus datos, corregirlos o eliminarlos escribiéndonos por WhatsApp.',
          'El titular de los datos personales tiene la facultad de ejercer el derecho de acceso a los mismos en forma gratuita a intervalos no inferiores a seis meses, salvo que se acredite un interés legítimo al efecto conforme lo establecido en el artículo 14, inciso 3 de la Ley N° 25.326. La Agencia de Acceso a la Información Pública, en su carácter de Órgano de Control de la Ley N° 25.326, tiene la atribución de atender las denuncias y reclamos que interpongan quienes resulten afectados en sus derechos por incumplimiento de las normas vigentes en materia de protección de datos personales.',
        ],
      },
    ],
  },
}

const doc = computed(() => DOCS[route.name] ?? DOCS.terminos)
</script>

<template>
  <div class="landing font-ui min-h-dvh bg-pumice text-obsidian">
    <div class="mx-auto max-w-6xl px-4">
      <header class="flex h-16 items-center justify-between sm:h-[4.5rem]">
        <router-link :to="{ name: 'landing' }" class="text-4xl text-accent"><BrandLogo /></router-link>
        <router-link :to="{ name: 'landing' }" class="inline-flex items-center gap-1.5 text-sm font-bold text-obsidian/60 hover:text-obsidian">
          <ArrowLeft :size="15" /> Volver al inicio
        </router-link>
      </header>

      <article class="mx-auto max-w-3xl py-10">
        <h1 class="admin-display text-5xl sm:text-6xl">{{ doc.title }}</h1>
        <p class="mt-2 text-sm text-obsidian/50">Última actualización: {{ UPDATED }}</p>
        <p class="mt-6 text-lg text-obsidian/70">{{ doc.intro }}</p>

        <section v-for="s in doc.sections" :id="s.id" :key="s.title" class="mt-10 scroll-mt-6">
          <h2 class="text-xl font-bold">{{ s.title }}</h2>
          <p v-for="(p, i) in s.body" :key="i" class="mt-3 leading-relaxed text-obsidian/70">{{ p }}</p>
          <a
            v-if="s.action"
            :href="waLink(s.action.text)"
            target="_blank"
            rel="noopener"
            class="admin-btn-primary mt-5"
          >
            <MessageCircle :size="17" /> {{ s.action.label }}
          </a>
        </section>

        <p class="mt-12 rounded-[1.5rem] bg-limestone p-5 text-obsidian/70">
          ¿Dudas? Escribinos por
          <a :href="waLink()" target="_blank" rel="noopener" class="font-bold text-accent hover:underline">WhatsApp ({{ WHATSAPP_DISPLAY }})</a>.
        </p>
      </article>

      <LandingFooter :on-landing="false" />
    </div>
  </div>
</template>
