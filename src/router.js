import { createRouter, createWebHistory } from 'vue-router'

export const telas = [
  { path: '/', nome: 'Painel', icone: 'inicio', component: () => import('./views/Painel.vue') },
  { path: '/alunos', nome: 'Alunos', icone: 'alunos', component: () => import('./views/Alunos.vue') },
  { path: '/modelos', nome: 'Modelos de treino', icone: 'modelos', component: () => import('./views/Modelos.vue') },
  { path: '/convidar', nome: 'Convidar aluno', icone: 'convidar', component: () => import('./views/Convidar.vue') },
  { path: '/conta', nome: 'Minha conta', icone: 'conta', component: () => import('./views/Conta.vue') },
]

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    ...telas.map((t) => ({ path: t.path, component: t.component, meta: { nome: t.nome } })),
    { path: '/alunos/:id', component: () => import('./views/Aluno.vue'), meta: { nome: 'Aluno' } },
    { path: '/alunos/:id/ficha/:ficha?', component: () => import('./views/MontarFicha.vue'), meta: { nome: 'Montar treino' } },
    { path: '/modelos/:id', component: () => import('./views/MontarModelo.vue'), meta: { nome: 'Modelo' } },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
  scrollBehavior: () => ({ top: 0 }),
})
