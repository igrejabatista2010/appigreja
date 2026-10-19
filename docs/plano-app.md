# Plano de implementação — App (Flutter)

Plano de execução e status do app. **Regras e requisitos não ficam aqui**: estão na skill [`app-igreja`](../.claude/skills/app-igreja/SKILL.md) (stack, pacotes, estrutura de pastas, convenções, casos de uso, navegação). Cada caso de uso só está pronto quando cumpre a **definição de pronto** (seção 12 da skill).

Plano do backend: [plano-backend.md](plano-backend.md). Dependências aparecem como `← B2.1` (precisa da tarefa do backend antes).

**Como usar:** marcar `[x]` ao concluir. Ao fim de cada etapa: `flutter analyze` sem warnings e `flutter test` passando.

Rodar no emulador: `flutter run --dart-define-from-file=env/dev.json`.

**Fora de escopo até as etapas 6 e 7:**
- Notificações: Firebase, registro de dispositivo, recebimento de push, notificação avulsa. Nas telas, as opções "Enviar notificação" (UC-18) e "Notificar membros ao publicar" (UC-14) salvam o valor no banco, mas o push só passa a sair na etapa 6.
- Flavors `dev`/`prod`, Codemagic e builds para as lojas. Até lá o app roda só no emulador, apontando para o `dev`.

---

## Etapa 1 — Fundação

- [ ] A1.1 `pubspec.yaml` com os pacotes da seção 3 da skill, **exceto os de push** (`firebase_*`, `flutter_local_notifications`, que entram na etapa 6). Remover o app de exemplo.
- [ ] A1.2 Inicialização: `main.dart` com `Supabase.initialize` lendo `env/dev.json`, `tz.initializeTimeZones()` e `.vscode/launch.json` com o `--dart-define-from-file`.
- [ ] A1.3 `core/`: `di/injection.dart` (get_it), `error/` (`Failure` sealed + exceptions), `usecase/usecase.dart` (`UseCase`, `NoParams`), `utils/church_time.dart` (`nowSp`, `todaySp`, `toSp`) com testes.
- [ ] A1.4 Tema com cores e logo placeholder em `core/theme`; l10n pt_BR (ARB + `flutter gen-l10n`).
- [ ] A1.5 `core/widgets`: carregando, erro com "Tentar novamente", vazio e `RoleGuard`.
- [ ] A1.6 `go_router`: shell responsivo (`NavigationBar` < 600, `NavigationRail` ≥ 600), destinos principais e páginas placeholder.
- [ ] A1.7 `analysis_options.yaml` com lints estritos; `flutter analyze` e `flutter test` limpos.

## Etapa 2 — Auth e membros (UC-01 a UC-10)

- [ ] A2.1 Domain compartilhado: `Role` (`hasAtLeast`), `MemberStatus`, entidade `Member`.
- [ ] A2.2 Feature `auth` (domain + data): `signUp` com metadata e detecção de e-mail já cadastrado (`identities` vazio), `verifyOTP` (signup e recovery), `resend`, `signIn` (`email_not_confirmed`), `resetPasswordForEmail`, `updateUser` (nova senha), `signOut`.
- [ ] A2.3 Telas: login, cadastro, confirmar e-mail (código + reenviar em 60s), recuperar senha (código + nova senha), aguardando aprovação ("Verificar novamente"), sem permissão. ← B1.8 para testar com e-mail real
- [ ] A2.4 `AuthBloc` global: sessão persistida, carrega a própria linha de `members`, escuta o Realtime (`user_id=eq.<uid>`), `blocked` → `signOut` + mensagem.
- [ ] A2.5 Guardas do `go_router` (`refreshListenable`), com testes para sem sessão, pending, member, leader e admin.
- [ ] A2.6 UC-05 Excluir minha conta (confirmação dupla). ← B2.4
- [ ] A2.7 UC-06 Meu perfil: editar nome, telefone, nascimento, endereço, gênero, estado civil e foto (compressão 512px); batismo e membresia só leitura. ← B2.0, B2.3
- [ ] A2.8 UC-07 Diretório: member pela RPC; leader/admin direto na tabela, com "Ligar" e "WhatsApp". Busca com debounce de 400ms e paginação. ← B2.1
- [ ] A2.9 UC-08 Aniversariantes do mês. ← B2.2
- [ ] A2.10 UC-09 Aprovações (admin): aprovar, recusar, excluir. ← B2.5
- [ ] A2.11 UC-10 Gestão de membros (admin): editar a ficha completa, role e status, cadastro manual, mensagens de erro do banco (último admin, própria role). ← B2.0

