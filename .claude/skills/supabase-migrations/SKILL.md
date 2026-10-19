---
name: supabase-migrations
description: Fluxo obrigatório para qualquer mudança no banco do Supabase deste app (tabelas, colunas, RLS, funções, triggers, views, buckets, cron, extensões, configuração do Auth e Edge Functions). Use sempre que for criar ou alterar algo no banco ou no backend Supabase, mesmo que seja "só uma coluna" ou "só uma política".
---

# Migrations do Supabase

O projeto usa **Supabase na nuvem** (sem Docker / sem stack local). O repositório é a fonte da verdade: o projeto `dev` e o futuro `prod` precisam poder ser recriados idênticos só com `supabase db push` + `supabase config push`.

Regras de modelagem (tabelas, RLS, roles, fuso, FKs) estão na skill `app-igreja`, seção 7. Esta skill trata do **como aplicar**.

## 1. Regra de ouro

**Toda mudança de schema vira um arquivo em `supabase/migrations/`.** Nunca criar ou alterar tabela, coluna, política, função, trigger, view, bucket, cron ou extensão pelo painel ou pelo SQL Editor.

Exceções (ficam fora das migrations porque são dados ou segredos, não schema):
- segredos no **Vault** (URL da `send-push`, chave usada pelo `pg_net`) e secrets das Edge Functions;
- script único do primeiro admin (`supabase/scripts/`, rodado à mão em cada ambiente);
- senha do SMTP (vem de variável de ambiente no `config.toml`).

O SQL Editor e o `supabase db query --linked` podem ser usados **só para consultar e testar** (ver seção 5).

## 2. Fluxo para mudar o banco

1. Criar o arquivo:
   ```bash
   supabase migration new <descricao_em_snake_case>
   ```
   Ex.: `create_members`, `add_notify_on_publish_to_events`, `rls_prayer_requests`.
2. Escrever o SQL no arquivo gerado (`supabase/migrations/<timestamp>_<nome>.sql`), seguindo as convenções da seção 3.
3. Conferir o que será aplicado:
   ```bash
   supabase db push --dry-run
   ```
4. Aplicar no projeto linkado:
   ```bash
   supabase db push
   ```
5. Confirmar com `supabase migration list` (local e remoto devem bater).
6. Rodar o teste da tabela (`supabase/tests/`) e `supabase db advisors --linked`.
7. Marcar a tarefa como concluída em `docs/plano-backend.md`, citando a migration.
8. Commit da migration junto com o código do app que depende dela.

Se o projeto ainda não estiver linkado: `supabase login` e `supabase link --project-ref <ref>`.

A senha do banco fica em `supabase/.env` (fora do git), na chave `DATABASE_PASSWORD`. Os comandos que conectam no banco (`link`, `db push`, `migration list`) a recebem pela variável `SUPABASE_DB_PASSWORD`, carregada sem imprimir o valor:

```powershell
$line = Get-Content supabase\.env | Where-Object { $_ -match '^DATABASE_PASSWORD=' }
$env:SUPABASE_DB_PASSWORD = ($line -replace '^DATABASE_PASSWORD=','').Trim('"')
```

## 3. Convenções do SQL

- **Nunca editar uma migration que já foi aplicada** (`db push`). Para corrigir, criar uma nova migration.
- Uma migration = um assunto. Não misturar features.
- Comentário no topo explicando o porquê e o UC relacionado (ex.: `-- UC-13: lotação garantida no banco`).
- Toda tabela nova, **na mesma migration**:
  - `id uuid primary key default gen_random_uuid()`, `created_at timestamptz not null default now()`, `updated_at timestamptz not null default now()` + trigger de `updated_at`;
  - `alter table ... enable row level security;`
  - as políticas de RLS dela (nenhuma tabela fica sem política no mesmo push);
  - FKs com o `on delete` definido na skill `app-igreja` (seção 7).
