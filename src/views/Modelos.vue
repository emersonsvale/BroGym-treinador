<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { sb, sessao } from '../lib/supabase'
import { erro, avisar, confirmar, data } from '../lib/util'
import Icone from '../components/Icone.vue'
import EnviarModelo from '../components/EnviarModelo.vue'

const router = useRouter()
const lista = ref([])
const carregando = ref(true)
const enviando = ref(null)

async function carregar() {
  const { data: r, error } = await sb.from('treinador_modelos').select('id, nome, descricao, semanas, treinos, usos, atualizado_em').eq('treinador_id', sessao.eu.user_id).order('atualizado_em', { ascending: false })
  if (error) erro(error)
  lista.value = r ?? []
  carregando.value = false
}
onMounted(carregar)

async function apagar(m) {
  if (!(await confirmar({ titulo: 'Apagar modelo', texto: `“${m.nome}” sai dos seus modelos. Quem já recebeu continua com a cópia dele.`, botao: 'Apagar', perigo: true }))) return
  const { error } = await sb.from('treinador_modelos').delete().eq('id', m.id)
  if (error) return erro(error)
  avisar('Modelo apagado.')
  carregar()
}
</script>

<template>
  <div class="surge">
    <div class="cabecalho">
      <div>
        <h1>Modelos de treino</h1>
        <p>Monte uma vez e mande pra quantos alunos quiser. Cada um recebe uma cópia que você ajusta depois.</p>
      </div>
      <button class="btn primario" @click="router.push('/modelos/novo')"><Icone nome="mais" />Novo modelo</button>
    </div>

    <div v-if="carregando" class="carregando"><div class="spinner" /></div>
    <div v-else-if="!lista.length" class="card vazio">
      Nenhum modelo ainda.<br />
      <button class="btn primario" style="margin-top: 12px" @click="router.push('/modelos/novo')">Criar o primeiro</button>
    </div>
    <div v-else class="grade g3">
      <div v-for="m in lista" :key="m.id" class="card modelo">
        <div class="linha" style="flex-wrap: nowrap">
          <span class="selo">{{ m.treinos.map((_, i) => String.fromCharCode(65 + i)).join('') }}</span>
          <div class="espaco" style="min-width: 0">
            <h3 class="corta" style="max-width: 100%">{{ m.nome }}</h3>
            <small>{{ m.treinos.length }} treinos<template v-if="m.semanas"> · {{ m.semanas }} semanas</template></small>
          </div>
        </div>
        <small v-if="m.descricao" class="texto-quebra">{{ m.descricao }}</small>
        <small>{{ m.usos ? `Enviado ${m.usos} ${m.usos === 1 ? 'vez' : 'vezes'}` : 'Ainda não enviado' }} · editado em {{ data(m.atualizado_em) }}</small>
        <div class="linha" style="margin-top: auto">
          <button class="btn primario pequeno" @click="enviando = m"><Icone nome="envio" :tam="14" />Enviar</button>
          <button class="btn pequeno" @click="router.push('/modelos/' + m.id)"><Icone nome="editar" :tam="14" />Editar</button>
          <button class="btn fantasma pequeno" :aria-label="`Apagar ${m.nome}`" @click="apagar(m)"><Icone nome="lixo" :tam="14" /></button>
        </div>
      </div>
    </div>

    <EnviarModelo v-if="enviando" :modelo="enviando" @fechar="enviando = null" @enviou="carregar" />
  </div>
</template>

<style scoped>
.modelo { display: flex; flex-direction: column; gap: 8px; min-height: 170px; }
.selo { min-width: 44px; height: 44px; padding: 0 8px; border-radius: 12px; background: var(--accent-soft); color: var(--accent-text); font-weight: 800; display: grid; place-items: center; font-size: 13px; }
</style>
