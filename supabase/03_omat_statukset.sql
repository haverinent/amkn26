-- =====================================================================
-- 3) Ylläpitäjän omat statukset vanhasta Excelistä
-- Aja VASTA kun olet kirjautunut sovellukseen kerran.
-- =====================================================================

insert into public.basket (user_id, task_id, status)
select u.id, t.id, v.status
from (values
  ('t001', 'Aloitettu'),
  ('t002', 'Valmis'),
  ('t003', 'Aloitettu'),
  ('t004', 'Annettu'),
  ('t005', 'Aloitettu'),
  ('t006', 'Aloitettu'),
  ('t007', 'Annettu'),
  ('t008', 'Annettu'),
  ('t009', 'Annettu'),
  ('t010', 'Annettu'),
  ('t011', 'Annettu'),
  ('t012', 'Palautettu'),
  ('t013', 'Palautettu'),
  ('t014', 'Palautettu'),
  ('t015', 'Palautettu'),
  ('t016', 'Palautettu'),
  ('t017', 'Palautettu'),
  ('t018', 'Valmis'),
  ('t019', 'Palautettu'),
  ('t020', 'Palautettu'),
  ('t021', 'Palautettu'),
  ('t022', 'Palautettu'),
  ('t023', 'Valmis'),
  ('t024', 'Palautettu'),
  ('t025', 'Palautettu'),
  ('t026', 'Palautettu'),
  ('t027', 'Valmis'),
  ('t028', 'Valmis'),
  ('t029', 'Palautettu'),
  ('t030', 'Palautettu'),
  ('t031', 'Valmis'),
  ('t032', 'Palautettu'),
  ('t033', 'Palautettu'),
  ('t034', 'Palautettu'),
  ('t035', 'Palautettu'),
  ('t036', 'Palautettu'),
  ('t037', 'Palautettu'),
  ('t038', 'Palautettu'),
  ('t039', 'Palautettu'),
  ('t040', 'Palautettu')
) as v(seed_key, status)
join public.tasks t on t.seed_key = v.seed_key
join auth.users u on lower(u.email) = (select email from public.allowed_emails where is_admin order by added_at limit 1)
on conflict (user_id, task_id) do nothing;
