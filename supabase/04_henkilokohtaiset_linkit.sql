-- =====================================================================
-- 4) Siirtyminen henkilökohtaisiin linkkeihin (ei sähköposteja)
-- Aja kerran SQL Editorissa. Poistaa sähköpostikirjautumisen rakenteet.
-- =====================================================================

begin;

-- ---------- Vanhan kirjautumisen purku ----------
drop policy if exists tasks_read   on public.tasks;
drop policy if exists tasks_insert on public.tasks;
drop policy if exists tasks_update on public.tasks;
drop policy if exists tasks_delete on public.tasks;
drop policy if exists courses_read   on public.courses;
drop policy if exists courses_insert on public.courses;
drop policy if exists courses_admin  on public.courses;
drop policy if exists courses_delete on public.courses;

drop trigger if exists check_allowed_signup on auth.users;
drop function if exists public.check_allowed_signup();
drop table if exists public.basket;
drop table if exists public.profiles;
drop table if exists public.allowed_emails;
drop function if exists public.is_member();
drop function if exists public.is_admin();

drop trigger if exists touch_task on public.tasks;
drop function if exists public.touch_task();
alter table public.tasks drop constraint if exists tasks_created_by_fkey;
alter table public.tasks drop constraint if exists tasks_updated_by_fkey;
alter table public.tasks alter column created_by drop default;
alter table public.tasks alter column updated_by drop default;

-- ---------- Uudet taulut ----------
create table if not exists public.members (
  id          uuid primary key default gen_random_uuid(),
  first_name  text not null check (char_length(first_name) between 1 and 30),
  token_hash  bytea not null unique,
  is_admin    boolean not null default false,
  created_at  timestamptz not null default now(),
  last_seen   timestamptz
);

alter table public.tasks add constraint tasks_created_by_fkey foreign key (created_by) references public.members(id) on delete set null;
alter table public.tasks add constraint tasks_updated_by_fkey foreign key (updated_by) references public.members(id) on delete set null;

create table if not exists public.basket (
  member_id uuid not null references public.members(id) on delete cascade,
  task_id   uuid not null references public.tasks(id) on delete cascade,
  status    text not null default 'Annettu' check (status in ('Annettu','Aloitettu','Valmis','Palautettu')),
  note      text not null default '',
  my_dl     date,
  added_at  timestamptz not null default now(),
  primary key (member_id, task_id)
);

-- Kaikki taulut lukkoon: pääsy vain alla olevien funktioiden kautta
alter table public.members enable row level security;
alter table public.basket  enable row level security;
alter table public.tasks   enable row level security;
alter table public.courses enable row level security;
revoke all on public.members, public.basket, public.tasks, public.courses from anon, authenticated;

-- ---------- Apufunktiot ----------
create or replace function public._hash(p text) returns bytea
language sql immutable as $$ select sha256(convert_to(coalesce(p,''), 'UTF8')) $$;

create or replace function public._new_token() returns text
language sql volatile as $$ select replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '') $$;

create or replace function public._me(p_token text) returns public.members
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  select * into m from public.members where token_hash = public._hash(p_token);
  if m.id is null then raise exception 'Linkki ei ole voimassa' using errcode = '28000'; end if;
  return m;
end $$;

-- ---------- Sovelluksen toiminnot ----------
create or replace function public.app_state(p_token text) returns json
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  m := public._me(p_token);
  update public.members set last_seen = now() where id = m.id and (last_seen is null or last_seen < now() - interval '1 hour');
  return json_build_object(
    'me', json_build_object('id', m.id, 'first_name', m.first_name, 'is_admin', m.is_admin),
    'courses', coalesce((select json_agg(json_build_object('code', code, 'name', name) order by code) from public.courses), '[]'),
    'tasks', coalesce((select json_agg(json_build_object('id', t.id, 'course', t.course, 'type', t.type, 'title', t.title,
        'dl', t.dl, 'moodle', t.moodle, 'info', t.info, 'created_by', t.created_by, 'created_by_name', c.first_name))
        from public.tasks t left join public.members c on c.id = t.created_by), '[]'),
    'basket', coalesce((select json_agg(json_build_object('task_id', task_id, 'status', status, 'note', note, 'my_dl', my_dl))
        from public.basket where member_id = m.id), '[]'),
    'members', case when m.is_admin then coalesce((select json_agg(json_build_object('id', id, 'first_name', first_name,
        'is_admin', is_admin, 'last_seen', last_seen) order by first_name) from public.members), '[]') else null end
  );
