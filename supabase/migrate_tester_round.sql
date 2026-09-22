-- ============================================================
-- SportSphere — tester-feedback migration
-- Venues (sports, prices), Matches (venue, type, over), Bookings
-- (tournament-aware conflicts, fixture auto-book), Coaches (pdf,
-- photo), Medical (certificates), Training (frequency/destination),
-- Accommodation (event context), Transport (destination), Expenses
-- (vendor link), RBAC & helpers. Idempotent.
-- ============================================================

-- ---------- 1) VENUES ----------
alter table public.venues add column if not exists booking_price_match numeric(12,2);
alter table public.venues add column if not exists booking_price_tournament numeric(12,2);

create table if not exists public.venue_sports (
  venue_id uuid not null references public.venues(id) on delete cascade,
  sport_id uuid not null references public.sports(id) on delete cascade,
  primary key (venue_id, sport_id)
);
alter table public.venue_sports enable row level security;
drop policy if exists "venue_sports read" on public.venue_sports;
create policy "venue_sports read" on public.venue_sports for select using (true);
drop policy if exists "venue_sports write" on public.venue_sports;
create policy "venue_sports write" on public.venue_sports for all
  using (public.is_admin() or public.current_role() in ('VenueManager','HR'))
  with check (public.is_admin() or public.current_role() in ('VenueManager','HR'));

-- Seed from legacy text column if present
do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='venues'
               and column_name='supported_sports_text') then
    execute $fn$
      insert into public.venue_sports (venue_id, sport_id)
      select v.id, s.id
      from public.venues v
      join public.sports s on s.name = trim(v.supported_sports_text)
      where v.supported_sports_text is not null
        and trim(v.supported_sports_text) <> ''
      on conflict do nothing
    $fn$;
  end if;
end $$;

-- ---------- 1b) PROFILES: separate phone field ----------
alter table public.profiles add column if not exists phone text;

-- ---------- 2) MATCHES ----------
alter table public.matches add column if not exists venue_id uuid references public.venues(id) on delete set null;
alter table public.matches add column if not exists match_type text not null default 'League Match';
alter table public.matches add column if not exists round_note text;

-- ---------- 3) VENUE BOOKINGS ----------
alter table public.venue_bookings add column if not exists is_tournament_block boolean not null default false;
alter table public.venue_bookings add column if not exists booked_for_match_id uuid references public.matches(id) on delete cascade;

-- ---------- 4) COACHES ----------
alter table public.coaches add column if not exists certification_url text;
alter table public.coaches add column if not exists avatar_url text;
alter table public.coaches add column if not exists trains_note text;

-- ---------- 5) MEDICAL ----------
alter table public.medical_records add column if not exists certificate_url text;

-- ---------- 6) TRAINING ----------
alter table public.training_sessions add column if not exists frequency text;
alter table public.training_sessions add column if not exists start_date date;
alter table public.training_sessions add column if not exists end_date date;

-- ---------- 7) ACCOMMODATION ----------
alter table public.accommodation add column if not exists event_note text;

-- ---------- 8) TRANSPORT ----------
alter table public.transport add column if not exists destination text;

-- ---------- 9) EXPENSES ----------
alter table public.expenses add column if not exists vendor_id uuid references public.vendors(id) on delete set null;
alter table public.expenses add column if not exists items_note text;
alter table public.expenses add column if not exists status text not null default 'Approved';
alter table public.expenses add column if not exists approved_by_id uuid references public.profiles(id) on delete set null;

-- ---------- 10) SCHOOL ACTIVITIES ----------
alter table public.school_activities add column if not exists coordinator text;
alter table public.school_activities add column if not exists venue_id uuid references public.venues(id) on delete set null;

-- ---------- 11) RBAC REPAIRS ----------
-- HR also runs venues (tester: "cant add venues in hr acc")
drop policy if exists "venues write" on public.venues;
create policy "venues write" on public.venues for all
  using (public.is_admin() or public.current_role() in ('VenueManager','HR'))
  with check (public.is_admin() or public.current_role() in ('VenueManager','HR'));

