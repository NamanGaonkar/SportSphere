-- ============================================================
-- SportSphere — module upgrade migration
-- 1) Payroll system upgrade: allowances, bonus, pay period, status,
--    payment method; net is now DB-computed (gross+allowances+bonus-deductions)
--    and covers coaches as well as staff.
-- 2) Venue Maintenance: tasks, assigned staff, status, cost.
-- 3) Housekeeping upgrade: venue link, staff profile link, time window, notes.
-- 4) Awards expansion: teams, award type (Medal/Trophy/Man of the Match/
--    Certificate/Cash Prize), prize money, linked match/tournament.
-- 5) Connection columns: sports (type/format/indoor-outdoor + supported
--    venues via venue_sports), venues (indoor/outdoor, facility details),
--    coaches (sport, certification, experience), tournaments (format),
--    staff (employment details), venue bookings (status + double-booking
--    prevention trigger).
-- Idempotent: safe to re-run.
-- ============================================================

-- ---------- 1) PAYROLL ----------
alter table public.payroll add column if not exists staff_id uuid;
alter table public.payroll add column if not exists coach_id uuid;
alter table public.payroll add column if not exists allowances numeric(12,2) default 0;
alter table public.payroll add column if not exists bonus numeric(12,2) default 0;
alter table public.payroll add column if not exists pay_period text default 'Monthly';
alter table public.payroll add column if not exists status text default 'Pending';
alter table public.payroll add column if not exists payment_method text default 'Bank Transfer';
alter table public.payroll add column if not exists paid_on date;
alter table public.payroll add column if not exists remarks text;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='payroll_staff_fk') then
    alter table public.payroll add constraint payroll_staff_fk
      foreign key (staff_id) references public.staff(id) on delete set null;
  end if;
end $$;
do $$ begin
  if not exists (select 1 from pg_constraint where conname='payroll_coach_fk') then
    alter table public.payroll add constraint payroll_coach_fk
      foreign key (coach_id) references public.coaches(id) on delete set null;
  end if;
end $$;

-- net becomes a generated column (DB-computed, can never disagree with gross).
-- PG cannot convert a plain column in place, so drop + re-add as generated.
do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='payroll' and column_name='net' and is_generated='ALWAYS'
  ) then
    alter table public.payroll drop column net;
    alter table public.payroll
      add column net numeric(12,2)
      generated always as (gross + coalesce(allowances,0) + coalesce(bonus,0) - coalesce(deductions,0)) stored;
  end if;
end $$;

create index if not exists payroll_staff_idx on public.payroll(staff_id);
create index if not exists payroll_coach_idx on public.payroll(coach_id);
create index if not exists payroll_month_idx on public.payroll(month desc);

-- ---------- 2) VENUE MAINTENANCE ----------
create table if not exists public.venue_maintenance (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid references public.venues(id) on delete cascade,
  issue_title text not null,
  description text,
  assigned_to text,
  reported_date date default current_date,
  completed_date date,
  cost numeric(12,2) default 0,
  status text not null default 'Reported',
  priority text default 'Medium',
  created_at timestamptz default now()
);

drop policy if exists "vm read" on public.venue_maintenance;
create policy "vm read" on public.venue_maintenance for select using (true);
drop policy if exists "vm write" on public.venue_maintenance;
create policy "vm write" on public.venue_maintenance for all
  using (is_admin() or current_role = 'VenueManager')
  with check (is_admin() or current_role = 'VenueManager');

-- ---------- 3) HOUSEKEEPING UPGRADE ----------
alter table public.housekeeping_tasks add column if not exists venue_id uuid references public.venues(id) on delete set null;
alter table public.housekeeping_tasks add column if not exists start_time timestamptz;
alter table public.housekeeping_tasks add column if not exists end_time timestamptz;
alter table public.housekeeping_tasks add column if not exists notes text;

-- ---------- 4) AWARDS EXPANSION ----------
alter table public.awards add column if not exists team_id uuid references public.teams(id) on delete set null;
alter table public.awards add column if not exists award_type text default 'Award';
alter table public.awards add column if not exists prize_money numeric(12,2) default 0;
alter table public.awards add column if not exists match_id uuid;
alter table public.awards add column if not exists tournament_id uuid references public.tournaments(id) on delete set null;
alter table public.awards add column if not exists notes text;

update public.awards set award_type = 'Award' where award_type is null;

-- ---------- 5) CONNECTION COLUMNS ----------
-- Sports: type, format, indoor/outdoor, supported venues
alter table public.sports add column if not exists sport_type text default 'Team';
alter table public.sports add column if not exists format text default 'League';
alter table public.sports add column if not exists indoor_outdoor text default 'Outdoor';

create table if not exists public.venue_sports (
  venue_id uuid not null references public.venues(id) on delete cascade,
  sport_id uuid not null references public.sports(id) on delete cascade,
  primary key (venue_id, sport_id)
);
drop policy if exists "vs read" on public.venue_sports;
create policy "vs read" on public.venue_sports for select using (true);
drop policy if exists "vs write" on public.venue_sports;
create policy "vs write" on public.venue_sports for all
  using (is_admin() or current_role = 'VenueManager')
  with check (is_admin() or current_role = 'VenueManager');

-- Venues: indoor/outdoor + facility details
alter table public.venues add column if not exists indoor_outdoor text default 'Outdoor';
alter table public.venues add column if not exists facility_details text;

