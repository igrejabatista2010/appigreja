---
name: app-igreja
description: Especificação e regras de implementação do app mobile da igreja (Flutter + BLoC + Clean Architecture + Supabase). Use sempre que for criar, alterar ou revisar qualquer funcionalidade, tela, tabela, política RLS ou Edge Function deste app.
---

# App da Igreja — Especificação para implementação

> Esta skill define **o quê** e **como**. A ordem das tarefas e o que já foi feito ficam em [`docs/plano-backend.md`](../../../docs/plano-backend.md) e [`docs/plano-app.md`](../../../docs/plano-app.md).

## 1. Contexto

- App mobile **Android e iOS** (celular e tablet) para **uma única igreja**, sem filiais, com ~150–250 membros.
- Substitui a InChurch. **Não há versão web**, nem dízimo ou pagamentos online.
- A administração acontece **dentro do próprio app**, liberada por perfil de acesso.
- Idioma da interface: **português do Brasil**. Fuso: `America/Sao_Paulo`.

## 2. Regras inegociáveis de stack

1. **Flutter** (canal stable mais recente) com Dart null-safety. Plataformas: apenas `android` e `ios`.
2. **Estado: `flutter_bloc` com Bloc (Events + States).**
   - Cubit só é permitido para estado de UI trivial e local, como mostrar/ocultar senha.
   - Proibido Provider, Riverpod, GetX, MobX ou `setState` para estado de negócio.
3. **Clean Architecture por feature:** `presentation → domain ← data`.
   - A camada `domain` é Dart puro: não importa Flutter, Supabase nem Firebase.
4. **Backend: Supabase.**
   - Recursos usados: Auth, Postgres com RLS, Storage, Edge Functions e pg_cron.
   - Não existe servidor próprio.
5. **Push: Firebase Cloud Messaging** (Android, e iOS via APNs), disparado por Edge Function do Supabase.
6. **Vídeos: apenas links do YouTube.** Nunca fazer upload de vídeo para o Storage.
7. **Build iOS: Codemagic** (o desenvolvedor não tem Mac).
   - Nada pode depender de passos manuais no Xcode local.
   - Configurações nativas iOS (capabilities, Info.plist, entitlements) ficam versionadas no repositório.
8. **A segurança vem da RLS.** Esconder botões na UI é só experiência do usuário, nunca controle de acesso.
9. Nunca embarcar a **secret key** (`sb_secret_...`, antiga `service_role`) no app.
   - `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` (`sb_publishable_...`, antiga `anon`) entram via `--dart-define-from-file=env/<ambiente>.json`, com `env/*.json` no `.gitignore`.
   - No código: `Supabase.initialize(url: ..., anonKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'))`. O parâmetro do `supabase_flutter` ainda se chama `anonKey`, mas recebe a publishable key.

## 3. Pacotes permitidos

| Uso | Pacote |
|---|---|
| Estado | `flutter_bloc`, `bloc_concurrency`, `equatable` |
| Resultado funcional | `fpdart` (`Either<Failure, T>`) |
| Injeção de dependência | `get_it` (`injectable` opcional) |
| Rotas | `go_router` |
| Backend | `supabase_flutter` |
| Push | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` |
| Imagens | `cached_network_image`, `image_picker`, `flutter_image_compress`, `photo_view` |
| Vídeo | `youtube_player_iframe` |
| Calendário | `table_calendar` |
| Formatação / i18n | `intl`, `flutter_localizations` |
| Links externos | `url_launcher`, `share_plus` |
| Markdown (estudo diário) | `flutter_markdown_plus` (o `flutter_markdown` foi descontinuado) |
| Fuso horário | `timezone` |
| Ícone e splash (dev_dependencies) | `flutter_launcher_icons`, `flutter_native_splash` |
| Testes | `flutter_test`, `bloc_test`, `mocktail` |

Não adicionar outros pacotes sem justificar no commit.

## 4. Estrutura de pastas

```
lib/
  main.dart
  app.dart                      # MaterialApp.router, tema, BlocProviders globais
  core/
    di/injection.dart           # registro get_it
    error/failures.dart         # Failure (sealed) e subtipos
    error/exceptions.dart
    usecase/usecase.dart        # abstract class UseCase<T, Params>
    router/app_router.dart      # go_router + guards de auth/status/role
    theme/                      # cores da igreja, tipografia
    l10n/                       # ARB pt_BR
    utils/                      # datas, moeda (centavos), validadores, compressão de imagem
    widgets/                    # componentes compartilhados (loading, erro com retry, vazio)
    push/push_service.dart      # FCM + notificações locais + roteamento por payload
  features/
    auth/
    members/
    schedule/                   # agenda recorrente + eventos + RSVP
    announcements/              # mensagens das lideranças
    notifications/              # registro de dispositivo e envio avulso
    prayer/
    media/                      # álbuns de fotos e vídeos
    daily_study/
    finance/                    # contas a pagar
    home/
```

Cada feature segue esta estrutura:

```
features/<feature>/
  domain/
    entities/
    repositories/               # interfaces (abstract class)
    usecases/                   # uma classe por caso de uso
  data/
    models/                     # fromJson/toJson + toEntity()/fromEntity()
    datasources/                # <feature>_remote_datasource.dart (Supabase)
    repositories/               # implementações
  presentation/
    bloc/                       # <nome>_bloc.dart, _event.dart, _state.dart
    pages/
    widgets/
