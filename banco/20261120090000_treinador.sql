-- Modo Treinador (Fase 1).
-- Treinador = conta comum do BroGym com uma linha em `treinadores`.
-- O treino que ele monta vira uma ficha (programa) DO ALUNO, marcada com treinador_id.
-- Toda ação do treinador passa por função trn_* que confere: é treinador ativo e o aluno é dele.
-- Aluno com treinador em faixa paga ganha PRO enquanto o vínculo durar (+7 dias depois de sair).

-- ---------- 1. Treinadores ----------
create table if not exists public.treinadores (
  user_id uuid primary key references auth.users(id) on delete cascade,
  nome text not null check (char_length(trim(nome)) between 2 and 60),
  cref text check (cref is null or char_length(cref) <= 30),
  cidade text check (cidade is null or char_length(cidade) <= 80),
  especialidades text[] not null default '{}',
  bio text check (bio is null or char_length(bio) <= 500),
  codigo text not null unique,
  -- Faixa: gratis (5 alunos, sem PRO), start (15), pro (40), elite (100).
  plano text not null default 'gratis' check (plano in ('gratis', 'start', 'pro', 'elite')),
  plano_ate timestamptz,          -- até quando a faixa paga vale (assinatura ou teste)
  em_teste boolean not null default false,
  fundador boolean not null default false,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
alter table public.treinadores enable row level security;
revoke all on public.treinadores from anon, authenticated;
drop policy if exists "treinadores: dono le" on public.treinadores;
create policy "treinadores: dono le" on public.treinadores for select using (user_id = auth.uid());
grant select on public.treinadores to authenticated;

-- Faixa que vale agora (paga vencida volta pro grátis).
create or replace function public.trn_plano_vigente(p_trn uuid)
returns text language sql stable security definer set search_path = public, pg_temp as $$
  select case when t.plano <> 'gratis' and t.plano_ate is not null and t.plano_ate > now() then t.plano else 'gratis' end
  from treinadores t where t.user_id = p_trn and t.ativo;
$$;
revoke all on function public.trn_plano_vigente(uuid) from public, anon, authenticated;

create or replace function public.trn_limite(p_plano text)
returns int language sql immutable as $$
  select case p_plano when 'start' then 15 when 'pro' then 40 when 'elite' then 100 else 5 end;
$$;

-- ---------- 2. Vínculo treinador ↔ aluno ----------
create table if not exists public.treinador_alunos (
  id uuid primary key default gen_random_uuid(),
  treinador_id uuid not null references public.treinadores(user_id) on delete cascade,
  aluno_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'ativo' check (status in ('ativo', 'saiu', 'removido')),
  ver_medidas boolean not null default true,
  ver_fotos boolean not null default false,
  ver_dieta boolean not null default false,
  criado_em timestamptz not null default now(),
  encerrado_em timestamptz,
  check (treinador_id <> aluno_id)
);
-- Um treinador ativo por aluno.
create unique index if not exists treinador_alunos_um_ativo on public.treinador_alunos (aluno_id) where status = 'ativo';
create index if not exists treinador_alunos_trn_idx on public.treinador_alunos (treinador_id, status);
alter table public.treinador_alunos enable row level security;
revoke all on public.treinador_alunos from anon, authenticated;

-- Aluno é meu (vínculo ativo)?
create or replace function public.trn_eh_meu(p_aluno uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from treinador_alunos v join treinadores t on t.user_id = v.treinador_id
    where v.treinador_id = auth.uid() and v.aluno_id = p_aluno and v.status = 'ativo' and t.ativo
  );
$$;
revoke all on function public.trn_eh_meu(uuid) from public, anon;
grant execute on function public.trn_eh_meu(uuid) to authenticated;

create or replace function public.trn_exigir()
returns void language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not exists (select 1 from treinadores where user_id = auth.uid() and ativo) then
    raise exception 'NAO_TREINADOR';
  end if;
end $$;
revoke all on function public.trn_exigir() from public, anon, authenticated;

create or replace function public.trn_exigir_aluno(p_aluno uuid)
returns void language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform trn_exigir();
  if not trn_eh_meu(p_aluno) then raise exception 'ALUNO_NAO_E_SEU'; end if;
end $$;
revoke all on function public.trn_exigir_aluno(uuid) from public, anon, authenticated;

-- ---------- 3. Ficha do treinador dentro das fichas do aluno ----------
alter table public.programas add column if not exists treinador_id uuid references public.treinadores(user_id) on delete set null;
alter table public.workouts add column if not exists treinador_id uuid references public.treinadores(user_id) on delete set null;
alter table public.programas add column if not exists vence_em date;
create index if not exists programas_treinador_idx on public.programas (treinador_id) where treinador_id is not null;

-- ---------- 4. Modelos de treino do treinador ----------
create table if not exists public.treinador_modelos (
  id uuid primary key default gen_random_uuid(),
  treinador_id uuid not null references public.treinadores(user_id) on delete cascade,
  nome text not null check (char_length(trim(nome)) between 1 and 80),
  descricao text check (descricao is null or char_length(descricao) <= 300),
  semanas int check (semanas is null or semanas between 1 and 52),
  -- [{ "nome": "Peito e tríceps", "exercises": [ {formato de workouts.exercises} ] }]
  treinos jsonb not null default '[]' check (jsonb_typeof(treinos) = 'array'),
  usos int not null default 0,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create index if not exists treinador_modelos_idx on public.treinador_modelos (treinador_id, atualizado_em desc);
alter table public.treinador_modelos enable row level security;
revoke all on public.treinador_modelos from anon, authenticated;
grant select, insert, update, delete on public.treinador_modelos to authenticated;
drop policy if exists "modelos: dono" on public.treinador_modelos;
create policy "modelos: dono" on public.treinador_modelos for all
  using (treinador_id = auth.uid() and exists (select 1 from treinadores t where t.user_id = auth.uid() and t.ativo))
  with check (treinador_id = auth.uid() and exists (select 1 from treinadores t where t.user_id = auth.uid() and t.ativo));

-- ---------- 5. Anamnese (uma por vínculo) ----------
create table if not exists public.treinador_anamneses (
  treinador_id uuid not null references public.treinadores(user_id) on delete cascade,
  aluno_id uuid not null references auth.users(id) on delete cascade,
  respostas jsonb not null default '{}' check (jsonb_typeof(respostas) = 'object'),
  atualizado_em timestamptz not null default now(),
  primary key (treinador_id, aluno_id)
);
alter table public.treinador_anamneses enable row level security;
revoke all on public.treinador_anamneses from anon, authenticated;

-- ---------- 6. Feedback do aluno no fim do treino ----------
create table if not exists public.treino_feedback (
  id uuid primary key default gen_random_uuid(),
  sessao_id uuid unique references public.workout_sessions(id) on delete cascade,
  aluno_id uuid not null references auth.users(id) on delete cascade,
  treinador_id uuid references public.treinadores(user_id) on delete set null,
  esforco int not null check (esforco between 1 and 10),
  incomodos text[] not null default '{}',
  comentario text check (comentario is null or char_length(comentario) <= 500),
  criado_em timestamptz not null default now(),
  lido_em timestamptz
);
create index if not exists treino_feedback_trn_idx on public.treino_feedback (treinador_id, criado_em desc);
create index if not exists treino_feedback_aluno_idx on public.treino_feedback (aluno_id, criado_em desc);
alter table public.treino_feedback enable row level security;
revoke all on public.treino_feedback from anon, authenticated;
grant select on public.treino_feedback to authenticated;
drop policy if exists "feedback: aluno le" on public.treino_feedback;
create policy "feedback: aluno le" on public.treino_feedback for select using (aluno_id = auth.uid());

-- ---------- 7. Chat treinador ↔ aluno ----------
create table if not exists public.treinador_mensagens (
  id uuid primary key default gen_random_uuid(),
  treinador_id uuid not null references public.treinadores(user_id) on delete cascade,
  aluno_id uuid not null references auth.users(id) on delete cascade,
  autor uuid not null references auth.users(id) on delete cascade,
  texto text not null check (char_length(trim(texto)) between 1 and 2000),
  criado_em timestamptz not null default now(),
  lida_em timestamptz
);
create index if not exists treinador_mensagens_idx on public.treinador_mensagens (treinador_id, aluno_id, criado_em desc);
alter table public.treinador_mensagens enable row level security;
revoke all on public.treinador_mensagens from anon, authenticated;
grant select on public.treinador_mensagens to authenticated;
drop policy if exists "mensagens: participantes leem" on public.treinador_mensagens;
create policy "mensagens: participantes leem" on public.treinador_mensagens for select
  using (aluno_id = auth.uid() or treinador_id = auth.uid());

-- ---------- 8. PRO pelo treinador ----------
-- Até quando o aluno tem PRO por causa do treinador (null = não tem).
create or replace function public.pro_treinador_ate(p_user uuid)
returns timestamptz language sql stable security definer set search_path = public, pg_temp as $$
  select max(case
      when v.status = 'ativo' then t.plano_ate
      else least(t.plano_ate, v.encerrado_em + interval '7 days')
    end)
  from treinador_alunos v join treinadores t on t.user_id = v.treinador_id
  where v.aluno_id = p_user and t.ativo and t.plano <> 'gratis' and t.plano_ate > now()
    and (v.status = 'ativo' or v.encerrado_em > now() - interval '7 days');
$$;
revoke all on function public.pro_treinador_ate(uuid) from public, anon, authenticated;

create or replace function public.eh_pro(p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from user_subscriptions s
    where s.user_id = p_user and s.is_premium and (s.expiration_date is null or s.expiration_date > now())
  ) or exists (select 1 from pro_cortesia c where c.user_id = p_user and c.ate > now())
  or coalesce(pro_treinador_ate(p_user) > now(), false)
  or eh_admin(p_user)
$$;

-- O app usa essa data pra liberar o PRO (cortesia ou treinador, o que for maior).
create or replace function public.meu_pro_cortesia()
returns timestamptz language sql stable security definer set search_path = public, pg_temp as $$
  select nullif(greatest(
    coalesce((select ate from pro_cortesia where user_id = (select auth.uid()) and ate > now()), '-infinity'::timestamptz),
    coalesce(pro_treinador_ate((select auth.uid())), '-infinity'::timestamptz)
  ), '-infinity'::timestamptz);
$$;
revoke all on function public.meu_pro_cortesia() from public, anon;
grant execute on function public.meu_pro_cortesia() to authenticated;

-- ---------- 9. Virar treinador e perfil ----------
create or replace function public.trn_gerar_codigo(p_nome text)
returns text language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare base text; c text; tentativas int := 0;
begin
  base := upper(regexp_replace(translate(coalesce(p_nome, ''), 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ', 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC'), '[^A-Za-z]', '', 'g'));
  base := regexp_replace(base, '^(PROF|PROFESSOR|PROFA|PERSONAL|COACH)', '');
  if char_length(base) < 3 then base := 'TRN'; end if;
  base := left(base, 4);
  loop
    c := base || '-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 3));
    exit when not exists (select 1 from treinadores where codigo = c);
    tentativas := tentativas + 1;
    if tentativas > 20 then raise exception 'não consegui gerar código'; end if;
  end loop;
  return c;
end $$;
revoke all on function public.trn_gerar_codigo(text) from public, anon, authenticated;

-- Ativa (ou reativa) o modo Treinador. Primeira vez: 14 dias de teste na faixa Start.
-- Os 50 primeiros viram fundadores (metade do preço pra sempre).
create or replace function public.virar_treinador(p_nome text, p_cref text default null, p_cidade text default null, p_especialidades text[] default '{}', p_bio text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_eu uuid := auth.uid(); v_novo boolean;
begin
  if v_eu is null then raise exception 'precisa entrar'; end if;
  if exists (select 1 from auth.users where id = v_eu and is_anonymous) then raise exception 'SALVE_A_CONTA'; end if;
  v_novo := not exists (select 1 from treinadores where user_id = v_eu);
  if v_novo then
    perform pg_advisory_xact_lock(hashtext('treinador_fundador'));
    insert into treinadores (user_id, nome, cref, cidade, especialidades, bio, codigo, plano, plano_ate, em_teste, fundador)
    values (v_eu, trim(p_nome), nullif(trim(p_cref), ''), nullif(trim(p_cidade), ''), coalesce(p_especialidades, '{}'), nullif(trim(p_bio), ''),
            trn_gerar_codigo(p_nome), 'start', now() + interval '14 days', true,
            (select count(*) from treinadores) < 50);
  else
    update treinadores set nome = trim(p_nome), cref = nullif(trim(p_cref), ''), cidade = nullif(trim(p_cidade), ''),
      especialidades = coalesce(p_especialidades, '{}'), bio = nullif(trim(p_bio), ''), ativo = true, atualizado_em = now()
    where user_id = v_eu;
  end if;
  return trn_eu();
end $$;
revoke all on function public.virar_treinador(text, text, text, text[], text) from public, anon;
grant execute on function public.virar_treinador(text, text, text, text[], text) to authenticated;

-- Meu perfil de treinador (null se não sou).
create or replace function public.trn_eu()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'user_id', t.user_id, 'nome', t.nome, 'cref', t.cref, 'cidade', t.cidade, 'especialidades', t.especialidades,
    'bio', t.bio, 'codigo', t.codigo, 'plano', t.plano, 'plano_vigente', trn_plano_vigente(t.user_id),
    'plano_ate', t.plano_ate, 'em_teste', t.em_teste, 'fundador', t.fundador, 'ativo', t.ativo,
    'limite', trn_limite(trn_plano_vigente(t.user_id)),
    'alunos_ativos', (select count(*) from treinador_alunos v where v.treinador_id = t.user_id and v.status = 'ativo'),
    'avatar_url', (select u.avatar_url from users u where u.id = t.user_id),
    'email', (select email from auth.users a where a.id = t.user_id),
    'vagas_fundador', greatest(0, 50 - (select count(*) from treinadores where fundador))
  )
  from treinadores t where t.user_id = auth.uid();
$$;
revoke all on function public.trn_eu() from public, anon;
grant execute on function public.trn_eu() to authenticated;

-- ---------- 10. Convite: prévia, aceitar, sair ----------
create or replace function public.previa_treinador(p_codigo text)
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object('nome', t.nome, 'cidade', t.cidade, 'especialidades', t.especialidades, 'cref', t.cref,
    'avatar_url', u.avatar_url, 'da_pro', trn_plano_vigente(t.user_id) <> 'gratis')
  from treinadores t left join users u on u.id = t.user_id
  where t.codigo = upper(trim(p_codigo)) and t.ativo;
$$;
revoke all on function public.previa_treinador(text) from public, anon;
grant execute on function public.previa_treinador(text) to authenticated;

create or replace function public.aceitar_treinador(p_codigo text, p_ver_medidas boolean default true, p_ver_fotos boolean default false, p_ver_dieta boolean default false)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_eu uuid := auth.uid(); t treinadores; v_ativos int;
begin
  if v_eu is null then raise exception 'precisa entrar'; end if;
  select * into t from treinadores where codigo = upper(trim(p_codigo)) and ativo;
  if t.user_id is null then raise exception 'CONVITE_INVALIDO'; end if;
  if t.user_id = v_eu then raise exception 'CONVITE_PROPRIO'; end if;
  if exists (select 1 from treinador_alunos where aluno_id = v_eu and treinador_id = t.user_id and status = 'ativo') then
    return jsonb_build_object('ok', true, 'ja_era', true);
  end if;
  perform pg_advisory_xact_lock(hashtext('trn_vagas_' || t.user_id::text));
  select count(*) into v_ativos from treinador_alunos where treinador_id = t.user_id and status = 'ativo';
  if v_ativos >= trn_limite(trn_plano_vigente(t.user_id)) then raise exception 'TREINADOR_SEM_VAGA'; end if;
  -- Sai do treinador anterior (se tinha).
  update treinador_alunos set status = 'saiu', encerrado_em = now() where aluno_id = v_eu and status = 'ativo';
  insert into treinador_alunos (treinador_id, aluno_id, ver_medidas, ver_fotos, ver_dieta)
  values (t.user_id, v_eu, coalesce(p_ver_medidas, true), coalesce(p_ver_fotos, false), coalesce(p_ver_dieta, false));
  insert into push_fila (user_id, titulo, texto, rota)
  values (t.user_id, 'Aluno novo!', coalesce((select full_name from users where id = v_eu), 'Um aluno') || ' aceitou seu convite.', '/treinador');
  return jsonb_build_object('ok', true, 'treinador', t.nome, 'da_pro', trn_plano_vigente(t.user_id) <> 'gratis');
end $$;
revoke all on function public.aceitar_treinador(text, boolean, boolean, boolean) from public, anon;
grant execute on function public.aceitar_treinador(text, boolean, boolean, boolean) to authenticated;

-- Meu treinador (lado do aluno).
create or replace function public.meu_treinador()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object('vinculo_id', v.id, 'treinador_id', t.user_id, 'nome', t.nome, 'cidade', t.cidade,
    'avatar_url', u.avatar_url, 'desde', v.criado_em, 'ver_medidas', v.ver_medidas, 'ver_fotos', v.ver_fotos, 'ver_dieta', v.ver_dieta,
    'pro_ate', pro_treinador_ate(v.aluno_id))
  from treinador_alunos v join treinadores t on t.user_id = v.treinador_id left join users u on u.id = t.user_id
  where v.aluno_id = auth.uid() and v.status = 'ativo';
$$;
revoke all on function public.meu_treinador() from public, anon;
grant execute on function public.meu_treinador() to authenticated;

create or replace function public.mudar_permissoes_treinador(p_ver_medidas boolean, p_ver_fotos boolean, p_ver_dieta boolean)
returns void language sql security definer set search_path = public, pg_temp as $$
  update treinador_alunos set ver_medidas = p_ver_medidas, ver_fotos = p_ver_fotos, ver_dieta = p_ver_dieta
  where aluno_id = auth.uid() and status = 'ativo';
$$;
revoke all on function public.mudar_permissoes_treinador(boolean, boolean, boolean) from public, anon;
grant execute on function public.mudar_permissoes_treinador(boolean, boolean, boolean) to authenticated;

-- Aluno sai: a ficha do treinador fica com ele (vira dele), o histórico também.
create or replace function public.sair_do_treinador()
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v treinador_alunos;
begin
  select * into v from treinador_alunos where aluno_id = auth.uid() and status = 'ativo';
  if v.id is null then return; end if;
  update treinador_alunos set status = 'saiu', encerrado_em = now() where id = v.id;
  insert into push_fila (user_id, titulo, texto, rota)
  values (v.treinador_id, 'Aluno saiu', coalesce((select full_name from users where id = v.aluno_id), 'Um aluno') || ' saiu da sua lista.', '/treinador');
end $$;
revoke all on function public.sair_do_treinador() from public, anon;
grant execute on function public.sair_do_treinador() to authenticated;

create or replace function public.trn_remover_aluno(p_aluno uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform trn_exigir_aluno(p_aluno);
  update treinador_alunos set status = 'removido', encerrado_em = now()
  where treinador_id = auth.uid() and aluno_id = p_aluno and status = 'ativo';
end $$;
revoke all on function public.trn_remover_aluno(uuid) from public, anon;
grant execute on function public.trn_remover_aluno(uuid) to authenticated;

-- ---------- 11. Painel do treinador ----------
-- Lista de alunos com o que o painel precisa.
create or replace function public.trn_alunos()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform trn_exigir();
  return coalesce((
    select jsonb_agg(x order by x->>'nome')
    from (
      select jsonb_build_object(
        'id', v.aluno_id, 'desde', v.criado_em,
        'nome', coalesce(u.full_name, 'Aluno'), 'usuario', u.username, 'avatar_url', u.avatar_url,
        'sequencia', coalesce(u.current_streak, 0), 'meta_semana', coalesce(u.workout_frequency_per_week, 4),
        'ultimo_treino', (select max(s.completed_at) from workout_sessions s where s.user_id = v.aluno_id and s.status = 'completed'),
        'treinando_agora', exists (select 1 from workout_sessions s where s.user_id = v.aluno_id and s.status = 'in_progress' and s.started_at > now() - interval '3 hours'),
        'treinos_semana', (select count(*) from workout_sessions s where s.user_id = v.aluno_id and s.status = 'completed' and s.completed_at >= date_trunc('week', now())),
        'treinos_30d', (select count(*) from workout_sessions s where s.user_id = v.aluno_id and s.status = 'completed' and s.completed_at > now() - interval '30 days'),
        'ficha', (select jsonb_build_object('id', p.id, 'nome', p.nome, 'vence_em', p.vence_em) from programas p
                  where p.user_id = v.aluno_id and p.treinador_id = v.treinador_id order by p.ativo desc, p.created_at desc limit 1),
        'feedback_novo', (select count(*) from treino_feedback f where f.aluno_id = v.aluno_id and f.treinador_id = v.treinador_id and f.lido_em is null),
        'mensagens_novas', (select count(*) from treinador_mensagens m where m.aluno_id = v.aluno_id and m.treinador_id = v.treinador_id and m.autor = v.aluno_id and m.lida_em is null)
      ) as x
      from treinador_alunos v left join users u on u.id = v.aluno_id
      where v.treinador_id = auth.uid() and v.status = 'ativo'
    ) q
  ), '[]'::jsonb);
end $$;
revoke all on function public.trn_alunos() from public, anon;
grant execute on function public.trn_alunos() to authenticated;

-- Tudo de um aluno (respeitando o que ele liberou).
create or replace function public.trn_aluno(p_aluno uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare v treinador_alunos;
begin
  perform trn_exigir_aluno(p_aluno);
  select * into v from treinador_alunos where treinador_id = auth.uid() and aluno_id = p_aluno and status = 'ativo';
  return jsonb_build_object(
    'id', p_aluno, 'desde', v.criado_em,
    'permissoes', jsonb_build_object('medidas', v.ver_medidas, 'fotos', v.ver_fotos, 'dieta', v.ver_dieta),
    'perfil', (select jsonb_build_object('nome', coalesce(u.full_name, 'Aluno'), 'usuario', u.username, 'avatar_url', u.avatar_url,
        'genero', u.gender, 'sequencia', coalesce(u.current_streak, 0), 'recorde_sequencia', coalesce(u.longest_streak, 0),
        'meta_semana', coalesce(u.workout_frequency_per_week, 4), 'total_treinos', coalesce(u.total_workouts, 0))
      from users u where u.id = p_aluno),
    'fichas', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'nome', p.nome, 'ativo', p.ativo, 'vence_em', p.vence_em,
        'treinos', coalesce((select jsonb_agg(jsonb_build_object('id', w.id, 'nome', w.name, 'exercises', w.exercises, 'posicao', w.posicao) order by w.posicao, w.created_at)
                             from workouts w where w.programa_id = p.id), '[]'::jsonb)) order by p.ativo desc, p.created_at desc)
      from programas p where p.user_id = p_aluno and p.treinador_id = auth.uid()), '[]'::jsonb),
    'sessoes', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'workout_id', s.workout_id, 'inicio', s.started_at, 'fim', s.completed_at,
        'minutos', s.duration_minutes, 'exercicios', s.exercises_completed) order by s.completed_at desc)
      from (select * from workout_sessions where user_id = p_aluno and status = 'completed' order by completed_at desc limit 40) s), '[]'::jsonb),
    'feedbacks', coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'sessao_id', f.sessao_id, 'esforco', f.esforco, 'incomodos', f.incomodos,
        'comentario', f.comentario, 'criado_em', f.criado_em, 'lido', f.lido_em is not null) order by f.criado_em desc)
      from (select * from treino_feedback where aluno_id = p_aluno and treinador_id = auth.uid() order by criado_em desc limit 30) f), '[]'::jsonb),
    'pesos', case when v.ver_medidas then coalesce((select jsonb_agg(jsonb_build_object('dia', b.measured_on, 'kg', b.weight_kg) order by b.measured_on)
      from (select * from body_weights where user_id = p_aluno order by measured_on desc limit 60) b), '[]'::jsonb) else null end,
    'anamnese', (select a.respostas from treinador_anamneses a where a.treinador_id = auth.uid() and a.aluno_id = p_aluno)
  );
