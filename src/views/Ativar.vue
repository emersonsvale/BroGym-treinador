<script setup>
import { ref, reactive } from 'vue'
import { sessao, rpc, sair } from '../lib/supabase'
import { ESPECIALIDADES } from '../lib/config'
import { erro, avisar } from '../lib/util'
import Icone from '../components/Icone.vue'

const meta = sessao.user?.user_metadata ?? {}
const f = reactive({ nome: sessao.eu?.nome || meta.full_name || meta.name || '', cref: sessao.eu?.cref || '', cidade: sessao.eu?.cidade || '', esp: [...(sessao.eu?.especialidades ?? [])] })
const ocupado = ref(false)

const alternar = (e) => { f.esp = f.esp.includes(e) ? f.esp.filter((x) => x !== e) : [...f.esp, e] }

async function ativar() {
  if (f.nome.trim().length < 2) { erro(new Error('Diga o nome que o aluno vai ver.')); return }
  ocupado.value = true
  try {
    sessao.eu = await rpc('virar_treinador', { p_nome: f.nome.trim(), p_cref: f.cref.trim() || null, p_cidade: f.cidade.trim() || null, p_especialidades: f.esp })
    avisar('Modo Treinador ativado! 14 dias grátis na faixa Start.')
  } catch (e) { erro(e) } finally { ocupado.value = false }
}
</script>

<template>
  <div class="tela">
    <div class="caixa card surge">
      <div class="topo">
        <span class="selo"><Icone nome="modelos" :tam="26" /></span>
        <h1>Treine seus alunos<br />dentro do BroGym</h1>
        <p class="muted">Monte treinos, acompanhe cada série e converse com seus alunos, no computador e no celular.</p>
        <ul>
          <li><Icone nome="estrela" :tam="16" /> Seus alunos ganham o BroGym PRO nas faixas pagas</li>
          <li><Icone nome="ia" :tam="16" /> Biblioteca de exercícios com vídeo</li>
          <li><Icone nome="check" :tam="16" /> 14 dias grátis na faixa Start (15 alunos)</li>
        </ul>
      </div>

      <div class="coluna">
        <label class="campo">Nome que o aluno vai ver
          <input v-model="f.nome" maxlength="60" placeholder="Prof. Rafael Costa" />
        </label>
        <div class="grade g2">
          <label class="campo">CREF (opcional)
            <input v-model="f.cref" maxlength="30" placeholder="000000-G/MA" />
          </label>
          <label class="campo">Cidade
            <input v-model="f.cidade" maxlength="80" placeholder="Imperatriz, MA" />
          </label>
        </div>
        <div class="campo">Especialidades
          <div class="linha" style="gap: 6px">
            <button v-for="e in ESPECIALIDADES" :key="e" type="button" class="chip" :class="{ on: f.esp.includes(e) }" :aria-pressed="f.esp.includes(e)" @click="alternar(e)">{{ e }}</button>
          </div>
        </div>
        <button class="btn primario grande" style="justify-content: center; margin-top: 6px" :disabled="ocupado" @click="ativar">
          {{ ocupado ? 'Ativando…' : 'Ativar modo Treinador' }}
        </button>
        <button class="btn fantasma pequeno" style="align-self: center" @click="sair">Entrar com outra conta</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tela { min-height: 100%; display: grid; place-items: center; padding: 20px;
  background: radial-gradient(1000px 500px at 50% -10%, color-mix(in srgb, var(--accent) 22%, transparent), transparent 60%), var(--bg); }
.caixa { width: min(560px, 100%); padding: 30px 28px; display: grid; gap: 22px; }
.topo { display: grid; gap: 10px; }
.selo { width: 52px; height: 52px; border-radius: 16px; background: var(--accent); color: #fff; display: grid; place-items: center; }
h1 { font-size: 28px; line-height: 1.1; }
.topo p { margin: 0; }
ul { list-style: none; padding: 0; margin: 4px 0 0; display: grid; gap: 8px; font-weight: 600; }
li { display: flex; gap: 8px; align-items: center; }
li :deep(svg) { color: var(--accent-text); }
.chip { border: 1px solid var(--line); background: var(--surface2); color: var(--muted); border-radius: 999px; padding: 7px 12px; font: 600 12.5px Inter, sans-serif; cursor: pointer; }
.chip.on { border-color: var(--accent); background: var(--accent-soft); color: var(--accent-text); }
</style>
