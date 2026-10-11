<script setup>
import { Trophy } from '@lucide/vue'
import { formatDuration } from '../../lib/trivia'

// Una fila del ranking de la trivia (GuestTrivia.vue). La del propio jugador
// (`mine`) va más grande y con sombra, esté dentro del top 10 o aparte.
// Usa las variables de color de la página (--accent, --tint, …).
defineProps({
  row: { type: Object, required: true }, // { position, name, correct, duration_ms }
  total: { type: Number, required: true },
  mine: { type: Boolean, default: false },
})
</script>

<template>
  <div class="rank-row flex items-center gap-3 rounded-2xl pr-4 pl-2.5" :class="mine ? 'mine py-3.5' : 'py-2.5'">
    <span class="place grid h-8 w-8 shrink-0 place-items-center rounded-full text-sm font-bold" :class="`p${row.position}`">
      <Trophy v-if="row.position === 1" :size="16" :stroke-width="2.5" aria-label="1" />
      <template v-else>{{ row.position }}</template>
    </span>
    <span class="flex min-w-0 flex-1 items-center gap-2">
      <span class="truncate font-semibold">{{ row.name }}</span>
      <span v-if="mine" class="you shrink-0 rounded-full px-2 py-0.5 text-[0.7rem] font-bold tracking-wide uppercase">Vos</span>
    </span>
    <span class="w-16 shrink-0 text-right font-bold tabular-nums">
      {{ row.correct }}<span class="text-xs font-semibold opacity-60">/{{ total }}</span>
    </span>
    <span class="soft w-16 shrink-0 text-right text-sm tabular-nums">{{ formatDuration(row.duration_ms) }}</span>
  </div>
</template>

<style scoped>
/* Mismo criterio que el proyector: tarjetas claras con borde de un pelo y el
   podio en el color del evento (1.º lleno, 2.º y 3.º suaves con anillo). */
.rank-row {
  background: var(--field);
  border: 1px solid var(--line);
  color: var(--ink);
}
.soft {
  color: var(--muted);
}
.place {
  font-family: 'Inter', ui-sans-serif, sans-serif;
  color: var(--muted);
}

/* Mi fila: color de la invitación, un poco más grande y con sombra. */
.rank-row.mine {
  background: var(--accent);
  border-color: transparent;
  color: var(--accent-on);
  font-size: 1.06rem;
  box-shadow: 0 10px 24px -10px var(--accent);
  margin-inline: -0.35rem;
}
.mine .soft {
  color: inherit;
  opacity: 0.8;
}
.mine .place {
  background: var(--accent-on);
  color: var(--accent);
}
.you {
  background: var(--accent-on);
  color: var(--accent);
}

/* Podio. */
.place.p1 {
  background: var(--accent);
  color: var(--accent-on);
}
.place.p2,
.place.p3 {
  background: var(--tint);
  color: var(--accent-text);
  box-shadow: inset 0 0 0 2px color-mix(in srgb, var(--accent) 30%, transparent);
}
/* En mi fila (fondo de color) el círculo va invertido, sea cual sea el puesto. */
.mine .place,
.mine .place.p1,
.mine .place.p2,
.mine .place.p3 {
  background: var(--accent-on);
  color: var(--accent);
  box-shadow: none;
}
</style>
