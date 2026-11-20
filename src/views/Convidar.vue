<script setup>
import { ref, computed, onMounted } from 'vue'
import QRCode from 'qrcode'
import { sessao } from '../lib/supabase'
import { linkConvite, PLANOS } from '../lib/config'
import { avisar } from '../lib/util'
import Icone from '../components/Icone.vue'

const link = computed(() => linkConvite(sessao.eu.codigo))
const qr = ref('')
onMounted(async () => {
  qr.value = await QRCode.toDataURL(link.value, { width: 520, margin: 1, color: { dark: '#0c0d0f', light: '#ffffff' }, errorCorrectionLevel: 'M' })
})

const daPro = computed(() => PLANOS[sessao.eu.plano_vigente]?.pro)
const vagas = computed(() => Math.max(0, sessao.eu.limite - sessao.eu.alunos_ativos))
const mensagem = computed(() =>
  `Oi! Agora meus treinos ficam no app BroGym. Instala por esse link e aceita meu convite que seu treino já aparece lá${daPro.value ? ' (e você ganha o BroGym PRO de graça enquanto treinar comigo)' : ''}:\n${link.value}\n\nSe o app pedir, meu código é ${sessao.eu.codigo}`)

async function copiar(t, msg) {
  try { await navigator.clipboard.writeText(t); avisar(msg) } catch { avisar('Não consegui copiar. Selecione e copie manualmente.', 'erro') }
}
const whatsapp = computed(() => `https://wa.me/?text=${encodeURIComponent(mensagem.value)}`)
</script>

<template>
  <div class="surge">
    <div class="cabecalho">
      <div>
        <h1>Convidar aluno</h1>
        <p>O aluno instala o BroGym pelo seu link e já cai no seu convite.</p>
      </div>
    </div>

    <div class="duas">
      <section class="card qr-card">
        <p class="muted" style="margin: 0">Aponte a câmera do celular</p>
        <div class="qr"><img v-if="qr" :src="qr" alt="QR Code do seu convite" width="260" height="260" /></div>
        <small>Código do convite</small>
        <div class="codigo titulo">{{ sessao.eu.codigo }}</div>
        <button class="btn pequeno" @click="copiar(sessao.eu.codigo, 'Código copiado.')"><Icone nome="copiar" :tam="14" />Copiar código</button>
      </section>

      <div class="coluna" style="gap: 14px">
        <section class="card coluna">
          <h2>Mandar pelo WhatsApp</h2>
          <textarea :value="mensagem" rows="6" readonly aria-label="Mensagem de convite" />
          <div class="linha">
            <a :href="whatsapp" target="_blank" rel="noopener" class="btn primario">Abrir no WhatsApp</a>
            <button class="btn" @click="copiar(mensagem, 'Mensagem copiada.')"><Icone nome="copiar" :tam="14" />Copiar mensagem</button>
            <button class="btn" @click="copiar(link, 'Link copiado.')"><Icone nome="copiar" :tam="14" />Copiar só o link</button>
          </div>
        </section>

        <section class="card" :class="daPro ? 'destaque' : ''">
          <template v-if="daPro">
            <strong><Icone nome="estrela" :tam="15" /> Quem entra pelo seu convite ganha o BroGym PRO</strong>
            <p class="muted" style="margin: 6px 0 0">Vale enquanto o aluno estiver com você e sua faixa estiver ativa.</p>
          </template>
          <template v-else>
            <strong>Na faixa Grátis os alunos não ganham PRO</strong>
            <p class="muted" style="margin: 6px 0 0">Nas faixas pagas cada aluno seu leva o BroGym PRO junto. <RouterLink to="/conta">Ver faixas</RouterLink></p>
          </template>
        </section>

        <section class="card linha entre">
          <span><strong>{{ vagas }}</strong> vaga{{ vagas === 1 ? '' : 's' }} na sua faixa ({{ sessao.eu.alunos_ativos }} de {{ sessao.eu.limite }} alunos)</span>
          <RouterLink v-if="vagas <= 2" to="/conta" class="btn pequeno">Aumentar faixa</RouterLink>
        </section>

        <section class="card plano">
          <h3 style="margin-bottom: 6px">Como o aluno entra</h3>
          <ol class="passos">
            <li>Abre o link (ou lê o QR Code) e instala o BroGym pela Play Store.</li>
            <li>No app, aceita o seu convite e escolhe o que você pode ver.</li>
            <li>Ele aparece em Alunos e você já monta o treino.</li>
          </ol>
          <small>Por enquanto o app é só Android.</small>
        </section>
      </div>
    </div>
  </div>
</template>

<style scoped>
.duas { display: grid; grid-template-columns: 340px minmax(0, 1fr); gap: 16px; align-items: start; }
@media (max-width: 900px) { .duas { grid-template-columns: 1fr; } }
.qr-card { display: flex; flex-direction: column; align-items: center; gap: 8px; text-align: center; background: radial-gradient(120% 90% at 50% 0%, color-mix(in srgb, var(--accent) 22%, transparent), transparent 60%), var(--surface); }
.qr { background: #fff; padding: 12px; border-radius: 18px; width: 284px; height: 284px; display: grid; place-items: center; margin: 6px 0; }
.qr img { width: 260px; height: 260px; display: block; }
.codigo { font-size: 28px; font-weight: 800; letter-spacing: .12em; }
textarea { resize: none; }
.destaque { background: linear-gradient(140deg, color-mix(in srgb, var(--gold) 14%, transparent), var(--surface) 70%); border-color: color-mix(in srgb, var(--gold) 35%, var(--line)); }
.destaque strong { color: var(--gold); display: flex; gap: 6px; align-items: center; }
.passos { margin: 0 0 8px; padding-left: 18px; display: grid; gap: 4px; }
</style>
