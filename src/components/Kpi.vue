<script setup>
defineProps({ rotulo: String, valor: [String, Number], detalhe: String, destaque: Boolean })
</script>
<template>
  <div class="card kpi" :class="{ destaque }">
    <small>{{ rotulo }}</small>
    <div class="valor titulo">{{ valor }}</div>
    <small v-if="detalhe" class="detalhe">{{ detalhe }}</small>
    <slot />
  </div>
</template>
<style scoped>
.kpi { display: flex; flex-direction: column; gap: 4px; min-height: 104px; }
.kpi small:first-child { font-weight: 600; }
.valor { font-size: 30px; font-weight: 800; font-variant-numeric: tabular-nums; line-height: 1.1; }
.destaque { background: linear-gradient(140deg, var(--accent-soft), var(--surface) 70%); border-color: color-mix(in srgb, var(--accent) 35%, var(--line)); }
.detalhe { font-size: 12px; }
</style>
