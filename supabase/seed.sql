-- ============================================================
-- SportSphere — demo seed data
-- Run in Supabase SQL Editor AFTER schema.sql.
-- Creates demo users (password for all: Passw0rd!) + data.
-- Re-runnable: cleans previous seed rows first.
-- ============================================================

-- ---------- helper: create auth user (idempotent) ----------
create or replace function public._seed_user(p_email text, p_name text, p_role text)
returns uuid
language plpgsql
as $$
declare
  uid uuid;
begin
  select id into uid from auth.users where email = p_email;
  if uid is not null then
    return uid;
  end if;

  uid := gen_random_uuid();
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_user_meta_data, created_at, updated_at)
  values (uid, 'authenticated', 'authenticated', p_email,
          crypt('Passw0rd!', gen_salt('bf', 10)),
          now(),
          jsonb_build_object('full_name', p_name, 'role', p_role),
          now(), now())
  returning id into uid;

  insert into auth.identities (id, user_id, provider_id, identity_data, provider,
                               last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), uid, uid::text,
          jsonb_build_object('sub', uid::text, 'email', p_email, 'email_verified', true),
          'email', now(), now(), now());

  -- profile row is created by the on_auth_user_created trigger; fill contact
  update public.profiles set contact_info = p_email where id = uid;

  return uid;
end;
$$;

-- ---------- cleanup previous seed (re-runnable) ----------
delete from auth.users where email like '%@sportsphere.app';
delete from public.tournaments where name in ('Inter-School Championship','State Level Meet','District Football Cup');
delete from public.teams where name in ('Falcon Strikers','Tiger Smash','Thunder XI','Titans');
delete from public.venues where name in ('Main Stadium','Indoor Arena','Practice Ground');
delete from public.inventory_items where name in ('Footballs','Basketballs','Cricket Kits','Cones & Ladders');
delete from public.vendors where name in ('SportMart Pvt Ltd','ProGear Supplies');

-- ---------- main seed ----------
do $$
declare
  u_admin uuid; u_coach1 uuid; u_coach2 uuid;
  u_ath1 uuid; u_ath2 uuid; u_ath3 uuid; u_ath4 uuid; u_hr uuid;
  c1 uuid; c2 uuid;
  t_falcon uuid; t_tiger uuid; t_thunder uuid; t_titans uuid;
  v_main uuid; v_indoor uuid; v_practice uuid;
  tour1 uuid; tour2 uuid; tour3 uuid;
  a1 uuid; a2 uuid; a3 uuid; a4 uuid;
  st1 uuid;
  d date; st text;
  i int;
