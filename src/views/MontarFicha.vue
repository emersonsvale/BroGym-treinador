<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { sb, rpc, sessao } from '../lib/supabase'
import { carregarAlunos } from '../lib/alunos'
import { treinosParaSalvar } from '../lib/ficha'
import { erro, avisar } from '../lib/util'
import FichaEditor from '../components/FichaEditor.vue'
import Modal from '../components/Modal.vue'
import Icone from '../components/Icone.vue'

const route = useRoute()
const router = useRouter()
const alunoId = route.params.id
const fichaId = ref(route.params.ficha || null)
const aluno = ref(null)
const f = reactive({ nome: 'Treino', vence: '', treinos: [] })
const carregando = ref(true)
const salvando = ref(false)

const copia = (x) => JSON.parse(JSON.stringify(x))

onMounted(async () => {
  try {
    const d = await rpc('trn_aluno', { p_aluno: alunoId })
    aluno.value = d.perfil
    const ficha = fichaId.value ? d.fichas.find((x) => x.id === fichaId.value) : null
    if (ficha) {
      f.nome = ficha.nome
      f.vence = ficha.vence_em || ''
      f.treinos = ficha.treinos.map((t) => ({ id: t.id, nome: t.nome, exercises: copia(t.exercises ?? []) }))
    } else {
      fichaId.value = null
      f.nome = 'Hipertrofia'
      f.treinos = [{ id: null, nome: 'Treino A', exercises: [] }]
      const venc = new Date(Date.now() + 42 * 86400000)
      f.vence = venc.toISOString().slice(0, 10)
    }
  } catch (e) { erro(e); router.replace('/alunos') } finally { carregando.value = false }
})

async function salvar() {
  if (!f.nome.trim()) { erro(new Error('Dê um nome pra ficha.')); return }
  if (f.treinos.some((t) => !t.exercises.length)) { erro(new Error('Todo treino precisa de pelo menos um exercício.')); return }
  salvando.value = true
  try {
    await rpc('trn_salvar_ficha', { p_aluno: alunoId, p_ficha: fichaId.value, p_nome: f.nome.trim(), p_treinos: treinosParaSalvar(f.treinos), p_vence_em: f.vence || null, p_avisar: true })
    await carregarAlunos(true)
    avisar(`Treino enviado pra ${aluno.value?.nome?.split(' ')[0] ?? 'o aluno'}. Ele recebe uma notificação.`)
    router.push(`/alunos/${alunoId}`)
  } catch (e) { erro(e) } finally { salvando.value = false }
}

// ---------- Modelos ----------
const modelos = ref([])
const escolhendo = ref(false)
async function abrirModelos() {
  escolhendo.value = true
  const { data } = await sb.from('treinador_modelos').select('id, nome, descricao, treinos, semanas').eq('treinador_id', sessao.eu.user_id).order('atualizado_em', { ascending: false })
  modelos.value = data ?? []
}
function usarModelo(m) {
  f.nome = m.nome
  f.treinos.splice(0, f.treinos.length, ...m.treinos.map((t) => ({ id: null, nome: t.nome, exercises: copia(t.exercises ?? []) })))
  if (m.semanas) f.vence = new Date(Date.now() + m.semanas * 7 * 86400000).toISOString().slice(0, 10)
  escolhendo.value = false
  avisar('Modelo carregado. Ajuste o que quiser antes de enviar.')
}
async function salvarComoModelo() {
  if (f.treinos.some((t) => !t.exercises.length)) { erro(new Error('Todo treino precisa de pelo menos um exercício.')); return }
  try {
    const treinos = treinosParaSalvar(f.treinos).map(({ nome, exercises }) => ({ nome, exercises }))
    const { error } = await sb.from('treinador_modelos').insert({ treinador_id: sessao.eu.user_id, nome: f.nome.trim(), treinos })
    if (error) throw error
    avisar('Salvo nos seus modelos.')
  } catch (e) { erro(e) }
}
</script>

<template>
  <div v-if="carregando" class="carregando"><div class="spinner" /></div>
  <div v-else class="surge">
    <RouterLink :to="`/alunos/${alunoId}`" class="btn fantasma pequeno" style="margin-bottom: 10px"><Icone nome="voltar" :tam="14" />{{ aluno?.nome }}</RouterLink>
    <div class="cabecalho">
      <div>
        <small>Treino de {{ aluno?.nome }}</small>
        <h1>{{ fichaId ? 'Editar ficha' : 'Nova ficha' }}</h1>
      </div>
      <div class="linha">
        <button class="btn" @click="abrirModelos">Usar modelo</button>
        <button class="btn" @click="salvarComoModelo">Salvar como modelo</button>
        <button class="btn primario" :disabled="salvando" @click="salvar"><Icone nome="envio" />{{ salvando ? 'Enviando…' : `Enviar pra ${aluno?.nome?.split(' ')[0] ?? 'aluno'}` }}</button>
      </div>
    </div>

    <div class="card linha" style="margin-bottom: 14px; align-items: flex-end">
      <label class="campo espaco" style="min-width: 240px">Nome da ficha<input v-model="f.nome" maxlength="60" placeholder="Hipertrofia" /></label>
      <label class="campo" style="width: 200px">Vence em<input v-model="f.vence" type="date" /></label>
      <small style="padding-bottom: 10px; max-width: 280px">Ao enviar, essa vira a ficha ativa do aluno no app. A IA do app não mexe nela.</small>
    </div>

    <FichaEditor :treinos="f.treinos" />

    <Modal v-if="escolhendo" titulo="Usar um modelo" @fechar="escolhendo = false">
      <div v-if="!modelos.length" class="vazio">Você ainda não tem modelos. Monte uma ficha e clique em “Salvar como modelo”.</div>
      <button v-for="m in modelos" :key="m.id" class="modelo" @click="usarModelo(m)">
        <strong>{{ m.nome }}</strong>
        <small>{{ m.treinos.length }} treinos<template v-if="m.semanas"> · {{ m.semanas }} semanas</template><template v-if="m.descricao"> · {{ m.descricao }}</template></small>
      </button>
    </Modal>
  </div>
</template>

<style scoped>
.modelo { display: grid; gap: 2px; width: 100%; text-align: left; padding: 12px; margin-bottom: 8px; border: 1px solid var(--line); background: var(--surface2); color: var(--text); border-radius: 12px; cursor: pointer; font: 14px Inter, sans-serif; }
.modelo:hover { border-color: var(--accent); }
</style>