-- Venue maintenance & housekeeping: Finance sees them (ops strip) and
-- VenueManager/HR run them.
drop policy if exists "maintenance read" on public.venue_maintenance;
drop policy if exists "maintenance write" on public.venue_maintenance;
create policy "maintenance read" on public.venue_maintenance for select using (true);
create policy "maintenance write" on public.venue_maintenance for all
  using (public.is_admin() or public.current_role() in ('VenueManager','HR','Finance'))
  with check (public.is_admin() or public.current_role() in ('VenueManager','HR','Finance'));

drop policy if exists "housekeeping read" on public.housekeeping_tasks;
drop policy if exists "housekeeping write" on public.housekeeping_tasks;
create policy "housekeeping read" on public.housekeeping_tasks for select using (true);
create policy "housekeeping write" on public.housekeeping_tasks for all
  using (public.is_admin() or public.current_role() in ('VenueManager','HR','Finance'))
  with check (public.is_admin() or public.current_role() in ('VenueManager','HR','Finance'));

-- Transport & accommodation: Finance can see/manage costs too.
drop policy if exists "transport write" on public.transport;
create policy "transport write" on public.transport for all
  using (public.is_admin() or public.current_role() in ('Coach','VenueManager','HR','Finance'))
  with check (public.is_admin() or public.current_role() in ('Coach','VenueManager','HR','Finance'));
drop policy if exists "accommodation write" on public.accommodation;
create policy "accommodation write" on public.accommodation for all
  using (public.is_admin() or public.current_role() in ('Coach','VenueManager','HR','Finance'))
  with check (public.is_admin() or public.current_role() in ('Coach','VenueManager','HR','Finance'));

-- Inventory: Finance + VenueManager manage stock too.
drop policy if exists "inventory write" on public.inventory_items;
create policy "inventory write" on public.inventory_items for all
  using (public.is_admin() or public.current_role() in ('Finance','HR','VenueManager'))
  with check (public.is_admin() or public.current_role() in ('Finance','HR','VenueManager'));
drop policy if exists "vendors write" on public.vendors;
create policy "vendors write" on public.vendors for all
  using (public.is_admin() or public.current_role() in ('Finance','HR'))
  with check (public.is_admin() or public.current_role() in ('Finance','HR'));

-- Purchases (if not already granted) — Finance/HR manage.
do $$ begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='purchase_order_items') then
    execute 'drop policy if exists "po_items write" on public.purchase_order_items';
    execute 'create policy "po_items write" on public.purchase_order_items for all
             using (public.is_admin() or public.current_role() in (''Finance'',''HR''))
             with check (public.is_admin() or public.current_role() in (''Finance'',''HR''))';
  end if;
end $$;

