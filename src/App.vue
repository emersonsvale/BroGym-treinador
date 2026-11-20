<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { sessao, sair, carregarSessao, sb } from './lib/supabase'
import { PLANOS } from './lib/config'
import { telas } from './router'
import Icone from './components/Icone.vue'
import Avatar from './components/Avatar.vue'
import Avisos from './components/Avisos.vue'
import Confirmacao from './components/Confirmacao.vue'
import Entrar from './views/Entrar.vue'
import Ativar from './views/Ativar.vue'

const route = useRoute()
const menuAberto = ref(false)

onMounted(async () => {
  sb.auth.onAuthStateChange((ev) => { if (ev === 'SIGNED_IN' || ev === 'SIGNED_OUT') carregarSessao() })
  if (sessao.carregando) await carregarSessao()
})

const plano = computed(() => PLANOS[sessao.eu?.plano_vigente] ?? PLANOS.gratis)
const uso = computed(() => Math.min(100, Math.round(((sessao.eu?.alunos_ativos ?? 0) / (sessao.eu?.limite || 5)) * 100)))
const ativo = (p) => route.path === p || (p !== '/' && route.path.startsWith(p))
</script>

<template>
  <div v-if="sessao.carregando" class="carregando" style="height: 100%"><div class="spinner" /></div>
  <Entrar v-else-if="!sessao.user" />
  <Ativar v-else-if="!sessao.eu || !sessao.eu.ativo" />

  <div v-else class="casca" :class="{ 'menu-aberto': menuAberto }">
    <aside class="lateral">
      <div class="marca">
        <img src="/icone.svg" alt="" width="30" height="30" />
        <div>
          <div class="titulo" style="font-size: 16px; font-weight: 800">BroGym</div>
          <small class="sobre">Treinador</small>
        </div>
      </div>
      <nav>
        <RouterLink v-for="t in telas" :key="t.path" :to="t.path" class="item" :class="{ ativo: ativo(t.path) }" @click="menuAberto = false">
          <Icone :nome="t.icone" />
          <span class="espaco">{{ t.nome }}</span>
        </RouterLink>
      </nav>
      <RouterLink to="/conta" class="faixa" @click="menuAberto = false">
        <div class="linha entre">
          <strong>{{ plano.nome }}<span v-if="sessao.eu.fundador" class="tag ouro" style="margin-left: 6px">Fundador</span></strong>
          <small class="num">{{ sessao.eu.alunos_ativos }}/{{ sessao.eu.limite }}</small>
        </div>
        <div class="barra"><span :style="{ width: uso + '%' }" /></div>
        <small v-if="sessao.eu.em_teste && sessao.eu.plano_vigente !== 'gratis'">Teste grátis até {{ new Date(sessao.eu.plano_ate).toLocaleDateString('pt-BR') }}</small>
      </RouterLink>
      <div class="eu">
        <Avatar :src="sessao.eu.avatar_url" :nome="sessao.eu.nome" />
        <div style="min-width: 0" class="espaco">
          <div class="corta" style="font-weight: 600; max-width: 140px">{{ sessao.eu.nome }}</div>
          <small class="corta" style="display: block; max-width: 140px">{{ sessao.eu.email }}</small>
        </div>
        <button class="btn fantasma pequeno" title="Sair" aria-label="Sair" @click="sair"><Icone nome="sair" /></button>
      </div>
    </aside>

    <header class="topo-celular">
      <button class="btn fantasma" aria-label="Menu" @click="menuAberto = !menuAberto"><Icone nome="menu" /></button>
      <strong class="titulo">BroGym Treinador</strong>
    </header>
    <div class="veu" @click="menuAberto = false" />

    <main class="conteudo">
      <RouterView :key="route.fullPath" />
    </main>
  </div>

  <Avisos />
  <Confirmacao />
</template>

<style scoped>
.casca { display: grid; grid-template-columns: 248px 1fr; min-height: 100%; }
.lateral { position: sticky; top: 0; height: 100vh; display: flex; flex-direction: column; border-right: 1px solid var(--line); background: var(--surface); padding: 16px 12px; gap: 10px; }
.marca { display: flex; align-items: center; gap: 10px; padding: 4px 8px 12px; }
.sobre { text-transform: uppercase; letter-spacing: .08em; font-size: 10.5px; font-weight: 600; }
nav { flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 2px; }
.item { display: flex; align-items: center; gap: 10px; padding: 10px; border-radius: 10px; color: var(--muted); font-weight: 600; font-size: 13.5px; transition: background .12s, color .12s; }
.item:hover { background: var(--surface2); color: var(--text); }
.item.ativo { background: var(--accent-soft); color: var(--accent-text); }
.faixa { display: grid; gap: 6px; padding: 12px; border-radius: 12px; border: 1px solid var(--line); background: var(--bg); color: var(--text); }
.barra { height: 6px; border-radius: 3px; background: var(--surface2); overflow: hidden; }
.barra span { display: block; height: 100%; background: var(--accent); border-radius: 3px; transition: width .6s; }
.eu { display: flex; align-items: center; gap: 10px; border-top: 1px solid var(--line); padding: 12px 6px 0; }
.conteudo { padding: 28px 32px 60px; width: 100%; min-width: 0; }
.topo-celular, .veu { display: none; }
@media (max-width: 900px) {
  .casca { grid-template-columns: 1fr; }
  .lateral { position: fixed; z-index: 40; left: 0; top: 0; width: 260px; transform: translateX(-100%); transition: transform .2s; }
  .menu-aberto .lateral { transform: none; }
  .menu-aberto .veu { display: block; position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 30; }
  .topo-celular { display: flex; align-items: center; gap: 8px; padding: 10px 12px; border-bottom: 1px solid var(--line); position: sticky; top: 0; background: var(--bg); z-index: 20; }
  .conteudo { padding: 18px 14px 50px; }
}
</style>
