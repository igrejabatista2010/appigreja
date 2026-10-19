-- Correções apontadas pelo `supabase db advisors`:
-- 1. Funções auxiliares de RLS saem de public (expostas em /rest/v1/rpc) para o schema
--    private, que não faz parte da API. As políticas passam a usar private.*.
-- 2. Políticas permissivas duplicadas (select/update) de members viram uma por ação.
-- 3. Trigger function security definer do último admin deixa de ser executável pela API.

-- ---------------------------------------------------------------------------
-- Schema private (fora de api.schemas no config.toml, então nunca é exposto)
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;
alter default privileges in schema private revoke execute on functions from public;

create or replace function private.current_member_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.id from public.members m where m.user_id = (select auth.uid());
$$;

create or replace function private.is_approved()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.members m
    where m.user_id = (select auth.uid())
      and m.status = 'approved'
  );
$$;

-- leader ou admin, aprovado.
create or replace function private.is_leader()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.members m
    where m.user_id = (select auth.uid())
      and m.status = 'approved'
      and m.role in ('leader', 'admin')
  );
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.members m
    where m.user_id = (select auth.uid())
      and m.status = 'approved'
      and m.role = 'admin'
  );
$$;

revoke execute on function
  private.current_member_id(), private.is_approved(), private.is_leader(), private.is_admin()
  from public, anon;
grant execute on function
  private.current_member_id(), private.is_approved(), private.is_leader(), private.is_admin()
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Políticas de members: uma por ação, usando private.*
-- ---------------------------------------------------------------------------
drop policy "members: le a propria linha" on public.members;
drop policy "members: leader le todos" on public.members;
drop policy "members: admin cria" on public.members;
drop policy "members: atualiza a propria linha" on public.members;
drop policy "members: admin atualiza todos" on public.members;
drop policy "members: admin exclui" on public.members;

-- Própria linha (sem exigir aprovação: pending/blocked leem o próprio status)
-- ou leader/admin (todos). Member comum lê os outros só pelas RPCs.
create policy "members: select"
  on public.members for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.is_leader())
  );

-- Cadastro manual de membro sem conta (UC-10).
create policy "members: insert"
  on public.members for insert to authenticated
  with check ((select private.is_admin()));

-- Próprio perfil (UC-06) ou admin (UC-10).
-- Role, status e e-mail do próprio usuário são barrados pelo trigger members_guard_update.
create policy "members: update"
  on public.members for update to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.is_admin())
  )
  with check (
    user_id = (select auth.uid())
    or (select private.is_admin())
  );

create policy "members: delete"
  on public.members for delete to authenticated
  using ((select private.is_admin()));

-- ---------------------------------------------------------------------------
-- Remove as versões públicas e fecha a trigger function do último admin
-- ---------------------------------------------------------------------------
drop function public.current_member_id();
drop function public.is_approved();
drop function public.is_leader();
drop function public.is_admin();

revoke execute on function public.members_protect_last_admin() from public, anon, authenticated;