-- ---------- 12) VENUE BOOKING RULES (Kartik #1, #18) ----------
-- One venue may host MULTIPLE matches per day, but a TOURNAMENT block
-- reserves the venue from its start date through its end date.
create or replace function public.check_booking_conflict()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_venue uuid;
  v_start timestamptz;
  v_end timestamptz;
  v_id uuid;
  v_match uuid;
begin
  v_venue  := coalesce(new.venue_id, old.venue_id);
  v_start  := coalesce(new.start_time, old.start_time);
  v_end    := coalesce(new.end_time, old.end_time);
  v_id     := coalesce(new.id, old.id);
  v_match  := coalesce(new.booked_for_match_id, old.booked_for_match_id);

  if new.status in ('Cancelled', 'Rejected') then
    return new;  -- cancelled bookings free the slot
  end if;

  if new.is_tournament_block then
    -- Tournament block: no other active booking may intersect the range.
    if exists (
      select 1 from public.venue_bookings b
      where b.venue_id = v_venue
        and b.id <> v_id
        and b.status not in ('Cancelled', 'Rejected')
        and tstzrange(b.start_time, b.end_time, '[)') && tstzrange(v_start, v_end, '[)')
    ) then
      raise exception 'Venue already booked for that period (tournament block)';
    end if;
  else
    -- Match booking on the same day as a tournament block: blocked.
    if exists (
      select 1 from public.venue_bookings b
      where b.venue_id = v_venue
        and b.id <> v_id
        and b.status not in ('Cancelled', 'Rejected')
        and b.is_tournament_block
        and tstzrange(b.start_time, b.end_time, '[)') && tstzrange(v_start, v_end, '[)')
    ) then
      raise exception 'Venue reserved for a tournament on that date';
    end if;
    -- Regular bookings may not overlap each other in time (same-day
    -- different-time slots are fine).
    if exists (
      select 1 from public.venue_bookings b
      where b.venue_id = v_venue
        and b.id <> v_id
        and b.status not in ('Cancelled', 'Rejected')
        and b.is_tournament_block = false
        and tstzrange(b.start_time, b.end_time, '[)') && tstzrange(v_start, v_end, '[)')
    ) then
      raise exception 'Venue is already booked for that time slot';
    end if;
  end if;

  -- One match = one booking per venue per day.
  if v_match is not null and exists (
    select 1 from public.venue_bookings b
    where b.venue_id = v_venue
      and b.booked_for_match_id = v_match
      and b.id <> v_id
      and b.start_time::date = v_start::date
  ) then
    raise exception 'This match already has a booking at this venue that day';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_booking_conflict on public.venue_bookings;
create trigger trg_booking_conflict
  before insert or update on public.venue_bookings
  for each row execute procedure public.check_booking_conflict();

-- ---------- 13) AUTO-BOOK VENUE FROM FIXTURES (Kartik #18) ----------
create or replace function public.auto_book_fixture_venue()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_start timestamptz;
  v_dur interval;
begin
  if new.venue_id is null then return new; end if;
  v_start := coalesce(new.scheduled_at, now());
  v_dur   := interval '4 hours';

  insert into public.venue_bookings
    (venue_id, booked_by, title, start_time, end_time, purpose, status, is_tournament_block, booked_for_match_id)
  values
    (new.venue_id,
     auth.uid(),
     coalesce(new.match_type, 'Match') || ': ' ||
       coalesce((select name from public.teams where id = new.team_a_id), 'TBD') || ' vs ' ||
       coalesce((select name from public.teams where id = new.team_b_id), 'TBD'),
     v_start, v_start + v_dur, 'Fixture', 'Confirmed', false, new.id)
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists trg_auto_book_fixture on public.matches;
create trigger trg_auto_book_fixture
  after insert on public.matches
  for each row execute procedure public.auto_book_fixture_venue();

-- ---------- 14) TOURNAMENT VENUE BLOCKS (Kartik #1) ----------
create or replace function public.block_venue_for_tournament()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.venue_id is null then return new; end if;

  insert into public.venue_bookings
    (venue_id, booked_by, title, start_time, end_time, purpose, status, is_tournament_block)
  values
    (new.venue_id,
     auth.uid(),
     'Tournament: ' || new.name,
     coalesce(new.start_date, current_date)::timestamptz,
     coalesce(new.end_date, new.start_date, current_date)::timestamptz + interval '1 day',
     'Tournament', 'Confirmed', true)
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists trg_block_venue_tournament on public.tournaments;
create trigger trg_block_venue_tournament
  after insert on public.tournaments
  for each row execute procedure public.block_venue_for_tournament();

-- ---------- 15) NOTIFICATION HELPER (tester: users sync everywhere) ----------
create or replace function public.notify_users(p_recipients uuid[], p_message text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.notifications (recipient_id, message)
  select unnest(p_recipients), p_message
  where not exists (select 1 from public.notifications n
                    where n.recipient_id = unnest(p_recipients)
                      and n.message = p_message
                      and n.created_at > now() - interval '1 minute');
end;
$$;
grant execute on function public.notify_users(uuid[], text) to authenticated;

-- ---------- 16) ATHLETE / COACH SELF-SERVICE PHOTO (tester #10, #11) ----------
-- Athletes and coaches may upload their own avatar through the profile
-- page; the roster row keeps a copy of the URL for list views.
drop policy if exists "athletes self update" on public.athletes;
create policy "athletes self update" on public.athletes for update
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- avatars bucket: coaches/athletes upload into their own folder (uid).
drop policy if exists "avatars own insert" on storage.objects;
create policy "avatars own insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (auth.uid())::text);

-- ---------- 17b) COACH <-> TEAM ASSIGNMENT (HR-run, security definer) ----------
create or replace function public.admin_assign_coach_teams(p_coach uuid, p_teams uuid[])
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if public.current_role() not in ('Admin', 'HR') then
    raise exception 'Only admins or HR can assign coach teams';
  end if;
  -- Unassign teams that were removed...
  update public.teams set coach_id = null
  where coach_id = p_coach and not (id = any(p_teams));
  -- ...then assign the selected ones.
  update public.teams set coach_id = p_coach
  where id = any(p_teams);