end $$;
revoke all on function public.trn_aluno(uuid) from public, anon;
grant execute on function public.trn_aluno(uuid) to authenticated;

-- Salva a ficha que o treinador monta pro aluno.
-- p_treinos: [{ "id": uuid|null, "nome": "Peito e tríceps", "exercises": [...] }] na ordem.
-- Treino que estava na ficha e não veio na lista é apagado. A ficha vira a ativa do aluno.
create or replace function public.trn_salvar_ficha(p_aluno uuid, p_ficha uuid, p_nome text, p_treinos jsonb, p_vence_em date default null, p_avisar boolean default true)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_ficha uuid := p_ficha; t jsonb; i int := 0; v_ids uuid[] := '{}'; v_id uuid; v_nome_trn text;
begin
  perform trn_exigir_aluno(p_aluno);
  if jsonb_typeof(p_treinos) <> 'array' or jsonb_array_length(p_treinos) = 0 then raise exception 'FICHA_VAZIA'; end if;
  if jsonb_array_length(p_treinos) > 7 then raise exception 'MAXIMO_7_TREINOS'; end if;
  if v_ficha is null then
    insert into programas (user_id, nome, ativo, posicao, treinador_id, vence_em)
    values (p_aluno, left(trim(p_nome), 60), false, 0, auth.uid(), p_vence_em)
    returning id into v_ficha;
  else
    if not exists (select 1 from programas where id = v_ficha and user_id = p_aluno and treinador_id = auth.uid()) then
      raise exception 'FICHA_NAO_E_SUA';
    end if;
    update programas set nome = left(trim(p_nome), 60), vence_em = p_vence_em where id = v_ficha;
  end if;
  for t in select * from jsonb_array_elements(p_treinos) loop
    i := i + 1;
    if jsonb_typeof(t->'exercises') <> 'array' or jsonb_array_length(t->'exercises') = 0 then raise exception 'TREINO_SEM_EXERCICIO'; end if;
    v_id := nullif(t->>'id', '')::uuid;
    if v_id is not null and exists (select 1 from workouts where id = v_id and programa_id = v_ficha) then
      update workouts set name = left(coalesce(t->>'nome', 'Treino'), 60), exercises = t->'exercises', posicao = i,
        estimated_duration = coalesce((t->>'minutos')::int, estimated_duration), updated_at = now()
      where id = v_id;
    else
      insert into workouts (user_id, name, exercises, is_ai_generated, programa_id, posicao, treinador_id, estimated_duration, workout_type)
      values (p_aluno, left(coalesce(t->>'nome', 'Treino'), 60), t->'exercises', false, v_ficha, i, auth.uid(),
              coalesce((t->>'minutos')::int, 45), left(coalesce(t->>'tipo', ''), 60))
      returning id into v_id;
    end if;
    v_ids := v_ids || v_id;
  end loop;
  delete from workouts where programa_id = v_ficha and not (id = any(v_ids));
  update programas set ativo = false where user_id = p_aluno and ativo and id <> v_ficha;
  update programas set ativo = true where id = v_ficha;
  if p_avisar then
    select nome into v_nome_trn from treinadores where user_id = auth.uid();
    insert into push_fila (user_id, titulo, texto, rota)
    values (p_aluno, 'Treino novo do seu treinador', v_nome_trn || ' atualizou sua ficha "' || left(trim(p_nome), 60) || '".', '/treinos');
  end if;
  return v_ficha;
