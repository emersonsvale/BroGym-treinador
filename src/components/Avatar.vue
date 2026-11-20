<script setup>
import { computed } from 'vue'
const props = defineProps({ src: String, nome: String, grande: Boolean })
const ini = computed(() => (props.nome || '?').split(' ').filter(Boolean).map((p) => p[0]).slice(0, 2).join('').toUpperCase())
</script>
<template>
  <img v-if="src" :src="src" class="avatar" :class="{ g: grande }" referrerpolicy="no-referrer" alt="" loading="lazy" />
  <span v-else class="avatar" :class="{ g: grande }">{{ ini }}</span>
</template>
