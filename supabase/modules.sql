-- ============================================================
-- SportSphere — remaining module tables (Phase 2/3 complete)
-- Purchases, Housekeeping, Training & Camps, Performance & Medical,
-- Events, Transport, Accommodation, Expenses, School Activities.
-- Run AFTER schema.sql. Uses same role helpers.
-- ============================================================

-- ---------- Vendor & Purchase Management ----------
create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid references public.vendors(id) on delete set null,
  items jsonb not null default '[]',   -- [{name, qty, price}]
  total numeric(12,2) default 0,
  status text not null default 'Draft', -- Draft/Ordered/Received/Cancelled
  created_at timestamptz not null default now()
);

-- ---------- Housekeeping Management ----------
create table if not exists public.housekeeping_tasks (
  id uuid primary key default gen_random_uuid(),
  area text not null,                   -- e.g. "Main Stadium - Changing Room"
  task text not null,                   -- e.g. "Floor cleaning"
  assigned_to text,
  scheduled_date date,
  status text not null default 'Pending', -- Pending/In Progress/Done
  created_at timestamptz not null default now()
);

-- ---------- Training & Training Camps ----------
create table if not exists public.training_sessions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  type text not null default 'Session', -- Session/Camp
  sport text,
  coach_id uuid references public.coaches(id) on delete set null,
  team_id uuid references public.teams(id) on delete set null,
  venue_id uuid references public.venues(id) on delete set null,
  start_time timestamptz,
  end_time timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

-- ---------- Athlete Performance & Medical ----------
create table if not exists public.performance_records (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  date date not null default current_date,
  metric text not null,                 -- e.g. "100m sprint", "VO2 max"
  value text not null,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.medical_records (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  date date not null default current_date,
  type text not null default 'Checkup', -- Checkup/Injury/Physio/Clearance
  details text not null,
  cleared boolean not null default true,
  created_at timestamptz not null default now()
);

-- ---------- Events Management ----------
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  type text not null default 'General', -- General/Ceremony/Workshop/Other
  date date,
  venue_id uuid references public.venues(id) on delete set null,
  description text,
  created_at timestamptz not null default now()
);

-- ---------- Transport & Accommodation ----------
create table if not exists public.transport (
  id uuid primary key default gen_random_uuid(),
  purpose text not null,                -- e.g. "Team bus to State Meet"
  vehicle text,
  driver text,
  depart_at timestamptz,
  return_at timestamptz,
  team_id uuid references public.teams(id) on delete set null,
  status text not null default 'Planned', -- Planned/In Transit/Completed
  created_at timestamptz not null default now()
);

create table if not exists public.accommodation (
  id uuid primary key default gen_random_uuid(),
  hotel text not null,
  location text,
  check_in date,
  check_out date,
  team_id uuid references public.teams(id) on delete set null,
  rooms int default 0,
  status text not null default 'Booked', -- Booked/Checked-in/Completed
  created_at timestamptz not null default now()
);

-- ---------- Finance & Expenses ----------
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  category text not null,               -- Equipment/Travel/Salary/Other
  amount numeric(12,2) not null default 0,
  date date not null default current_date,
  description text,
  approved_by text,
  created_at timestamptz not null default now()
);

-- ---------- School Sports Activities ----------
create table if not exists public.school_activities (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  school text,
  date date,
  participants int default 0,
  description text,
  created_at timestamptz not null default now()
);

-- ============================================================
-- RLS: all these tables are org-wide readable; admin writes,
-- with coach write on training/performance where it makes sense.
-- ============================================================
alter table public.purchase_orders enable row level security;
alter table public.housekeeping_tasks enable row level security;
alter table public.training_sessions enable row level security;
alter table public.performance_records enable row level security;
alter table public.medical_records enable row level security;
alter table public.events enable row level security;
alter table public.transport enable row level security;
alter table public.accommodation enable row level security;
alter table public.expenses enable row level security;
alter table public.school_activities enable row level security;

create policy "po read" on public.purchase_orders for select using (true);
create policy "po write" on public.purchase_orders for all using (public.is_admin()) with check (public.is_admin());

create policy "hk read" on public.housekeeping_tasks for select using (true);
create policy "hk write" on public.housekeeping_tasks for all using (public.is_admin() or public.current_role() = 'VenueManager') with check (public.is_admin() or public.current_role() = 'VenueManager');

create policy "train read" on public.training_sessions for select using (true);
create policy "train write" on public.training_sessions for all using (public.is_admin() or public.current_role() = 'Coach') with check (public.is_admin() or public.current_role() = 'Coach');

create policy "perf read" on public.performance_records for select using (true);
create policy "perf write" on public.performance_records for all using (public.is_admin() or public.current_role() = 'Coach') with check (public.is_admin() or public.current_role() = 'Coach');

create policy "med read" on public.medical_records for select using (true);
create policy "med write" on public.medical_records for all using (public.is_admin()) with check (public.is_admin());

create policy "events read" on public.events for select using (true);
create policy "events write" on public.events for all using (public.is_admin()) with check (public.is_admin());

create policy "transport read" on public.transport for select using (true);
create policy "transport write" on public.transport for all using (public.is_admin()) with check (public.is_admin());

create policy "accom read" on public.accommodation for select using (true);
create policy "accom write" on public.accommodation for all using (public.is_admin()) with check (public.is_admin());

create policy "expenses read" on public.expenses for select using (public.is_admin() or public.current_role() in ('Finance','HR'));
create policy "expenses write" on public.expenses for all using (public.is_admin() or public.current_role() = 'Finance') with check (public.is_admin() or public.current_role() = 'Finance');

create policy "activities read" on public.school_activities for select using (true);
create policy "activities write" on public.school_activities for all using (public.is_admin() or public.current_role() = 'Coach') with check (public.is_admin() or public.current_role() = 'Coach');
