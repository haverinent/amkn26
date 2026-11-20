-- =====================================================================
-- 10) Henkilökohtaiset linkit pois – kirjautuminen vain tunnuksella ja salasanalla
-- Aja kerran SQL Editorissa. Aseta ENSIN oma salasanasi sovelluksessa (Oma tili),
-- muuten skripti pysähtyy, jottet lukitse itseäsi ulos.
-- =====================================================================
begin;

do $$ begin
  if exists (select 1 from public.members where is_admin and pw_hash is null) then
    raise exception 'Ylläpitäjällä ei ole vielä salasanaa. Aseta se sovelluksessa (Oma tili) ja aja skripti uudelleen.';
  end if;
end $$;

-- Tunniste tarkistetaan vain kirjautumisista (istunnoista)
create or replace function public._me(p_token text) returns public.members
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  select mb.* into m from public.sessions s join public.members mb on mb.id = s.member_id
  where s.token_hash = public._hash(p_token) and s.expires_at > now();
  if m.id is null then raise exception 'Kirjautuminen ei ole voimassa' using errcode = '28000'; end if;
  return m;
end $$;

drop function if exists public.app_add_member(text, text, boolean);
drop function if exists public.app_reset_link(text, uuid);

create or replace function public.app_create_member(p_token text, p_name text, p_username text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare m public.members; v_pw text := public._new_password();
        v_user text := lower(trim(coalesce(p_username,'')));
begin
  m := public._me(p_token);
  if not m.is_admin then raise exception 'Vain ylläpitäjälle'; end if;
  if v_user !~ '^[a-z0-9._-]{2,30}$' then raise exception 'Tunnuksessa saa olla vain kirjaimia a–z, numeroita sekä . _ -'; end if;
  if exists (select 1 from public.members where username = v_user) then raise exception 'Tunnus on jo käytössä'; end if;
  insert into public.members (first_name, username, pw_hash)
  values (trim(p_name), v_user, extensions.crypt(v_pw, extensions.gen_salt('bf', 10)));
  return json_build_object('username', v_user, 'password', v_pw);
end $$;

-- Linkkien tiivisteet poistetaan kokonaan
alter table public.members drop column if exists token_hash;

commit;
