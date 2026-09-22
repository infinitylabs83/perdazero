-- ==========================================
-- PERDAZERO — SCHEMA COMPLETO (multi-tenant + RLS)
-- Reflete exatamente o que está em produção desde 22/09/2026.
-- Seguro rodar em um projeto Supabase NOVO e vazio, do zero.
-- NÃO contém nenhum DROP TABLE — não use isto contra um projeto com dados.
-- ==========================================

-- 1. TABELAS
-- ------------------------------------------
create table if not exists contas (
  id uuid primary key default gen_random_uuid(),
  nome_rede text not null default 'Minha Empresa',
  logo_rede text,
  plano text not null default 'trial',
  trial_expira_em timestamptz default (now() + interval '14 days'),
  ativo boolean default true,
  meta_mensal numeric default 0,
  criado_em timestamptz default now()
);

create table if not exists perfis (
  id uuid primary key references auth.users(id) on delete cascade,
  conta_id uuid not null references contas(id) on delete cascade,
  nome text not null,
  funcao text not null default 'admin',
  avatar text default '👔',
  criado_em timestamptz default now()
);

create table if not exists lojas (
  id serial primary key,
  conta_id uuid not null references contas(id) on delete cascade,
  nome text not null,
  slug_acesso text unique not null default substring(md5(random()::text), 1, 8)
);

create table if not exists equipe (
  id serial primary key,
  conta_id uuid not null references contas(id) on delete cascade,
  loja_id int references lojas(id) on delete cascade,
  nome text not null,
  funcao text not null default 'operacional',
  codigo text default '', -- PIN de 4 dígitos; NUNCA é exposto ao navegador (ver seção 4)
  avatar text default '👨‍🍳'
);

create table if not exists produtos (
  id serial primary key,
  conta_id uuid not null references contas(id) on delete cascade,
  nome text not null,
  icone text default '📦',
  custo numeric default 0,
  unidade text default 'un'
);

create table if not exists historico (
  id serial primary key,
  conta_id uuid not null references contas(id) on delete cascade,
  loja_id int references lojas(id) on delete cascade,
  relator text,
  responsavel text,
  prod text,
  qtd numeric default 0,
  uni text default 'un',
  motivo text,
  observacao text,
  hora text,
  img text default '📦',
  custo_total numeric default 0,
  foto_url text, -- caminho dentro do bucket privado "fotos_perdas" (não é mais URL pública)
  timestamp bigint default (extract(epoch from now()) * 1000)::bigint,
  comentario_gestor text
);

-- 2. RLS — cada conta só vê os próprios dados
-- ------------------------------------------
alter table contas    enable row level security;
alter table perfis    enable row level security;
alter table lojas     enable row level security;
alter table equipe    enable row level security;
alter table produtos  enable row level security;
alter table historico enable row level security;

create or replace function minha_conta_id()
returns uuid
language sql stable security definer
as $$
  select conta_id from perfis where id = auth.uid() limit 1
$$;

create policy "contas_select"  on contas  for select using (id = minha_conta_id());
create policy "contas_update"  on contas  for update using (id = minha_conta_id());

create policy "perfis_select"  on perfis  for select using (conta_id = minha_conta_id());

create policy "lojas_select"   on lojas   for select   to authenticated using (conta_id = minha_conta_id());
create policy "lojas_insert"   on lojas   for insert   with check (conta_id = minha_conta_id());
create policy "lojas_update"   on lojas   for update   using (conta_id = minha_conta_id());
create policy "lojas_delete"   on lojas   for delete   using (conta_id = minha_conta_id());

create policy "equipe_select"  on equipe  for select   to authenticated using (conta_id = minha_conta_id());
create policy "equipe_insert"  on equipe  for insert   with check (conta_id = minha_conta_id());
create policy "equipe_update"  on equipe  for update   using (conta_id = minha_conta_id());
create policy "equipe_delete"  on equipe  for delete   using (conta_id = minha_conta_id());

create policy "produtos_select" on produtos for select to authenticated using (conta_id = minha_conta_id());
create policy "produtos_insert" on produtos for insert with check (conta_id = minha_conta_id());
create policy "produtos_update" on produtos for update using (conta_id = minha_conta_id());
create policy "produtos_delete" on produtos for delete using (conta_id = minha_conta_id());

create policy "hist_select" on historico for select to authenticated using (conta_id = minha_conta_id());
create policy "hist_update" on historico for update to authenticated using (conta_id = minha_conta_id());
create policy "hist_delete" on historico for delete to authenticated using (conta_id = minha_conta_id());
-- Sem NENHUMA política pública de leitura/escrita em lojas/equipe/produtos/historico.
-- O fluxo do QR (sem login) passa inteiro pelas funções da seção 4.

-- 3. TRIGGERS
-- ------------------------------------------

-- Cria conta + perfil admin automaticamente no signup
create or replace function handle_novo_usuario()
returns trigger
language plpgsql security definer
as $$
declare
  nova_conta_id uuid;