- Funções: `create or replace function`; `security definer` sempre com `set search_path = ''` (e nomes qualificados, ex.: `public.members`) ou `set search_path = public`.
- Funções auxiliares de RLS (`is_admin()` etc.) ficam no schema **`private`**, nunca em `public` (que é exposto em `/rest/v1/rpc`). Nas políticas: `(select private.is_admin())`.
- Só RPCs feitas para o app ficam em `public`: `revoke execute ... from anon, public;` e `grant execute ... to authenticated;`.
- Trigger functions `security definer` em `public`: `revoke execute ... from public, anon, authenticated;`.
- Uma política permissiva por ação (`select`, `insert`, `update`, `delete`). Juntar condições com `or` em vez de criar duas políticas para a mesma ação.
- "Hoje" em SQL: `(now() at time zone 'America/Sao_Paulo')::date`. Nunca `current_date`.
- Nada de segredo, URL de projeto ou e-mail de pessoa escrito no SQL. Ler do Vault (`vault.decrypted_secrets`).
- Nomes em inglês, `snake_case`; textos visíveis ao usuário (mensagens de exceção que chegam ao app) em pt-BR.

### Esqueleto de tabela nova

```sql
-- UC-XX: <motivo>
create table public.<tabela> (
  id uuid primary key default gen_random_uuid(),
  -- colunas
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_updated_at
  before update on public.<tabela>
  for each row execute function public.set_updated_at();

alter table public.<tabela> enable row level security;

create policy "<tabela>: select"
  on public.<tabela> for select to authenticated
  using ((select private.is_approved()));

create policy "<tabela>: insert"
  on public.<tabela> for insert to authenticated
  with check ((select private.is_leader()));

create policy "<tabela>: update"
  on public.<tabela> for update to authenticated
  using ((select private.is_leader()))
  with check ((select private.is_leader()));

create policy "<tabela>: delete"
  on public.<tabela> for delete to authenticated
  using ((select private.is_leader()));
```

Depois de todo `db push`, rodar `supabase db advisors --linked` e corrigir os avisos (numa nova migration). O aviso sobre `public.rls_auto_enable()` é de uma função criada pelo próprio Supabase e pode ser ignorado.

## 4. Outras partes do backend

| O que mudou | Onde fica | Como aplicar |
|---|---|---|
| Auth (confirmação de e-mail, OTP, senha mínima, templates, SMTP) | `supabase/config.toml` e `supabase/templates/` | `supabase config push` (mostra o diff e pede confirmação) |
| Edge Function | `supabase/functions/<nome>/index.ts` | `supabase functions deploy <nome> --use-api` (sem Docker) |
| Secrets de Edge Function | nunca no repositório | `supabase secrets set NOME=valor` |
| Buckets e políticas de Storage | migration (`insert into storage.buckets` + políticas em `storage.objects`) | `supabase db push` |
| Jobs do pg_cron | migration (`cron.schedule(...)`) | `supabase db push` |

## 5. Testar RLS sem Docker

Os testes ficam em `supabase/tests/<assunto>_rls_test.sql` e rodam direto no projeto linkado:

```bash
supabase db query --linked -f supabase/tests/members_rls_test.sql
```

Formato (ver `members_rls_test.sql` como modelo):
- um único bloco `do $$ ... $$` que cria os usuários de teste em `auth.users` (os triggers criam os `members`), ajusta roles como `postgres` e depois simula cada usuário com:
  ```sql
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', <uuid>, 'role', 'authenticated')::text, true);
  ```
- cada verificação que falha faz `raise exception 'FALHOU: ...'`;
- o bloco **sempre termina** com `raise exception 'TESTES OK: ...'`. A exceção desfaz tudo, então nada fica gravado no banco. O "erro" com `TESTES OK` é o resultado esperado.
- cobrir member, leader, admin e, quando fizer sentido, pending.

Toda tabela nova ganha seu arquivo de teste (ou um bloco no teste existente) na mesma tarefa da migration.

## 6. Proibido sem confirmação explícita do usuário

- `supabase db reset --linked` (apaga o banco remoto inteiro);
- migration com `drop table`, `drop column`, `truncate` ou que apague dados;
- `supabase db push` ou `supabase config push` no projeto de **produção**.

Antes de qualquer um desses, mostrar o SQL/diff ao usuário e esperar o "ok".
