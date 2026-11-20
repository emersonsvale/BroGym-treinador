<script setup>
import { ref, watch, computed } from 'vue'
import { confirmacao as c } from '../lib/util'
import Modal from './Modal.vue'

const digitado = ref('')
watch(() => c.aberta, (v) => { if (v) digitado.value = '' })
const liberado = computed(() => !c.digitar || digitado.value.trim().toUpperCase() === c.digitar.toUpperCase())
const fechar = (r) => { c.aberta = false; c.resolver?.(r) }
</script>
<template>
  <Modal v-if="c.aberta" :titulo="c.titulo" largura="440px" @fechar="fechar(false)">
    <p class="texto-quebra" style="margin: 0 0 14px; color: var(--muted)">{{ c.texto }}</p>
    <label v-if="c.digitar" class="campo" style="margin-bottom: 14px">
      Digite <strong style="color: var(--text)">{{ c.digitar }}</strong> pra confirmar
      <input v-model="digitado" autofocus />
    </label>
    <div class="linha" style="justify-content: flex-end">
      <button class="btn fantasma" @click="fechar(false)">Cancelar</button>
      <button class="btn" :class="c.perigo ? 'perigo' : 'primario'" :disabled="!liberado" @click="fechar(true)">{{ c.botao }}</button>
    </div>
  </Modal>
</template>
