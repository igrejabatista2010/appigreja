-- Vínculo entre auth.users e members, só DEPOIS de o e-mail ser confirmado (UC-01).
-- Assim ninguém assume a conta de um membro importado só por saber o e-mail dele.
--
-- - membro com o mesmo e-mail e sem conta (importado ou cadastrado pelo admin): vincula
--   o user_id e mantém o status atual (normalmente approved);
-- - senão: cria um members pending/member com full_name e phone de raw_user_meta_data.
-- Este trigger NÃO dispara push. O aviso aos admins vem do trigger de push de members.

create or replace function public.link_member_on_email_confirmed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(new.email));
  v_member_id uuid;
begin
  if new.email_confirmed_at is null or v_email is null then
    return new;
  end if;

  -- Já vinculado (ex.: trigger reexecutado): nada a fazer.
  if exists (select 1 from public.members m where m.user_id = new.id) then
    return new;
  end if;

  update public.members m
     set user_id = new.id
   where m.email = v_email
     and m.user_id is null
  returning m.id into v_member_id;

  if v_member_id is null then
    insert into public.members (user_id, full_name, email, phone, role, status)
    values (
      new.id,
      coalesce(
        nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
        split_part(v_email, '@', 1)
      ),
      v_email,
      nullif(btrim(new.raw_user_meta_data ->> 'phone'), ''),
      'member',
      'pending'
    );
  end if;

  return new;
end;
$$;

revoke execute on function public.link_member_on_email_confirmed() from public, anon, authenticated;

-- Usuário criado já confirmado (ex.: criado pelo painel com "auto confirm").
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  when (new.email_confirmed_at is not null)
  execute function public.link_member_on_email_confirmed();

-- Fluxo normal: confirmação por código OTP.
create trigger on_auth_user_email_confirmed
  after update of email_confirmed_at on auth.users
  for each row
  when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function public.link_member_on_email_confirmed();
