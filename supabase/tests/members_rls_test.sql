-- Testes de RLS e triggers de members (UC-01, UC-06, UC-07, UC-09, UC-10).
--
-- Rodar:  supabase db query --linked -f supabase/tests/members_rls_test.sql
--
-- Tudo roda num único bloco DO que termina SEMPRE com exceção, então nada é gravado.
--   sucesso -> erro "TESTES OK: ..."
--   falha   -> erro "FALHOU: <descrição>"

do $$
declare
  u_admin   uuid := gen_random_uuid();
  u_leader  uuid := gen_random_uuid();
  u_member  uuid := gen_random_uuid();
  u_pending uuid := gen_random_uuid();
  u_import  uuid := gen_random_uuid();
  m_admin   uuid;
  m_leader  uuid;
  m_member  uuid;
  m_import  uuid;
  n         integer;
  ok        boolean;
  total     integer;
  passed    integer := 0;
begin
  -- -------------------------------------------------------------------------
  -- Preparação (como postgres)
  -- -------------------------------------------------------------------------
  insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, aud, role)
  values
    (u_admin,   't_admin@teste.local',   now(), '{"full_name":"T Admin"}',   'authenticated', 'authenticated'),
    (u_leader,  't_leader@teste.local',  now(), '{"full_name":"T Leader"}',  'authenticated', 'authenticated'),
    (u_member,  't_member@teste.local',  now(), '{"full_name":"T Member","phone":"11999990000"}', 'authenticated', 'authenticated'),
    (u_pending, 't_pending@teste.local', now(), '{"full_name":"T Pending"}', 'authenticated', 'authenticated');

  select id into m_admin  from public.members where user_id = u_admin;
  select id into m_leader from public.members where user_id = u_leader;
  select id into m_member from public.members where user_id = u_member;

  -- Trigger de vínculo criou pending/member com dados do metadata
  if (select count(*) from public.members where user_id in (u_admin, u_leader, u_member, u_pending)) <> 4 then
    raise exception 'FALHOU: trigger de vínculo não criou os 4 members';
  end if;
  if exists (select 1 from public.members where user_id = u_member
             and (status <> 'pending' or role <> 'member' or phone <> '11999990000' or full_name <> 'T Member')) then
    raise exception 'FALHOU: member novo não veio pending/member com nome e telefone do metadata';
  end if;
  passed := passed + 1;

  update public.members set role = 'admin',  status = 'approved' where id = m_admin;
  update public.members set role = 'leader', status = 'approved' where id = m_leader;
  update public.members set status = 'approved' where id = m_member;
  select count(*) into total from public.members;

  -- -------------------------------------------------------------------------
  -- Vínculo de membro importado: só depois de confirmar o e-mail
  -- -------------------------------------------------------------------------
  insert into public.members (full_name, email, status) values ('T Importado', 't_import@teste.local', 'approved')
  returning id into m_import;
  total := total + 1;

  insert into auth.users (id, email, raw_user_meta_data, aud, role)
  values (u_import, 'T_Import@teste.local', '{"full_name":"Outro Nome"}', 'authenticated', 'authenticated');

  if (select user_id from public.members where id = m_import) is not null then
    raise exception 'FALHOU: membro importado foi vinculado antes da confirmação do e-mail';
  end if;
  passed := passed + 1;

  update auth.users set email_confirmed_at = now() where id = u_import;

  if (select user_id from public.members where id = m_import) is distinct from u_import
     or (select status from public.members where id = m_import) <> 'approved'
     or (select count(*) from public.members where email = 't_import@teste.local') <> 1 then
    raise exception 'FALHOU: confirmação não vinculou o membro importado (approved, sem duplicar)';
  end if;
  passed := passed + 1;

  -- -------------------------------------------------------------------------
  -- MEMBER
  -- -------------------------------------------------------------------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', u_member, 'role', 'authenticated')::text, true);

  select count(*) into n from public.members;
  if n <> 1 then raise exception 'FALHOU: member deveria ver só a própria linha, viu %', n; end if;
  if not private.is_approved() or private.is_leader() or private.is_admin() then
    raise exception 'FALHOU: funções de role erradas para member';
  end if;
  if private.current_member_id() is distinct from m_member then
    raise exception 'FALHOU: current_member_id() errado para member';
  end if;
  passed := passed + 1;

  update public.members set full_name = 'T Member Editado', phone = '11888880000' where id = m_member;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALHOU: member não conseguiu editar o próprio perfil'; end if;
  passed := passed + 1;

  ok := false;
  begin
    update public.members set role = 'admin' where id = m_member;
  exception when others then ok := true;
  end;
  if not ok then raise exception 'FALHOU: member conseguiu alterar a própria role'; end if;

  ok := false;
  begin
    update public.members set status = 'blocked' where id = m_member;
  exception when others then ok := true;
  end;
  if not ok then raise exception 'FALHOU: member conseguiu alterar o próprio status'; end if;

  ok := false;
  begin
    update public.members set email = 'outro@teste.local' where id = m_member;
  exception when others then ok := true;
  end;
  if not ok then raise exception 'FALHOU: member conseguiu alterar o próprio e-mail'; end if;
  passed := passed + 1;

  update public.members set full_name = 'Hackeado' where id = m_leader;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALHOU: member editou outro membro'; end if;

  delete from public.members where id = m_leader;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALHOU: member excluiu outro membro'; end if;

  ok := false;
  begin
    insert into public.members (full_name, email) values ('Intruso', 'intruso@teste.local');
  exception when others then ok := true;
  end;
  if not ok then raise exception 'FALHOU: member conseguiu criar membro'; end if;
  passed := passed + 1;

  -- -------------------------------------------------------------------------
  -- PENDING
  -- -------------------------------------------------------------------------
  perform set_config('request.jwt.claims', json_build_object('sub', u_pending, 'role', 'authenticated')::text, true);

  select count(*) into n from public.members;
  if n <> 1 then raise exception 'FALHOU: pending deveria ver só a própria linha (para ler o status), viu %', n; end if;
  if private.is_approved() then raise exception 'FALHOU: is_approved() verdadeiro para pending'; end if;
  passed := passed + 1;

  -- -------------------------------------------------------------------------
  -- LEADER
  -- -------------------------------------------------------------------------
  perform set_config('request.jwt.claims', json_build_object('sub', u_leader, 'role', 'authenticated')::text, true);

  select count(*) into n from public.members;
  if n <> total then raise exception 'FALHOU: leader deveria ver todos (%), viu %', total, n; end if;
  if not private.is_leader() or private.is_admin() then
    raise exception 'FALHOU: funções de role erradas para leader';
  end if;

  update public.members set full_name = 'Hackeado' where id = m_member;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALHOU: leader editou outro membro'; end if;

  delete from public.members where id = m_member;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FALHOU: leader excluiu membro'; end if;
  passed := passed + 1;

  -- -------------------------------------------------------------------------
  -- ADMIN
  -- -------------------------------------------------------------------------
  perform set_config('request.jwt.claims', json_build_object('sub', u_admin, 'role', 'authenticated')::text, true);

  if not private.is_admin() or not private.is_leader() then
    raise exception 'FALHOU: funções de role erradas para admin';
  end if;

  update public.members set role = 'leader', status = 'approved' where id = m_member;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALHOU: admin não conseguiu alterar a role de outro membro'; end if;
  passed := passed + 1;

  ok := false;
  begin
    update public.members set role = 'member' where id = m_admin;
  exception when others then ok := true;
  end;
  if not ok then raise exception 'FALHOU: admin conseguiu alterar a própria role'; end if;

  ok := false;
  begin
    update public.members set user_id = null where id = m_member;
  exception when others then ok := true;
  end;
  if not ok then raise exception 'FALHOU: admin conseguiu alterar user_id pelo app'; end if;
  passed := passed + 1;

  insert into public.members (full_name, email, status) values ('T Manual', 't_manual@teste.local', 'approved');
  total := total + 1;
  passed := passed + 1;

  -- -------------------------------------------------------------------------
  -- Último admin (como postgres, simulando as Edge Functions)
  -- -------------------------------------------------------------------------
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);

  -- Este teste só é confiável se não houver outro admin de verdade no banco.
  if (select count(*) from public.members where role = 'admin' and status = 'approved') = 1 then
    ok := false;
    begin
      delete from public.members where id = m_admin;
    exception when others then ok := sqlerrm like 'É preciso manter pelo menos um administrador%';
    end;
    if not ok then raise exception 'FALHOU: foi possível excluir o último admin'; end if;

    ok := false;
    begin
      update public.members set status = 'blocked' where id = m_admin;
    exception when others then ok := sqlerrm like 'É preciso manter pelo menos um administrador%';
    end;
    if not ok then raise exception 'FALHOU: foi possível bloquear o último admin'; end if;

    update public.members set role = 'admin' where id = m_leader;
    delete from public.members where id = m_admin;
    get diagnostics n = row_count;
    if n <> 1 then raise exception 'FALHOU: com outro admin, deveria ser possível excluir'; end if;
    passed := passed + 1;
  end if;

  raise exception 'TESTES OK: % grupos de verificação passaram (nada foi gravado)', passed;
end;
$$;