end $$;
revoke all on function public.trn_salvar_ficha(uuid, uuid, text, jsonb, date, boolean) from public, anon;
grant execute on function public.trn_salvar_ficha(uuid, uuid, text, jsonb, date, boolean) to authenticated;

-- Manda um modelo pra vários alunos (cada um recebe uma cópia).
create or replace function public.trn_enviar_modelo(p_modelo uuid, p_alunos uuid[], p_vence_em date default null)
returns int language plpgsql security definer set search_path = public, pg_temp as $$
declare m treinador_modelos; a uuid; n int := 0;
begin
  perform trn_exigir();
  select * into m from treinador_modelos where id = p_modelo and treinador_id = auth.uid();
  if m.id is null then raise exception 'MODELO_NAO_ENCONTRADO'; end if;
  foreach a in array p_alunos loop
    perform trn_salvar_ficha(a, null, m.nome, m.treinos, p_vence_em, true);
    n := n + 1;
  end loop;
  update treinador_modelos set usos = usos + n where id = m.id;
  return n;
end $$;
revoke all on function public.trn_enviar_modelo(uuid, uuid[], date) from public, anon;
grant execute on function public.trn_enviar_modelo(uuid, uuid[], date) to authenticated;

create or replace function public.trn_salvar_anamnese(p_aluno uuid, p_respostas jsonb)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform trn_exigir_aluno(p_aluno);
  insert into treinador_anamneses (treinador_id, aluno_id, respostas) values (auth.uid(), p_aluno, coalesce(p_respostas, '{}'))
  on conflict (treinador_id, aluno_id) do update set respostas = excluded.respostas, atualizado_em = now();