begin
  insert into contas (nome_rede)
  values (coalesce(new.raw_user_meta_data->>'nome_rede', 'Minha Empresa'))
  returning id into nova_conta_id;

  insert into perfis (id, conta_id, nome, funcao, avatar)
  values (
    new.id, nova_conta_id,
    coalesce(new.raw_user_meta_data->>'nome', split_part(new.email, '@', 1)),
    'admin', '👔'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_novo_usuario();

-- Impede o próprio dono de mudar plano/trial pelo navegador (só service_role pode)
create or replace function protege_colunas_plano()
returns trigger
language plpgsql
as $$
begin
  if auth.role() <> 'service_role' then
    new.plano           := old.plano;
    new.trial_expira_em := old.trial_expira_em;
    new.ativo           := old.ativo;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protege_plano on contas;
create trigger trg_protege_plano
  before update on contas
  for each row execute function protege_colunas_plano();

-- 4. FUNÇÕES DO FLUXO QR (sem login) — SECURITY DEFINER
-- ------------------------------------------
-- O funcionário nunca faz select direto nas tabelas: tudo passa por aqui,
-- que valida o slug/loja no servidor e nunca devolve o PIN ("codigo").

create or replace function qr_contexto_loja(p_slug text)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_loja lojas%rowtype;
  v_result jsonb;
begin
  select * into v_loja from lojas where slug_acesso = p_slug;
  if not found then return null; end if;

  select jsonb_build_object(
    'loja', jsonb_build_object('id', v_loja.id, 'nome', v_loja.nome, 'conta_id', v_loja.conta_id),
    'conta', (select jsonb_build_object('id', c.id, 'nome_rede', c.nome_rede, 'logo_rede', c.logo_rede)
              from contas c where c.id = v_loja.conta_id and c.ativo = true),
    'equipe', (select coalesce(jsonb_agg(jsonb_build_object(
                 'id', e.id, 'nome', e.nome, 'avatar', e.avatar,
                 'funcao', e.funcao, 'loja_id', e.loja_id,
                 'tem_senha', (e.funcao <> 'operacional' and coalesce(e.codigo,'') <> '')
               )), '[]'::jsonb) from equipe e where e.loja_id = v_loja.id),
    'produtos', (select coalesce(jsonb_agg(jsonb_build_object(
                   'id', p.id, 'nome', p.nome, 'icone', p.icone,
                   'custo', p.custo, 'unidade', p.unidade
                 )), '[]'::jsonb) from produtos p where p.conta_id = v_loja.conta_id)
  ) into v_result;

  return v_result;
end;
$$;

create or replace function qr_verificar_pin(p_membro_id int, p_pin text)
returns boolean
language sql security definer set search_path = public
as $$
  select exists (
    select 1 from equipe
    where id = p_membro_id and codigo = p_pin and coalesce(codigo,'') <> ''
  );
$$;

create or replace function qr_registrar_perda(
  p_slug text, p_loja_id int, p_relator text, p_responsavel text,
  p_prod text, p_qtd numeric, p_uni text, p_motivo text,
  p_observacao text, p_icone text, p_custo_unitario numeric,
  p_foto_path text
)
returns historico
language plpgsql security definer set search_path = public
as $$
declare
  v_loja lojas%rowtype;
  v_row historico%rowtype;
begin
  select * into v_loja from lojas where slug_acesso = p_slug and id = p_loja_id;
  if not found then raise exception 'Loja inválida para este QR Code'; end if;

  if not exists (select 1 from contas where id = v_loja.conta_id and ativo = true) then
    raise exception 'Conta inativa';
  end if;

  insert into historico (
    conta_id, loja_id, relator, responsavel, prod, qtd, uni, motivo,
    observacao, hora, img, custo_total, foto_url, timestamp
  ) values (
    v_loja.conta_id, v_loja.id, p_relator, p_responsavel, p_prod, p_qtd, p_uni, p_motivo,
    p_observacao, 'Hoje, ' || to_char(now(), 'HH24:MI'),
    p_icone, p_qtd * p_custo_unitario, p_foto_path,
    (extract(epoch from now()) * 1000)::bigint
  ) returning * into v_row;

  return v_row;
end;
$$;

grant execute on function qr_contexto_loja(text) to anon, authenticated;
grant execute on function qr_verificar_pin(int, text) to anon, authenticated;
grant execute on function qr_registrar_perda(text,int,text,text,text,numeric,text,text,text,text,numeric,text) to anon, authenticated;

-- 5. STORAGE: fotos das perdas (bucket privado, com limite de tamanho/tipo)
-- ------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos_perdas', 'fotos_perdas', false, 5242880, array['image/jpeg','image/png','image/webp','image/heic'])
on conflict (id) do update set public = false, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/heic'];

-- Upload: só dentro da pasta de uma conta ativa e existente (contaId/arquivo.ext)
create policy "fotos_upload_restrito" on storage.objects
  for insert with check (
    bucket_id = 'fotos_perdas'
    and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
    and exists (select 1 from contas where id = (storage.foldername(name))[1]::uuid and ativo = true)
  );

-- Leitura: só o dono autenticado da própria conta (via supabase.storage.createSignedUrl no app)
create policy "fotos_leitura_dono" on storage.objects
  for select to authenticated using (
    bucket_id = 'fotos_perdas'
    and (storage.foldername(name))[1] = minha_conta_id()::text
  );

-- ==========================================
-- FIM. Depois de rodar num projeto novo:
--   1. Authentication > Settings > Site URL = URL do seu app
--   2. Testar cadastro de um dono, criar 1 loja/produto/funcionário,
--      escanear o QR e registrar uma perda de teste.
-- ==========================================
