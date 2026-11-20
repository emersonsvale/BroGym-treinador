<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { sessao } from '../lib/supabase'
import { alunos, carregarAlunos, atencao } from '../lib/alunos'
import { erro } from '../lib/util'
import Kpi from '../components/Kpi.vue'
import Avatar from '../components/Avatar.vue'
import Icone from '../components/Icone.vue'
import TabelaAlunos from '../components/TabelaAlunos.vue'

const router = useRouter()
const carregando = ref(!alunos.carregado)

onMounted(async () => {
  try { await carregarAlunos(true) } catch (e) { erro(e) } finally { carregando.value = false }
})

const lista = computed(() => alunos.lista)
const hoje = computed(() => lista.value.filter((a) => a.treinouHoje).length)
const parados = computed(() => lista.value.filter((a) => a.status === 'parado').length)
const novidades = computed(() => lista.value.reduce((s, a) => s + (a.feedback_novo || 0) + (a.mensagens_novas || 0), 0))
const itens = computed(() => atencao(lista.value).slice(0, 8))
const recentes = computed(() => [...lista.value].sort((a, b) => new Date(b.ultimo_treino || 0) - new Date(a.ultimo_treino || 0)).slice(0, 8))

const saudacao = (() => {
  const h = Number(new Date().toLocaleString('en-US', { timeZone: 'America/Sao_Paulo', hour: 'numeric', hour12: false }))
  return h < 12 ? 'Bom dia' : h < 18 ? 'Boa tarde' : 'Boa noite'
})()
const primeiroNome = computed(() => (sessao.eu?.nome || '').replace(/^(prof\.?|profa\.?|personal|coach)\s+/i, '').split(' ')[0])
const dataHoje = new Date().toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo', weekday: 'long', day: 'numeric', month: 'long' })
</script>

<template>
  <div class="surge">
    <div class="cabecalho">
      <div>
        <small style="text-transform: capitalize">{{ dataHoje }}</small>
        <h1>{{ saudacao }}, {{ primeiroNome }}</h1>
      </div>
      <div class="linha">
        <RouterLink to="/modelos" class="btn">Modelos de treino</RouterLink>
        <RouterLink to="/convidar" class="btn primario"><Icone nome="convidar" />Convidar aluno</RouterLink>
      </div>
    </div>

    <div v-if="carregando" class="carregando"><div class="spinner" /></div>

    <template v-else-if="!lista.length">
      <div class="card boas-vindas">
        <h2>Seu primeiro aluno está a um link de distância</h2>
        <p class="muted">Mande seu convite pelo WhatsApp. Quando o aluno instalar o BroGym e aceitar, ele aparece aqui e você já monta o treino dele.</p>
        <div class="linha">
          <RouterLink to="/convidar" class="btn primario grande">Pegar meu convite</RouterLink>
          <RouterLink to="/modelos" class="btn grande">Criar um modelo de treino</RouterLink>
        </div>
      </div>
    </template>

    <template v-else>
      <div class="grade g4" style="margin-bottom: 18px">
        <Kpi rotulo="Alunos ativos" :valor="`${lista.length} de ${sessao.eu.limite}`" destaque />
        <Kpi rotulo="Treinaram hoje" :valor="hoje" />
        <Kpi rotulo="Parados há 3+ dias" :valor="parados" />
        <Kpi rotulo="Feedbacks e mensagens" :valor="novidades" />
      </div>

      <div class="duas">
        <section>
          <div class="linha entre" style="margin-bottom: 10px">
            <h2>Alunos</h2>
            <RouterLink to="/alunos" class="btn fantasma pequeno">Ver todos <Icone nome="seta" :tam="14" /></RouterLink>
          </div>
          <TabelaAlunos :lista="recentes" />
        </section>

        <section class="card">
          <h2 style="margin-bottom: 12px">Precisa de atenção</h2>
          <div v-if="!itens.length" class="muted" style="padding: 8px 0">Tudo em dia. Bom trabalho!</div>
          <button v-for="(i, k) in itens" :key="k" class="aviso-linha" @click="router.push('/alunos/' + i.a.id)">
            <span class="ponto" :class="i.nivel" />
            <Avatar :src="i.a.avatar_url" :nome="i.a.nome" />
            <span class="espaco" style="text-align: left"><strong>{{ i.a.nome.split(' ')[0] }}</strong> {{ i.texto }}</span>
            <span class="tag">{{ i.acao }}</span>
          </button>
        </section>
      </div>
    </template>
  </div>
</template>

<style scoped>
.duas { display: grid; grid-template-columns: minmax(0, 1fr) 340px; gap: 18px; align-items: start; }
@media (max-width: 1100px) { .duas { grid-template-columns: 1fr; } }
.boas-vindas { display: grid; gap: 12px; padding: 28px; background: linear-gradient(140deg, var(--accent-soft), var(--surface) 70%); }
.boas-vindas p { margin: 0; max-width: 560px; }
.aviso-linha { display: flex; align-items: center; gap: 10px; width: 100%; padding: 10px 6px; border: 0; border-bottom: 1px solid var(--line); background: none; color: var(--text); font: 13px Inter, sans-serif; cursor: pointer; border-radius: 8px; }
.aviso-linha:last-child { border-bottom: 0; }
.aviso-linha:hover { background: var(--surface2); }
.ponto { width: 8px; height: 8px; border-radius: 50%; flex: none; }
.ponto.vermelho { background: var(--accent); }
.ponto.ambar { background: var(--amber); }
.ponto.ciano { background: var(--cyan); }
</style>