> UC-04 (sair) nesta etapa só faz `signOut`. A remoção do token do dispositivo entra com A6.2.

## Etapa 3 — Agenda/eventos, estudo diário e oração

- [ ] A3.1 UC-11 Agenda: `table_calendar` com cultos fixos expandidos no mês + eventos publicados. ← B3.1, B3.2
- [ ] A3.2 UC-12 Detalhe do evento: mapa e compartilhar. ← B3.2
- [ ] A3.3 UC-13 Confirmar/cancelar presença, com "Esgotado" vindo do banco. ← B3.3
- [ ] A3.4 UC-14 Gestão de eventos (leader/admin): CRUD, capa (1200px), publicar, "Notificar membros" (só salva o valor). ← B3.2
- [ ] A3.5 UC-15 Agenda fixa (admin). ← B3.1
- [ ] A3.6 UC-16 Lista de confirmados (leader/admin). ← B3.3
- [ ] A3.7 UC-31 Estudo do dia + histórico com busca (`flutter_markdown_plus`). ← B3.4
- [ ] A3.8 UC-32 Marcar como lido + "dias seguidos". ← B3.4 (B3.5 se necessário)
- [ ] A3.9 UC-33 Programar estudos (leader/admin). ← B3.4
- [ ] A3.10 UC-22 Criar pedido de oração. ← B3.6
- [ ] A3.11 UC-23 Mural com "Estou orando". ← B3.6
- [ ] A3.12 UC-24 Meus pedidos. ← B3.6
- [ ] A3.13 UC-25 e UC-26 Pedidos da liderança e moderação. ← B3.6

## Etapa 4 — Comunicados e mídias (UC-17, UC-18, UC-27 a UC-30)

- [ ] A4.1 UC-17 e UC-18 Comunicados: feed com fixados e gestão ("Enviar notificação" só salva o valor). ← B4.1
- [ ] A4.2 UC-27 Galeria: álbuns, fotos e visualizador com zoom (`photo_view`). ← B4.2
- [ ] A4.3 UC-28 Vídeos do YouTube. ← B4.2
- [ ] A4.4 UC-29 e UC-30 Gestão de mídias: upload múltiplo (1600px + miniatura 400px) com progresso e nova tentativa; capa, ordem e exclusão (removendo os arquivos do Storage); adicionar vídeo por URL. ← B4.2

## Etapa 5 — Financeiro e Início (UC-35 a UC-37, UC-41 a UC-43, UC-39)

- [ ] A5.1 UC-35 a UC-37 Contas a pagar (admin): mês, filtros, totais, vencidas em vermelho, máscara R$ em centavos, comprovante, "Copiar contas do mês anterior". ← B5.1
- [ ] A5.2 UC-41 a UC-43 Fluxo de caixa (admin): saldo, resumo do mês por categoria, lista de movimentações, registrar entrada (doador: membro ou nome livre) e saída avulsa. ← B5.2, B5.3
- [ ] A5.3 UC-39 Início: estudo do dia, próximos eventos, últimos comunicados, aniversariantes da semana, pull-to-refresh.

## Etapa 6 — Notificações (UC-19 a UC-21)

- [ ] A6.1 Firebase no app: `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, `flutterfire configure`, permissões iOS/Android versionadas. ← B6.1
- [ ] A6.2 UC-19 Registrar dispositivo após qualquer login (pending ou approved) + `onTokenRefresh`; UC-04 passa a remover o token ao sair. ← B6.2
- [ ] A6.3 UC-20 `push_service`: notificação local em primeiro plano e navegação ao tocar (aberto, em segundo plano ou fechado).
- [ ] A6.4 UC-21 Notificação avulsa (leader/admin), com pré-visualização. ← B6.4

## Etapa 7 — Distribuição, polimento e publicação

- [ ] A7.1 Flavors `dev`/`prod` (ids `…igreja.dev` e `…igreja`), `env/prod.json` e Firebase por flavor. ← B7.2
- [ ] A7.2 `codemagic.yaml`: Android e iOS (TestFlight), um workflow por flavor, chaves em variáveis criptografadas.
- [ ] A7.3 Ícone, splash e nome do app (`flutter_launcher_icons`, `flutter_native_splash`), com as cores e o logo da igreja.
- [ ] A7.4 URL da política de privacidade configurável (exigida pelas lojas).
- [ ] A7.5 Revisão de acessibilidade (fonte escalável, alvos ≥ 48px, contraste AA) e de layout em tablet.
- [ ] A7.6 Versão de teste para a cliente e para um grupo da igreja; ajustes.
- [ ] A7.7 Publicação na Play Store e na App Store (contas da igreja).
