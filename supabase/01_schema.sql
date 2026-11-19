-- =====================================================================
-- Opintotehtävät N26 – tietokannan rakenne ja käyttöoikeudet
-- Aja tämä Supabasessa: SQL Editor → New query → liitä → Run
-- =====================================================================

-- ---------- Taulut ----------

-- Sallitut käyttäjät (vain ylläpitäjä näkee)
create table if not exists public.allowed_emails (
  email     text primary key check (email = lower(email)),
  is_admin  boolean not null default false,
  added_at  timestamptz not null default now()
);

-- Kurssit (yhteinen)
create table if not exists public.courses (
  code  text primary key,
  name  text not null
);

-- Tehtävät ja tentit (yhteinen)
create table if not exists public.tasks (
  id          uuid primary key default gen_random_uuid(),
  course      text not null references public.courses(code) on update cascade,
  type        text not null check (type in ('Yksilö','Ryhmä','Tentti')),
  title       text not null default '',
  dl          date,
  moodle      text not null default '' check (moodle = '' or moodle ~* '^https?://'),
  info        text not null default '',
  seed_key    text unique,
  created_by  uuid default auth.uid() references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_by  uuid default auth.uid() references auth.users(id) on delete set null,
  updated_at  timestamptz not null default now()
);

-- Oma kori (henkilökohtainen, vain omistaja näkee)
create table if not exists public.basket (
  user_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  task_id   uuid not null references public.tasks(id) on delete cascade,
  status    text not null default 'Annettu' check (status in ('Annettu','Aloitettu','Valmis','Palautettu')),
  note      text not null default '',
  my_dl     date,
  added_at  timestamptz not null default now(),
  primary key (user_id, task_id)
);

-- Profiili: vain etunimi tai nimimerkki
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  first_name  text not null default '' check (char_length(first_name) <= 30)
);

-- ---------- Apufunktiot ----------

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.allowed_emails
                 where email = lower(coalesce(auth.jwt() ->> 'email','')));
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.allowed_emails
                 where email = lower(coalesce(auth.jwt() ->> 'email','')) and is_admin);
$$;

grant execute on function public.is_member() to authenticated;
grant execute on function public.is_admin()  to authenticated;

-- Estää tunnuksen luomisen osoitteelle, joka ei ole sallittujen listalla
create or replace function public.check_allowed_signup() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.allowed_emails where email = lower(new.email)) then
    raise exception 'Sähköpostiosoite ei ole sallittujen listalla';
  end if;
  return new;
end $$;

drop trigger if exists check_allowed_signup on auth.users;
create trigger check_allowed_signup before insert on auth.users
  for each row execute function public.check_allowed_signup();

-- Päivitysaika ja -tekijä automaattisesti
create or replace function public.touch_task() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;

drop trigger if exists touch_task on public.tasks;
create trigger touch_task before update on public.tasks
  for each row execute function public.touch_task();

-- ---------- Käyttöoikeudet (Row Level Security) ----------

alter table public.allowed_emails enable row level security;
alter table public.courses        enable row level security;
alter table public.tasks          enable row level security;
alter table public.basket         enable row level security;
alter table public.profiles       enable row level security;

-- Sallitut: vain ylläpitäjä
drop policy if exists admin_all on public.allowed_emails;
create policy admin_all on public.allowed_emails for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Kurssit: jäsenet lukevat ja lisäävät, ylläpitäjä muokkaa ja poistaa
drop policy if exists courses_read   on public.courses;
drop policy if exists courses_insert on public.courses;
drop policy if exists courses_admin  on public.courses;
drop policy if exists courses_delete on public.courses;
create policy courses_read   on public.courses for select to authenticated using (public.is_member());
create policy courses_insert on public.courses for insert to authenticated with check (public.is_member());
create policy courses_admin  on public.courses for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy courses_delete on public.courses for delete to authenticated using (public.is_admin());

-- Tehtävät: jäsenet lukevat, lisäävät ja muokkaavat; poisto lisääjältä tai ylläpitäjältä
drop policy if exists tasks_read   on public.tasks;
drop policy if exists tasks_insert on public.tasks;
drop policy if exists tasks_update on public.tasks;
drop policy if exists tasks_delete on public.tasks;
create policy tasks_read   on public.tasks for select to authenticated using (public.is_member());
create policy tasks_insert on public.tasks for insert to authenticated with check (public.is_member() and created_by = auth.uid());
create policy tasks_update on public.tasks for update to authenticated using (public.is_member()) with check (public.is_member());
create policy tasks_delete on public.tasks for delete to authenticated using (public.is_admin() or created_by = auth.uid());

-- Kori: vain omat rivit
drop policy if exists basket_own on public.basket;
create policy basket_own on public.basket for all to authenticated
  using (user_id = auth.uid() and public.is_member())
  with check (user_id = auth.uid() and public.is_member());

-- Profiilit: jäsenet näkevät etunimet, jokainen muokkaa omaansa
drop policy if exists profiles_read  on public.profiles;
drop policy if exists profiles_write on public.profiles;
drop policy if exists profiles_upd   on public.profiles;
create policy profiles_read  on public.profiles for select to authenticated using (public.is_member());
create policy profiles_write on public.profiles for insert to authenticated with check (id = auth.uid() and public.is_member());
create policy profiles_upd   on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Kirjautumattomat eivät saa mitään
revoke all on public.allowed_emails, public.courses, public.tasks, public.basket, public.profiles from anon;

-- ---------- Reaaliaikaiset päivitykset (muiden lisäämät tehtävät näkyvät heti) ----------
do $$ begin
  alter publication supabase_realtime add table public.tasks, public.courses;
exception when others then null;
end $$;
