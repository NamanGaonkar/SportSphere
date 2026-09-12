-- ============================================================
-- SportSphere — full schema + RLS + trigger
-- Run top-to-bottom in Supabase SQL Editor.
-- Auth: users sign up via app; trigger creates profiles row.
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------- ENUMS ----------
create type user_role as enum ('Admin','Coach','Athlete','HR','Finance','VenueManager');
create type tournament_level as enum ('School','District','State','National');
create type match_status as enum ('Scheduled','Live','Completed','Cancelled');
create type attendance_status as enum ('Present','Absent','Late','Leave');

-- ---------- CORE: PROFILES ----------
-- NOTE: id references auth.users for real signups (see trigger), but roster-only
-- profiles created from the web app (no login yet) are also allowed.
create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  full_name text not null default '',
  role user_role not null default 'Athlete',
  avatar_url text,
  contact_info text,
  created_at timestamptz not null default now()
);

-- ---------- COACHES (before teams: teams.coach_id references this) ----------
create table public.coaches (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete cascade,
  specialization text,
  created_at timestamptz not null default now()
);

-- ---------- TEAMS ----------
create table public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sport text not null,
  coach_id uuid references public.coaches(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ---------- ATHLETES ----------
create table public.athletes (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete cascade,
  dob date,
  sport text,
  team_id uuid references public.teams(id) on delete set null,
  medical_notes text,
  created_at timestamptz not null default now()
);

-- Staff (Phase 2)
create table public.staff (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete cascade,
  department text,
  designation text,
  created_at timestamptz not null default now()
);

-- ---------- VENUES ----------
create table public.venues (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  capacity int,
  status text not null default 'Active',
  created_at timestamptz not null default now()
);

create table public.venue_bookings (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  booked_by uuid references public.profiles(id) on delete set null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  purpose text,
  created_at timestamptz not null default now()
);

-- ---------- TOURNAMENTS / MATCHES ----------
create table public.tournaments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  level tournament_level not null default 'School',
  start_date date,
  end_date date,
  venue_id uuid references public.venues(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid references public.tournaments(id) on delete cascade,
  team_a_id uuid references public.teams(id) on delete cascade,
  team_b_id uuid references public.teams(id) on delete cascade,
  scheduled_at timestamptz,
  status match_status not null default 'Scheduled',
  score_a int default 0,
  score_b int default 0,
  result text,
  created_at timestamptz not null default now()
);

create index idx_matches_tournament on public.matches(tournament_id);
create index idx_matches_status on public.matches(status);

-- ---------- ATTENDANCE ----------
create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  date date not null default current_date,
  status attendance_status not null default 'Present',
  leave_reason text,
  created_at timestamptz not null default now(),
  unique(profile_id, date)
);

-- ---------- PAYROLL / STAFF (Phase 2) ----------
create table public.payroll (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid references public.staff(id) on delete cascade,
  month date not null,
  gross numeric(12,2) default 0,
  deductions numeric(12,2) default 0,
  net numeric(12,2) generated always as (gross - deductions) stored,
  created_at timestamptz not null default now()
);

-- ---------- INVENTORY / VENDORS (Phase 3 scaffold) ----------
create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  quantity int default 0,
  condition text default 'Good',
  created_at timestamptz not null default now()
);

create table public.vendors (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact text,
  category text,
  created_at timestamptz not null default now()
);

create table public.awards (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid references public.athletes(id) on delete cascade,
  title text not null,
  date date,
  level text,
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  message text not null,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_notifications_recipient on public.notifications(recipient_id, read);

-- ---------- updated_at helper (skip: all tables use created_at only) ----------

-- ---------- TRIGGER: auto-create profile on signup ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- upsert-safe: a roster-only profile may already exist with this id
  insert into public.profiles (id, full_name, role, contact_info)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'Athlete'),
    new.email
  )
  on conflict (id) do update
    set contact_info = excluded.contact_info,
        full_name = case when profiles.full_name = '' then excluded.full_name else profiles.full_name end;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles enable row level security;
alter table public.teams enable row level security;
alter table public.athletes enable row level security;
alter table public.coaches enable row level security;
alter table public.staff enable row level security;
alter table public.venues enable row level security;
alter table public.venue_bookings enable row level security;
alter table public.tournaments enable row level security;
alter table public.matches enable row level security;
alter table public.attendance enable row level security;
alter table public.payroll enable row level security;
alter table public.inventory_items enable row level security;
alter table public.vendors enable row level security;
alter table public.awards enable row level security;
alter table public.notifications enable row level security;

