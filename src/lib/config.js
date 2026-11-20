// Chaves PÚBLICAS do Supabase (as mesmas do app). Quem protege os dados é o banco:
// toda função trn_* confere se a pessoa é treinador ativo e se o aluno é dela.
export const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL || 'https://soloxmcolcblqkerugas.supabase.co'
export const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvbG94bWNvbGNibHFrZXJ1Z2FzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY4ODg3ODgsImV4cCI6MjA4MjQ2NDc4OH0.cwqtLug_3oUn5xCqXiC6oRFiLf-NR1H6PmfLlJYutRE'

// Link da Play com o código do treinador no referrer (o app lê e abre o convite).
export const PLAY = 'https://play.google.com/store/apps/details?id=com.mycompany.gynbro'
export const linkConvite = (codigo) =>
  `${PLAY}&referrer=${encodeURIComponent(new URLSearchParams({ utm_source: 'treinador', utm_medium: 'painel', treinador: codigo }).toString())}`

export const PLANOS = {
  gratis: { nome: 'Grátis', alunos: 5, preco: 0, pro: false },
  start: { nome: 'Start', alunos: 15, preco: 29.9, pro: true },
  pro: { nome: 'Pro', alunos: 40, preco: 59.9, pro: true },
  elite: { nome: 'Elite', alunos: 100, preco: 99.9, pro: true },
}

export const ESPECIALIDADES = ['Musculação', 'Emagrecimento', 'Hipertrofia', 'Funcional', 'Corrida', 'Crossfit', 'Online', 'Idosos', 'Reabilitação', 'Nutrição']

// Miniatura leve do exercício (mesma regra do app: thumb/ em WebP).
const BUCKET = 'https://cnd.valeapps.com.br/brogymexercicios'
export function miniatura(url) {
  if (!url) return ''
  if (!url.includes('cnd.valeapps.com.br/brogymexercicios')) return url
  let d = url
  try { d = decodeURIComponent(url) } catch { /* usa como veio */ }
  let resto = d.slice(d.indexOf('brogymexercicios') + 'brogymexercicios'.length).replace(/^\//, '').replace(/^(webp|thumb)\//, '')
  const ponto = resto.lastIndexOf('.')
  if (ponto > 0) resto = resto.slice(0, ponto)
  return `${BUCKET}/thumb/${resto.split('/').map(encodeURIComponent).join('/')}.webp`
}
