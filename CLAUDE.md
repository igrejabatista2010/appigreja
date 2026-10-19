# church_app

App mobile da igreja (Flutter + BLoC + Clean Architecture + Supabase).

A especificação completa (stack, pacotes permitidos, roles, modelo de dados, casos de uso e ordem de implementação) está em [.claude/skills/app-igreja/SKILL.md](.claude/skills/app-igreja/SKILL.md). Siga-a em qualquer criação ou alteração de funcionalidade, tela, tabela, política RLS ou Edge Function.

Qualquer mudança no banco ou no backend Supabase segue o fluxo da skill [supabase-migrations](.claude/skills/supabase-migrations/SKILL.md): sempre por arquivo em `supabase/migrations/` aplicado com `supabase db push`, nunca pelo painel.

## Onde paramos

O que fazer a seguir e o que já está pronto ficam nos planos:
- [docs/plano-backend.md](docs/plano-backend.md) — Supabase (tarefas `B<etapa>.<n>`)
- [docs/plano-app.md](docs/plano-app.md) — Flutter (tarefas `A<etapa>.<n>`)

Outros documentos:
- [docs/requisitos-cliente.md](docs/requisitos-cliente.md) — conversa original com a cliente e decisões tomadas
- [docs/modelo-dados.md](docs/modelo-dados.md) — diagrama das tabelas (resumo da seção 7 da skill; atualizar junto)

Ao concluir uma tarefa, marque `[x]` no plano correspondente. Regras e requisitos ficam só na skill `app-igreja`; os planos apenas referenciam UCs e seções dela.
