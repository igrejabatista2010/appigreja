# Plano de implementação — Backend (Supabase)

Plano de execução e status do backend. **Regras e requisitos não ficam aqui**: estão na skill [`app-igreja`](../.claude/skills/app-igreja/SKILL.md) (seção 7: modelo de dados, RLS, Edge Functions, cron). Como aplicar mudanças: skill [`supabase-migrations`](../.claude/skills/supabase-migrations/SKILL.md).

Plano do app: [plano-app.md](plano-app.md). Dependências entre os dois aparecem como `→ A2.3` (tarefa do app que usa esta).

**Como usar:** marcar `[x]` ao concluir, com a migration/arquivo entre parênteses. Toda tarefa de banco termina com teste em `supabase/tests/` passando e `supabase db advisors --linked` sem avisos novos.

**Fora de escopo até a etapa 6:** push (Firebase, `send-push`, `device_tokens`, triggers de push, jobs do pg_cron). Colunas ligadas a push (`announcements.send_push`, `events.notify_on_publish`, `events.notified_at`) já são criadas com as tabelas, mas sem efeito até lá.

## Ambiente

| | `dev` (atual) | `prod` (etapa 7) |
|---|---|---|
| Projeto | `appigrejabatista` (ref `lktcchedpmisuuniesqy`) | a criar |
| Região | `us-east-1` | **South America (São Paulo)** |
| Plano | Free | Pro |
| Conta | conta da igreja | conta da igreja |

O `dev` é descartável: serve para desenvolver e será desligado depois que o `prod` existir.

---

## Etapa 1 — Fundação

- [x] B1.1 CLI instalada, `supabase init` e `link` com o projeto `dev`. Senha do banco em `supabase/.env`.
- [x] B1.2 Auth no `config.toml` + `config push`: confirmação de e-mail, OTP de 6 dígitos, senha mínima 8, reenvio a cada 60s.
- [x] B1.3 Extensões `pg_cron` e `pg_net` (`20261019195108_enable_extensions`).
- [x] B1.4 `members`, tipos `member_role`/`member_status`, trigger de `updated_at`, guarda de role/status/e-mail do próprio usuário, proteção do último admin, RLS e Realtime (`20261019195110_create_members`).
- [x] B1.5 Vínculo `auth.users` → `members` só após confirmar o e-mail (`20261019195112_link_auth_users_to_members`).
- [x] B1.6 Funções de RLS movidas para o schema `private` e políticas unificadas, conforme advisors (`20261019195337_move_rls_helpers_to_private_schema`).
- [x] B1.7 Teste `supabase/tests/members_rls_test.sql`: 13 grupos passando.
- [ ] B1.8 **SMTP pelo Gmail da igreja + templates pt-BR com `{{ .Token }}`** (fazer quando for testar cadastro/login, etapa 2).
  1. No Gmail da igreja: ativar a verificação em 2 etapas e gerar uma **senha de app**.
  2. Em `supabase/.env`: `SMTP_USER=<gmail da igreja>` e `SMTP_PASS=<senha de app>`.
  3. Descomentar no `config.toml` o bloco `[auth.email.smtp]` e os dois templates; `supabase config diff` e `config push`.
  4. Testar: cadastro com um e-mail qualquer recebe o código em pt-BR.
  - Bloqueia o fluxo por código do UC-01 e UC-03: sem SMTP, o Free não aceita templates e o e-mail padrão só chega para membros da equipe do Supabase. → A2.3
- [ ] B1.9 Script `supabase/scripts/first_admin.sql` (fora das migrations): promove a admin aprovado o membro com um e-mail informado. Rodar uma vez por ambiente.

## Etapa 2 — Auth e membros (UC-01 a UC-10, UC-40)

- [x] B2.0 Campos da ficha em `members` (`address`, `gender`, `marital_status`, `baptism_date`, `membership_date`) + enums + guarda: o próprio membro não altera batismo/membresia; + teste (`20261019204436_add_profile_fields_to_members`; `members_rls_test.sql` com 14 grupos). → A2.7, A2.11
- [ ] B2.1 RPC `public.get_member_directory(search, limit, offset)` → `id, full_name, photo_url`, só aprovados, + teste. → A2.8
- [ ] B2.2 RPC `public.get_birthdays(from_date, to_date)` → sem o ano, com virada de ano (29/dez–04/jan), + teste. → A2.9
- [ ] B2.3 Bucket público `avatars` + políticas (cada usuário escreve só na própria pasta), + teste. → A2.7
- [ ] B2.4 Edge Function `delete-account` (ordem: apaga `members`, depois o Auth; erro amigável de último admin). → A2.6
- [ ] B2.5 Edge Function `admin-delete-member` (valida admin aprovado pelo JWT, mesma ordem, bloqueia a si mesmo). → A2.10
- [ ] B2.6 Script `tool/import_inchurch.dart` (UC-40): upsert por `inchurch_id`, idempotente, relatório de registros sem e-mail.
  - Precisa do JSON exportado da InChurch e da secret key via variável de ambiente.

