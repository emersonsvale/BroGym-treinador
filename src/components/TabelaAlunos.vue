<script setup>
import { useRouter } from 'vue-router'
import Avatar from './Avatar.vue'
import { desde } from '../lib/util'
defineProps({ lista: Array })
const router = useRouter()
const ultimo = (a) => (a.ultimo_treino ? (a.treinouHoje ? 'hoje' : `há ${desde(a.ultimo_treino)}`) : 'nunca')
</script>

<template>
  <div class="tabela-wrap">
    <table>
      <thead>
        <tr><th>Aluno</th><th>Ficha</th><th>Último treino</th><th>Semana</th><th class="num">Sequência</th></tr>
      </thead>
      <tbody>
        <tr v-for="a in lista" :key="a.id" class="clicavel" tabindex="0" @click="router.push('/alunos/' + a.id)" @keydown.enter="router.push('/alunos/' + a.id)">
          <td>
            <div class="linha" style="flex-wrap: nowrap">
              <Avatar :src="a.avatar_url" :nome="a.nome" />
              <div style="min-width: 0">
                <div class="corta" style="font-weight: 700; max-width: 220px">{{ a.nome }}</div>
                <small v-if="a.usuario">@{{ a.usuario }}</small>
              </div>
              <span v-if="a.mensagens_novas" class="tag ciano" title="Mensagens novas">{{ a.mensagens_novas }} msg</span>
              <span v-if="a.feedback_novo" class="tag ciano" title="Feedbacks novos">{{ a.feedback_novo }} feedback</span>
            </div>
          </td>
          <td>
            <span v-if="a.ficha">{{ a.ficha.nome }}
              <span v-if="a.venceEm != null && a.venceEm <= 5" class="tag ambar" style="margin-left: 4px">{{ a.venceEm < 0 ? 'vencida' : `vence em ${a.venceEm} d` }}</span>
            </span>
            <span v-else class="tag vermelho">sem ficha</span>
          </td>
          <td :style="{ color: a.status === 'parado' ? 'var(--accent-text)' : a.treinouHoje ? 'var(--success)' : 'inherit' }">{{ a.treinando_agora ? 'treinando agora' : ultimo(a) }}</td>
          <td>
            <span class="semana" :title="`${a.treinos_semana} de ${a.meta_semana} treinos nesta semana`">
              <span v-for="i in Math.max(a.meta_semana, a.treinos_semana)" :key="i" :class="{ on: i <= a.treinos_semana }" />
            </span>
          </td>
          <td class="num" :style="{ color: a.sequencia ? 'var(--gold)' : 'var(--muted)', fontWeight: 700 }">{{ a.sequencia }} {{ a.sequencia === 1 ? 'dia' : 'dias' }}</td>
        </tr>
        <tr v-if="!lista.length"><td colspan="5" class="vazio">Nenhum aluno aqui.</td></tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.semana { display: inline-flex; gap: 3px; }
.semana span { width: 12px; height: 12px; border-radius: 4px; background: var(--surface2); border: 1px solid var(--line); }
.semana span.on { background: var(--accent); border-color: var(--accent); }
</style>
