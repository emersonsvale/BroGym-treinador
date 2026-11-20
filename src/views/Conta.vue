<script setup>
import { ref, reactive, computed } from 'vue'
import { sessao, rpc } from '../lib/supabase'
import { PLANOS, ESPECIALIDADES } from '../lib/config'
import { erro, avisar, data } from '../lib/util'
import Icone from '../components/Icone.vue'

const eu = computed(() => sessao.eu)
const f = reactive({ nome: eu.value.nome, cref: eu.value.cref || '', cidade: eu.value.cidade || '', esp: [...(eu.value.especialidades ?? [])], bio: eu.value.bio || '' })
const salvando = ref(false)
const alternar = (e) => { f.esp = f.esp.includes(e) ? f.esp.filter((x) => x !== e) : [...f.esp, e] }

async function salvar() {
  salvando.value = true
  try {
    sessao.eu = await rpc('virar_treinador', { p_nome: f.nome.trim(), p_cref: f.cref.trim() || null, p_cidade: f.cidade.trim() || null, p_especialidades: f.esp, p_bio: f.bio.trim() || null })
    avisar('Perfil salvo.')
  } catch (e) { erro(e) } finally { salvando.value = false }
}

const preco = (p) => (p.preco ? (eu.value.fundador ? p.preco / 2 : p.preco) : 0)
const reais = (v) => v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
const faixas = computed(() => Object.entries(PLANOS).map(([id, p]) => ({ id, ...p, atual: eu.value.plano_vigente === id })))
</script>

<template>
  <div class="surge">
    <div class="cabecalho"><div><h1>Minha conta</h1><p>{{ eu.email }}</p></div></div>

    <div class="duas">
      <section class="card coluna">
        <h2>Perfil que o aluno vê</h2>
        <label class="campo">Nome<input v-model="f.nome" maxlength="60" /></label>
        <div class="grade g2">
          <label class="campo">CREF (opcional)<input v-model="f.cref" maxlength="30" /></label>
          <label class="campo">Cidade<input v-model="f.cidade" maxlength="80" /></label>
        </div>
        <div class="campo">Especialidades
          <div class="linha" style="gap: 6px">
            <button v-for="e in ESPECIALIDADES" :key="e" type="button" class="chip" :class="{ on: f.esp.includes(e) }" :aria-pressed="f.esp.includes(e)" @click="alternar(e)">{{ e }}</button>
          </div>
        </div>
        <label class="campo">Sobre você (opcional)<textarea v-model="f.bio" maxlength="500" rows="3" placeholder="Formação, como você trabalha, o que gosta de treinar" /></label>
        <button class="btn primario" style="align-self: flex-start" :disabled="salvando" @click="salvar">{{ salvando ? 'Salvando…' : 'Salvar perfil' }}</button>
      </section>

      <section class="coluna" style="gap: 14px">
        <div class="card">
          <div class="linha entre">
            <h2>Sua faixa</h2>
            <span v-if="eu.fundador" class="tag ouro"><Icone nome="coroa" :tam="12" />Fundador · 50% pra sempre</span>
          </div>
          <p style="margin: 8px 0 0">
            <strong>{{ PLANOS[eu.plano_vigente].nome }}</strong> · {{ eu.alunos_ativos }} de {{ eu.limite }} alunos
            <template v-if="eu.em_teste && eu.plano_vigente !== 'gratis'"><br /><span class="muted">Teste grátis até {{ data(eu.plano_ate) }}. Depois disso, sem assinatura, a conta volta pra faixa Grátis (5 alunos, sem PRO pros alunos).</span></template>
            <template v-else-if="eu.plano_vigente !== 'gratis'"><br /><span class="muted">Ativa até {{ data(eu.plano_ate) }}.</span></template>
          </p>
        </div>

        <div class="faixas">
          <div v-for="p in faixas" :key="p.id" class="card faixa" :class="{ atual: p.atual }">
            <div class="linha entre"><h3>{{ p.nome }}</h3><span v-if="p.atual" class="tag vermelho">atual</span></div>
            <div class="preco titulo">{{ p.preco ? reais(preco(p)) : 'R$ 0' }}<small v-if="p.preco">/mês</small></div>
            <small v-if="p.preco && eu.fundador" style="text-decoration: line-through">{{ reais(p.preco) }}</small>
            <small>até {{ p.alunos }} alunos</small>
            <small :style="{ color: p.pro ? 'var(--gold)' : 'var(--muted)' }">{{ p.pro ? 'Alunos ganham PRO' : 'Sem PRO pros alunos' }}</small>
          </div>
        </div>
        <p class="muted" style="margin: 0; font-size: 12.5px">A assinatura das faixas pagas abre em breve. Anual: paga 10 meses e leva 12.</p>
      </section>
    </div>
  </div>
</template>

<style scoped>
.duas { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 16px; align-items: start; }
@media (max-width: 1000px) { .duas { grid-template-columns: 1fr; } }
.chip { border: 1px solid var(--line); background: var(--surface2); color: var(--muted); border-radius: 999px; padding: 7px 12px; font: 600 12.5px Inter, sans-serif; cursor: pointer; }
.chip.on { border-color: var(--accent); background: var(--accent-soft); color: var(--accent-text); }
.faixas { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.faixa { display: flex; flex-direction: column; gap: 2px; padding: 14px; }
.faixa.atual { border-color: var(--accent); background: linear-gradient(140deg, var(--accent-soft), var(--surface) 70%); }
.preco { font-size: 24px; font-weight: 800; margin-top: 4px; }
.preco small { font: 500 12px Inter, sans-serif; color: var(--muted); }
</style>
