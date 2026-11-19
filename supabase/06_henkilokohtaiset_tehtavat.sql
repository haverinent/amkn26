-- =====================================================================
-- 6) Henkilökohtaiset tehtävät (näkyvät vain luojalleen)
-- Aja kerran SQL Editorissa.
-- =====================================================================
begin;

alter table public.tasks add column if not exists owner_id uuid references public.members(id) on delete cascade;

-- Näkyykö tehtävä tälle jäsenelle
create or replace function public._visible(p_task uuid, p_member uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.tasks where id = p_task and (owner_id is null or owner_id = p_member));
$$;
revoke all on function public._visible(uuid, uuid) from public, anon, authenticated;

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
        'dl', t.dl, 'moodle', t.moodle, 'info', t.info, 'created_by', t.created_by, 'created_by_name', c.first_name,
        'private', t.owner_id is not null))
        from public.tasks t left join public.members c on c.id = t.created_by
        where t.owner_id is null or t.owner_id = m.id), '[]'),
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
  if not public._visible(p_task, m.id) then raise exception 'Tehtävää ei löydy'; end if;
  insert into public.basket (member_id, task_id, status, note, my_dl)
  values (m.id, p_task, coalesce(p_status,'Annettu'), coalesce(p_note,''), p_my_dl)
  on conflict (member_id, task_id) do update set status = excluded.status, note = excluded.note, my_dl = excluded.my_dl;
end $$;

create or replace function public.app_add_basket_many(p_token text, p_tasks uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  m := public._me(p_token);
  insert into public.basket (member_id, task_id)
  select m.id, x from unnest(p_tasks) x where public._visible(x, m.id)
  on conflict do nothing;
end $$;

drop function if exists public.app_save_task(text,uuid,text,text,text,date,text,text,text,boolean);
create or replace function public.app_save_task(p_token text, p_id uuid, p_course text, p_type text, p_title text,
  p_dl date, p_moodle text, p_info text, p_new_course_name text, p_to_basket boolean, p_private boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare m public.members; v_id uuid; v_owner uuid;
begin
  m := public._me(p_token);
  if not exists (select 1 from public.courses where code = p_course) then
    if coalesce(trim(p_new_course_name),'') = '' then raise exception 'Tuntematon kurssi'; end if;
    insert into public.courses (code, name) values (p_course, trim(p_new_course_name));
  end if;
  if p_id is null then
    insert into public.tasks (course, type, title, dl, moodle, info, created_by, updated_by, owner_id)
    values (p_course, p_type, coalesce(p_title,''), p_dl, coalesce(p_moodle,''), coalesce(p_info,''), m.id, m.id,
            case when p_private then m.id end)
    returning id into v_id;
    if p_to_basket or p_private then insert into public.basket (member_id, task_id) values (m.id, v_id); end if;
  else
    select owner_id into v_owner from public.tasks where id = p_id;
    if not found or (v_owner is not null and v_owner <> m.id) then raise exception 'Tehtävää ei löydy'; end if;
    update public.tasks set course = p_course, type = p_type, title = coalesce(p_title,''), dl = p_dl,
      moodle = coalesce(p_moodle,''), info = coalesce(p_info,''), updated_by = m.id, updated_at = now(),
      -- oman tehtävän voi jakaa kaikille; jaettua ei voi muuttaa henkilökohtaiseksi
      owner_id = case when v_owner is not null and not coalesce(p_private,true) then null else v_owner end
    where id = p_id returning id into v_id;
  end if;
  return v_id;
end $$;

create or replace function public.app_delete_task(p_token text, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m public.members;
begin
  m := public._me(p_token);
  delete from public.tasks where id = p_id
    and (owner_id is null or owner_id = m.id)
    and (m.is_admin or created_by = m.id or owner_id = m.id);
  if not found then raise exception 'Vain lisääjä tai ylläpitäjä voi poistaa'; end if;
end $$;

grant execute on function public.app_save_task(text,uuid,text,text,text,date,text,text,text,boolean,boolean) to anon, authenticated;

commit;
