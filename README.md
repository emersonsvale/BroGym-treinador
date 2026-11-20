# BroGym Treinador

Painel web do treinador do BroGym (`brogym-treinador.valeapps.com.br`).

- Vue 3 + Vite, página estática servida por nginx (Dockerfile) no Coolify. Mesmo molde do painel admin.
- Login: Google ou link no e-mail (mesma conta do app). Sem código de 2 etapas.
- Segurança no banco: toda ação chama uma função `trn_*` do Supabase que confere se a pessoa é treinador ativo
  e se o aluno é dela (vínculo ativo). O aluno escolhe o que o treinador vê (medidas, fotos, dieta).
- Banco: `banco/20261120090000_treinador.sql` (cópia; a original fica no repositório do app, em `supabase/migrations/`).

## Deploy

Coolify (coo.valeapps.com.br), build pelo `Dockerfile`, porta 80. Push na `main` publica sozinho.

## Rodar local

```
npm install
npm run dev
```

O login com Google/link só volta pra endereços cadastrados em Supabase > Auth > URL Configuration.
