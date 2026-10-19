-- Extensões usadas pelos lembretes agendados (UC-34, UC-38) e pelos triggers de push.
-- pg_cron: agenda os jobs (roda em UTC).
-- pg_net: chamadas HTTP assíncronas do Postgres para a Edge Function send-push.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