end;
$$;
grant execute on function public.admin_assign_coach_teams(uuid, uuid[]) to authenticated;

-- ---------- 17c) ADMIN CREATE USER (staff/HR without invite emails) ----------
create or replace function public.admin_create_user(
  p_email text,
  p_password text,
  p_name text,
  p_role text,
  p_department text default null,
  p_designation text default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_uid uuid;
  v_req user_role;
begin
  if public.current_role() <> 'Admin' then
    raise exception 'Only admins can create accounts';
  end if;
  if p_role not in ('Admin','Coach','Athlete','HR','Finance','VenueManager') then
    raise exception 'Unknown role';
  end if;
  if length(p_password) < 6 then
    raise exception 'Password must be at least 6 characters';
  end if;
  if not (p_role = 'Admin' and public.current_role() = 'Admin') then
    v_req := p_role::user_role;
  else
    v_req := 'Admin';
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at, raw_app_meta_data,
    raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new,
    email_change, email_change_token_current
  ) values (
    '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
    lower(trim(p_email)),
    crypt(p_password, gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('full_name', p_name, 'role', v_req::text),
    now(), now(), '', '', '', '', ''
  )
  returning id into v_uid;

  -- roster row for coaches/staff so management pages can link records
  if v_req = 'Coach' then
    insert into public.coaches (profile_id) values (v_uid) on conflict do nothing;
  elsif v_req in ('HR','Finance','VenueManager') then
    insert into public.staff (profile_id, department, designation)
    values (v_uid, p_department, coalesce(p_designation, p_role)) on conflict do nothing;
  end if;

  return v_uid;
end;
$$;
grant execute on function public.admin_create_user(text, text, text, text, text, text) to authenticated;

-- ---------- 17) DOCUMENTS BUCKET (certifications, medical certificates) ----------
insert into storage.buckets (id, name, public)
values ('documents', 'documents', true)
on conflict (id) do nothing;

drop policy if exists "documents read" on storage.objects;
create policy "documents read" on storage.objects for select
  using (bucket_id = 'documents');
drop policy if exists "documents auth insert" on storage.objects;
create policy "documents auth insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'documents');
drop policy if exists "documents auth update" on storage.objects;
create policy "documents auth update" on storage.objects for update to authenticated
  using (bucket_id = 'documents');
drop policy if exists "documents admin delete" on storage.objects;
create policy "documents admin delete" on storage.objects for delete to authenticated
  using (bucket_id = 'documents' and public.is_admin());

-- HR manages coach records too (tester: "cant assign teams to the coaches")
drop policy if exists "coaches write" on public.coaches;
create policy "coaches write" on public.coaches for all
  using (public.is_admin() or public.current_role() = 'HR')
  with check (public.is_admin() or public.current_role() = 'HR');
