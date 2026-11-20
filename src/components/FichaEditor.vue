<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { buscarExercicios, categoriasExercicio } from '../lib/supabase'
import { miniatura } from '../lib/config'
import { itemDoCatalogo, letra, minutos } from '../lib/ficha'
import { erro } from '../lib/util'
import Icone from './Icone.vue'

// treinos: [{ id, nome, exercises: [...] }] — editado no lugar (reativo do pai).
const props = defineProps({ treinos: Array })
const atual = ref(0)
const treino = computed(() => props.treinos[atual.value])

// ---------- Biblioteca ----------
const busca = ref('')
const categoria = ref('')
const categorias = ref([])
const catalogo = ref([])
const pagina = ref(0)
const fim = ref(false)
const carregandoCat = ref(false)

async function carregarCatalogo(reset = true) {
  if (reset) { pagina.value = 0; fim.value = false }
  carregandoCat.value = true
  try {
    const r = await buscarExercicios({ busca: busca.value, categoria: categoria.value || null, pagina: pagina.value })
    catalogo.value = reset ? r : [...catalogo.value, ...r]
    fim.value = r.length < 40
  } catch (e) { erro(e) } finally { carregandoCat.value = false }
}
let t
watch([busca, categoria], () => { clearTimeout(t); t = setTimeout(() => carregarCatalogo(true), 250) })
onMounted(async () => { carregarCatalogo(); categorias.value = await categoriasExercicio() })
const mais = () => { pagina.value++; carregarCatalogo(false) }

const noTreino = (e) => treino.value?.exercises.some((x) => x.exercise_id === e.exercise_id)
function adicionar(e) {
  if (!treino.value) return
  treino.value.exercises.push(itemDoCatalogo(e))
}

// ---------- Treinos ----------
function novoTreino() {
  if (props.treinos.length >= 7) return
  props.treinos.push({ id: null, nome: `Treino ${letra(props.treinos.length)}`, exercises: [] })
  atual.value = props.treinos.length - 1
}
function apagarTreino(i) {
  props.treinos.splice(i, 1)
  atual.value = Math.max(0, Math.min(atual.value, props.treinos.length - 1))
}
function mover(i, d) {
  const l = treino.value.exercises
  const j = i + d
  if (j < 0 || j >= l.length) return
  ;[l[i], l[j]] = [l[j], l[i]]
}
const tirar = (i) => treino.value.exercises.splice(i, 1)

// Arrastar da biblioteca pro treino.
const arrastando = ref(null)
const soltar = () => { if (arrastando.value) adicionar(arrastando.value); arrastando.value = null }
</script>

