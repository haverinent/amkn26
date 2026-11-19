-- =====================================================================
-- 9) Kirjautuminen käyttäjätunnuksella ja salasanalla (linkit toimivat edelleen)
-- Aja kerran SQL Editorissa.
-- =====================================================================
begin;

create extension if not exists pgcrypto with schema extensions;

alter table public.members add column if not exists username     text unique check (username = lower(username) and char_length(username) between 2 and 30);
alter table public.members add column if not exists pw_hash      text;
alter table public.members add column if not exists failed       int not null default 0;
alter table public.members add column if not exists locked_until timestamptz;

-- Nykyisille jäsenille tunnus etunimestä (tyhjät/kaksoiskappaleet saavat numeron)
update public.members m set username = x.u from (
  select id, lower(regexp_replace(first_name, '\s+', '', 'g'))
         || case when row_number() over (partition by lower(first_name) order by created_at) > 1
                 then row_number() over (partition by lower(first_name) order by created_at)::text else '' end as u
  from public.members) x
where m.id = x.id and m.username is null;

-- Kirjautumiset (laitekohtaiset istunnot)
create table if not exists public.sessions (
  token_hash  bytea primary key,
  member_id   uuid not null references public.members(id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '365 days'
);
alter table public.sessions enable row level security;
revoke all on public.sessions from anon, authenticated;

-- Linkki TAI istunto kelpaa tunnisteeksi
create or replace function public._me(p_token text) returns public.members
language plpgsql security definer set search_path = public as $$
declare m public.members; h bytea := public._hash(p_token);
begin
  select * into m from public.members where token_hash = h;
  if m.id is null then
    select mb.* into m from public.sessions s join public.members mb on mb.id = s.member_id
    where s.token_hash = h and s.expires_at > now();
  end if;
  if m.id is null then raise exception 'Linkki ei ole voimassa' using errcode = '28000'; end if;
  return m;
end $$;

-- Helposti kirjoitettava salasana: kolme sanaa ja kaksi numeroa
create or replace function public._new_password() returns text
language sql volatile as $$
  with w as (select array['karhu','kettu','ilves','hirvi','susi','orava','majava','saukko','kotka','haukka',
    'joutsen','kurki','lokki','pollo','tikka','hauki','ahven','lohi','kuha','silakka','kivi','kallio','vuori',
    'joki','meri','lampi','suo','metsa','niitty','pelto','tuuli','myrsky','sade','lumi','jaa','pakkanen','kesa',
    'talvi','kevat','syksy','aamu','ilta','yo','paiva','kuu','tahti','aurinko','pilvi','salama','sumu','sauna',
    'tuli','savu','kipina','hiillos','letku','kypara','tikas','paloauto','sireeni','kartta','kompassi','radio',
    'reppu','teltta','kuksa','puukko','kirves','vasara','naula','lauta','tupa','silta','tie','polku','satama',
    'majakka','vene','airo','purje','ankkuri','saari','niemi','lahti','koski','putous','laakso','harju','kumpu',
    'rinne','kangas','korpi','lehto','kaski','aho','paju','koivu','manty','kuusi','tammi','vaahtera','pihlaja']::text[] as a)
  select a[1 + floor(random()*array_length(a,1))::int] || '-' ||
         a[1 + floor(random()*array_length(a,1))::int] || '-' ||
         a[1 + floor(random()*array_length(a,1))::int] || '-' ||
         lpad(floor(random()*100)::int::text, 2, '0')
  from w;
$$;

-- Kirjautuminen: palauttaa {ok, token} tai {ok:false, error}
create or replace function public.app_login(p_username text, p_password text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare m public.members; v_tok text;
begin
  select * into m from public.members where username = lower(trim(coalesce(p_username,'')));
  if m.id is null or m.pw_hash is null then
    perform extensions.crypt('x', extensions.gen_salt('bf', 10));
    return json_build_object('ok', false, 'error', 'Väärä käyttäjätunnus tai salasana');
  end if;
  if m.locked_until is not null and m.locked_until > now() then
    return json_build_object('ok', false, 'error', 'Liian monta väärää yritystä. Yritä uudelleen 15 minuutin kuluttua.');
  end if;
  if m.pw_hash = extensions.crypt(coalesce(p_password,''), m.pw_hash) then
    update public.members set failed = 0, locked_until = null, last_seen = now() where id = m.id;
    v_tok := public._new_token();
    insert into public.sessions (token_hash, member_id) values (public._hash(v_tok), m.id);
    delete from public.sessions where expires_at < now();
    return json_build_object('ok', true, 'token', v_tok);
  end if;
  -- 8 väärää yritystä lukitsee tunnuksen 15 minuutiksi, minkä jälkeen laskuri alkaa alusta
  update public.members set
    locked_until = case when failed + 1 >= 8 then now() + interval '15 minutes' end,
    failed = case when failed + 1 >= 8 then 0 else failed + 1 end
  where id = m.id;
  return json_build_object('ok', false, 'error', 'Väärä käyttäjätunnus tai salasana');
end $$;

create or replace function public.app_logout(p_token text) returns void
language sql security definer set search_path = public as $$
  delete from public.sessions where token_hash = public._hash(p_token);
$$;

-- Oman salasanan vaihto
create or replace function public.app_set_password(p_token text, p_new text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare m public.members;
begin
  m := public._me(p_token);
  if char_length(coalesce(p_new,'')) < 8 then raise exception 'Salasanan pitää olla vähintään 8 merkkiä'; end if;
  update public.members set pw_hash = extensions.crypt(p_new, extensions.gen_salt('bf', 10)), failed = 0, locked_until = null
  where id = m.id;
  -- muut laitteet kirjataan ulos, tämä laite jää
  delete from public.sessions where member_id = m.id and token_hash <> public._hash(p_token);
end $$;

-- Ylläpito: uusi salasana jäsenelle (näytetään kerran)
create or replace function public.app_reset_password(p_token text, p_member uuid) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare m public.members; v_pw text := public._new_password();
begin
  m := public._me(p_token);
  if not m.is_admin then raise exception 'Vain ylläpitäjälle'; end if;
  update public.members set pw_hash = extensions.crypt(v_pw, extensions.gen_salt('bf', 10)), failed = 0, locked_until = null
  where id = p_member;
  if p_member <> m.id then delete from public.sessions where member_id = p_member; end if;
  return v_pw;
end $$;

-- Ylläpito: käyttäjätunnuksen vaihto
create or replace function public.app_set_username(p_token text, p_member uuid, p_username text) returns void
language plpgsql security definer set search_path = public as $$
declare m public.members; v text := lower(trim(coalesce(p_username,'')));
begin
  m := public._me(p_token);
  if not m.is_admin then raise exception 'Vain ylläpitäjälle'; end if;
  if v !~ '^[a-z0-9._-]{2,30}$' then raise exception 'Tunnuksessa saa olla vain kirjaimia a–z, numeroita sekä . _ -'; end if;
  if exists (select 1 from public.members where username = v and id <> p_member) then raise exception 'Tunnus on jo käytössä'; end if;
  update public.members set username = v where id = p_member;
end $$;

-- Ylläpito: uusi jäsen tunnuksella, salasanalla ja linkillä
create or replace function public.app_create_member(p_token text, p_name text, p_username text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare m public.members; v_tok text := public._new_token(); v_pw text := public._new_password();
        v_user text := lower(trim(coalesce(p_username,'')));
begin
  m := public._me(p_token);
  if not m.is_admin then raise exception 'Vain ylläpitäjälle'; end if;
  if v_user !~ '^[a-z0-9._-]{2,30}$' then raise exception 'Tunnuksessa saa olla vain kirjaimia a–z, numeroita sekä . _ -'; end if;
  if exists (select 1 from public.members where username = v_user) then raise exception 'Tunnus on jo käytössä'; end if;
  insert into public.members (first_name, token_hash, username, pw_hash)
  values (trim(p_name), public._hash(v_tok), v_user, extensions.crypt(v_pw, extensions.gen_salt('bf', 10)));
  return json_build_object('username', v_user, 'password', v_pw, 'token', v_tok);
end $$;

-- Tila: mukaan tunnus ja tieto salasanasta
create or replace function public.app_state(p_token text) returns json
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  m := public._me(p_token);
  update public.members set last_seen = now() where id = m.id and (last_seen is null or last_seen < now() - interval '1 hour');
  return json_build_object(
    'me', json_build_object('id', m.id, 'first_name', m.first_name, 'is_admin', m.is_admin,
                            'username', m.username, 'has_password', m.pw_hash is not null),
    'courses', coalesce((select json_agg(json_build_object('code', code, 'name', name) order by code) from public.courses), '[]'),
    'tasks', coalesce((select json_agg(json_build_object('id', t.id, 'course', t.course, 'type', t.type, 'title', t.title,
        'dl', t.dl, 'moodle', t.moodle, 'info', t.info, 'created_by', t.created_by, 'created_by_name', c.first_name,
        'private', t.owner_id is not null, 'audience', t.audience))
        from public.tasks t left join public.members c on c.id = t.created_by
        where t.owner_id is null or t.owner_id = m.id), '[]'),
    'basket', coalesce((select json_agg(json_build_object('task_id', task_id, 'status', status, 'note', note,
        'my_dl', my_dl, 'hidden', hidden)) from public.basket where member_id = m.id), '[]'),
    'members', case when m.is_admin then coalesce((select json_agg(json_build_object('id', id, 'first_name', first_name,
        'is_admin', is_admin, 'last_seen', last_seen, 'username', username, 'has_password', pw_hash is not null)
        order by first_name) from public.members), '[]') else null end
  );
end $$;

revoke all on function public._new_password() from public, anon, authenticated;
grant execute on function
  public.app_login(text,text), public.app_logout(text), public.app_set_password(text,text),
  public.app_reset_password(text,uuid), public.app_set_username(text,uuid,text), public.app_create_member(text,text,text)
  to anon, authenticated;

commit;
