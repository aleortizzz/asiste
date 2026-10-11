<script setup>
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
      {{ row.position }}
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
.rank-row {
  background: var(--tint);
  color: var(--ink);
}
.soft {
  color: var(--muted);
}
.place {
  background: var(--field);
  color: var(--ink);
}

/* Mi fila: color de la invitación, un poco más grande y con sombra. */
.rank-row.mine {
  background: var(--accent);
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

/* Podio: también en mi fila. */
.place.p1 {
  background: #fde68a;
  color: #92400e;
}
.place.p2 {
  background: #e5e7eb;
  color: #374151;
}
.place.p3 {
  background: #fed7aa;
  color: #9a3412;
}
</style>
