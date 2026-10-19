-- B2.0 / UC-06, UC-10: campos da ficha do membro.
-- O app substitui a InChurch e passa a ser a ficha oficial da igreja.
-- Visibilidade igual à do telefone: o próprio membro e leader/admin (RLS de members já cobre).
-- Datas eclesiásticas (batismo, membresia) só o admin altera.

create type public.member_gender as enum ('male', 'female');
create type public.marital_status as enum ('single', 'married', 'stable_union', 'divorced', 'widowed');

alter table public.members
  add column address text check (address is null or char_length(address) <= 300),
  add column gender public.member_gender,
  add column marital_status public.marital_status,
  add column baptism_date date,
  add column membership_date date;

-- Guarda de update: além de role/status/e-mail, o próprio membro não altera
-- baptism_date nem membership_date.
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
    if new.baptism_date is distinct from old.baptism_date
       or new.membership_date is distinct from old.membership_date then
      raise exception 'As datas de batismo e de membresia são preenchidas pela secretaria.'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;
