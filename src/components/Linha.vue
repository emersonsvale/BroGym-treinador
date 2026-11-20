<script setup>
import { computed } from 'vue'
// Gráfico de linha simples: pontos [{ x: rótulo, y: número }].
const props = defineProps({ pontos: Array, unidade: { type: String, default: '' }, altura: { type: Number, default: 160 } })
const L = 600
const g = computed(() => {
  const p = props.pontos ?? []
  if (!p.length) return null
  const ys = p.map((v) => v.y)
  let min = Math.min(...ys), max = Math.max(...ys)
  if (min === max) { min -= 1; max += 1 }
  const pad = (max - min) * 0.15
  min -= pad; max += pad
  const H = props.altura - 30
  const X = (i) => (p.length === 1 ? L / 2 : 12 + (i * (L - 24)) / (p.length - 1))
  const Y = (v) => 10 + H - ((v - min) / (max - min)) * H
  const pts = p.map((v, i) => [X(i), Y(v.y)])
  const d = pts.map((q, i) => `${i ? 'L' : 'M'}${q[0].toFixed(1)} ${q[1].toFixed(1)}`).join(' ')
  const area = `${d} L${pts.at(-1)[0].toFixed(1)} ${10 + H} L${pts[0][0].toFixed(1)} ${10 + H} Z`
  return { pts, d, area, H, primeiro: p[0], ultimo: p.at(-1) }
})
const fmt = (v) => `${Number(v).toLocaleString('pt-BR', { maximumFractionDigits: 1 })}${props.unidade}`
</script>

<template>
  <div v-if="!g" class="muted" style="padding: 20px 0">Ainda sem dados.</div>
  <svg v-else :viewBox="`0 0 ${L} ${altura}`" width="100%" :height="altura" role="img" :aria-label="`De ${fmt(g.primeiro.y)} para ${fmt(g.ultimo.y)}`">
    <line x1="0" :x2="L" :y1="10 + g.H" :y2="10 + g.H" stroke="var(--line)" />
    <path :d="g.area" fill="color-mix(in srgb, var(--accent) 14%, transparent)" />
    <path :d="g.d" fill="none" stroke="var(--accent)" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" class="traco" />
    <circle v-for="(q, i) in g.pts" :key="i" :cx="q[0]" :cy="q[1]" r="3.5" fill="var(--accent)"><title>{{ pontos[i].x }}: {{ fmt(pontos[i].y) }}</title></circle>
    <text x="12" :y="altura - 4" fill="var(--muted)" font-size="11">{{ g.primeiro.x }}</text>
    <text :x="L - 12" :y="altura - 4" fill="var(--muted)" font-size="11" text-anchor="end">{{ g.ultimo.x }}</text>
    <text :x="Math.min(L - 12, g.pts.at(-1)[0])" :y="Math.max(14, g.pts.at(-1)[1] - 10)" fill="var(--text)" font-size="13" font-weight="700" text-anchor="end">{{ fmt(g.ultimo.y) }}</text>
  </svg>
</template>

<style scoped>
.traco { stroke-dasharray: 2000; stroke-dashoffset: 2000; animation: desenha 1.4s ease forwards; }
@keyframes desenha { to { stroke-dashoffset: 0; } }
@media (prefers-reduced-motion: reduce) { .traco { animation: none; stroke-dashoffset: 0; } }
</style>