-- helper: current user's role (security definer so policies avoid RLS recursion)
create or replace function public.current_role()
returns user_role
language sql stable security definer
set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer
set search_path = public as $$ select public.current_role() = 'Admin' $$;

create or replace function public.is_staff_role()
returns boolean language sql stable security definer
set search_path = public as $$
  select public.current_role() in ('Admin','HR','Finance','VenueManager')
$$;

-- profiles: everyone reads, self-update, admin writes all
create policy "profiles read" on public.profiles for select using (true);
create policy "profiles self update" on public.profiles for update using (id = auth.uid());
create policy "profiles admin update" on public.profiles for update using (public.is_admin());
create policy "profiles admin insert" on public.profiles for insert with check (public.is_admin());

-- teams / venues / tournaments / matches: everyone reads, admin+coach write
create policy "teams read" on public.teams for select using (true);
create policy "teams write" on public.teams for all using (public.is_admin() or public.current_role() = 'Coach') with check (public.is_admin() or public.current_role() = 'Coach');

create policy "venues read" on public.venues for select using (true);
create policy "venues write" on public.venues for all using (public.is_admin() or public.current_role() = 'VenueManager') with check (public.is_admin() or public.current_role() = 'VenueManager');

create policy "bookings read" on public.venue_bookings for select using (true);
create policy "bookings write" on public.venue_bookings for all using (public.is_admin() or public.current_role() in ('Coach','VenueManager')) with check (public.is_admin() or public.current_role() in ('Coach','VenueManager'));

create policy "tournaments read" on public.tournaments for select using (true);
create policy "tournaments write" on public.tournaments for all using (public.is_admin()) with check (public.is_admin());

create policy "matches read" on public.matches for select using (true);
create policy "matches write" on public.matches for all using (public.is_admin() or public.current_role() = 'Coach') with check (public.is_admin() or public.current_role() = 'Coach');

-- athletes: read all (team rosters are public within org), write admin+coach
create policy "athletes read" on public.athletes for select using (true);
create policy "athletes write" on public.athletes for all using (public.is_admin() or public.current_role() = 'Coach') with check (public.is_admin() or public.current_role() = 'Coach');
create policy "athletes self update" on public.athletes for update using (profile_id = auth.uid());

-- coaches: read all, write admin
create policy "coaches read" on public.coaches for select using (true);
create policy "coaches write" on public.coaches for all using (public.is_admin()) with check (public.is_admin());
create policy "coaches self update" on public.coaches for update using (profile_id = auth.uid());

-- staff: read all, write admin/HR
create policy "staff read" on public.staff for select using (true);
create policy "staff write" on public.staff for all using (public.is_admin() or public.current_role() = 'HR') with check (public.is_admin() or public.current_role() = 'HR');

-- attendance: coaches/admin/HR read all; athletes read+insert own
create policy "attendance read all" on public.attendance for select using (
  public.is_admin() or public.current_role() in ('Coach','HR') or profile_id = auth.uid()
);
create policy "attendance self insert" on public.attendance for insert with check (profile_id = auth.uid());
create policy "attendance write" on public.attendance for all using (public.is_admin() or public.current_role() in ('Coach','HR')) with check (public.is_admin() or public.current_role() in ('Coach','HR'));

-- payroll: admin/Finance read+write; staff sees own via staff.profile_id
create policy "payroll read" on public.payroll for select using (
  public.is_admin() or public.current_role() = 'Finance'
  or exists (select 1 from public.staff s where s.id = payroll.staff_id and s.profile_id = auth.uid())
);
create policy "payroll write" on public.payroll for all using (public.is_admin() or public.current_role() = 'Finance') with check (public.is_admin() or public.current_role() = 'Finance');

-- inventory/vendors: everyone reads, admin writes
create policy "inventory read" on public.inventory_items for select using (true);
create policy "inventory write" on public.inventory_items for all using (public.is_admin()) with check (public.is_admin());

create policy "vendors read" on public.vendors for select using (true);
create policy "vendors write" on public.vendors for all using (public.is_admin()) with check (public.is_admin());

-- awards: everyone reads, admin/coach write
create policy "awards read" on public.awards for select using (true);
create policy "awards write" on public.awards for all using (public.is_admin() or public.current_role() = 'Coach') with check (public.is_admin() or public.current_role() = 'Coach');

-- notifications: recipient-only
create policy "notifications own" on public.notifications for select using (recipient_id = auth.uid());
create policy "notifications admin write" on public.notifications for insert with check (public.is_admin());
create policy "notifications self update" on public.notifications for update using (recipient_id = auth.uid());
