import { createApp } from 'vue'
import App from './App.vue'
import { router } from './router'
import { sessao, carregarSessao } from './lib/supabase'
import './style.css'

router.beforeEach(async () => {
  if (sessao.carregando) await carregarSessao()
  return true // App.vue mostra login / ativação quando falta
})

router.afterEach((to) => { document.title = `${to.meta?.nome ?? 'Treinador'} · BroGym Treinador` })

// Saiu versão nova do painel com a página aberta: recarrega uma vez em vez de quebrar.
window.addEventListener('vite:preloadError', (e) => {
  e.preventDefault()
  if (!sessionStorage.getItem('recarregou')) { sessionStorage.setItem('recarregou', '1'); location.reload() }
})
window.addEventListener('load', () => setTimeout(() => sessionStorage.removeItem('recarregou'), 5000))

createApp(App).use(router).mount('#app')
