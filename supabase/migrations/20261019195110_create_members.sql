-- Tabela members, roles/status, funções auxiliares de RLS e proteções de role.
-- Base para UC-01 a UC-10 (app-igreja, seções 6 e 7).

-- ---------------------------------------------------------------------------
-- Utilitário genérico: updated_at
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------
create type public.member_role as enum ('member', 'leader', 'admin');
create type public.member_status as enum ('pending', 'approved', 'blocked');

-- ---------------------------------------------------------------------------
-- Tabela
-- ---------------------------------------------------------------------------
create table public.members (
  id uuid primary key default gen_random_uuid(),
  -- null = membro importado ou cadastrado pelo admin, ainda sem conta.
  user_id uuid unique references auth.users (id) on delete set null,
  full_name text not null check (char_length(btrim(full_name)) between 1 and 120),
  -- null permitido: membros importados sem e-mail (UC-40).
  email text unique check (email = lower(btrim(email))),
  phone text,
  birth_date date,
  photo_url text,
  role public.member_role not null default 'member',
  status public.member_status not null default 'pending',
  inchurch_id integer unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index members_status_idx on public.members (status);

create trigger set_updated_at
  before update on public.members
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Funções auxiliares de RLS (security definer: leem members sem passar pela RLS)
-- ---------------------------------------------------------------------------
create or replace function public.current_member_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.id from public.members m where m.user_id = (select auth.uid());
$$;

create or replace function public.is_approved()
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
create or replace function public.is_leader()
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

create or replace function public.is_admin()
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
  public.current_member_id(), public.is_approved(), public.is_leader(), public.is_admin()
  from public, anon;
grant execute on function
  public.current_member_id(), public.is_approved(), public.is_leader(), public.is_admin()
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Proteção: o próprio membro não altera role, status nem e-mail;
-- user_id e inchurch_id só mudam por processos internos (vínculo, importação).
-- Chamadas sem usuário (triggers do Auth, service role, SQL do dono) passam.
-- ---------------------------------------------------------------------------
create or replace function public.members_guard_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    return new;
  end if;

  if new.user_id is distinct from old.user_id
     or new.inchurch_id is distinct from old.inchurch_id then
    raise exception 'Estes dados do membro não podem ser alterados pelo app.'
      using errcode = '42501';
  end if;

  if old.user_id = v_uid then
    if new.role is distinct from old.role or new.status is distinct from old.status then
      raise exception 'Você não pode alterar o seu próprio perfil de acesso ou status.'
        using errcode = '42501';
    end if;
    if new.email is distinct from old.email then
      raise exception 'O e-mail não pode ser alterado por aqui.'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

create trigger members_guard_update
  before update on public.members
  for each row execute function public.members_guard_update();

-- ---------------------------------------------------------------------------
-- Proteção: sempre existe pelo menos um admin aprovado.
-- Cobre rebaixar, bloquear e excluir (delete-account e admin-delete-member).
-- ---------------------------------------------------------------------------
create or replace function public.members_protect_last_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'admin' and old.status = 'approved'
     and (tg_op = 'DELETE' or new.role <> 'admin' or new.status <> 'approved') then
    -- Serializa a checagem: dois admins se rebaixando ao mesmo tempo não zeram a lista.
    perform pg_advisory_xact_lock(hashtext('public.members.last_admin'));

    if not exists (
      select 1 from public.members m
      where m.role = 'admin' and m.status = 'approved' and m.id <> old.id
    ) then
      raise exception 'É preciso manter pelo menos um administrador. Promova outro membro a admin antes.'
        using errcode = 'P0001', hint = 'last_admin';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger members_protect_last_admin
  before update of role, status or delete on public.members
  for each row execute function public.members_protect_last_admin();

-- ---------------------------------------------------------------------------
-- Permissões e RLS
-- ---------------------------------------------------------------------------
revoke all on public.members from anon;
grant select, insert, update, delete on public.members to authenticated;

alter table public.members enable row level security;

-- Própria linha: sem exigir is_approved(), para pending/blocked lerem o próprio status
-- (AuthBloc e Realtime).
create policy "members: le a propria linha"
  on public.members for select to authenticated
  using (user_id = (select auth.uid()));

-- Leader/admin leem todos (diretório completo, UC-07; gestão, UC-09/10).
-- Member comum lê os outros só pelas RPCs get_member_directory / get_birthdays.
create policy "members: leader le todos"
  on public.members for select to authenticated
  using ((select public.is_leader()));

-- Cadastro manual de membro sem conta (UC-10).
create policy "members: admin cria"
  on public.members for insert to authenticated
  with check ((select public.is_admin()));

-- Perfil próprio (UC-06). Role, status e e-mail são barrados pelo trigger members_guard_update.
create policy "members: atualiza a propria linha"
  on public.members for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "members: admin atualiza todos"
  on public.members for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create policy "members: admin exclui"
  on public.members for delete to authenticated
  using ((select public.is_admin()));

-- ---------------------------------------------------------------------------
-- Realtime: o AuthBloc escuta a própria linha (mudança de role/status na hora).
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.members;
