// Formato do exercício salvo em workouts.exercises (igual ao app).
export function itemDoCatalogo(e) {
  return {
    name: e.exercise_name,
    exercise_id: e.exercise_id,
    category_id: e.category_id ?? null,
    category_name: e.category_name ?? null,
    muscle_group: e.category_name ?? null,
    media_url: e.media_url ?? null,
    sets: 3,
    reps: '10-12',
    rest_seconds: 60,
    weight: null,
    notes: null,
  }
}

// Limpa e numera antes de salvar.
export function prepararExercicios(lista) {
  return lista.map((x, i) => ({
    name: x.name,
    exercise_id: x.exercise_id ?? null,
    category_id: x.category_id ?? null,
    category_name: x.category_name ?? null,
    muscle_group: x.category_name ?? x.muscle_group ?? null,
    media_url: x.media_url ?? null,
    sets: Math.min(12, Math.max(1, parseInt(x.sets, 10) || 3)),
    reps: String(x.reps || '10-12').slice(0, 20),
    rest_seconds: Math.min(600, Math.max(15, parseInt(x.rest_seconds, 10) || 60)),
    weight: x.weight === '' || x.weight == null ? null : Number(String(x.weight).replace(',', '.')) || null,
    notes: x.notes ? String(x.notes).slice(0, 300) : null,
    order_index: i + 1,
  }))
}

// Minutos estimados (mesma conta do app: 40 s por série + descanso).
export const minutos = (lista) => Math.max(10, Math.round(lista.reduce((s, x) => s + (parseInt(x.sets, 10) || 3) * (40 + (parseInt(x.rest_seconds, 10) || 60)), 0) / 60))

// Tipo do treino = até 2 grupos musculares.
export function tipo(lista) {
  const g = []
  for (const x of lista) if (x.category_name && !g.includes(x.category_name)) g.push(x.category_name)
  return g.slice(0, 2).join(' e ')
}

export function treinosParaSalvar(treinos) {
  return treinos.map((t) => ({
    id: t.id || null,
    nome: (t.nome || 'Treino').trim().slice(0, 60),
    exercises: prepararExercicios(t.exercises),
    minutos: minutos(t.exercises),
    tipo: tipo(t.exercises),
  }))
}

export const letra = (i) => String.fromCharCode(65 + i)

// Dias desde uma data.
export const diasDesde = (d) => (d ? Math.floor((Date.now() - new Date(d).getTime()) / 86400000) : null)