```

Os testes espelham `lib/` dentro de `test/`.

## 5. Convenções de código

- **UseCase:** uma classe por caso de uso, com método `call(Params)` que retorna `Future<Either<Failure, T>>`.
  - Sem parâmetros, usar `NoParams`.
- **Repository impl:**
  - captura `PostgrestException`, `AuthException`, `StorageException`, `SocketException` e `FunctionException`;
  - converte cada uma para o `Failure` correspondente (`ServerFailure`, `AuthFailure`, `NetworkFailure`, `PermissionFailure`, `NotFoundFailure`, `ValidationFailure`);
  - nunca deixa exceção chegar ao Bloc.
- **State:** usar uma única classe com `enum Status { initial, loading, success, failure }` mais `copyWith`.
  - Vale para telas com lista, formulário ou paginação.
  - Para fluxos simples, usar sealed classes.
- **Eventos de busca:** usar `restartable()` do `bloc_concurrency`.
- **Eventos de submit:** usar `droppable()`.
- **Paginação:** 20 itens por página via `.range()`, com scroll infinito.
- **Datas:** salvar como `timestamptz` (UTC) e exibir convertidas para `America/Sao_Paulo`, no formato `pt_BR`.
  - Converter com o pacote `timezone` (`tz.initializeTimeZones()` no `main`), **independente do fuso do aparelho**.
  - Centralizar em `core/utils/church_time.dart`, com as funções `nowSp()`, `todaySp()` e `toSp(DateTime)`.
  - "Hoje" (estudo do dia, contas vencidas, aniversariantes) é sempre o dia em São Paulo.
- **Dinheiro:** sempre inteiro em **centavos** (`amount_cents`), formatado como `R$` só na UI.
- **Imagens:** comprimir antes do upload.
  - Fotos de galeria: lado maior 1600px, qualidade 80, mais miniatura de 400px.
  - Avatar e capa: 512px e 1200px, respectivamente.
- **Strings:** nada de texto literal em widget; tudo nos ARB `pt_BR`.
- **Layout responsivo:**
  - largura < 600: `NavigationBar` inferior;
  - largura ≥ 600 (tablet): `NavigationRail` e grids com mais colunas.
- **Estados de tela:** toda tela com dado remoto trata **carregando, vazio, erro (com "Tentar novamente") e sucesso**.
- **Testes obrigatórios:** teste unitário para todo usecase (com repository mockado) e todo Bloc (`bloc_test`).

## 6. Perfis e permissões (roles)

O sistema **tem níveis de permissão obrigatórios**. A hierarquia é cumulativa: cada nível herda tudo do nível abaixo.

| Role | Quem é | Hierarquia |
|---|---|---|
| `member` | Membro aprovado da igreja | 1 (base) |
| `leader` | Líder de ministério, pastor auxiliar | 2 (member + gestão de conteúdo) |
| `admin` | Administrador do sistema (secretaria, pastor titular) | 3 (acesso total) |

`members.role`: `member` | `leader` | `admin` (padrão `member`)
`members.status`: `pending` | `approved` | `blocked`

O login é obrigatório. Só usuário `approved` acessa o conteúdo; `pending` vê apenas a tela "Aguardando aprovação".

### 6.1 Como a permissão é aplicada (3 camadas, todas obrigatórias)

1. **Banco (RLS):** a camada de segurança real.
   - Toda política de INSERT, UPDATE e DELETE de conteúdo administrativo usa `private.is_leader()` ou `private.is_admin()`.
   - Mesmo que alguém altere o app, o banco recusa.
2. **Rotas (`go_router`):**
   - rotas de gestão ficam em `/gestao/*` (leader+);
   - rotas de administração ficam em `/admin/*` (admin);
   - o `redirect` lê a role do `AuthBloc` e manda para `/sem-permissao` quem não tiver nível.
3. **UI:** menus, botões e abas de gestão só são renderizados para quem tem a role.
   - Usar o widget `RoleGuard(minRole: Role.leader, child: ...)` em `core/widgets`.

### 6.2 Implementação no app

- **Domain:** `enum Role { member, leader, admin }`, com o método `bool hasAtLeast(Role other)` (comparação por índice).
- **`AuthBloc` (global):** mantém `AuthState` com `user`, `member`, `role` e `status`.
  - Carrega o registro de `members` após o login.
  - Escuta mudanças da própria linha via **Supabase Realtime**. Se um admin rebaixar ou bloquear alguém, o app reage na hora: rotas reavaliadas, menus atualizados e logout se o usuário for bloqueado.
- **Repositórios:** nunca confiam em role vinda da UI. Quem decide é sempre a RLS.
- **Testes obrigatórios:**
  - Bloc e guardas de rota testados para as três roles;
  - políticas RLS testadas com três usuários de teste (um por role) no ambiente `dev`, por scripts em `supabase/tests/` (formato na skill `supabase-migrations`, seção 5).

### 6.3 Telas exclusivas por role

**Leader e admin** (área "Gestão", no menu Mais):
- Criar/editar eventos e ver a lista de confirmados (UC-14, UC-16)
- Publicar comunicados (UC-18)
- Notificação avulsa (UC-21)
- Pedidos de oração da liderança (UC-25)
- Criar álbuns e adicionar vídeos (UC-29, UC-30)
- Programar estudos diários (UC-33)
- Diretório com contatos completos (UC-07, visão estendida)

**Somente admin** (área "Administração", no menu Mais):
- Aprovação de cadastros (UC-09)
- Gestão de membros: editar dados, **alterar role** e status, cadastro manual (UC-10)
- Agenda recorrente (UC-15)
- Moderação de pedidos de oração (UC-26)
- Financeiro — contas a pagar (UC-35 a UC-38)

**Regras de role:**
- Só `admin` altera a role de alguém, e ninguém altera a própria role (bloqueado pela RLS).
- Deve existir **pelo menos um admin** aprovado sempre. Isso é garantido no banco por triggers em `members`, valendo para qualquer origem (app, Edge Function ou SQL):
  - `before update`: impede rebaixar ou bloquear o último admin aprovado;
  - `before delete`: impede excluir o último admin aprovado. Cobre a `delete-account` e a `admin-delete-member`.
  - Um único trigger (`members_protect_last_admin`, `before update of role, status or delete`) pega um `pg_advisory_xact_lock` antes de contar, para duas operações simultâneas não removerem os dois últimos admins.
  - O erro tem `hint = 'last_admin'`, que o app usa para mostrar a mensagem certa.
- O primeiro admin **não** fica em migration (o e-mail muda por ambiente). É definido pelo script `supabase/scripts/first_admin.sql`, rodado uma vez em cada ambiente depois de a pessoa criar a conta.

| Recurso | member | leader | admin |
|---|---|---|---|
| Ver agenda, eventos, comunicados, mídias, estudos | ✅ | ✅ | ✅ |
| Confirmar presença em evento | ✅ | ✅ | ✅ |
| Diretório de membros (nome + foto) | ✅ | ✅ | ✅ |
| Aniversário de outros membros (só dia/mês) | ✅ | ✅ | ✅ |
| Ver telefone, e-mail e data de nascimento completa de outros membros | ❌ | ✅ | ✅ |
| Criar pedido de oração / "Estou orando" | ✅ | ✅ | ✅ |
| Ver pedidos "só liderança" | ❌ | ✅ | ✅ |
| Criar/editar eventos, comunicados, álbuns, vídeos, estudos | ❌ | ✅ (próprios) | ✅ (todos) |
| Agenda recorrente (cultos fixos) | ❌ | ❌ | ✅ |
| Aprovar cadastros, alterar role/status | ❌ | ❌ | ✅ |
| Notificação avulsa | ❌ | ✅ | ✅ |
| Financeiro (contas a pagar e fluxo de caixa) | ❌ | ❌ | ✅ |

## 7. Modelo de dados (Supabase)

Todas as tabelas têm `id uuid pk default gen_random_uuid()`, `created_at timestamptz default now()` e `updated_at` (atualizado por trigger), salvo indicação em contrário. **Toda tabela tem RLS habilitada.**

**`members.user_id → auth.users(id)`:** `on delete set null`. Com o padrão `restrict`, a exclusão do usuário do Auth falharia nas Edge Functions.

**Chaves estrangeiras para `members`**, para que excluir um membro não quebre nada nem apague conteúdo da igreja:
- Autoria de conteúdo (`created_by`, `author_id` em eventos, comunicados, álbuns, vídeos, estudos e contas): `on delete set null`. A UI mostra "Autor removido".
- Vínculos pessoais (`event_rsvps`, `prayer_intercessions`, `daily_study_reads`, `device_tokens`): `on delete cascade`.
- `prayer_requests.member_id`: `on delete set null`. O pedido continua no mural como anônimo.
- `cash_entries.donor_member_id`: `on delete set null`. A entrada continua no caixa, sem o doador.
- `cash_entries.bill_id → bills`: `on delete set null`. Excluir uma conta já paga não apaga o dinheiro que saiu.
- `media_photos.album_id → media_albums`: `on delete cascade`. `media_albums.cover_photo_id → media_photos`: `on delete set null` (apagar a foto da capa deixa o álbum sem capa, e o app usa a primeira foto por `position`).

| Tabela | Colunas principais |
|---|---|
| `members` | `user_id uuid unique null → auth.users`, `full_name`, `email` (único, minúsculo, null para importados sem e-mail), `phone`, `birth_date date`, `photo_url`, `role` (enum `member_role`), `status` (enum `member_status`), `inchurch_id int unique null`. **Ficha (todas opcionais):** `address text`, `gender` (enum `member_gender`: `male`, `female`), `marital_status` (enum `marital_status`: `single`, `married`, `stable_union`, `divorced`, `widowed`), `baptism_date date`, `membership_date date` |
| `schedule_items` (agenda recorrente) | `title`, `description`, `weekday smallint (0=domingo)`, `start_time time`, `end_time time`, `location`, `active bool` |
| `events` | `title`, `description`, `cover_url`, `location`, `starts_at`, `ends_at`, `rsvp_enabled bool`, `capacity int null`, `published bool`, `notify_on_publish bool`, `notified_at timestamptz null`, `created_by → members` |
| `event_rsvps` | `event_id`, `member_id`, `created_at` — pk composta |
| `announcements` | `title`, `body`, `audience ('all'\|'leaders')`, `pinned bool`, `send_push bool`, `author_id → members`, `published_at` |
| `prayer_requests` | `member_id`, `body`, `visibility ('public'\|'leaders')`, `is_anonymous bool`, `status ('open'\|'answered'\|'archived')` |
| `prayer_intercessions` | `request_id`, `member_id` — pk composta ("Estou orando") |
| `media_albums` | `title`, `description`, `cover_photo_id → media_photos null`, `event_date date`, `created_by` |
| `media_photos` | `album_id → media_albums`, `storage_path` (1600px), `thumb_path` (400px), `width`, `height`, `position int` (ordem no álbum) |
| `videos` | `title`, `description`, `youtube_id`, `published_at`, `created_by` |
| `daily_studies` | `publish_date date unique`, `title`, `bible_reference`, `body` (markdown), `created_by` |
| `daily_study_reads` | `study_id`, `member_id`, `read_at` — pk composta |
| `bills` | `description`, `amount_cents int`, `due_date date`, `category`, `status ('pending'\|'paid')`, `paid_at date null`, `notes`, `receipt_path null`, `created_by` |
| `cash_entries` (caixa único) | `type ('in'\|'out')`, `amount_cents int > 0`, `occurred_on date`, `category` (texto com sugestões), `description`, `payment_method ('cash'\|'pix'\|'transfer'\|'card')`, `donor_member_id → members null`, `donor_name text null`, `bill_id → bills unique null`, `receipt_path null`, `created_by` |
| `device_tokens` | `member_id`, `token unique`, `platform ('android'\|'ios')` |
| `push_log` | `title`, `body`, `audience`, `data jsonb`, `sent_by`, `status`, `error` |

**Funções auxiliares para RLS** (`security definer`, `stable`): `current_member_id()`, `is_approved()`, `is_leader()` (leader ou admin) e `is_admin()`.
- Ficam no schema **`private`**, que não é exposto pela API (`/rest/v1/rpc`). Nas políticas, chamar sempre qualificado e dentro de `select`: `(select private.is_admin())`.
- Só as RPCs de leitura feitas para o app (ex.: `get_member_directory`) ficam em `public`.

**Configuração do Supabase Auth (obrigatória):**
- **"Confirm email" ativado.** A confirmação é feita por **código OTP de 6 dígitos**, sem link nem deep link.
  - **Os dois templates** usam `{{ .Token }}`: "Confirm signup" e "Reset Password".
- Com "Confirm email" ativo, o Supabase **não cria sessão** para quem não confirmou. O `signUp` retorna o usuário sem sessão, e o `signInWithPassword` falha com o código `email_not_confirmed`.
- **SMTP próprio (Brevo, plano gratuito) obrigatório também no `dev`:**
  - no plano Free, o Supabase **recusa templates personalizados** sem SMTP próprio, e sem o template com `{{ .Token }}` o fluxo por código não funciona;
  - o SMTP padrão só entrega para membros da equipe da organização e tem limite baixíssimo de envios por hora.
- Templates de e-mail em pt-BR, versionados em `supabase/templates/` e ligados no `config.toml`.
- Toda essa configuração fica no `supabase/config.toml` e é aplicada com `supabase config push`, nunca pelo painel.

**Triggers de vínculo (segurança):** o vínculo só acontece **depois de o e-mail ser confirmado**. Assim ninguém assume a conta de um membro importado só por saber o e-mail dele.
- `after insert on auth.users`: só age se `email_confirmed_at` já vier preenchido. Caso contrário, não faz nada.
- `after update of email_confirmed_at on auth.users`, quando o campo passa de nulo para preenchido:
  - Se existir um `members` com o mesmo e-mail (case-insensitive) e `user_id` nulo (membro importado ou cadastrado pelo admin): vincula o `user_id` e mantém `approved`.
  - Senão: cria um `members` com `status = 'pending'` e `role = 'member'`. O `full_name` e o `phone` são lidos de `raw_user_meta_data`, que o app envia no `signUp(data: {...})`.
  - O trigger **não** dispara push. Quem avisa os admins é o trigger de push de `members` (ver Edge Functions).
- Ambas as funções são `security definer`, com `search_path` fixo.
- O app é a **ficha oficial** da igreja (a InChurch será abandonada). Os campos da ficha seguem a mesma visibilidade do telefone: o próprio membro e leader/admin veem; os outros members não.
- O membro não pode alterar o próprio `role`, `status`, `email`, `baptism_date` nem `membership_date` (datas eclesiásticas são do admin), e ninguém altera `user_id` ou `inchurch_id` pelo app. Isso é garantido pelo trigger `members_guard_update` (a RLS não compara valor antigo com novo). Chamadas sem usuário (triggers do Auth, service role) passam.

**Dados sensíveis: RLS por linha + RPCs de leitura (obrigatório)**

A RLS controla **linhas, não colunas**. Por isso, tabelas com dados que um member pode ver só em parte **não** liberam SELECT direto para ele. A leitura parcial passa por funções RPC.

Regras das RPCs:
- `security definer`, `set search_path = ''` (nomes qualificados), `stable`;
- começam com `if not private.is_approved() then raise exception`;
- devolvem **apenas** as colunas permitidas;
- `revoke execute ... from anon, public` e `grant execute ... to authenticated`.

| Tabela | SELECT direto (RLS) | Leitura do member via RPC |
|---|---|---|
| `members` | Própria linha + leader/admin | `get_member_directory(search, limit, offset)` → `id, full_name, photo_url`<br>`get_birthdays(from_date, to_date)` → `id, full_name, photo_url, birth_day, birth_month` (**sem o ano**). Compara só dia e mês e trata a virada do ano (ex.: 29/dez a 04/jan) |
| `prayer_requests` | Próprio autor + leader/admin | `get_prayer_feed(limit, offset)` → pedidos públicos e abertos, com `author_name`/`author_id` = `null` quando anônimo (exceto para o próprio autor e leader/admin), mais `praying_count` e `i_am_praying` |
| `prayer_intercessions` | Própria linha + leader/admin | Contagem só pela `get_prayer_feed` |
| `event_rsvps` | Própria linha + leader/admin | `get_event_rsvp_summary(event_id)` → `count`, `capacity`, `i_am_going` |

- Leader e admin continuam lendo as tabelas diretamente (ex.: lista de confirmados no UC-16, contatos no UC-07), já que a RLS libera para eles.
- A política de SELECT da **própria linha** em `members` (`user_id = auth.uid()`) **não exige `is_approved()`**.
  - O usuário `pending` ou `blocked` precisa ler o próprio status para o `AuthBloc` e o Realtime funcionarem.
  - Esse SELECT não dá acesso a nenhum conteúdo da igreja.
- **Proibido** criar views com `security_invoker = false` para contornar isso: ficam expostas pela API e o linter do Supabase acusa.

**Estudos futuros:**
- A RLS de `daily_studies` para members só libera `publish_date <= (now() at time zone 'America/Sao_Paulo')::date`.
- **Nunca usar `current_date`**: no Supabase a sessão roda em UTC, e o estudo apareceria às 21h do dia anterior.
- Leaders e admins veem todos.
- A mesma regra de fuso vale para qualquer comparação de "hoje" em SQL, como contas vencidas e aniversariantes.

**Storage:**
- Buckets **públicos**, com caminhos UUID: `avatars`, `event-covers`, `media`.
  - Escrita só para leader/admin, exceto `avatars`, onde cada usuário escreve só a própria pasta.
- Bucket **privado** `receipts`: comprovantes de `bills` e `cash_entries`, só admin, acesso por URL assinada.
- **Apagar a linha no banco não apaga o arquivo no Storage** (nem por `cascade`). Toda exclusão que envolve arquivo remove os arquivos também:
  - foto: `storage_path` e `thumb_path`;
  - álbum: todos os arquivos das fotos dele, antes de apagar o álbum;
  - capa de evento, avatar e comprovante: o arquivo antigo, ao trocar ou excluir.
  - O app remove primeiro os arquivos e depois a linha. Se a remoção de arquivo falhar, a linha **não** é apagada e o erro aparece com "Tentar novamente".
- Caminhos: `media/<album_id>/<photo_id>.jpg` e `media/<album_id>/<photo_id>_thumb.jpg`, para que um álbum possa ser limpo pela pasta.

**Edge Functions:**
- `send-push`:
  - recebe `{title, body, audience, data}` e envia via FCM HTTP v1, usando a service account guardada em secret;
  - remove tokens inválidos e grava em `push_log`;
  - é chamada pelo app (envio avulso, após validar se quem chama é leader) e por **triggers condicionais** no Postgres.
  - Os triggers usam `pg_net`, e não Database Webhooks, que disparam em toda alteração e reenviariam push a cada edição:
    - `announcements` → `after insert` com `send_push = true`;
    - `events` → trigger **`before insert or update`**:
      - só age quando `new.published = true`, `new.notify_on_publish = true` e `new.notified_at is null`;
      - na mesma passada, define `new.notified_at = now()` e chama `net.http_post`;
      - **sem `UPDATE` na própria tabela**, para evitar que o trigger dispare a si mesmo;
      - o `pg_net` só envia depois do commit, então um rollback não dispara push;
      - despublicar e republicar ou editar **nunca reenvia**.
    - `members` → `after insert` com `status = 'pending'` → push para os admins. **É o único ponto** que avisa sobre novo cadastro;
    - `members` → `after update` quando `status` passa de `pending` para `approved` → push para o próprio membro.
- `delete-account`:
  - **Ordem obrigatória:**
    1. apaga o registro de `members`. Se o trigger de último admin recusar, a função retorna o erro "Você é o único administrador. Promova outro membro a admin antes de excluir sua conta.";
    2. **só depois**, com a service role, exclui o usuário do Auth.
  - Motivo da ordem: se o Auth fosse apagado primeiro e o passo 2 falhasse, sobraria um `members` com `user_id` nulo e e-mail preenchido. O trigger de vínculo o trataria como membro importado, e uma conta nova com esse e-mail entraria aprovada, com a role antiga.
  - Se o passo 2 falhar, o usuário do Auth fica sem `members`. Ao tentar entrar, ele cai no fluxo de cadastro pendente, que é seguro. A função registra o erro em log para nova tentativa.
  - As FKs já cuidam do resto:
    - pedidos de oração ficam anônimos (`set null`);
    - confirmações, intercessões, leituras e tokens são apagados (`cascade`);
    - o conteúdo criado pelo membro permanece, com autor nulo (`set null`).
- `admin-delete-member`:
  - valida no próprio código que quem chama é admin: obtém o usuário pelo JWT (`auth.getUser`) e, com a secret key, confere em `members` se ele é `admin` e `approved` (as funções `private.*` não são acessíveis pela API);
  - segue **a mesma ordem da `delete-account`**: primeiro apaga o `members`, depois exclui o usuário do Auth (se houver). As FKs aplicam as mesmas regras;
  - impede excluir o último admin e excluir a si mesmo (para isso existe a `delete-account`).

**pg_cron:**
- 06:00 (São Paulo): push do estudo do dia, se existir um.
- 08:00 (São Paulo): push para admins com contas vencendo em até 2 dias.
- **O pg_cron roda em UTC.** O Brasil não tem horário de verão, então use `0 9 * * *` e `0 11 * * *`.
- Os jobs chamam a Edge Function `send-push` via **`pg_net`** (`net.http_post`). Ativar as extensões `pg_cron` e `pg_net` na migration.
- A URL da função e a chave usada no header `Authorization` ficam no **Supabase Vault**, nunca escritas no SQL.

**Realtime:**
- Adicionar `members` à publicação: `alter publication supabase_realtime add table members;`.
- A RLS também vale para o Realtime. Como member só tem SELECT na própria linha, ele só recebe as próprias mudanças.
- O app ainda assina com o filtro `user_id=eq.<uid>`, para leader e admin não receberem as mudanças de todos.

**Fluxo de caixa:**
- `bills` e `cash_entries`: RLS **só admin** (leitura e escrita). Doador e valor doado são dados sensíveis (LGPD).
- Trigger `after update of status, amount_cents, paid_at on bills`:
  - `pending` → `paid`: cria a saída em `cash_entries` (`type = 'out'`, valor, `occurred_on = paid_at`, categoria e descrição da conta, `bill_id`, comprovante);
  - `paid` → `pending` (desfazer): apaga a saída ligada;
  - conta já paga com valor ou data alterados: atualiza a saída ligada.
- Saídas com `bill_id` **não são editadas nem apagadas direto** (trigger em `cash_entries`). Elas mudam só pela conta a pagar.
- Doador só em entradas (`check`): `donor_member_id` ou `donor_name`, ambos opcionais. Sem nenhum dos dois, o app mostra "Não informado".
- Saldo = soma das entradas − soma das saídas, calculado no banco por RPC (`get_cash_summary(from_date, to_date)` → saldo atual, entradas e saídas do período, totais por categoria).

**Integridade no banco:**
- **Lotação de evento:** trigger `before insert on event_rsvps`.
  - Faz `select ... from events where id = new.event_id for update`, travando a linha do evento.
  - Conta as confirmações e lança exceção se `capacity` foi atingida.
  - Também rejeita se `rsvp_enabled = false` ou o evento já terminou.
  - Desabilitar o botão na UI não basta: duas confirmações simultâneas passariam do limite.

## 8. Casos de uso

Formato: **ator** — fluxo — regras — critérios de aceite (CA).

### Autenticação (`auth`)

**UC-01 Criar conta** — visitante
- Formulário: nome, e-mail, telefone, senha (mínimo 8) e confirmação.
- O nome e o telefone vão em `signUp(email, password, data: {'full_name': ..., 'phone': ...})`. O trigger os lê de `raw_user_meta_data` ao criar o `members`.
- Após enviar o formulário, abre a tela **"Confirme seu e-mail"**, onde o usuário digita o código de 6 dígitos (`verifyOTP(type: signup)`), com botão "Reenviar código" e intervalo de 60s.
- Depois da confirmação:
  - se o e-mail já existir como membro importado ou cadastrado pelo admin, a conta entra **aprovada**;
  - caso contrário, entra em **pendente** e os admins recebem um push.
- CA:
  - e-mail inválido mostra erro claro;
  - **e-mail já cadastrado:** com "Confirm email" ativo, o `signUp` **não retorna erro**. Por proteção contra descoberta de e-mails, ele devolve um usuário falso.
    - Detectar com `response.user?.identities?.isEmpty == true`.
    - Mostrar "E-mail já cadastrado. Faça login ou recupere a senha.", com botões para as duas ações.
  - sem confirmar o e-mail, o usuário **não** é vinculado nem aprovado;
  - após a confirmação, o usuário pendente vai para a tela "Aguardando aprovação".

**UC-02 Entrar** — usuário
- Login com e-mail e senha.
- Se o login falhar com `email_not_confirmed`: reenviar o código (`resend(type: signup)`) e abrir a tela "Confirme seu e-mail".
- Redirecionamento por status:
  - `approved` → Início;
  - `pending` → Aguardando aprovação (com botão "Verificar novamente");
  - `blocked` → mensagem de acesso bloqueado e logout.
- A sessão persiste entre aberturas do app.

**UC-03 Recuperar senha** — usuário
- Usa **código OTP de 6 dígitos por e-mail** (`resetPasswordForEmail` + `verifyOTP(type: recovery)`), sem deep link.
- Depois do código, o usuário define a nova senha.

**UC-04 Sair**
- Remove o token do dispositivo de `device_tokens`, faz `signOut` e volta ao login.

**UC-05 Excluir minha conta** — usuário (exigência da Apple)
- Fica em Perfil → "Excluir conta", com confirmação dupla.
- Chama `delete-account`, desloga e mostra a confirmação.

### Membros (`members`)

**UC-06 Ver e editar meu perfil**
- Campos editáveis: foto (com compressão), nome, telefone, data de nascimento, endereço, gênero e estado civil.
- Só leitura: e-mail, data de batismo e data de membresia (essas duas são preenchidas pelo admin).

**UC-07 Diretório de membros** — approved
- Lista paginada com busca por nome (debounce de 400ms).
- Member vê só nome e foto, lidos pela RPC `get_member_directory`. Ele **não** tem SELECT direto em `members`.
- Leader/admin também vê telefone, e-mail e aniversário, com botões "Ligar" e "WhatsApp" (`url_launcher`).

**UC-08 Aniversariantes do mês**
- Lista ordenada por dia, com destaque para os de hoje. Também aparece como card na Início.
- Lida pela RPC `get_birthdays(primeiro_dia_do_mês, último_dia_do_mês)`, que devolve **só dia e mês**, nunca o ano.

**UC-09 Aprovar cadastros** — admin
- Lista de pendentes, com três ações:
  - **aprovar**;
  - **recusar**: muda para `blocked` e é reversível;
  - **excluir**: remove de vez via Edge Function `admin-delete-member`, com confirmação.
- Ao aprovar, o usuário recebe um push "Seu cadastro foi aprovado".

**UC-10 Gerenciar membro** — admin
- Editar todos os dados da ficha (incluindo batismo e membresia), `role` e `status`.
- Cadastrar membro manualmente, sem conta. Ele se vincula ao criar conta com o mesmo e-mail.
- CA: o admin não pode remover o próprio papel de admin.

### Agenda e eventos (`schedule`)

**UC-11 Ver agenda** — approved
- Calendário mensal (`table_calendar`) com uma lista do dia abaixo.
- Une os `schedule_items`, expandidos para as datas do mês exibido, com os `events` publicados.
- Marcadores diferentes para culto fixo e evento.

**UC-12 Ver evento**
- Mostra capa, título, data/hora, local (botão abre o mapa via `url_launcher`) e descrição.
- Botão de compartilhar (`share_plus`).

**UC-13 Confirmar/cancelar presença** — approved
- Só aparece se `rsvp_enabled`.
- Respeita `capacity`: lotado → botão desabilitado com o texto "Esgotado".
- Mostra o total de confirmados, lido pela RPC `get_event_rsvp_summary`. O member não vê **quem** confirmou.
- A lotação é garantida no banco pelo trigger de `event_rsvps`. Se ele recusar, a UI mostra "Esgotado" e atualiza o resumo.

**UC-14 Gerenciar eventos** — leader/admin
- Criar, editar, despublicar e excluir.
- Upload de capa.
- Opção "Notificar membros ao publicar" (coluna `notify_on_publish`).
- O push sai **uma única vez**, na primeira publicação (controlado por `notified_at`). Edições não reenviam.

**UC-15 Gerenciar agenda recorrente** — admin
- CRUD de `schedule_items` (ex.: "Culto de domingo, 19h").

**UC-16 Ver confirmados** — leader/admin
- Lista de nomes e total de confirmados por evento.

### Mensagens das lideranças (`announcements`)

> Premissa: comunicados de **mão única**, dos líderes para os membros. **Não é chat.**

**UC-17 Ver comunicados** — approved
- Feed paginado, com os fixados no topo.
- Member vê apenas `audience = 'all'`; leaders também veem `'leaders'`.
- Tela de detalhe com texto completo.

**UC-18 Publicar comunicado** — leader/admin
- Campos: título, texto, público (todos/líderes), fixar e "Enviar notificação".
- O leader edita e exclui os próprios; o admin, qualquer um.

### Notificações (`notifications`)

**UC-19 Registrar dispositivo**
- Após **qualquer login com sessão**, `pending` ou `approved`: pede permissão (iOS e Android 13+), obtém o token FCM e faz upsert em `device_tokens`.
  - Precisa ser assim para o usuário `pending` receber o push "Seu cadastro foi aprovado".
  - A RLS de `device_tokens` permite INSERT, UPDATE e DELETE da própria linha para qualquer usuário autenticado com registro em `members`, **sem exigir `is_approved()`**.
- Escuta `onTokenRefresh`.

**UC-20 Receber e abrir notificação**
- Payload: `data: {type, id}`, com `type` ∈ `event | announcement | daily_study | member_approval | bill`.
- Com o app em primeiro plano: mostra notificação local.
- Ao tocar (primeiro plano, segundo plano ou app fechado): navega até a tela do conteúdo via `go_router`.

**UC-21 Notificação avulsa** — leader/admin
- Campos: título (máx. 50), texto (máx. 150) e público (todos/líderes).
- Pré-visualização e confirmação antes de enviar. O envio fica registrado em `push_log`.

### Pedidos de oração (`prayer`)

**UC-22 Criar pedido** — approved
- Campos: texto (máx. 1000), visibilidade (mural público / só liderança) e "Enviar como anônimo".

**UC-23 Mural de oração**
- Lista os pedidos públicos e abertos, lidos pela RPC `get_prayer_feed`.
- Botão "Estou orando" alterna o registro em `prayer_intercessions`.
- O contador e o estado do botão vêm da `get_prayer_feed` (`praying_count`, `i_am_praying`). O member não vê **quem** está orando.

**UC-24 Meus pedidos**
- O autor marca como respondido (com selo "Oração respondida 🙏"), arquiva ou exclui.

**UC-25 Pedidos da liderança** — leader/admin
- Aba extra com os pedidos "só liderança". O nome do autor aparece mesmo nos anônimos.

**UC-26 Moderar** — admin
- Excluir qualquer pedido.

### Mídias (`media`)

**UC-27 Galeria de fotos** — approved
- Grid de álbuns → grid de fotos → visualizador em tela cheia com zoom e swipe (`photo_view`).
- Compartilhar foto.

**UC-28 Vídeos** — approved
- Lista com thumbnail (`https://img.youtube.com/vi/<id>/hqdefault.jpg`) e player embutido (`youtube_player_iframe`).

**UC-29 Criar álbum e enviar fotos** — leader/admin
- Seleção múltipla, compressão, upload com barra de progresso por foto e possibilidade de tentar de novo as que falharem.
- Cada foto gera **duas versões no app** antes do upload: 1600px (qualidade 80) e miniatura de 400px. Grades usam a miniatura; o visualizador em tela cheia usa a de 1600px.
- Definir capa (uma foto do álbum); reordenar fotos (`position`); excluir fotos e o álbum, removendo também os arquivos do Storage.

**UC-30 Adicionar vídeo** — leader/admin
- Colar uma URL do YouTube (formatos `watch?v=`, `youtu.be/`, `shorts/`, `live/`).
- Extrair e validar o `youtube_id` e mostrar a pré-visualização antes de salvar.

### Estudo diário (`daily_study`)

**UC-31 Ler estudo do dia** — approved
- Destaque na Início: título, referência bíblica e texto em markdown.
- Histórico paginado com busca por título ou referência.

**UC-32 Marcar como lido**
- Registra em `daily_study_reads`. Mostra um check no histórico e a contagem de "dias seguidos".

**UC-33 Programar estudos** — leader/admin
- Cadastrar com antecedência, escolhendo a `publish_date` (única por dia).
- Lista de programados futuros, com edição.

**UC-34 Lembrete diário**
- O pg_cron dispara um push às 06:00 se houver estudo publicado no dia.

### Financeiro (`finance`) — somente admin

**UC-35 Contas a pagar do mês**
- Seletor de mês e filtro por status (todas / pendentes / pagas / vencidas).
- Cards com os totais: pendente, pago e vencido.
- Vencidas (`pending` com `due_date` < hoje) aparecem destacadas em vermelho.

**UC-36 Cadastrar/editar/excluir conta**
- Campos: descrição, valor (máscara R$, salvo em centavos), vencimento, categoria (texto com sugestões das já usadas) e observação.
- Botão **"Copiar contas do mês anterior"**: mostra as contas do mês anterior para o admin marcar quais repetir; as escolhidas são criadas no mês atual como `pending`, com o mesmo dia de vencimento (ajustado para o último dia do mês, se necessário) e o valor editável antes de salvar. Não existe recorrência automática no banco.

**UC-37 Marcar como paga / desfazer**
- Informa a data do pagamento (padrão: hoje) e, opcionalmente, anexa o comprovante (foto, bucket `receipts`).
- Marcar como paga gera a saída no caixa automaticamente; desfazer remove essa saída (trigger no banco, ver seção 7).

**UC-38 Lembrete de vencimento**
- O pg_cron envia push aos admins sobre as contas pendentes que vencem em até 2 dias.

**UC-41 Fluxo de caixa** — admin
- Mostra o **saldo atual** e, para o mês escolhido: total de entradas, total de saídas e totais por categoria.
- Lista as movimentações do mês (entradas em verde, saídas em vermelho), com filtro por tipo e categoria.
- As saídas geradas por contas pagas aparecem com o selo "Conta a pagar" e levam à conta ao tocar.

**UC-42 Registrar entrada** — admin
- Campos: valor (máscara R$), data (padrão: hoje), categoria (sugestões: Dízimo, Oferta, Doação, Evento, Outros), forma de pagamento, doador e descrição.
- Doador: escolher um membro da lista **ou** digitar um nome livre (visitante, "Anônimo"). Opcional.
- Comprovante opcional (bucket `receipts`).

**UC-43 Registrar saída avulsa** — admin
- Para gastos que não passaram por contas a pagar (ex.: compra de material).
- Campos: valor, data, categoria, forma de pagamento, descrição e comprovante opcional.
- Editar e excluir entradas e saídas avulsas. Saídas de contas pagas só mudam pela conta (UC-37).

### Início (`home`)

**UC-39 Tela inicial** — approved
- Cards na ordem:
  1. estudo do dia;
  2. próximos 3 eventos;
  3. últimos 3 comunicados;
  4. aniversariantes da semana, via `get_birthdays(hoje, hoje + 6 dias)` no fuso de São Paulo.
- Pull-to-refresh. Cada card leva à sua feature.

### Migração (fora do app)

**UC-40 Importar membros da InChurch**
- Script em `tool/import_inchurch.dart`, executado localmente com a service role key via variável de ambiente, **nunca commitada**.
- Lê o JSON exportado de `GET /v1/people/` (paginado) da API pública da InChurch.
- Faz upsert em `members` por `inchurch_id`, com `status = 'approved'` e e-mail normalizado.
- Idempotente: rodar duas vezes não duplica.
- Ao final, gera um relatório com os registros sem e-mail, que não poderão se vincular sozinhos.

## 9. Navegação

Destinos principais:
- **Início**
- **Agenda**
- **Comunicados**
- **Oração**
- **Mais**, que agrupa:
  - **para todos:** Mídias, Estudos, Membros, Meu perfil;
  - **seção "Gestão"** (leader e admin, rotas `/gestao/*`): Eventos, Comunicados, Notificação avulsa, Oração da liderança, Mídias (gestão), Estudos programados;
  - **seção "Administração"** (só admin, rotas `/admin/*`): Aprovações, Membros (gestão e roles), Agenda fixa, Moderação de oração, Financeiro (contas a pagar e caixa).

Guardas do `go_router`, avaliados nesta ordem no `redirect`:
1. sem sessão → `/login` (as rotas públicas `/login`, `/cadastro`, `/confirmar-email` e `/recuperar-senha` são liberadas);
2. `pending` → `/aguardando`;
3. `/gestao/*` sem role leader ou acima → `/sem-permissao`;
4. `/admin/*` sem role admin → `/sem-permissao`.

O `redirect` **só lê estado**, sem efeitos colaterais:
- **Usuário bloqueado:** quem faz o logout é o `AuthBloc`. Ao receber `blocked`, no login ou via Realtime, ele chama `signOut` e emite um estado com a mensagem "Acesso bloqueado". O redirect então cai na regra 1.
- **E-mail não confirmado:** não existe guarda para isso, porque não há sessão nesse caso. A navegação para `/confirmar-email` é feita pelos fluxos do UC-01 e do UC-02.

O `redirect` escuta o `AuthBloc` (via `refreshListenable`), então qualquer mudança de role ou status reavalia a rota atual na hora. A RLS bloqueia de qualquer forma.

## 10. Requisitos não funcionais

- Funciona em retrato no celular e em retrato e paisagem no tablet.
- Fonte escalável (acessibilidade), alvos de toque ≥ 48px, contraste AA.
- Tema centralizado em `core/theme`. Cores e logo da igreja ficam como placeholders até a cliente enviar.
- Imagens sempre via `cached_network_image`, com placeholder.
- Sem conexão: mostrar estado de erro com "Tentar novamente". Não há modo offline completo.
- LGPD: coletar o mínimo necessário. Exclusão de conta disponível (UC-05). URL da política de privacidade configurável, exigida pelas lojas.
- Ícone, splash e nome do app configurados (`flutter_launcher_icons`, `flutter_native_splash` como dev_dependencies).

## 11. Ordem de implementação

Visão geral das etapas. O detalhamento em tarefas e o status ficam em `docs/plano-backend.md` e `docs/plano-app.md`.

1. **Fundação:**
   - **git** antes de qualquer código. O `.gitignore` cobre `env/*.json`, `.env`, chaves, `*.keystore`/`*.jks` e service accounts. Commits pequenos, um por caso de uso;
   - projeto, DI, rotas, tema, l10n;
   - migrations SQL do Supabase em `supabase/migrations/`, **sempre** seguindo a skill `supabase-migrations`. O desenvolvimento usa o Supabase na nuvem (projeto `dev`), sem stack local.
2. **Auth e membros:** UC-01 a UC-10, mais o UC-40 (importação).
3. **Agenda/eventos, estudo diário e oração:** UC-11 a UC-16, UC-31 a UC-33 e UC-22 a UC-26.
4. **Comunicados e mídias:** UC-17, UC-18 e UC-27 a UC-30.
5. **Financeiro e Início:** UC-35 a UC-37, UC-41 a UC-43 (fluxo de caixa) e UC-39.
6. **Notificações:** Firebase, `device_tokens`, `send-push`, triggers de push, jobs do pg_cron; UC-19 a UC-21, UC-34, UC-38 e os pushes previstos nos outros UCs (novo cadastro, cadastro aprovado, evento publicado, comunicado).
7. **Distribuição e publicação:** flavors `dev`/`prod`, Codemagic (Android e iOS via TestFlight), projeto Supabase `prod`, ícones, versão de teste para a cliente e um grupo da igreja, publicação nas lojas.

**Até a etapa 6, nada de push:** as colunas `announcements.send_push`, `events.notify_on_publish` e `events.notified_at` já são criadas e as telas salvam esses valores, mas o envio só passa a existir na etapa 6. Até a etapa 7, o app roda só no emulador, apontando para o Supabase `dev`.

**Ambientes:**
- **Supabase `dev`:** projeto atual na conta da igreja (plano Free, `us-east-1`). É descartável e será desligado depois que o `prod` existir.
  - Projetos Free pausam após ~7 dias sem uso. Para reativar, basta clicar em "Restore" no painel, e os dados não se perdem.
- **Supabase `prod`:** projeto novo na conta da igreja, região **São Paulo**, plano Pro. Recriado do zero com `db push` + `config push` + `functions deploy`.
- **Firebase:** um único projeto com **dois apps registrados por plataforma** (ids `…igreja.dev` e `…igreja`), configurados com `flutterfire configure` por flavor. Resultado: um `google-services.json` em `android/app/src/<flavor>/` e um `GoogleService-Info.plist` por flavor no iOS (copiado por script de build).
- **Codemagic:** um workflow por flavor, com os arquivos e chaves vindos de variáveis de ambiente criptografadas.

Ao terminar cada etapa, rodar `flutter analyze` sem warnings e `flutter test` com tudo passando.

## 12. Definição de pronto (por caso de uso)

- [ ] Entidade, repository (interface + impl), usecase, Bloc e tela implementados nas camadas corretas.
- [ ] Política RLS cobre o caso, testada com usuários member, leader e admin.
- [ ] Estados de carregando, vazio, erro e sucesso tratados.
- [ ] Testes unitários do usecase e do Bloc.
- [ ] Textos em ARB pt_BR; layout conferido em celular e tablet.
- [ ] Sem `print`, sem chave sensível no código, `flutter analyze` limpo.

## 13. Premissas

Fonte original: [`docs/requisitos-cliente.md`](../../../docs/requisitos-cliente.md).

**Confirmadas:**
1. "Lideranças (aba mensagens)" = comunicados de mão única dos líderes, **não** chat.
2. Células **fora do escopo**. A menção da cliente a células só detalhava o financeiro.
3. O app substitui a InChurch e é a ficha oficial dos membros (campos de ficha em `members`).

**A confirmar com a cliente** (implementar assim, mas manter o código fácil de ajustar):
1. Pedido anônimo fica oculto para membros, mas leaders e admins veem o autor.
2. Membros comuns veem só nome e foto no diretório.
3. Financeiro restrito a admin (não existe role "tesoureiro").
4. Eventos com confirmação de presença opcional, sem venda de ingresso.
5. **Fluxo de caixa (UC-41 a UC-43):** sugestão do desenvolvedor, além do pedido da cliente (que citou só contas a pagar). Mostrar a ideia à cliente antes de implementar a etapa 5.