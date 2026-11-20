import { reactive } from 'vue'

const fusoBR = 'America/Sao_Paulo'

export const num = (n) => (n == null ? '—' : Number(n).toLocaleString('pt-BR'))
export const pct = (a, b) => (!b ? '—' : `${Math.round((a / b) * 100)}%`)
export const usd = (n) => (n == null ? '—' : `US$ ${Number(n).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`)
export const dinheiro = (cents, moeda = 'BRL') => {
  if (cents == null) return '—'
  try { return (cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: moeda || 'BRL' }) } catch { return `${moeda} ${(cents / 100).toFixed(2)}` }
}
export const data = (d) => (d ? new Date(d).toLocaleDateString('pt-BR', { timeZone: fusoBR }) : '—')
export const dataHora = (d) => (d ? new Date(d).toLocaleString('pt-BR', { timeZone: fusoBR, day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—')
export const desde = (d) => {
  if (!d) return '—'
  const s = (Date.now() - new Date(d).getTime()) / 1000
  if (s < 60) return 'agora'
  if (s < 3600) return `${Math.floor(s / 60)} min`
  if (s < 86400) return `${Math.floor(s / 3600)} h`
  if (s < 86400 * 30) return `${Math.floor(s / 86400)} d`
  return data(d)
}
// Pra <input type="datetime-local"> no fuso de Brasília.
export const paraInput = (d) => {
  if (!d) return ''
  const x = new Date(new Date(d).toLocaleString('en-US', { timeZone: fusoBR }))
  const p = (n) => String(n).padStart(2, '0')
  return `${x.getFullYear()}-${p(x.getMonth() + 1)}-${p(x.getDate())}T${p(x.getHours())}:${p(x.getMinutes())}`
}
export const deInput = (v) => (v ? new Date(`${v}:00-03:00`).toISOString() : null)

// Avisos rápidos (toast).
export const avisos = reactive({ lista: [] })
export function avisar(texto, tipo = 'ok') {
  const id = Math.random()
  avisos.lista.push({ id, texto, tipo })
  setTimeout(() => { avisos.lista = avisos.lista.filter((a) => a.id !== id) }, tipo === 'erro' ? 6000 : 3500)
}
export const erro = (e) => avisar(e?.message || String(e), 'erro')

// Confirmação em modal (promessa).
export const confirmacao = reactive({ aberta: false, titulo: '', texto: '', botao: 'Confirmar', perigo: false, digitar: '', resolver: null })
export function confirmar({ titulo, texto = '', botao = 'Confirmar', perigo = false, digitar = '' }) {
  return new Promise((resolve) => {
    Object.assign(confirmacao, { aberta: true, titulo, texto, botao, perigo, digitar, resolver: resolve })
  })
}

export const nomesOrigem = (o) => ({ 'orgânico': 'Orgânico', organico: 'Orgânico', 'play-organico': 'Play (orgânico)', 'apps.facebook.com': 'Anúncios Meta' }[o] || o)

// Países (código ISO de 2 letras).
let nomesPaises
try { nomesPaises = new Intl.DisplayNames(['pt-BR'], { type: 'region' }) } catch { nomesPaises = null }
export const nomePais = (c) => {
  if (!c || c === '??') return 'Sem localização'
  try { return nomesPaises?.of(c.toUpperCase()) || c } catch { return c }
}
// Imagem da bandeira (emoji de bandeira não aparece no Windows).
export const bandeira = (c) => (c && /^[a-z]{2}$/i.test(c) ? `https://flagcdn.com/w40/${c.toLowerCase()}.png` : null)
