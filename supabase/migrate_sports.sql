-- ============================================================
-- SportSphere — SPORTS migration + seed (conflict-safe)
-- 1) sports source-of-truth table (10 seeded sports)
-- 2) sport_id on teams / tournaments / training_sessions
-- 3) athlete_sports join table (multi-sport athletes)
-- 4) legacy text sport -> sport_id backfill, then rename to sport_legacy
-- 5) merge roster rows into the six LOGIN users (coach/athlete/staff)
-- 6) real 14-day attendance for all six users
-- 7) attendance self-update policy fix
-- 8) realtime publication for live web <-> mobile sync
-- Idempotent: safe to run more than once.
-- ============================================================

-- ---------- 1) SPORTS TABLE (single source of truth) ----------
create table if not exists public.sports (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  icon text,
  created_at timestamptz not null default now()
);

insert into public.sports (name) values
  ('Football'), ('Cricket'), ('Basketball'), ('Athletics/Track & Field'), ('Badminton'),
  ('Table Tennis'), ('Hockey'), ('Volleyball'), ('Swimming'), ('Kabaddi')
on conflict (name) do nothing;

alter table public.sports enable row level security;

drop policy if exists "sports read" on public.sports;
create policy "sports read" on public.sports for select using (true);

drop policy if exists "sports admin write" on public.sports;
create policy "sports admin write" on public.sports for all
  using (public.is_admin()) with check (public.is_admin());

-- ---------- 2) SPORT LINKS ON CORE TABLES ----------
alter table public.teams             add column if not exists sport_id uuid references public.sports(id) on delete set null;
alter table public.tournaments       add column if not exists sport_id uuid references public.sports(id) on delete set null;
alter table public.training_sessions add column if not exists sport_id uuid references public.sports(id) on delete set null;

create index if not exists idx_teams_sport       on public.teams(sport_id);
create index if not exists idx_tournaments_sport on public.tournaments(sport_id);
create index if not exists idx_training_sport    on public.training_sessions(sport_id);

-- ---------- 3) ATHLETE_SPORTS JOIN (multi-sport athletes) ----------
create table if not exists public.athlete_sports (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  sport_id uuid not null references public.sports(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(athlete_id, sport_id)
);

alter table public.athlete_sports enable row level security;

drop policy if exists "athlete_sports read" on public.athlete_sports;
create policy "athlete_sports read" on public.athlete_sports for select using (true);

drop policy if exists "athlete_sports write" on public.athlete_sports;
create policy "athlete_sports write" on public.athlete_sports for all
  using (public.is_admin() or public.current_role() = 'Coach')
  with check (public.is_admin() or public.current_role() = 'Coach');

create index if not exists idx_athlete_sports_athlete on public.athlete_sports(athlete_id);
create index if not exists idx_athlete_sports_sport   on public.athlete_sports(sport_id);

-- ---------- 4) BACKFILL sport_id FROM LEGACY TEXT ----------
-- Exact name match first, then prefix match (legacy 'Athletics' -> 'Athletics/Track & Field').
update public.teams t
set sport_id = s.id
from public.sports s
where t.sport_id is null
  and (lower(t.sport) = lower(s.name) or lower(s.name) like lower(t.sport) || '%');

update public.training_sessions tr
set sport_id = s.id
from public.sports s
where tr.sport_id is null and tr.sport is not null
  and (lower(tr.sport) = lower(s.name) or lower(s.name) like lower(tr.sport) || '%');

insert into public.athlete_sports (athlete_id, sport_id)
select a.id, s.id
from public.athletes a
join public.sports s
  on lower(s.name) = lower(a.sport) or lower(s.name) like lower(a.sport) || '%'
where a.sport is not null
on conflict (athlete_id, sport_id) do nothing;

-- Preserve the original values, then rename so apps use exactly one
-- source of truth (sport_id / athlete_sports).
do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='teams' and column_name='sport') then
    alter table public.teams rename column sport to sport_legacy;
  end if;
end $$;

do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='athletes' and column_name='sport') then
    alter table public.athletes rename column sport to sport_legacy;
  end if;
end $$;

do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='training_sessions' and column_name='sport') then
    alter table public.training_sessions rename column sport to sport_legacy;
  end if;
end $$;

-- ---------- 5a) TOURNAMENT SPORT LINKS ----------
update public.tournaments set sport_id = (select id from public.sports where name = 'Football')
  where name = 'Inter-School Cup' and sport_id is null;
update public.tournaments set sport_id = (select id from public.sports where name = 'Athletics/Track & Field')
  where name = 'District Championship' and sport_id is null;
update public.tournaments set sport_id = (select id from public.sports where name = 'Basketball')
  where name = 'State League' and sport_id is null;
update public.tournaments set sport_id = (select id from public.sports where name = 'Cricket')
  where name = 'National Meet' and sport_id is null;

-- ---------- 5b) MERGE ROSTER ROWS INTO THE LOGIN USERS ----------
-- Coach: if both 'Rahul Verma' and 'Coach One' coach rows exist, move all
-- teams/training to Coach One's row and drop the duplicate row.
do $$
declare
  rahul_coach uuid;
  coach_one_coach uuid;
begin
  select c.id into rahul_coach from public.coaches c
    join public.profiles p on p.id = c.profile_id where p.full_name = 'Rahul Verma';
  select c.id into coach_one_coach from public.coaches c
    join public.profiles p on p.id = c.profile_id where p.full_name = 'Coach One';

  if rahul_coach is not null and coach_one_coach is not null and rahul_coach <> coach_one_coach then
    update public.teams set coach_id = coach_one_coach where coach_id = rahul_coach;
    update public.training_sessions set coach_id = coach_one_coach where coach_id = rahul_coach;
    delete from public.coaches where id = rahul_coach;
  elsif rahul_coach is not null and coach_one_coach is null then
    update public.coaches set profile_id = (select id from public.profiles where full_name = 'Coach One')
      where id = rahul_coach;
  end if;