end $$;

create or replace function public.app_set_basket(p_token text, p_task uuid, p_status text, p_note text, p_my_dl date) returns void
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  m := public._me(p_token);
  insert into public.basket (member_id, task_id, status, note, my_dl)
  values (m.id, p_task, coalesce(p_status,'Annettu'), coalesce(p_note,''), p_my_dl)
  on conflict (member_id, task_id) do update set status = excluded.status, note = excluded.note, my_dl = excluded.my_dl;
end $$;

create or replace function public.app_add_basket_many(p_token text, p_tasks uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  m := public._me(p_token);
  insert into public.basket (member_id, task_id) select m.id, unnest(p_tasks) on conflict do nothing;
end $$;

create or replace function public.app_remove_basket(p_token text, p_task uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  m := public._me(p_token);
  delete from public.basket where member_id = m.id and task_id = p_task;
end $$;

create or replace function public.app_save_task(p_token text, p_id uuid, p_course text, p_type text, p_title text,
  p_dl date, p_moodle text, p_info text, p_new_course_name text, p_to_basket boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare m public.members; v_id uuid;
begin
  m := public._me(p_token);
  if not exists (select 1 from public.courses where code = p_course) then
    if coalesce(trim(p_new_course_name),'') = '' then raise exception 'Tuntematon kurssi'; end if;
    insert into public.courses (code, name) values (p_course, trim(p_new_course_name));
  end if;
  if p_id is null then
    insert into public.tasks (course, type, title, dl, moodle, info, created_by, updated_by)
    values (p_course, p_type, coalesce(p_title,''), p_dl, coalesce(p_moodle,''), coalesce(p_info,''), m.id, m.id)
    returning id into v_id;
    if p_to_basket then insert into public.basket (member_id, task_id) values (m.id, v_id); end if;
  else
    update public.tasks set course = p_course, type = p_type, title = coalesce(p_title,''), dl = p_dl,
      moodle = coalesce(p_moodle,''), info = coalesce(p_info,''), updated_by = m.id, updated_at = now()
    where id = p_id returning id into v_id;
  end if;
  return v_id;
end $$;

create or replace function public.app_delete_task(p_token text, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  m := public._me(p_token);
  delete from public.tasks where id = p_id and (m.is_admin or created_by = m.id);
  if not found then raise exception 'Vain lisääjä tai ylläpitäjä voi poistaa'; end if;
end $$;

create or replace function public.app_rename(p_token text, p_name text) returns void
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  m := public._me(p_token);
  update public.members set first_name = trim(p_name) where id = m.id;
end $$;

-- ---------- Ylläpito ----------
create or replace function public.app_add_member(p_token text, p_name text, p_admin boolean) returns text
language plpgsql security definer set search_path = public as $$
declare m public.members; v_tok text := public._new_token();
begin
  m := public._me(p_token);
  if not m.is_admin then raise exception 'Vain ylläpitäjälle'; end if;
  insert into public.members (first_name, token_hash, is_admin) values (trim(p_name), public._hash(v_tok), coalesce(p_admin,false));
  return v_tok;
end $$;

create or replace function public.app_reset_link(p_token text, p_member uuid) returns text
language plpgsql security definer set search_path = public as $$
declare m public.members; v_tok text := public._new_token();
begin
  m := public._me(p_token);
  if not m.is_admin and m.id <> p_member then raise exception 'Vain ylläpitäjälle'; end if;
  update public.members set token_hash = public._hash(v_tok) where id = p_member;
  return v_tok;
end $$;

create or replace function public.app_remove_member(p_token text, p_member uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  m := public._me(p_token);
  if not m.is_admin then raise exception 'Vain ylläpitäjälle'; end if;
  if m.id = p_member then raise exception 'Et voi poistaa itseäsi'; end if;
  delete from public.members where id = p_member;
end $$;

-- Sisäiset apufunktiot eivät ole kutsuttavissa sivulta
revoke all on function public._hash(text), public._new_token(), public._me(text) from public, anon, authenticated;
grant execute on function
  public.app_state(text), public.app_set_basket(text,uuid,text,text,date), public.app_add_basket_many(text,uuid[]),
  public.app_remove_basket(text,uuid), public.app_save_task(text,uuid,text,text,text,date,text,text,text,boolean),
  public.app_delete_task(text,uuid), public.app_rename(text,text), public.app_add_member(text,text,boolean),
  public.app_reset_link(text,uuid), public.app_remove_member(text,uuid)
  to anon, authenticated;

commit;
