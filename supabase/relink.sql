-- ============================================================
-- SportSphere — re-link demo data to real auth users
-- Maps old (orphaned) profile rows to the new admin-created
-- profiles by full_name, then deletes the orphans.
-- ============================================================

-- 1) map old profile id -> new profile id (match on full_name,
--    new profiles are those present in auth.users)
create temp table _map as
select old.id as old_id, new.id as new_id
from public.profiles old
join public.profiles new on new.full_name = old.full_name
where exists (select 1 from auth.users u where u.id = new.id)
  and not exists (select 1 from auth.users u where u.id = old.id);

-- 2) re-point child tables
update public.athletes a
set profile_id = m.new_id
from _map m where a.profile_id = m.old_id;

update public.coaches c
set profile_id = m.new_id
from _map m where c.profile_id = m.old_id;

update public.staff s
set profile_id = m.new_id
from _map m where s.profile_id = m.old_id;

update public.attendance at
set profile_id = m.new_id
from _map m where at.profile_id = m.old_id;

update public.notifications n
set recipient_id = m.new_id
from _map m where n.recipient_id = m.old_id;

-- 3) delete orphaned profiles (no auth user behind them)
delete from public.profiles p
where not exists (select 1 from auth.users u where u.id = p.id);

drop table _map;

-- 4) report
select
  (select count(*) from auth.users) as auth_users,
  (select count(*) from public.profiles) as profiles,
  (select count(*) from public.athletes) as athletes,
  (select count(*) from public.attendance) as attendance;