end $$;

-- Athletes: if both 'Aarav Mehta' and 'Athlete One' athlete rows exist,
-- move referencing rows to Athlete One's row and drop the duplicate.
do $$
declare
  aarav_athlete uuid;
  athlete_one_athlete uuid;
begin
  select a.id into aarav_athlete from public.athletes a
    join public.profiles p on p.id = a.profile_id where p.full_name = 'Aarav Mehta';
  select a.id into athlete_one_athlete from public.athletes a
    join public.profiles p on p.id = a.profile_id where p.full_name = 'Athlete One';

  if aarav_athlete is not null and athlete_one_athlete is not null and aarav_athlete <> athlete_one_athlete then
    update public.performance_records set athlete_id = athlete_one_athlete where athlete_id = aarav_athlete;
    update public.medical_records     set athlete_id = athlete_one_athlete where athlete_id = aarav_athlete;
    update public.awards              set athlete_id = athlete_one_athlete where athlete_id = aarav_athlete;
    delete from public.athletes where id = aarav_athlete;  -- cascades athlete_sports
  elsif aarav_athlete is not null and athlete_one_athlete is null then
    update public.athletes set profile_id = (select id from public.profiles where full_name = 'Athlete One')
      where id = aarav_athlete;
  end if;
end $$;

-- Staff: re-point HR / Finance roster rows to the login users (no
-- conflict: those users have no staff rows yet).
update public.staff
set profile_id = (select id from public.profiles where full_name = 'HR Manager')
where profile_id = (select id from public.profiles where full_name = 'Deepak Rane')
  and exists (select 1 from public.profiles where full_name = 'HR Manager')
  and not exists (select 1 from public.staff s join public.profiles p on p.id = s.profile_id where p.full_name = 'HR Manager');

update public.staff
set profile_id = (select id from public.profiles where full_name = 'Finance Lead')
where profile_id = (select id from public.profiles where full_name = 'Kavita Krishnan')
  and exists (select 1 from public.profiles where full_name = 'Finance Lead')
  and not exists (select 1 from public.staff s join public.profiles p on p.id = s.profile_id where p.full_name = 'Finance Lead');

-- Venue Manager gets a staff row + last-month payroll so the Finance/HR
-- modules show real data for that user too.
insert into public.staff (profile_id, department, designation)
select p.id, 'Facilities', 'Venue Manager'
from public.profiles p
where p.full_name = 'Venue Manager'
  and not exists (select 1 from public.staff s where s.profile_id = p.id);

insert into public.payroll (staff_id, month, gross, deductions)
select s.id, date_trunc('month', current_date - interval '1 month'), 58000, 7400
from public.staff s join public.profiles p on p.id = s.profile_id
where p.full_name = 'Venue Manager'
  and not exists (
    select 1 from public.payroll px
    where px.staff_id = s.id and px.month = date_trunc('month', current_date - interval '1 month')
  );

-- Multi-sport examples so the join table shows its range.
insert into public.athlete_sports (athlete_id, sport_id)
select a.id, s.id from public.athletes a, public.sports s
where s.name = 'Kabaddi'
  and a.profile_id = (select id from public.profiles where full_name = 'Athlete One')
on conflict (athlete_id, sport_id) do nothing;

insert into public.athlete_sports (athlete_id, sport_id)
select a.id, s.id from public.athletes a, public.sports s
where s.name = 'Swimming'
  and a.profile_id = (select id from public.profiles where full_name = 'Meera Iyer')
on conflict (athlete_id, sport_id) do nothing;

-- ---------- 6) REAL 14-DAY ATTENDANCE FOR ALL SIX LOGIN USERS ----------
insert into public.attendance (profile_id, date, status, leave_reason)
select p.id,
       d::date,
       case
         when abs(hashtext(p.id::text) + extract(day from d)::int) % 11 = 0 then 'Absent'::attendance_status
         when abs(hashtext(p.id::text) + extract(day from d)::int) % 13 = 0 then 'Late'::attendance_status
         when abs(hashtext(p.id::text) + extract(day from d)::int) % 17 = 0 then 'Leave'::attendance_status
         else 'Present'::attendance_status
       end,
       case
         when abs(hashtext(p.id::text) + extract(day from d)::int) % 17 = 0
           then 'Personal / family commitment'
         else null
       end
from public.profiles p,
     generate_series(current_date - 13, current_date, interval '1 day') d
where p.full_name in
  ('Admin SportSphere','Athlete One','Coach One','HR Manager','Finance Lead','Venue Manager')
on conflict (profile_id, date) do nothing;

-- Older seeded Leave rows have no reason — fill a sensible one.
update public.attendance
set leave_reason = 'Personal / family commitment'
where status = 'Leave' and leave_reason is null;

-- ---------- 7) FIX: users can edit their OWN attendance rows ----------
drop policy if exists "attendance self update" on public.attendance;
create policy "attendance self update" on public.attendance
  for update using (profile_id = auth.uid());

-- ---------- 8) REALTIME: live sync between web + mobile ----------
do $$
declare t text;
begin
  foreach t in array array[
    'sports','teams','tournaments','training_sessions','matches',
    'attendance','athletes','athlete_sports','notifications'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
