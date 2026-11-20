<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { sb, sessao } from '../lib/supabase'
import { treinosParaSalvar } from '../lib/ficha'
import { erro, avisar } from '../lib/util'
import FichaEditor from '../components/FichaEditor.vue'
import EnviarModelo from '../components/EnviarModelo.vue'
import Icone from '../components/Icone.vue'

const route = useRoute()
const router = useRouter()
const id = ref(route.params.id === 'novo' ? null : route.params.id)
const f = reactive({ nome: '', descricao: '', semanas: 6, treinos: [], usos: 0 })
const carregando = ref(true)
const salvando = ref(false)
const enviando = ref(null)

onMounted(async () => {
  if (id.value) {
    const { data, error } = await sb.from('treinador_modelos').select('*').eq('id', id.value).maybeSingle()
    if (error || !data) { erro(error || new Error('Modelo não encontrado.')); router.replace('/modelos'); return }
    Object.assign(f, { nome: data.nome, descricao: data.descricao || '', semanas: data.semanas || '', usos: data.usos })
    f.treinos = data.treinos.map((t) => ({ id: null, nome: t.nome, exercises: t.exercises ?? [] }))
  } else {
    f.nome = 'Hipertrofia iniciante'
    f.treinos = [{ id: null, nome: 'Treino A', exercises: [] }]
  }
  carregando.value = false
})

async function salvar() {
  if (!f.nome.trim()) return erro(new Error('Dê um nome pro modelo.'))
  if (f.treinos.some((t) => !t.exercises.length)) return erro(new Error('Todo treino precisa de pelo menos um exercício.'))
  salvando.value = true
  try {
    const dados = {
      treinador_id: sessao.eu.user_id,
      nome: f.nome.trim(),
      descricao: f.descricao.trim() || null,
      semanas: f.semanas ? Math.min(52, Math.max(1, parseInt(f.semanas, 10))) : null,
      treinos: treinosParaSalvar(f.treinos).map(({ nome, exercises }) => ({ nome, exercises })),
      atualizado_em: new Date().toISOString(),
    }
    if (id.value) {
      const { error } = await sb.from('treinador_modelos').update(dados).eq('id', id.value)
      if (error) throw error
    } else {
      const { data, error } = await sb.from('treinador_modelos').insert(dados).select('id').single()
      if (error) throw error
      id.value = data.id
      router.replace('/modelos/' + data.id)
    }
    avisar('Modelo salvo.')
    return true
  } catch (e) { erro(e) } finally { salvando.value = false }
}

async function salvarEEnviar() {
  if (await salvar()) enviando.value = { id: id.value, nome: f.nome, semanas: f.semanas }
}
</script>

<template>
  <div v-if="carregando" class="carregando"><div class="spinner" /></div>
  <div v-else class="surge">
    <RouterLink to="/modelos" class="btn fantasma pequeno" style="margin-bottom: 10px"><Icone nome="voltar" :tam="14" />Modelos</RouterLink>
    <div class="cabecalho">
      <div>
        <small>Modelo de treino</small>
        <h1>{{ id ? f.nome : 'Novo modelo' }}</h1>
      </div>
      <div class="linha">
        <button class="btn" :disabled="salvando" @click="salvar">{{ salvando ? 'Salvando…' : 'Salvar' }}</button>
        <button class="btn primario" :disabled="salvando" @click="salvarEEnviar"><Icone nome="envio" />Salvar e enviar</button>
      </div>
    </div>

    <div class="card linha" style="margin-bottom: 14px; align-items: flex-end">
      <label class="campo espaco" style="min-width: 220px">Nome<input v-model="f.nome" maxlength="80" /></label>
      <label class="campo" style="width: 140px">Semanas<input v-model="f.semanas" inputmode="numeric" placeholder="6" /></label>
      <label class="campo espaco" style="min-width: 260px">Descrição (opcional)<input v-model="f.descricao" maxlength="300" placeholder="Pra quem está começando, 4× por semana" /></label>
    </div>

    <FichaEditor :treinos="f.treinos" />

    <EnviarModelo v-if="enviando" :modelo="enviando" @fechar="enviando = null" />
  </div>
</template>
