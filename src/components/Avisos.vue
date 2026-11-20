<script setup>
import { avisos } from '../lib/util'
</script>
<template>
  <div class="avisos">
    <TransitionGroup name="aviso">
      <div v-for="a in avisos.lista" :key="a.id" class="aviso" :class="a.tipo">{{ a.texto }}</div>
    </TransitionGroup>
  </div>
</template>
<style scoped>
.avisos { position: fixed; right: 18px; bottom: 18px; display: flex; flex-direction: column; gap: 8px; z-index: 100; max-width: min(420px, calc(100vw - 36px)); }
.aviso { background: var(--surface); border: 1px solid var(--line); border-left: 4px solid var(--success); padding: 12px 14px; border-radius: 12px; box-shadow: var(--sombra); font-weight: 500; }
.aviso.erro { border-left-color: var(--accent); }
.aviso-enter-from, .aviso-leave-to { opacity: 0; transform: translateY(10px); }
.aviso-enter-active, .aviso-leave-active { transition: all .2s; }
</style>
