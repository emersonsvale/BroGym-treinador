import { createClient } from '@supabase/supabase-js'
import { reactive } from 'vue'
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config'

export const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    flowType: 'pkce',
    storageKey: 'brogym-treinador-auth',
  },
})

// Estado da sessão: user = conta logada; eu = perfil de treinador (null se ainda não ativou).
export const sessao = reactive({ carregando: true, user: null, eu: null })

const traduzir = (msg = '') => {
  const m = {
    NAO_TREINADOR: 'Ative o modo Treinador primeiro.',
    ALUNO_NAO_E_SEU: 'Esse aluno não está mais na sua lista.',
    FICHA_VAZIA: 'Adicione pelo menos um treino.',
    TREINO_SEM_EXERCICIO: 'Todo treino precisa de pelo menos um exercício.',
    MAXIMO_7_TREINOS: 'Uma ficha pode ter no máximo 7 treinos.',
    FICHA_NAO_E_SUA: 'Essa ficha não é sua.',
    MODELO_NAO_ENCONTRADO: 'Modelo não encontrado.',
    SALVE_A_CONTA: 'Salve sua conta no app (com Google) antes de virar treinador.',
    TREINADOR_SEM_VAGA: 'Sua faixa está cheia.',
  }
  for (const k of Object.keys(m)) if (msg.includes(k)) return m[k]
  if (msg.includes('JWT expired')) return 'Sua sessão expirou. Entre de novo.'
  if (msg.includes('Failed to fetch')) return 'Sem conexão com o servidor.'
  return msg
}

// Chama uma função do banco e devolve os dados (ou lança erro já traduzido).
export async function rpc(nome, args = {}) {
  const { data, error } = await sb.rpc(nome, args)
  if (error) throw new Error(traduzir(error.message))
  return data
}

export async function carregarSessao() {
  sessao.carregando = true
  try {
    const { data: { session } } = await sb.auth.getSession()
    sessao.user = session?.user ?? null
    sessao.eu = sessao.user ? await rpc('trn_eu') : null
  } catch (e) {
    console.error(e)
    sessao.eu = null
  } finally {
    sessao.carregando = false
  }
}

export async function atualizarEu() {
  try { sessao.eu = await rpc('trn_eu') } catch { /* mantém */ }
}

export async function sair() {
  await sb.auth.signOut()
  sessao.user = null
  sessao.eu = null
  location.href = '/'
}

// Catálogo de exercícios do BroGym (mesma view do app).
export async function buscarExercicios({ busca = '', categoria = null, pagina = 0, tamanho = 40 } = {}) {
  let q = sb.from('vw_exercises_details').select('exercise_id, exercise_name, category_name, category_id, media_url').eq('is_active', true)
  const b = busca.trim().replace(/[,()%]/g, ' ')
  if (b) q = q.ilike('exercise_name', `%${b}%`)
  if (categoria) q = q.eq('category_name', categoria)
  const { data, error } = await q.order('exercise_name').range(pagina * tamanho, pagina * tamanho + tamanho - 1)
  if (error) throw new Error(traduzir(error.message))
  return data
}

export async function categoriasExercicio() {
  const { data, error } = await sb.from('exercise_categories').select('name').order('name')
  if (error) return []
  return data.map((c) => c.name)
}