<template>
  <div class="editor">
    <section class="card biblioteca" aria-label="Biblioteca de exercícios">
      <h3>Exercícios</h3>
      <label><span class="sr">Buscar exercício</span><input v-model="busca" type="search" placeholder="Buscar exercício" /></label>
      <select v-model="categoria" aria-label="Grupo muscular">
        <option value="">Todos os grupos</option>
        <option v-for="c in categorias" :key="c" :value="c">{{ c }}</option>
      </select>
      <div class="lista-cat">
        <div v-for="e in catalogo" :key="e.exercise_id" class="cat" draggable="true" @dragstart="arrastando = e" @dragend="arrastando = null">
          <img v-if="e.media_url" :src="miniatura(e.media_url)" class="miniatura" alt="" loading="lazy" />
          <span v-else class="miniatura" />
          <span class="espaco"><span class="nome">{{ e.exercise_name }}</span><small>{{ e.category_name }}</small></span>
          <span v-if="noTreino(e)" class="tag verde">no treino</span>
          <button v-else class="btn primario pequeno" :aria-label="`Adicionar ${e.exercise_name}`" @click="adicionar(e)"><Icone nome="mais" :tam="14" /></button>
        </div>
        <div v-if="carregandoCat" class="carregando"><div class="spinner" /></div>
        <button v-else-if="!fim && catalogo.length" class="btn fantasma pequeno" style="align-self: center" @click="mais">Carregar mais</button>
        <div v-else-if="!catalogo.length" class="vazio">Nada encontrado.</div>
      </div>
      <small>Arraste pro treino ou clique em +</small>
    </section>

    <section class="principal">
      <div class="linha" role="tablist" aria-label="Divisão do treino">
        <button v-for="(tr, i) in treinos" :key="i" role="tab" class="btn" :class="{ primario: i === atual }" :aria-selected="i === atual" @click="atual = i">{{ letra(i) }} · {{ tr.nome || 'Treino' }}</button>
        <button v-if="treinos.length < 7" class="btn fantasma" @click="novoTreino"><Icone nome="mais" :tam="14" />Treino</button>
      </div>

      <div v-if="treino" class="card" @dragover.prevent @drop.prevent="soltar">
        <div class="linha" style="margin-bottom: 12px">
          <label class="campo espaco" style="min-width: 220px">Nome do treino {{ letra(atual) }}
            <input v-model="treino.nome" maxlength="60" placeholder="Peito e tríceps" />
          </label>
          <small style="align-self: flex-end; padding-bottom: 10px">{{ treino.exercises.length }} exercícios · ~{{ minutos(treino.exercises) }} min</small>
          <button v-if="treinos.length > 1" class="btn perigo pequeno" style="align-self: flex-end; margin-bottom: 6px" @click="apagarTreino(atual)"><Icone nome="lixo" :tam="14" />Apagar treino</button>
        </div>

        <div class="tabela-wrap" style="border: 0">
          <table>
            <thead><tr><th style="width: 30px">#</th><th>Exercício</th><th style="width: 76px">Séries</th><th style="width: 92px">Reps</th><th style="width: 92px">Carga kg</th><th style="width: 96px">Descanso s</th><th>Observação</th><th style="width: 96px"></th></tr></thead>
            <tbody>
              <tr v-for="(x, i) in treino.exercises" :key="i">
                <td class="muted">{{ i + 1 }}</td>
                <td><div class="linha" style="flex-wrap: nowrap; gap: 8px"><img v-if="x.media_url" :src="miniatura(x.media_url)" class="mini" alt="" loading="lazy" /><strong>{{ x.name }}</strong></div></td>
                <td><input v-model="x.sets" inputmode="numeric" class="cel" :aria-label="`Séries de ${x.name}`" /></td>
                <td><input v-model="x.reps" class="cel" :aria-label="`Repetições de ${x.name}`" /></td>
                <td><input v-model="x.weight" inputmode="decimal" class="cel" placeholder="—" :aria-label="`Carga de ${x.name}`" /></td>
                <td><input v-model="x.rest_seconds" inputmode="numeric" class="cel" :aria-label="`Descanso de ${x.name}`" /></td>
                <td><input v-model="x.notes" maxlength="300" placeholder="Dica pro aluno" :aria-label="`Observação de ${x.name}`" /></td>
                <td>
                  <div class="linha" style="gap: 2px; flex-wrap: nowrap">
                    <button class="btn fantasma pequeno" :aria-label="`Subir ${x.name}`" :disabled="i === 0" @click="mover(i, -1)"><Icone nome="cima" :tam="14" /></button>
                    <button class="btn fantasma pequeno" :aria-label="`Descer ${x.name}`" :disabled="i === treino.exercises.length - 1" @click="mover(i, 1)"><Icone nome="baixo" :tam="14" /></button>
                    <button class="btn fantasma pequeno" :aria-label="`Tirar ${x.name}`" @click="tirar(i)"><Icone nome="lixo" :tam="14" /></button>
                  </div>
                </td>
              </tr>
              <tr v-if="!treino.exercises.length"><td colspan="8" class="vazio">Escolha exercícios na biblioteca ao lado.</td></tr>
            </tbody>
          </table>
        </div>
        <div class="soltar" :class="{ ativo: arrastando }">+ Solte um exercício aqui</div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.editor { display: grid; grid-template-columns: 300px minmax(0, 1fr); gap: 16px; align-items: start; }
@media (max-width: 1000px) { .editor { grid-template-columns: 1fr; } .biblioteca { position: static !important; max-height: 420px; } }
.biblioteca { position: sticky; top: 16px; display: flex; flex-direction: column; gap: 10px; max-height: calc(100vh - 32px); padding: 14px; }
.lista-cat { flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 2px; margin: 0 -6px; }
.cat { display: flex; align-items: center; gap: 10px; padding: 6px; border-radius: 10px; cursor: grab; }
.cat:hover { background: var(--surface2); }
.cat .nome { display: block; font-weight: 600; font-size: 13px; line-height: 1.25; }
.cat small { font-size: 11.5px; }
.miniatura { width: 40px; height: 40px; background: #e9eaec; object-fit: contain; }
.mini { width: 32px; height: 32px; border-radius: 6px; background: #e9eaec; object-fit: contain; flex: none; }
.principal { display: flex; flex-direction: column; gap: 12px; min-width: 0; }
.cel { padding: 7px 8px; text-align: center; font-weight: 700; font-variant-numeric: tabular-nums; }
td { padding: 8px 6px; }
th { padding: 10px 6px; }
.soltar { margin-top: 10px; border: 1px dashed var(--line); border-radius: 10px; padding: 12px; text-align: center; color: var(--muted); font-size: 13px; transition: all .15s; }
.soltar.ativo { border-color: var(--accent); color: var(--accent-text); background: var(--accent-soft); }
.sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
</style>