## Etapa 3 — Agenda/eventos, estudo diário e oração (UC-11 a UC-16, UC-22 a UC-26, UC-31 a UC-33)

- [ ] B3.1 `schedule_items` + RLS (admin escreve, aprovados leem) + teste. → A3.5
- [ ] B3.2 `events` + RLS (leader edita os próprios, admin todos; members veem só publicados) + bucket `event-covers` + teste. → A3.1, A3.4
- [ ] B3.3 `event_rsvps` + trigger de lotação (`for update` no evento) + RPC `get_event_rsvp_summary` + teste com concorrência. → A3.3, A3.6
- [ ] B3.4 `daily_studies` (RLS por `publish_date` em São Paulo) + `daily_study_reads` + teste. → A3.7–A3.9
- [ ] B3.5 Contagem de "dias seguidos" (UC-32): RPC `get_study_streak()` no fuso de São Paulo, se o cálculo no app ficar pesado.
- [ ] B3.6 `prayer_requests` + `prayer_intercessions` + RPC `get_prayer_feed` (anônimos ocultos para member) + teste. → A3.10–A3.13

## Etapa 4 — Comunicados e mídias (UC-17, UC-18, UC-27 a UC-30)

- [ ] B4.1 `announcements` + RLS (`audience`, leader edita os próprios) + teste. → A4.1
- [ ] B4.2 `media_albums` (`cover_photo_id`), `media_photos` (`thumb_path`, `position`), `videos` + RLS + bucket `media` (pastas por álbum) + teste. → A4.2–A4.4

## Etapa 5 — Financeiro e Início (UC-35 a UC-37, UC-41 a UC-43, UC-39)

> Antes de começar: mostrar o fluxo de caixa (UC-41 a UC-43) à cliente, já que vai além do que ela pediu.

- [ ] B5.1 `bills` + RLS (só admin) + bucket privado `receipts` (URL assinada) + teste. → A5.1
- [ ] B5.2 `cash_entries` + RLS (só admin) + trigger em `bills` que gera/remove/atualiza a saída ao pagar/desfazer + trigger que bloqueia editar saídas ligadas a contas + teste. → A5.2
- [ ] B5.3 RPC `get_cash_summary(from_date, to_date)`: saldo atual, entradas e saídas do período, totais por categoria + teste. → A5.2
- [ ] B5.4 Início (UC-39): sem tabela nova. Avaliar uma RPC `get_home_summary` só se a tela ficar lenta com várias consultas.

## Etapa 6 — Notificações (UC-19 a UC-21, UC-34, UC-38 e os pushes dos outros UCs)

- [ ] B6.1 Projeto Firebase (conta da igreja) e service account para FCM HTTP v1, guardada como secret. Compartilhado com A6.1.
- [ ] B6.2 `device_tokens` + RLS (própria linha, **sem** exigir aprovação) + teste. → A6.2
- [ ] B6.3 `push_log` + RLS (leitura só admin).
- [ ] B6.4 Edge Function `send-push`: públicos `all`, `leaders`, `admins` e um membro específico; remove tokens inválidos; grava em `push_log`; valida leader quando chamada pelo app. → A6.4
- [ ] B6.5 Vault com URL da função e chave + função `private.enqueue_push(...)` usando `net.http_post`.
- [ ] B6.6 Triggers de push:
  - `members` novo `pending` → admins;
  - `members` `pending` → `approved` → o próprio membro (UC-09);
  - `events` publicado com `notify_on_publish` (`before insert or update`, `notified_at`);
  - `announcements` com `send_push`.
- [ ] B6.7 pg_cron `0 9 * * *` (06:00 SP): estudo do dia (UC-34).
- [ ] B6.8 pg_cron `0 11 * * *` (08:00 SP): contas vencendo em até 2 dias → admins (UC-38).

## Etapa 7 — Produção

- [ ] B7.1 Criar o projeto `prod` em São Paulo, plano Pro, na conta da igreja.
- [ ] B7.2 `link` no prod → `db push` → `config push` → `functions deploy` → `secrets set` → segredos no Vault.
- [ ] B7.3 SMTP do Gmail da igreja e templates no prod (mesmo `config.toml`, `SMTP_*` no `.env`), conferidos com envio real de cadastro e recuperação de senha.
- [ ] B7.4 `first_admin.sql` com o e-mail da cliente.
- [ ] B7.5 Importação da InChurch no prod (B2.6) e conferência do relatório.
- [ ] B7.6 Advisors sem avisos, backups diários conferidos, proteção de senhas vazadas ativada.
- [ ] B7.7 Desligar o projeto `dev` quando não for mais necessário.
