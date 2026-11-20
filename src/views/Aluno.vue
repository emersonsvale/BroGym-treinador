<script setup>
import { ref, reactive, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { sb, rpc, sessao } from '../lib/supabase'
import { carregarAlunos } from '../lib/alunos'
import { erro, avisar, confirmar, data, dataHora, desde } from '../lib/util'
import { letra } from '../lib/ficha'
import Avatar from '../components/Avatar.vue'
import Icone from '../components/Icone.vue'
import Kpi from '../components/Kpi.vue'
import Linha from '../components/Linha.vue'

const route = useRoute()
const router = useRouter()
const id = route.params.id
const aba = ref(route.query.aba || 'geral')
const d = ref(null)
const carregando = ref(true)

async function carregar() {
  try { d.value = await rpc('trn_aluno', { p_aluno: id }) } catch (e) { erro(e); router.replace('/alunos') } finally { carregando.value = false }
}
onMounted(carregar)

const perfil = computed(() => d.value?.perfil ?? {})
const ficha = computed(() => d.value?.fichas?.find((f) => f.ativo) ?? d.value?.fichas?.[0] ?? null)
const sessoes = computed(() => d.value?.sessoes ?? [])
const treinos30 = computed(() => sessoes.value.filter((s) => Date.now() - new Date(s.fim) < 30 * 86400000).length)
const naoLidos = computed(() => (d.value?.feedbacks ?? []).filter((f) => !f.lido).length)
const nomeTreino = (wid) => ficha.value?.treinos?.find((t) => t.id === wid)?.nome ?? (sessoes.value.find((s) => s.workout_id === wid)?.exercicios?.[0]?.workout_name) ?? 'Treino'

// Cargas: maior carga por sessão de cada exercício.
const exercicios = computed(() => {
  const m = new Map()
  for (const s of [...sessoes.value].reverse()) {
    for (const e of s.exercicios ?? []) {
      const max = Math.max(0, ...(e.series ?? []).map((x) => Number(x.weight) || 0))
      if (!max) continue
      const nome = e.exercise_name || 'Exercício'
      if (!m.has(nome)) m.set(nome, [])
      m.get(nome).push({ x: new Date(s.fim).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' }), y: max })
    }
  }
  return [...m.entries()].filter(([, p]) => p.length >= 1).sort((a, b) => b[1].length - a[1].length)
})
const exSel = ref('')
const pontosCarga = computed(() => (exercicios.value.find(([n]) => n === (exSel.value || exercicios.value[0]?.[0]))?.[1] ?? []))
const pontosPeso = computed(() => (d.value?.pesos ?? []).map((p) => ({ x: new Date(p.dia + 'T12:00:00').toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' }), y: Number(p.kg) })))

function resumoSessao(s) {
  const ex = s.exercicios ?? []
  const series = ex.reduce((n, e) => n + (e.series?.length ?? 0), 0)
  const pulados = ex.filter((e) => !e.completed).length
  return { ex: ex.length, series, pulados }
}

async function remover() {
  if (!(await confirmar({ titulo: 'Remover aluno', texto: `${perfil.value.nome} sai da sua lista. A ficha e o histórico continuam com ele, e o PRO pelo treinador acaba em 7 dias.`, botao: 'Remover', perigo: true }))) return
  try { await rpc('trn_remover_aluno', { p_aluno: id }); await carregarAlunos(true); avisar('Aluno removido.'); router.replace('/alunos') } catch (e) { erro(e) }
}

async function abrirAba(a) {
  aba.value = a
  router.replace({ query: a === 'geral' ? {} : { aba: a } })
  if (a === 'feedbacks' && naoLidos.value) {
    try { await rpc('trn_marcar_feedbacks_lidos', { p_aluno: id }); d.value.feedbacks.forEach((f) => (f.lido = true)) } catch { /* ok */ }
  }
  if (a === 'chat') abrirChat()
}

// ---------- Chat ----------
const msgs = ref([])
const texto = ref('')
const enviando = ref(false)
const caixa = ref(null)
let timer
async function lerMsgs() {
  const { data: r } = await sb.from('treinador_mensagens').select('id, autor, texto, criado_em, lida_em').eq('treinador_id', sessao.eu.user_id).eq('aluno_id', id).order('criado_em', { ascending: false }).limit(100)
  const novo = (r ?? []).reverse()
  const mudou = novo.length !== msgs.value.length
  msgs.value = novo
  if (mudou) { await nextTick(); caixa.value?.scrollTo({ top: 1e9 }) }
  if (novo.some((m) => m.autor === id && !m.lida_em)) rpc('trn_ler_mensagens', { p_aluno: id }).catch(() => {})
}
function abrirChat() { lerMsgs(); clearInterval(timer); timer = setInterval(lerMsgs, 10000) }
onUnmounted(() => clearInterval(timer))
async function enviar() {
  const t = texto.value.trim()
  if (!t) return
  enviando.value = true
  try { await rpc('trn_mandar_mensagem', { p_texto: t, p_aluno: id }); texto.value = ''; await lerMsgs() } catch (e) { erro(e) } finally { enviando.value = false }
}

// ---------- Anamnese ----------
const perguntas = [
  { k: 'objetivo', r: 'Objetivo' },
  { k: 'nivel', r: 'Nível (iniciante, intermediário, avançado)' },
  { k: 'frequencia', r: 'Dias e horários disponíveis' },
  { k: 'lesoes', r: 'Lesões, dores ou limitações' },
  { k: 'saude', r: 'Condições de saúde e remédios' },
  { k: 'historico', r: 'Histórico de treino' },
  { k: 'observacoes', r: 'Observações' },
]
const anam = reactive({})
const salvandoAnam = ref(false)
const iniciarAnamnese = () => Object.assign(anam, Object.fromEntries(perguntas.map((p) => [p.k, d.value?.anamnese?.[p.k] ?? ''])))
async function salvarAnamnese() {
  salvandoAnam.value = true
  try { await rpc('trn_salvar_anamnese', { p_aluno: id, p_respostas: { ...anam } }); d.value.anamnese = { ...anam }; avisar('Anamnese salva.') } catch (e) { erro(e) } finally { salvandoAnam.value = false }
}
</script>

<template>
  <div v-if="carregando" class="carregando"><div class="spinner" /></div>
  <div v-else-if="d" class="surge">
    <RouterLink to="/alunos" class="btn fantasma pequeno" style="margin-bottom: 10px"><Icone nome="voltar" :tam="14" />Alunos</RouterLink>

    <div class="cabecalho">
      <div class="linha" style="gap: 14px; flex-wrap: nowrap">
        <Avatar :src="perfil.avatar_url" :nome="perfil.nome" grande />
        <div>
          <h1>{{ perfil.nome }}</h1>
          <div class="linha" style="gap: 6px; margin-top: 4px">
            <small v-if="perfil.usuario">@{{ perfil.usuario }}</small>
            <small>· seu aluno desde {{ data(d.desde) }}</small>
            <span v-if="sessao.eu.plano_vigente !== 'gratis'" class="tag ouro">PRO pelo treinador</span>
          </div>
        </div>
      </div>
      <div class="linha">
        <button class="btn" @click="abrirAba('chat')"><Icone nome="chat" />Chat</button>
        <RouterLink :to="`/alunos/${id}/ficha/${ficha?.id ?? ''}`" class="btn primario"><Icone nome="editar" />{{ ficha ? 'Editar treino' : 'Montar treino' }}</RouterLink>
      </div>
    </div>

    <div class="abas" role="tablist">
      <button class="aba" :class="{ ativa: aba === 'geral' }" role="tab" :aria-selected="aba === 'geral'" @click="abrirAba('geral')">Visão geral</button>
      <button class="aba" :class="{ ativa: aba === 'historico' }" role="tab" :aria-selected="aba === 'historico'" @click="abrirAba('historico')">Treinos feitos</button>
      <button class="aba" :class="{ ativa: aba === 'feedbacks' }" role="tab" :aria-selected="aba === 'feedbacks'" @click="abrirAba('feedbacks')">Feedbacks<span v-if="naoLidos" class="tag vermelho">{{ naoLidos }}</span></button>
      <button class="aba" :class="{ ativa: aba === 'chat' }" role="tab" :aria-selected="aba === 'chat'" @click="abrirAba('chat')">Chat</button>
      <button class="aba" :class="{ ativa: aba === 'anamnese' }" role="tab" :aria-selected="aba === 'anamnese'" @click="iniciarAnamnese(); abrirAba('anamnese')">Anamnese</button>
    </div>

    <!-- Visão geral -->
    <template v-if="aba === 'geral'">
      <div class="grade g4" style="margin-bottom: 16px">
        <Kpi rotulo="Treinos em 30 dias" :valor="treinos30" />
        <Kpi rotulo="Sequência" :valor="`${perfil.sequencia} ${perfil.sequencia === 1 ? 'dia' : 'dias'}`" :detalhe="`recorde: ${perfil.recorde_sequencia}`" />
        <Kpi rotulo="Meta por semana" :valor="`${perfil.meta_semana}×`" />
        <Kpi rotulo="Último treino" :valor="sessoes[0] ? desde(sessoes[0].fim) : '—'" :detalhe="sessoes[0] ? dataHora(sessoes[0].fim) : 'ainda não treinou'" />
      </div>

      <div class="duas">
        <div class="coluna" style="gap: 16px">
          <section class="card">
            <div class="linha entre" style="margin-bottom: 12px">
              <h2>Ficha atual</h2>
              <span v-if="ficha?.vence_em" class="tag ambar">vence em {{ data(ficha.vence_em + 'T12:00:00') }}</span>
            </div>
            <div v-if="!ficha" class="vazio" style="padding: 18px">
              Ainda sem treino montado por você.<br />
              <RouterLink :to="`/alunos/${id}/ficha/`" class="btn primario" style="margin-top: 10px">Montar treino</RouterLink>
            </div>
            <template v-else>
              <h3 style="margin-bottom: 8px">{{ ficha.nome }}</h3>
              <div v-for="(t, i) in ficha.treinos" :key="t.id" class="treino-linha">
                <span class="letra">{{ letra(i) }}</span>
                <span class="espaco"><strong>{{ t.nome }}</strong><br /><small>{{ t.exercises.length }} exercícios · {{ t.exercises.slice(0, 3).map((e) => e.name).join(', ') }}{{ t.exercises.length > 3 ? '…' : '' }}</small></span>
              </div>
            </template>
          </section>

          <section class="card">
            <div class="linha entre" style="margin-bottom: 8px">
              <h2>Evolução de carga</h2>
              <select v-if="exercicios.length" v-model="exSel" style="width: auto; max-width: 260px" aria-label="Exercício">
                <option value="">{{ exercicios[0][0] }}</option>
                <option v-for="e in exercicios.slice(1)" :key="e[0]" :value="e[0]">{{ e[0] }}</option>
              </select>
            </div>
            <Linha :pontos="pontosCarga" unidade=" kg" />
          </section>
        </div>

        <div class="coluna" style="gap: 16px">
          <section class="card">
            <h2 style="margin-bottom: 8px">Peso</h2>
            <div v-if="d.pesos === null" class="muted"><Icone nome="bloqueio" :tam="14" /> O aluno não liberou peso e medidas.</div>
            <Linha v-else :pontos="pontosPeso" unidade=" kg" :altura="130" />
          </section>
          <section class="card">
            <h2 style="margin-bottom: 10px">Últimos feedbacks</h2>
            <div v-if="!d.feedbacks.length" class="muted">Nenhum feedback ainda.</div>
            <div v-for="f in d.feedbacks.slice(0, 3)" :key="f.id" class="fb">
              <span class="nota" :class="{ alto: f.esforco >= 8 }">{{ f.esforco }}</span>
              <div class="espaco">
                <div v-if="f.comentario" class="texto-quebra">“{{ f.comentario }}”</div>
                <small>{{ dataHora(f.criado_em) }}<template v-if="f.incomodos?.length"> · incomodou: {{ f.incomodos.join(', ') }}</template></small>
              </div>
            </div>
          </section>
          <section class="card plano">
            <small><Icone nome="bloqueio" :tam="13" /> {{ perfil.nome.split(' ')[0] }} liberou: treinos e cargas<template v-if="d.permissoes.medidas">, peso e medidas</template><template v-if="d.permissoes.fotos">, fotos</template><template v-if="d.permissoes.dieta">, dieta</template>.</small>
            <button class="btn perigo pequeno" style="margin-top: 10px" @click="remover">Remover aluno</button>
          </section>
        </div>
      </div>
    </template>

    <!-- Histórico -->
    <template v-else-if="aba === 'historico'">
      <div v-if="!sessoes.length" class="vazio card">Nenhum treino concluído ainda.</div>
      <div v-for="s in sessoes" :key="s.id" class="card sessao">
        <div class="linha entre">
          <strong>{{ nomeTreino(s.workout_id) }}</strong>
          <small>{{ dataHora(s.fim) }} · {{ s.minutos ?? '—' }} min · {{ resumoSessao(s).series }} séries</small>
        </div>
        <span v-if="resumoSessao(s).pulados" class="tag ambar" style="margin-top: 6px">{{ resumoSessao(s).pulados }} exercício(s) incompleto(s)</span>
        <table style="margin-top: 8px">
          <tbody>
            <tr v-for="(e, k) in s.exercicios" :key="k">
              <td style="padding: 6px 0; width: 40%">{{ e.exercise_name }}</td>
              <td style="padding: 6px 0" class="muted">
                <span v-for="(x, j) in e.series" :key="j" class="serie">{{ x.weight ? `${x.weight} kg` : '—' }} × {{ x.reps ?? '—' }}</span>
                <span v-if="!e.series?.length" class="tag">pulado</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <!-- Feedbacks -->
    <template v-else-if="aba === 'feedbacks'">
      <div v-if="!d.feedbacks.length" class="vazio card">O aluno ainda não mandou feedback. Ele responde no fim de cada treino.</div>
      <div v-for="f in d.feedbacks" :key="f.id" class="card fb" style="margin-bottom: 10px">
        <span class="nota" :class="{ alto: f.esforco >= 8 }">{{ f.esforco }}</span>
        <div class="espaco">
          <div v-if="f.comentario" class="texto-quebra" style="margin-bottom: 4px">“{{ f.comentario }}”</div>
          <small>Esforço {{ f.esforco }}/10 · {{ dataHora(f.criado_em) }}</small>
          <div v-if="f.incomodos?.length" class="linha" style="gap: 4px; margin-top: 6px"><span v-for="x in f.incomodos" :key="x" class="tag vermelho">{{ x }}</span></div>
        </div>
      </div>
    </template>

    <!-- Chat -->
    <template v-else-if="aba === 'chat'">
      <div class="card chat">
        <div ref="caixa" class="mensagens">
          <div v-if="!msgs.length" class="vazio">Mande a primeira mensagem pro {{ perfil.nome.split(' ')[0] }}. Ele recebe uma notificação no celular.</div>
          <div v-for="m in msgs" :key="m.id" class="msg" :class="{ minha: m.autor !== id }">
            <div class="texto-quebra">{{ m.texto }}</div>
            <small>{{ dataHora(m.criado_em) }}</small>
          </div>
        </div>
        <form class="linha" style="flex-wrap: nowrap" @submit.prevent="enviar">
          <label class="espaco"><span class="sr">Mensagem</span><input v-model="texto" maxlength="2000" placeholder="Escreva uma mensagem" /></label>
          <button class="btn primario" :disabled="enviando || !texto.trim()"><Icone nome="envio" />Enviar</button>
        </form>
      </div>
    </template>

    <!-- Anamnese -->
    <template v-else-if="aba === 'anamnese'">
      <div class="card coluna" style="max-width: 760px">
        <p class="muted" style="margin: 0">Só você vê. Use pra montar o treino e quando pedir pra IA sugerir um rascunho.</p>
        <label v-for="p in perguntas" :key="p.k" class="campo">{{ p.r }}<textarea v-model="anam[p.k]" rows="2" maxlength="1000" /></label>
        <button class="btn primario" style="align-self: flex-start" :disabled="salvandoAnam" @click="salvarAnamnese">{{ salvandoAnam ? 'Salvando…' : 'Salvar anamnese' }}</button>
      </div>
    </template>
  </div>
</template>

<style scoped>
.duas { display: grid; grid-template-columns: minmax(0, 1fr) 360px; gap: 16px; align-items: start; }
@media (max-width: 1100px) { .duas { grid-template-columns: 1fr; } }
.treino-linha { display: flex; gap: 12px; align-items: center; padding: 8px 0; border-top: 1px solid var(--line); }
.letra { width: 34px; height: 34px; border-radius: 10px; background: var(--accent); color: #fff; font-weight: 800; display: grid; place-items: center; flex: none; }
.fb { display: flex; gap: 12px; align-items: flex-start; padding: 8px 0; }
.nota { width: 40px; height: 40px; border-radius: 12px; background: var(--surface2); font: 800 18px 'Inter Tight', sans-serif; display: grid; place-items: center; flex: none; }
.nota.alto { background: color-mix(in srgb, var(--amber) 18%, transparent); color: var(--amber); }
.sessao { margin-bottom: 10px; }
.sessao td { border-bottom: 1px solid var(--line); }
.serie { display: inline-block; margin-right: 10px; font-variant-numeric: tabular-nums; }
.chat { display: flex; flex-direction: column; gap: 12px; max-width: 760px; height: min(70vh, 640px); }
.mensagens { flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; padding-right: 4px; }
.msg { align-self: flex-start; max-width: 75%; background: var(--surface2); padding: 10px 12px; border-radius: 14px 14px 14px 4px; }
.msg.minha { align-self: flex-end; background: var(--accent-soft); border-radius: 14px 14px 4px 14px; }
.msg small { display: block; margin-top: 4px; font-size: 11px; }
.sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
</style>