begin
  -- ---------- users ----------
  u_admin  := public._seed_user('admin@sportsphere.app',   'Jaya Sharma',    'Admin');
  u_coach1 := public._seed_user('coach@sportsphere.app',   'Rahul Verma',    'Coach');
  u_coach2 := public._seed_user('coach2@sportsphere.app',  'Priya Nair',     'Coach');
  u_ath1   := public._seed_user('athlete@sportsphere.app', 'Arjun Mehta',    'Athlete');
  u_ath2   := public._seed_user('athlete2@sportsphere.app','Sneha Kulkarni', 'Athlete');
  u_ath3   := public._seed_user('athlete3@sportsphere.app','Vikram Singh',   'Athlete');
  u_ath4   := public._seed_user('athlete4@sportsphere.app','Ananya Rao',     'Athlete');
  u_hr     := public._seed_user('hr@sportsphere.app',      'Deepa Iyer',     'HR');

  -- ---------- coaches ----------
  insert into public.coaches (profile_id, specialization) values (u_coach1, 'Football / Cricket') returning id into c1;
  insert into public.coaches (profile_id, specialization) values (u_coach2, 'Basketball / Athletics') returning id into c2;

  -- ---------- venues ----------
  insert into public.venues (name, location, capacity, status) values ('Main Stadium','MG Road, Bengaluru',5000,'Active') returning id into v_main;
  insert into public.venues (name, location, capacity, status) values ('Indoor Arena','HSR Layout, Bengaluru',1200,'Active') returning id into v_indoor;
  insert into public.venues (name, location, capacity, status) values ('Practice Ground','Whitefield, Bengaluru',300,'Maintenance') returning id into v_practice;

  -- ---------- teams ----------
  insert into public.teams (name, sport, coach_id) values ('Falcon Strikers','Football', c1) returning id into t_falcon;
  insert into public.teams (name, sport, coach_id) values ('Tiger Smash','Basketball', c2) returning id into t_tiger;
  insert into public.teams (name, sport, coach_id) values ('Thunder XI','Cricket', c1) returning id into t_thunder;
  insert into public.teams (name, sport, coach_id) values ('Titans','Athletics', c2) returning id into t_titans;

  -- ---------- athletes ----------
  insert into public.athletes (profile_id, dob, sport, team_id, medical_notes)
    values (u_ath1, '2008-03-14', 'Football', t_falcon, 'Mild asthma — inhaler in kit bag') returning id into a1;
  insert into public.athletes (profile_id, dob, sport, team_id, medical_notes)
    values (u_ath2, '2009-07-02', 'Basketball', t_tiger, null) returning id into a2;
  insert into public.athletes (profile_id, dob, sport, team_id, medical_notes)
    values (u_ath3, '2007-11-25', 'Cricket', t_thunder, null) returning id into a3;
  insert into public.athletes (profile_id, dob, sport, team_id, medical_notes)
    values (u_ath4, '2008-01-19', 'Athletics', t_titans, 'Recovering ankle sprain') returning id into a4;

  -- ---------- staff (HR) + payroll ----------
  insert into public.staff (profile_id, department, designation) values (u_hr, 'People Ops','HR Manager') returning id into st1;
  insert into public.payroll (staff_id, month, gross, deductions) values (st1, date_trunc('month', current_date - interval '1 month'), 85000, 9500);
  insert into public.payroll (staff_id, month, gross, deductions) values (st1, date_trunc('month', current_date), 85000, 9500);

  -- ---------- tournaments ----------
  insert into public.tournaments (name, level, start_date, end_date, venue_id)
    values ('Inter-School Championship','School', current_date - 10, current_date + 5, v_main) returning id into tour1;
  insert into public.tournaments (name, level, start_date, end_date, venue_id)
    values ('State Level Meet','State', current_date + 12, current_date + 15, v_indoor) returning id into tour2;
  insert into public.tournaments (name, level, start_date, end_date, venue_id)
    values ('District Football Cup','District', current_date - 30, current_date - 25, v_main) returning id into tour3;

  -- ---------- matches: mix of Completed / Live / Scheduled ----------
  insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status, score_a, score_b, result)
    values (tour3, t_falcon, t_tiger, now() - interval '28 days', 'Completed', 3, 1, 'Falcon Strikers won 3-1');
  insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status, score_a, score_b, result)
    values (tour3, t_falcon, t_thunder, now() - interval '26 days', 'Completed', 2, 2, 'Draw 2-2');
  insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status, score_a, score_b, result)
    values (tour1, t_falcon, t_titans, now() - interval '2 days', 'Completed', 4, 0, 'Falcon Strikers won 4-0');
  insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status, score_a, score_b)
    values (tour1, t_tiger, t_thunder, now(), 'Live', 1, 0);
  insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status)
    values (tour1, t_titans, t_tiger, now() + interval '2 days', 'Scheduled');
  insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status)
    values (tour2, t_titans, t_thunder, now() + interval '13 days', 'Scheduled');

  -- ---------- attendance: last 10 days per athlete (deterministic) ----------
  for i in 0..9 loop
    d := current_date - i;
    insert into public.attendance (profile_id, date, status, leave_reason)
    values (u_ath1, d,
            (case (extract(day from d)::int + 1) % 7
               when 2 then 'Late' when 5 then 'Absent' else 'Present' end)::attendance_status, null)
    on conflict (profile_id, date) do nothing;
    insert into public.attendance (profile_id, date, status, leave_reason)
    values (u_ath2, d,
            (case (extract(day from d)::int + 3) % 7
               when 2 then 'Leave' when 4 then 'Late' else 'Present' end)::attendance_status,
            (case when (extract(day from d)::int + 3) % 7 = 2 then 'Family function' else null end))
    on conflict (profile_id, date) do nothing;
    insert into public.attendance (profile_id, date, status)
    values (u_ath3, d,
            (case (extract(day from d)::int + 5) % 7
               when 3 then 'Absent' else 'Present' end)::attendance_status)
    on conflict (profile_id, date) do nothing;
    insert into public.attendance (profile_id, date, status)
    values (u_ath4, d,
            (case (extract(day from d)::int + 6) % 7
               when 1 then 'Late' when 4 then 'Leave' else 'Present' end)::attendance_status)
    on conflict (profile_id, date) do nothing;
  end loop;

  -- ---------- awards ----------
  insert into public.awards (athlete_id, title, date, level) values (a1, 'Top Scorer — District Football Cup', current_date - 24, 'District');
  insert into public.awards (athlete_id, title, date, level) values (a1, 'Best Player — Inter-School', current_date - 2, 'School');
  insert into public.awards (athlete_id, title, date, level) values (a2, 'MVP — State Basketball', current_date - 60, 'State');

  -- ---------- inventory / vendors ----------
  insert into public.inventory_items (name, category, quantity, condition) values
    ('Footballs','Equipment',24,'Good'),
    ('Basketballs','Equipment',15,'Good'),
    ('Cricket Kits','Kits',10,'Worn'),
    ('Cones & Ladders','Training',40,'Good');
  insert into public.vendors (name, contact, category) values
    ('SportMart Pvt Ltd','sales@sportmart.example','Equipment'),
    ('ProGear Supplies','orders@progear.example','Kits');

  -- ---------- notifications ----------
  insert into public.notifications (recipient_id, message, read) values
    (u_ath1, 'Your match vs Titans kicks off at 5 PM today. Report by 4 PM.', false),
    (u_ath1, 'Attendance marked Present for today.', true),
    (u_ath1, 'New award added: Best Player — Inter-School.', false),
    (u_coach1, 'Live match: Tiger Smash vs Thunder XI is in progress.', false),
    (u_admin, 'Weekly report is ready: 94% attendance across teams.', false);
end;
$$;

drop function public._seed_user(text, text, text);
