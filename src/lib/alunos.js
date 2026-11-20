import { reactive } from 'vue'
import { rpc } from './supabase'
import { diasDesde } from './ficha'

// Lista de alunos compartilhada entre as telas (recarrega a cada 60 s no máximo).
export const alunos = reactive({ lista: [], carregado: false, em: 0 })

export async function carregarAlunos(forcar = false) {
  if (!forcar && alunos.carregado && Date.now() - alunos.em < 60000) return alunos.lista
  const r = await rpc('trn_alunos')
  alunos.lista = (r ?? []).map(enriquecer)
  alunos.carregado = true
  alunos.em = Date.now()
  return alunos.lista
}

const hoje = () => new Date().toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' })

function enriquecer(a) {
  const dias = diasDesde(a.ultimo_treino)
  const treinouHoje = a.ultimo_treino && new Date(a.ultimo_treino).toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' }) === hoje()
  const vence = a.ficha?.vence_em ? Math.ceil((new Date(a.ficha.vence_em + 'T23:59:59-03:00') - Date.now()) / 86400000) : null
  let status = 'ativo'
  if (!a.ficha) status = 'sem_ficha'
  else if (dias == null || dias >= 3) status = 'parado'
  return { ...a, dias, treinouHoje, venceEm: vence, status }
}

export function atencao(lista) {
  const itens = []
  for (const a of lista) {
    if (!a.ficha) itens.push({ a, nivel: 'vermelho', texto: 'está sem ficha', acao: 'Montar' })
    else if (a.dias == null) itens.push({ a, nivel: 'ambar', texto: 'ainda não treinou', acao: 'Chamar' })
    else if (a.dias >= 3) itens.push({ a, nivel: 'vermelho', texto: `está há ${a.dias} dias sem treinar`, acao: 'Chamar' })
    if (a.feedback_novo > 0) itens.push({ a, nivel: 'ciano', texto: `mandou ${a.feedback_novo} feedback${a.feedback_novo > 1 ? 's' : ''}`, acao: 'Ver' })
    if (a.mensagens_novas > 0) itens.push({ a, nivel: 'ciano', texto: `mandou ${a.mensagens_novas} mensage${a.mensagens_novas > 1 ? 'ns' : 'm'}`, acao: 'Responder' })
    if (a.venceEm != null && a.venceEm <= 5) itens.push({ a, nivel: 'ambar', texto: a.venceEm < 0 ? 'está com a ficha vencida' : `tem ficha vencendo em ${a.venceEm} dia${a.venceEm === 1 ? '' : 's'}`, acao: 'Renovar' })
  }
  const peso = { vermelho: 0, ambar: 1, ciano: 2 }
  return itens.sort((x, y) => peso[x.nivel] - peso[y.nivel])
}
