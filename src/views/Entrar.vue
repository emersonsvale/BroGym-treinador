<script setup>
import { ref } from 'vue'
import { sb } from '../lib/supabase'

const email = ref('')
const enviado = ref(false)
const ocupado = ref(false)
const msgErro = ref('')

async function google() {
  msgErro.value = ''
  const { error } = await sb.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: location.origin + '/' } })
  if (error) msgErro.value = error.message
}

async function link() {
  msgErro.value = ''
  if (!email.value.includes('@')) { msgErro.value = 'Digite seu e-mail.'; return }
  ocupado.value = true
  const { error } = await sb.auth.signInWithOtp({ email: email.value.trim(), options: { emailRedirectTo: location.origin + '/' } })
  ocupado.value = false
  if (error) msgErro.value = error.message
  else enviado.value = true
}
</script>

<template>
  <div class="tela-login">
    <div class="caixa-login card surge">
      <img src="/icone.svg" width="52" height="52" alt="" />
      <h1 style="margin-top: 14px">BroGym Treinador</h1>
      <p class="muted" style="margin: 6px 0 22px">Monte treinos e acompanhe seus alunos. Entre com a mesma conta do app.</p>

      <button class="btn grande" style="width: 100%; justify-content: center" @click="google">
        <svg width="18" height="18" viewBox="0 0 48 48"><path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z"/><path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/><path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z"/><path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z"/></svg>
        Entrar com Google
      </button>

      <div class="ou"><span>ou</span></div>

      <template v-if="!enviado">
        <label class="campo">E-mail
          <input v-model="email" type="email" placeholder="voce@email.com" autocomplete="email" @keydown.enter="link" />
        </label>
        <button class="btn primario grande" style="width: 100%; justify-content: center; margin-top: 12px" :disabled="ocupado" @click="link">
          {{ ocupado ? 'Enviando…' : 'Receber link de acesso' }}
        </button>
      </template>
      <div v-else class="enviado">
        Mandamos um link pra <strong>{{ email }}</strong>. Abre o e-mail neste mesmo navegador.
      </div>

      <p v-if="msgErro" class="erro-login">{{ msgErro }}</p>
      <p class="muted" style="font-size: 12px; margin: 20px 0 0">Primeira vez? Depois de entrar você ativa o modo Treinador e ganha 14 dias grátis na faixa Start.</p>
    </div>
  </div>
</template>

<style scoped>
.tela-login { min-height: 100%; display: grid; place-items: center; padding: 20px;
  background: radial-gradient(1000px 500px at 50% -10%, color-mix(in srgb, var(--accent) 22%, transparent), transparent 60%), var(--bg); }
.caixa-login { width: min(400px, 100%); padding: 32px 28px; text-align: center; }
.caixa-login label { text-align: left; }
.ou { display: flex; align-items: center; gap: 10px; color: var(--muted); margin: 18px 0; font-size: 12px; }
.ou::before, .ou::after { content: ''; flex: 1; border-top: 1px solid var(--line); }
.enviado { background: var(--surface2); border-radius: 12px; padding: 14px; text-align: left; }
.erro-login { color: var(--accent-text); margin: 14px 0 0; font-weight: 500; }
</style>