-- Coaches: sport + certification + experience
alter table public.coaches add column if not exists sport_id uuid references public.sports(id) on delete set null;
alter table public.coaches add column if not exists certification text;
alter table public.coaches add column if not exists experience_years integer;

-- Tournaments: format
alter table public.tournaments add column if not exists format text default 'Knockout';

-- Staff: employment details
alter table public.staff add column if not exists join_date date;
alter table public.staff add column if not exists employment_type text default 'Full-time';
alter table public.staff add column if not exists qualification text;
alter table public.staff add column if not exists responsibilities text;

-- ---------- 6) VENUE BOOKING WORKFLOW ----------
alter table public.venue_bookings add column if not exists status text not null default 'Pending';
alter table public.venue_bookings add column if not exists title text;

-- Double-booking prevention: only one active (Pending/Confirmed) booking per
-- venue may overlap a time window. Cancelled/Rejected bookings don't block.
create or replace function public.prevent_double_booking() returns trigger as $$
begin
  if new.status in ('Cancelled','Rejected') then
    return new;
  end if;
  if exists (
    select 1 from public.venue_bookings b
    where b.venue_id = new.venue_id
      and b.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000')
      and b.status in ('Pending','Confirmed')
      and b.start_time < new.end_time
      and new.start_time < b.end_time
  ) then
    raise exception 'That venue is already booked for an overlapping time (status: Pending/Confirmed)';
  end if;
  return new;
end $$ language plpgsql;

drop trigger if exists trg_no_double_booking on public.venue_bookings;
create trigger trg_no_double_booking
  before insert or update of venue_id, start_time, end_time, status
  on public.venue_bookings
  for each row execute function public.prevent_double_booking();

-- ---------- REALTIME ----------
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='venue_maintenance') then
    alter publication supabase_realtime add table public.venue_maintenance;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='venue_sports') then
    alter publication supabase_realtime add table public.venue_sports;
  end if;
end $$;

-- ---------- SEED: employment details ----------
update public.staff set join_date = coalesce(join_date, created_at::date);

-- ---------- SEED: payroll history (3 months, staff + coaches) ----------
insert into public.payroll (staff_id, month, gross, deductions, allowances, bonus, pay_period, status, payment_method, remarks)
select s.id, m.month, 42000 + (row_number() over ())::int * 1500, 3200, 4000, 2000, 'Monthly', 'Paid', 'Bank Transfer', 'Seeded payroll record'
from public.staff s
cross join (select (date_trunc('month', current_date) - (n || ' month')::interval)::date as month from generate_series(0,2) n) m
where not exists (select 1 from public.payroll p where p.staff_id = s.id and p.month = m.month);

insert into public.payroll (coach_id, month, gross, deductions, allowances, bonus, pay_period, status, payment_method, remarks)
select c.id, m.month, 55000 + (row_number() over ())::int * 1500, 4200, 5000, 3000, 'Monthly', 'Paid', 'Bank Transfer', 'Seeded payroll record'
from public.coaches c
cross join (select (date_trunc('month', current_date) - (n || ' month')::interval)::date as month from generate_series(0,2) n) m
where not exists (select 1 from public.payroll p where p.coach_id = c.id and p.month = m.month);

-- ---------- SEED: venue maintenance ----------
insert into public.venue_maintenance (venue_id, issue_title, description, assigned_to, reported_date, cost, status, priority)
select v.id, 'Floodlight inspection', 'Quarterly electrical inspection of floodlights and wiring.', 'Ramesh Kumar', current_date - 3, 8500, 'In Progress', 'High'
from public.venues v where v.status = 'Active'
and not exists (select 1 from public.venue_maintenance vm where vm.venue_id = v.id);

insert into public.venue_maintenance (venue_id, issue_title, description, assigned_to, reported_date, cost, status, priority)
select v.id, 'Turf repair', 'Patch worn turf sections in the playing area.', 'Grounds Crew A', current_date - 10, 15000, 'Reported', 'Medium'
from public.venues v where v.indoor_outdoor = 'Outdoor'
and not exists (select 1 from public.venue_maintenance vm where vm.venue_id = v.id and vm.issue_title = 'Turf repair');

-- ---------- SEED: housekeeping tasks with venue links ----------
insert into public.housekeeping_tasks (area, task, assigned_to, scheduled_date, status, venue_id, notes)
select 'Changing rooms', 'Deep clean and restock supplies', 'Sunil Verma', current_date, 'Pending', v.id, 'Before evening sessions'
from public.venues v where not exists (select 1 from public.housekeeping_tasks h where h.venue_id = v.id and h.task like 'Deep clean%')
limit 4;

-- ---------- SEED: supported sports per venue ----------
insert into public.venue_sports (venue_id, sport_id)
select v.id, s.id from public.venues v, public.sports s
where (v.indoor_outdoor = 'Indoor' and s.indoor_outdoor = 'Indoor')
   or (v.indoor_outdoor = 'Outdoor' and s.indoor_outdoor = 'Outdoor')
on conflict do nothing;

-- ---------- SEED: coach details ----------
-- Coaches inherit a sport from the teams they coach (first team wins).
update public.coaches c set sport_id = t.sport_id
from public.teams t where t.coach_id = c.id and t.sport_id is not null and c.sport_id is null;
