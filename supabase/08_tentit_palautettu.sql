-- =====================================================================
-- 8) Tehdyt tentit statukseen Palautettu (aiemmin Valmis)
-- =====================================================================
update public.basket b set status = 'Palautettu'
from public.tasks t
where t.id = b.task_id and t.type = 'Tentti' and b.status = 'Valmis';

update public.basket b set status = 'Annettu'
from public.tasks t
where t.id = b.task_id and t.type = 'Tentti' and b.status = 'Aloitettu';
