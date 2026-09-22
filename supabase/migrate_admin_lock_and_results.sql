-- ============================================================
-- SportSphere — admin hard-lock + auto staff records + results seed
-- 1) IMMUTABLE ADMIN: DB triggers make the Admin role unchangeable by
--    ANYONE through ANY client (web, phone, REST). Admin rows cannot be
--    renamed, demoted or deleted; nobody can promote into Admin either.
--    (Creating additional admins remains a deliberate SQL-only act.)
-- 2) AUTO STAFF RECORDS: every HR / Finance / VenueManager signup or role
--    change gets a staff row (department default per role) so they appear
--    in Staff & HR on both apps immediately. Backfill for existing rows.
-- 3) RESULT COMPOSER FIX: the insert-composer was AFTER INSERT (a no-op,
--    it could never write the row) — now BEFORE INSERT.
-- 4) RESULTS SEED: completed fixtures across seven sports so dashboards
--    show every score format (runs/wickets, sets, games, goals, positions).
--    Junk 'Test Team' fixtures removed first.
-- ============================================================

-- ---------- 1) IMMUTABLE ADMIN ----------
create or replace function public.guard_admin_role_immutable()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Admin-role rows are frozen: no rename, no role change, no demotion.
  if old.role = 'Admin' then
    if new.role is distinct from 'Admin'
       or new.full_name is distinct from old.full_name then
      raise exception 'The primary Admin account is immutable.';
    end if;
  end if;
  -- Nobody can promote anything into an Admin row via client writes.
  if new.role = 'Admin' and old.role is distinct from 'Admin' then
    raise exception 'Admin accounts are created by SQL only.';
  end if;
  return new;
end;
$$;

create or replace function public.guard_admin_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.role = 'Admin' then
    raise exception 'The primary Admin account cannot be deleted.';
  end if;
  return old;
end;
$$;

drop trigger if exists trg_admin_immutable on public.profiles;
drop trigger if exists trg_admin_immutable_del on public.profiles;
create trigger trg_admin_immutable
  before update on public.profiles
  for each row execute procedure public.guard_admin_role_immutable();
create trigger trg_admin_immutable_del
  before delete on public.profiles
  for each row execute procedure public.guard_admin_delete();

-- ---------- 2) AUTO STAFF RECORDS ----------
create or replace function public.ensure_staff_record()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_dept text;
begin
  if new.role not in ('HR', 'Finance', 'VenueManager') then
    return new;
  end if;
  if exists (select 1 from public.staff where profile_id = new.id) then
    return new;
  end if;
  v_dept := case new.role
    when 'HR' then 'Human Resources'
    when 'Finance' then 'Finance'
    else 'Venue Operations'
  end;
  insert into public.staff (profile_id, department, designation, employment_type, join_date)
  values (new.id, v_dept, v_dept || ' Officer', 'Full-time', current_date);
  return new;
end;
$$;

drop trigger if exists trg_ensure_staff on public.profiles;
create trigger trg_ensure_staff
  after insert or update of role on public.profiles
  for each row execute procedure public.ensure_staff_record();

-- Backfill everyone who already has such a role but no staff row.
insert into public.staff (profile_id, department, designation, employment_type, join_date)
select p.id,
       case p.role
         when 'HR' then 'Human Resources'
         when 'Finance' then 'Finance'
         else 'Venue Operations'
       end,
       case p.role
         when 'HR' then 'Human Resources Officer'
         when 'Finance' then 'Finance Officer'
         else 'Venue Operations Officer'
       end,
       'Full-time', current_date
from public.profiles p
where p.role in ('HR', 'Finance', 'VenueManager')
  and not exists (select 1 from public.staff s where s.profile_id = p.id);

-- ---------- 3) RESULT COMPOSER FIX (AFTER INSERT was a silent no-op) ----------
drop trigger if exists trg_compose_result_ins on public.matches;
create trigger trg_compose_result_ins
  before insert on public.matches
  for each row execute procedure public.compose_match_result_ins();

-- ---------- 4) RESULTS SEED ----------
alter table public.matches add column if not exists seed_note text;

-- Junk tester fixtures + team out first (bookings reference matches).
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='venue_bookings'
               and column_name='match_id') then
    delete from public.venue_bookings vb
    using public.matches m, public.teams t
    where vb.match_id = m.id and t.id = m.team_a_id and t.name = 'Test Team';
  end if;
  delete from public.matches m
  using public.teams t
  where t.id = m.team_a_id and t.name = 'Test Team';
  delete from public.teams where name = 'Test Team';
end $$;

-- Clear any earlier seed pass, then re-seed (idempotent).
delete from public.matches where seed_note = 'results-seed-v1';

-- Every sport needs two squads for a fixture: give the single-team sports
-- a realistic opposition team.
insert into public.teams (name, sport_id)
select v.tname, s.id
from (values
  ('Volleyball Spartans', 'Volleyball'),
  ('Badminton Phantoms', 'Badminton'),
  ('Court Rivals', 'Basketball'),
  ('Hockey Strikers', 'Hockey'),
  ('Aqua Waves', 'Swimming'),
  ('Track Racers', 'Athletics/Track & Field')
) as v(tname, sport)
join public.sports s on s.name = v.sport
where not exists (select 1 from public.teams t where t.name = v.tname);

-- The fixtures themselves: one completed result per sport, using each
-- sport's own score fields (runs/wickets, sets+points, games+points,
-- goals, finishing positions). Realtime + triggers fill result strings.
insert into public.matches
  (team_a_id, team_b_id, venue_id, scheduled_at, status,
   score_a, score_b, wickets_a, wickets_b, sets_a, sets_b, seed_note)
select
  ta.id, tb.id,
  (select v.id from public.venues v
    join public.venue_sports vs on vs.venue_id = v.id and vs.sport_id = sp.sport_id
    limit 1),
  now() - make_interval(days => seed.days),
  'Completed',
  seed.score_a, seed.score_b, seed.wk_a, seed.wk_b, seed.st_a, seed.st_b,
  'results-seed-v1'
from (values
  ('Football',               12,  3,   1,   null, null, null, null),
  ('Football',               30,  2,   2,   null, null, null, null),
  ('Cricket',                 9, 184, 176,   7,    9,   null, null),
  ('Cricket',                 5, 201, 198,   5,    8,   null, null),
  ('Volleyball',              8,  62,  48,  null, null,  3,   1),
  ('Badminton',               6,  21,  18,  null, null,  2,   0),
  ('Basketball',             14,  68,  61,  null, null, null, null),
  ('Hockey',                  4,   2,   1,  null, null, null, null),
  ('Athletics/Track & Field',10,   1,   2,  null, null, null, null),
  ('Swimming',                7,   1,   3,  null, null, null, null)
) as seed(sport, days, score_a, score_b, wk_a, wk_b, st_a, st_b)
join lateral (
  select s.id as sport_id from public.sports s where s.name = seed.sport
) sp on true
join lateral (
  select t.id from public.teams t
  where t.sport_id = sp.sport_id and t.name not like '%Spartans%'
    and t.name not like '%Phantoms%' and t.name not like '%Rivals%'
    and t.name not like '%Strikers%' and t.name not like '%Waves%'
    and t.name not like '%Racers%'
  order by t.created_at limit 1
) ta on true
join lateral (
  select t.id from public.teams t
  where t.sport_id = sp.sport_id and t.id <> ta.id
  order by t.created_at desc limit 1
) tb on true;