end $$;
revoke all on function public.trn_salvar_anamnese(uuid, jsonb) from public, anon;
grant execute on function public.trn_salvar_anamnese(uuid, jsonb) to authenticated;

create or replace function public.trn_marcar_feedbacks_lidos(p_aluno uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform trn_exigir_aluno(p_aluno);
  update treino_feedback set lido_em = now() where treinador_id = auth.uid() and aluno_id = p_aluno and lido_em is null;
end $$;
revoke all on function public.trn_marcar_feedbacks_lidos(uuid) from public, anon;
grant execute on function public.trn_marcar_feedbacks_lidos(uuid) to authenticated;

-- ---------- 12. Feedback e chat ----------
create or replace function public.enviar_feedback_treino(p_sessao uuid, p_esforco int, p_incomodos text[] default '{}', p_comentario text default null)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_trn uuid;
begin
  if not exists (select 1 from workout_sessions where id = p_sessao and user_id = auth.uid()) then raise exception 'SESSAO_NAO_E_SUA'; end if;
  select treinador_id into v_trn from treinador_alunos where aluno_id = auth.uid() and status = 'ativo';
  insert into treino_feedback (sessao_id, aluno_id, treinador_id, esforco, incomodos, comentario)
  values (p_sessao, auth.uid(), v_trn, p_esforco, coalesce(p_incomodos, '{}'), nullif(trim(p_comentario), ''))
  on conflict (sessao_id) do update set esforco = excluded.esforco, incomodos = excluded.incomodos, comentario = excluded.comentario;
  if v_trn is not null and p_comentario is not null and trim(p_comentario) <> '' then
    insert into push_fila (user_id, titulo, texto, rota)
    values (v_trn, 'Feedback de ' || coalesce((select split_part(full_name, ' ', 1) from users where id = auth.uid()), 'aluno'),
            'Esforço ' || p_esforco || '/10: ' || left(trim(p_comentario), 120), '/treinador');
  end if;
end $$;
revoke all on function public.enviar_feedback_treino(uuid, int, text[], text) from public, anon;
grant execute on function public.enviar_feedback_treino(uuid, int, text[], text) to authenticated;

-- Manda mensagem no chat. Treinador: p_outro = aluno. Aluno: p_outro = null (vai pro treinador dele).
create or replace function public.trn_mandar_mensagem(p_texto text, p_aluno uuid default null)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_trn uuid; v_aluno uuid; v_id uuid; v_para uuid; v_nome text;
begin
  if p_aluno is not null then
    perform trn_exigir_aluno(p_aluno);
    v_trn := auth.uid(); v_aluno := p_aluno; v_para := p_aluno;
    select nome into v_nome from treinadores where user_id = v_trn;
  else
    select treinador_id into v_trn from treinador_alunos where aluno_id = auth.uid() and status = 'ativo';
    if v_trn is null then raise exception 'SEM_TREINADOR'; end if;
    v_aluno := auth.uid(); v_para := v_trn;
    select split_part(coalesce(full_name, 'Aluno'), ' ', 1) into v_nome from users where id = v_aluno;
  end if;
  insert into treinador_mensagens (treinador_id, aluno_id, autor, texto) values (v_trn, v_aluno, auth.uid(), trim(p_texto))
  returning id into v_id;
  insert into push_fila (user_id, titulo, texto, rota)
  values (v_para, coalesce(v_nome, 'Mensagem'), left(trim(p_texto), 140), case when v_para = v_trn then '/treinador' else '/meu-treinador' end);
  return v_id;
end $$;
revoke all on function public.trn_mandar_mensagem(text, uuid) from public, anon;
grant execute on function public.trn_mandar_mensagem(text, uuid) to authenticated;

create or replace function public.trn_ler_mensagens(p_aluno uuid default null)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if p_aluno is not null then
    perform trn_exigir_aluno(p_aluno);
    update treinador_mensagens set lida_em = now() where treinador_id = auth.uid() and aluno_id = p_aluno and autor = p_aluno and lida_em is null;
  else
    update treinador_mensagens set lida_em = now() where aluno_id = auth.uid() and autor <> auth.uid() and lida_em is null;
  end if;
end $$;
revoke all on function public.trn_ler_mensagens(uuid) from public, anon;
grant execute on function public.trn_ler_mensagens(uuid) to authenticated;

-- ---------- 13. Proteção: ficha do treinador ----------
-- Vínculo ativo entre aluno e treinador (usado pelos gatilhos abaixo, que rodam como quem chamou).
create or replace function public.trn_vinculo_ativo(p_aluno uuid, p_trn uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (select 1 from treinador_alunos v where v.aluno_id = p_aluno and v.treinador_id = p_trn and v.status = 'ativo');
$$;
revoke all on function public.trn_vinculo_ativo(uuid, uuid) from public, anon;
grant execute on function public.trn_vinculo_ativo(uuid, uuid) to authenticated;
-- O aluno não edita nem apaga treino montado pelo treinador (só o treinador, pelas funções).
-- Continua podendo mudar a ordem e ativar outra ficha.
-- Sem security definer de propósito: current_user diz se quem mexe é o app (authenticated) ou uma função do servidor.
create or replace function public.workouts_do_treinador_protegido()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if old.treinador_id is null then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  -- Funções do treinador (security definer) rodam como dono: liberado.
  if current_user not in ('authenticated', 'anon') then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  -- Aluno: apagar só se ele já saiu do treinador; editar só posição/ficha.
  if tg_op = 'DELETE' then
    if trn_vinculo_ativo(old.user_id, old.treinador_id) then
      raise exception 'TREINO_DO_TREINADOR';
    end if;
    return old;
  end if;
  if trn_vinculo_ativo(old.user_id, old.treinador_id)
     and (new.exercises is distinct from old.exercises or new.name is distinct from old.name or new.treinador_id is distinct from old.treinador_id) then
    raise exception 'TREINO_DO_TREINADOR';
  end if;
  return new;
end $$;
drop trigger if exists workouts_do_treinador_protegido on public.workouts;
create trigger workouts_do_treinador_protegido before update or delete on public.workouts
  for each row execute function public.workouts_do_treinador_protegido();

-- Ficha do treinador também não pode ser apagada pelo aluno enquanto o vínculo está ativo.
create or replace function public.programas_do_treinador_protegido()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if old.treinador_id is not null and current_user in ('authenticated', 'anon')
     and trn_vinculo_ativo(old.user_id, old.treinador_id) then
    raise exception 'TREINO_DO_TREINADOR';
  end if;
  return old;
end $$;
drop trigger if exists programas_do_treinador_protegido on public.programas;
create trigger programas_do_treinador_protegido before delete on public.programas
  for each row execute function public.programas_do_treinador_protegido();

-- Só as funções do servidor marcam (ou desmarcam) uma ficha/treino como do treinador.
create or replace function public.treinador_id_so_servidor()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if current_user in ('authenticated', 'anon') then
    if tg_op = 'INSERT' and new.treinador_id is not null then
      raise exception 'TREINO_DO_TREINADOR';
    end if;
    if tg_op = 'UPDATE' and new.treinador_id is distinct from old.treinador_id then
      raise exception 'TREINO_DO_TREINADOR';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists treinador_id_so_servidor on public.programas;
create trigger treinador_id_so_servidor before insert or update on public.programas
  for each row execute function public.treinador_id_so_servidor();
drop trigger if exists treinador_id_so_servidor on public.workouts;
create trigger treinador_id_so_servidor before insert or update on public.workouts
  for each row execute function public.treinador_id_so_servidor();
