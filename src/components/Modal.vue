<script setup>
import { onMounted, onUnmounted } from 'vue'
import Icone from './Icone.vue'
const props = defineProps({ titulo: String, largura: { type: String, default: '560px' }, lateral: Boolean })
const emit = defineEmits(['fechar'])
const tecla = (e) => { if (e.key === 'Escape') emit('fechar') }
onMounted(() => window.addEventListener('keydown', tecla))
onUnmounted(() => window.removeEventListener('keydown', tecla))
</script>
<template>
  <Teleport to="body">
    <div class="fundo" :class="{ lateral: props.lateral }" @mousedown.self="emit('fechar')">
      <div class="caixa surge" :style="{ width: largura }">
        <div class="linha entre topo">
          <h2>{{ titulo }}</h2>
          <button class="btn fantasma pequeno" @click="emit('fechar')"><Icone nome="fechar" /></button>
        </div>
        <div class="corpo"><slot /></div>
      </div>
    </div>
  </Teleport>
</template>
<style scoped>
.fundo { position: fixed; inset: 0; background: rgba(0, 0, 0, .55); display: grid; place-items: center; z-index: 60; padding: 16px; backdrop-filter: blur(2px); }
.caixa { background: var(--surface); border: 1px solid var(--line); border-radius: 18px; max-width: 100%; max-height: calc(100vh - 32px); display: flex; flex-direction: column; box-shadow: var(--sombra); }
.topo { padding: 16px 18px 10px; }
.corpo { padding: 4px 18px 18px; overflow-y: auto; }
.fundo.lateral { place-items: stretch end; padding: 0; }
.fundo.lateral .caixa { height: 100vh; max-height: 100vh; border-radius: 18px 0 0 18px; }
</style>
