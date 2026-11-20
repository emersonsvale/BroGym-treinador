<script setup>
import { ref, computed, onMounted } from 'vue'
import { rpc } from '../lib/supabase'
import { alunos, carregarAlunos } from '../lib/alunos'
import { erro, avisar } from '../lib/util'
import Modal from './Modal.vue'
import Avatar from './Avatar.vue'

const props = defineProps({ modelo: Object })
const emit = defineEmits(['fechar', 'enviou'])
const marcados = ref([])
const vence = ref(props.modelo.semanas ? new Date(Date.now() + props.modelo.semanas * 7 * 86400000).toISOString().slice(0, 10) : '')
const enviando = ref(false)
onMounted(() => carregarAlunos().catch(erro))

const todos = computed(() => marcados.value.length === alunos.lista.length && alunos.lista.length > 0)
const alternarTodos = () => { marcados.value = todos.value ? [] : alunos.lista.map((a) => a.id) }

async function enviar() {
  if (!marcados.value.length) return
  enviando.value = true
  try {
    const n = await rpc('trn_enviar_modelo', { p_modelo: props.modelo.id, p_alunos: marcados.value, p_vence_em: vence.value || null })
    await carregarAlunos(true)
    avisar(`“${props.modelo.nome}” enviado pra ${n} aluno${n === 1 ? '' : 's'}.`)
    emit('enviou'); emit('fechar')
  } catch (e) { erro(e) } finally { enviando.value = false }
}
</script>

<template>
  <Modal :titulo="`Enviar “${modelo.nome}”`" @fechar="emit('fechar')">
    <p class="muted" style="margin: 0 0 12px">Cada aluno recebe uma cópia, que vira a ficha ativa dele no app.</p>
    <div v-if="!alunos.lista.length" class="vazio">Você ainda não tem alunos. Mande seu convite primeiro.</div>
    <template v-else>
      <label class="linha-check" style="margin-bottom: 8px"><input type="checkbox" :checked="todos" @change="alternarTodos" />Todos os alunos</label>
      <div class="lista">
        <label v-for="a in alunos.lista" :key="a.id" class="linha-check aluno">
          <input v-model="marcados" type="checkbox" :value="a.id" />
          <Avatar :src="a.avatar_url" :nome="a.nome" />
          <span class="espaco">{{ a.nome }}</span>
          <small v-if="a.ficha">tem “{{ a.ficha.nome }}”</small>
        </label>
      </div>
      <label class="campo" style="margin-top: 12px; max-width: 220px">Vence em<input v-model="vence" type="date" /></label>
      <div class="linha" style="justify-content: flex-end; margin-top: 14px">
        <button class="btn fantasma" @click="emit('fechar')">Cancelar</button>
        <button class="btn primario" :disabled="!marcados.length || enviando" @click="enviar">{{ enviando ? 'Enviando…' : `Enviar pra ${marcados.length}` }}</button>
      </div>
    </template>
  </Modal>
</template>

<style scoped>
.lista { max-height: 320px; overflow-y: auto; display: grid; gap: 2px; }
.aluno { padding: 6px; border-radius: 10px; }
.aluno:hover { background: var(--surface2); }
</style>
