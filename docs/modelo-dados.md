# Modelo de dados

Visão geral das tabelas e relacionamentos do Supabase. **A fonte da verdade é a skill [`app-igreja`](../.claude/skills/app-igreja/SKILL.md), seção 7** (colunas, RLS, triggers); este diagrama é um resumo para consulta e para mostrar à cliente. Ao mudar o modelo na skill, atualize aqui também.

Todas as tabelas têm `id uuid` (exceto as de chave composta), `created_at` e `updated_at`, omitidos no diagrama.

```mermaid
erDiagram
    AUTH_USERS ||--o| MEMBERS : "user_id (set null)"

    MEMBERS {
        uuid user_id FK "null = sem conta"
        text full_name
        text email UK "null = importado sem e-mail"
        text phone
        date birth_date
        text photo_url
        enum role "member | leader | admin"
        enum status "pending | approved | blocked"
        int inchurch_id UK
        text address
        enum gender
        enum marital_status
        date baptism_date
        date membership_date
    }

    SCHEDULE_ITEMS {
        text title
        smallint weekday "0 = domingo"
        time start_time
        time end_time
        text location
        bool active
    }

    EVENTS {
        text title
        text cover_url
        text location
        timestamptz starts_at
        timestamptz ends_at
        bool rsvp_enabled
        int capacity "null = sem limite"
        bool published
        bool notify_on_publish
        timestamptz notified_at
        uuid created_by FK
    }
    MEMBERS |o--o{ EVENTS : "created_by (set null)"

    EVENT_RSVPS {
        uuid event_id PK
        uuid member_id PK
    }
    EVENTS ||--o{ EVENT_RSVPS : "cascade"
    MEMBERS ||--o{ EVENT_RSVPS : "cascade"

    ANNOUNCEMENTS {
        text title
        text body
        text audience "all | leaders"
        bool pinned
        bool send_push
        timestamptz published_at
        uuid author_id FK
    }
    MEMBERS |o--o{ ANNOUNCEMENTS : "author_id (set null)"

    PRAYER_REQUESTS {
        uuid member_id FK "null = autor removido"
        text body
        text visibility "public | leaders"
        bool is_anonymous
        text status "open | answered | archived"
    }
    MEMBERS |o--o{ PRAYER_REQUESTS : "set null"

    PRAYER_INTERCESSIONS {
        uuid request_id PK
        uuid member_id PK
    }
    PRAYER_REQUESTS ||--o{ PRAYER_INTERCESSIONS : "cascade"
    MEMBERS ||--o{ PRAYER_INTERCESSIONS : "cascade"

    DAILY_STUDIES {
        date publish_date UK
        text title
        text bible_reference
        text body "markdown"
        uuid created_by FK
    }
    MEMBERS |o--o{ DAILY_STUDIES : "created_by (set null)"

    DAILY_STUDY_READS {
        uuid study_id PK
        uuid member_id PK
        timestamptz read_at
    }
    DAILY_STUDIES ||--o{ DAILY_STUDY_READS : "cascade"
    MEMBERS ||--o{ DAILY_STUDY_READS : "cascade"

    MEDIA_ALBUMS {
        text title
        uuid cover_photo_id FK
        date event_date
        uuid created_by FK
    }
    MEMBERS |o--o{ MEDIA_ALBUMS : "created_by (set null)"

    MEDIA_PHOTOS {
        uuid album_id FK
        text storage_path "1600px"
        text thumb_path "400px"
        int width
        int height
        int position
    }
    MEDIA_ALBUMS ||--o{ MEDIA_PHOTOS : "cascade"
    MEDIA_PHOTOS |o--o| MEDIA_ALBUMS : "capa (set null)"

    VIDEOS {
        text title
        text youtube_id
        timestamptz published_at
        uuid created_by FK
    }
    MEMBERS |o--o{ VIDEOS : "created_by (set null)"

    BILLS {
        text description
        int amount_cents
        date due_date
        text category
        text status "pending | paid"
        date paid_at
        text receipt_path
        uuid created_by FK
    }
    MEMBERS |o--o{ BILLS : "created_by (set null)"

    CASH_ENTRIES {
        text type "in | out"
        int amount_cents
        date occurred_on
        text category
        text payment_method
        uuid donor_member_id FK "só entradas"
        text donor_name "só entradas"
        uuid bill_id FK, UK "saída gerada por conta paga"
        text receipt_path
        uuid created_by FK
    }
    MEMBERS |o--o{ CASH_ENTRIES : "doador (set null)"
    BILLS |o--o| CASH_ENTRIES : "bill_id (set null)"

    DEVICE_TOKENS {
        uuid member_id FK
        text token UK
        text platform "android | ios"
    }
    MEMBERS ||--o{ DEVICE_TOKENS : "cascade (etapa 6)"

    PUSH_LOG {
        text title
        text body
        text audience
        jsonb data
        uuid sent_by FK
        text status
    }
    MEMBERS |o--o{ PUSH_LOG : "sent_by (set null, etapa 6)"
```

## Por área

| Área | Tabelas | Quem escreve | Quem lê |
|---|---|---|---|
| Membros | `members` | o próprio (perfil), admin (tudo) | o próprio + leader/admin; members leem nome/foto e aniversário por RPC |
| Agenda | `schedule_items`, `events`, `event_rsvps` | admin (fixos), leader/admin (eventos), approved (RSVP próprio) | approved (total de confirmados por RPC) |
| Comunicados | `announcements` | leader/admin | approved, por `audience` |
| Oração | `prayer_requests`, `prayer_intercessions` | approved | mural por RPC (anônimos ocultos), leader/admin tudo |
| Estudo diário | `daily_studies`, `daily_study_reads` | leader/admin (estudos), approved (leitura própria) | approved (só até hoje em São Paulo) |
| Mídias | `media_albums`, `media_photos`, `videos` | leader/admin | approved |
| Financeiro | `bills`, `cash_entries` | admin | admin |
| Notificações (etapa 6) | `device_tokens`, `push_log` | o próprio (token), Edge Function (log) | o próprio, admin (log) |

## Storage

| Bucket | Acesso | Conteúdo |
|---|---|---|
| `avatars` | público; cada um escreve na própria pasta | fotos de perfil (512px) |
| `event-covers` | público; leader/admin escrevem | capas de eventos (1200px) |
| `media` | público; leader/admin escrevem | `<album_id>/<photo_id>.jpg` e `_thumb.jpg` |
| `receipts` | **privado**, só admin, URL assinada | comprovantes de contas e do caixa |

Vídeos não ficam no Storage: só o `youtube_id`.
