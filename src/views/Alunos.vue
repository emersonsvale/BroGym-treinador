<script setup>
import { ref, computed, onMounted } from 'vue'
import { sessao } from '../lib/supabase'
import { alunos, carregarAlunos } from '../lib/alunos'
import { erro } from '../lib/util'
import Icone from '../components/Icone.vue'
import TabelaAlunos from '../components/TabelaAlunos.vue'

const busca = ref('')
const filtro = ref('todos')
const carregando = ref(!alunos.carregado)

onMounted(async () => {
  try { await carregarAlunos(true) } catch (e) { erro(e) } finally { carregando.value = false }
})

const filtros = computed(() => [
  { id: 'todos', nome: 'Todos', n: alunos.lista.length },
  { id: 'ativo', nome: 'Em dia', n: alunos.lista.filter((a) => a.status === 'ativo').length },
  { id: 'parado', nome: 'Parados', n: alunos.lista.filter((a) => a.status === 'parado').length },
  { id: 'sem_ficha', nome: 'Sem ficha', n: alunos.lista.filter((a) => a.status === 'sem_ficha').length },
  { id: 'vencendo', nome: 'Ficha vencendo', n: alunos.lista.filter((a) => a.venceEm != null && a.venceEm <= 5).length },
])

const lista = computed(() => {
  const b = busca.value.trim().toLowerCase()
  return alunos.lista.filter((a) => {
    if (b && !a.nome.toLowerCase().includes(b) && !(a.usuario || '').toLowerCase().includes(b)) return false
    if (filtro.value === 'vencendo') return a.venceEm != null && a.venceEm <= 5
    return filtro.value === 'todos' || a.status === filtro.value
  })
})
</script>

<template>
  <div class="surge">
    <div class="cabecalho">
      <div>
        <h1>Alunos</h1>
        <p>{{ alunos.lista.length }} de {{ sessao.eu.limite }} vagas da sua faixa.</p>
      </div>
      <RouterLink to="/convidar" class="btn primario"><Icone nome="convidar" />Convidar aluno</RouterLink>
    </div>

    <div class="linha" style="margin-bottom: 14px">
      <label style="position: relative; flex: 1 1 260px; max-width: 360px">
        <span class="sr">Buscar aluno</span>
        <input v-model="busca" type="search" placeholder="Buscar aluno" style="padding-left: 36px" />
        <span style="position: absolute; left: 11px; top: 11px; color: var(--muted)"><Icone nome="busca" :tam="16" /></span>
      </label>
      <div class="linha" style="gap: 6px">
        <button v-for="f in filtros" :key="f.id" class="btn pequeno" :class="{ primario: filtro === f.id }" :aria-pressed="filtro === f.id" @click="filtro = f.id">{{ f.nome }} {{ f.n }}</button>
      </div>
    </div>

    <div v-if="carregando" class="carregando"><div class="spinner" /></div>
    <TabelaAlunos v-else :lista="lista" />
  </div>
</template>

<style scoped>
.sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
</style>
