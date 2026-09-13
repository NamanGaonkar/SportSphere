-- ============================================================
-- SportSphere — organization data (realistic, no demo placeholders)
-- Populates every module so all six roles see a working system.
-- Safe to run once on a clean database.
-- ============================================================

-- ---------- Roster profiles (no login yet; linked staff/roles stay) ----------
insert into public.profiles (full_name, role) values
  ('Aarav Mehta','Athlete'), ('Ishita Sharma','Athlete'), ('Kabir Nair','Athlete'),
  ('Meera Iyer','Athlete'), ('Rohan Gupta','Athlete'), ('Ananya Rao','Athlete'),
  ('Vikram Singh','Athlete'), ('Sara Thomas','Athlete'), ('Aditya Joshi','Athlete'),
  ('Nisha Pillai','Athlete'), ('Karan Malhotra','Athlete'), ('Divya Menon','Athlete'),
  ('Farhan Khan','Athlete'), ('Priya Deshmukh','Athlete'),
  ('Rahul Verma','Coach'), ('Sunita Bose','Coach'), ('Imran Qureshi','Coach'),
  ('Deepak Rane','HR'), ('Kavita Krishnan','Finance'), ('Mahesh Patil','VenueManager');

-- ---------- Coaches (link 3 coach profiles) ----------
insert into public.coaches (profile_id, specialization)
select id, 'Football' from public.profiles where full_name = 'Rahul Verma';
insert into public.coaches (profile_id, specialization)
select id, 'Athletics' from public.profiles where full_name = 'Sunita Bose';
insert into public.coaches (profile_id, specialization)
select id, 'Basketball' from public.profiles where full_name = 'Imran Qureshi';

-- ---------- HR / Finance staff rows ----------
insert into public.staff (profile_id, department, designation)
select id, 'Human Resources', 'HR Manager' from public.profiles where full_name = 'Deepak Rane';
insert into public.staff (profile_id, department, designation)
select id, 'Finance', 'Finance Lead' from public.profiles where full_name = 'Kavita Krishnan';

-- ---------- Teams ----------
insert into public.teams (name, sport, coach_id)
select 'Falcons U-18', 'Football', c.id from public.coaches c
  join public.profiles p on p.id = c.profile_id where p.full_name = 'Rahul Verma';
insert into public.teams (name, sport, coach_id)
select 'Track Titans', 'Athletics', c.id from public.coaches c
  join public.profiles p on p.id = c.profile_id where p.full_name = 'Sunita Bose';
insert into public.teams (name, sport, coach_id)
select 'Court Kings', 'Basketball', c.id from public.coaches c
  join public.profiles p on p.id = c.profile_id where p.full_name = 'Imran Qureshi';
insert into public.teams (name, sport, coach_id)
select 'Falcons U-16', 'Football', c.id from public.coaches c
  join public.profiles p on p.id = c.profile_id where p.full_name = 'Rahul Verma';

-- ---------- Athletes ----------
insert into public.athletes (profile_id, dob, sport, team_id)
select p.id, '2008-04-12', 'Football', t.id from public.profiles p, public.teams t
  where p.full_name = 'Aarav Mehta' and t.name = 'Falcons U-18';
insert into public.athletes (profile_id, dob, sport, team_id)
select p.id, '2008-09-30', 'Football', t.id from public.profiles p, public.teams t
  where p.full_name = 'Ishita Sharma' and t.name = 'Falcons U-18';
insert into public.athletes (profile_id, dob, sport, team_id)
select p.id, '2009-01-22', 'Football', t.id from public.profiles p, public.teams t
  where p.full_name = 'Kabir Nair' and t.name = 'Falcons U-16';
insert into public.athletes (profile_id, dob, sport, team_id)
select p.id, '2007-11-05', 'Athletics', t.id from public.profiles p, public.teams t
  where p.full_name = 'Meera Iyer' and t.name = 'Track Titans';
insert into public.athletes (profile_id, dob, sport, team_id)
select p.id, '2008-06-18', 'Athletics', t.id from public.profiles p, public.teams t
  where p.full_name = 'Rohan Gupta' and t.name = 'Track Titans';
insert into public.athletes (profile_id, dob, sport, team_id)
select p.id, '2008-02-14', 'Athletics', t.id from public.profiles p, public.teams t
  where p.full_name = 'Ananya Rao' and t.name = 'Track Titans';
insert into public.athletes (profile_id, dob, sport, team_id)
select p.id, '2007-08-25', 'Basketball', t.id from public.profiles p, public.teams t
  where p.full_name = 'Vikram Singh' and t.name = 'Court Kings';
insert into public.athletes (profile_id, dob, sport, team_id)
select p.id, '2008-12-01', 'Basketball', t.id from public.profiles p, public.teams t
  where p.full_name = 'Sara Thomas' and t.name = 'Court Kings';
insert into public.athletes (profile_id, dob, sport, team_id)
select p.id, '2009-03-17', 'Basketball', t.id from public.profiles p, public.teams t
  where p.full_name = 'Aditya Joshi' and t.name = 'Court Kings';
insert into public.athletes (profile_id, dob, sport)
select p.id, '2009-07-09', 'Football' from public.profiles p where p.full_name = 'Nisha Pillai';
insert into public.athletes (profile_id, dob, sport)
select p.id, '2008-10-28', 'Athletics' from public.profiles p where p.full_name = 'Karan Malhotra';
insert into public.athletes (profile_id, dob, sport)
select p.id, '2007-05-16', 'Basketball' from public.profiles p where p.full_name = 'Divya Menon';
insert into public.athletes (profile_id, dob, sport)
select p.id, '2009-02-02', 'Football' from public.profiles p where p.full_name = 'Farhan Khan';
insert into public.athletes (profile_id, dob, sport)
select p.id, '2008-08-08', 'Athletics' from public.profiles p where p.full_name = 'Priya Deshmukh';

-- ---------- Venues ----------
insert into public.venues (name, location, capacity, status) values
  ('Central Stadium', 'City Center', 12000, 'Active'),
  ('North Ground', 'North Campus', 3500, 'Active'),
  ('Indoor Arena', 'Sports Complex', 2200, 'Maintenance'),
  ('Hilltop Turf', 'Hill Road', 1800, 'Active');

insert into public.venue_bookings (venue_id, start_time, end_time, purpose)
select id, now() + interval '2 day 10 hour', now() + interval '2 day 12 hour', 'Falcons U-18 practice'
  from public.venues where name = 'Central Stadium';
insert into public.venue_bookings (venue_id, start_time, end_time, purpose)
select id, now() + interval '3 day 16 hour', now() + interval '3 day 18 hour', 'Track Titans sprint drills'
  from public.venues where name = 'North Ground';
insert into public.venue_bookings (venue_id, start_time, end_time, purpose)
select id, now() + interval '5 day 9 hour', now() + interval '5 day 11 hour', 'Court Kings friendly'
  from public.venues where name = 'Indoor Arena';

-- ---------- Tournaments ----------
insert into public.tournaments (name, level, start_date, end_date, venue_id) values
  ('Inter-School Cup', 'School', current_date - 10, current_date + 5,
    (select id from public.venues where name = 'Central Stadium')),
  ('District Championship', 'District', current_date + 12, current_date + 18,
    (select id from public.venues where name = 'North Ground')),
  ('State League', 'State', current_date + 30, current_date + 40,
    (select id from public.venues where name = 'Central Stadium')),
  ('National Meet', 'National', current_date + 60, current_date + 65,
    (select id from public.venues where name = 'Indoor Arena'));

-- ---------- Matches ----------
insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status, score_a, score_b, result)
select t.id, fa.id, fb.id, now() - interval '3 day', 'Completed', 3, 1,
       'Falcons U-18 3 - 1 Court Kings'
  from public.tournaments t, public.teams fa, public.teams fb
  where t.name = 'Inter-School Cup' and fa.name = 'Falcons U-18' and fb.name = 'Court Kings';

insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status, score_a, score_b, result)
select t.id, ta.id, tr.id, now() - interval '1 day', 'Completed', 2, 2,
       'Track Titans 2 - 2 Falcons U-16'
  from public.tournaments t, public.teams ta, public.teams tr
  where t.name = 'Inter-School Cup' and ta.name = 'Track Titans' and tr.name = 'Falcons U-16';

insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status, score_a, score_b)
select t.id, ck.id, fu16.id, now() + interval '2 hours', 'Live', 1, 0
  from public.tournaments t, public.teams ck, public.teams fu16
  where t.name = 'Inter-School Cup' and ck.name = 'Court Kings' and fu16.name = 'Falcons U-16';

insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status, score_a, score_b)
select t.id, fu18.id, ck.id, now() + interval '4 day', 'Scheduled', 0, 0
  from public.tournaments t, public.teams fu18, public.teams ck
  where t.name = 'District Championship' and fu18.name = 'Falcons U-18' and ck.name = 'Court Kings';

insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status, score_a, score_b)
select t.id, tr.id, fu18.id, now() + interval '8 day', 'Scheduled', 0, 0
  from public.tournaments t, public.teams tr, public.teams fu18
  where t.name = 'District Championship' and tr.name = 'Track Titans' and fu18.name = 'Falcons U-18';

insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status, score_a, score_b)
select t.id, fu16.id, tr.id, now() + interval '14 day', 'Scheduled', 0, 0
  from public.tournaments t, public.teams fu16, public.teams tr
  where t.name = 'State League' and fu16.name = 'Falcons U-16' and tr.name = 'Track Titans';

-- ---------- Attendance: last 10 days for every athlete ----------
insert into public.attendance (profile_id, date, status)
select a.profile_id,
       d::date,
       case
         when abs(hashtext(a.id::text) + extract(day from d)::int) % 11 = 0 then 'Absent'::attendance_status
         when abs(hashtext(a.id::text) + extract(day from d)::int) % 13 = 0 then 'Late'::attendance_status
         when abs(hashtext(a.id::text) + extract(day from d)::int) % 17 = 0 then 'Leave'::attendance_status
         else 'Present'::attendance_status
       end
  from public.athletes a,
       generate_series(current_date - 9, current_date, interval '1 day') as d
on conflict (profile_id, date) do nothing;

-- ---------- Payroll for staff ----------
insert into public.payroll (staff_id, month, gross, deductions)
select s.id, date_trunc('month', current_date - interval '1 month'), 65000, 8200
  from public.staff s join public.profiles p on p.id = s.profile_id where p.full_name = 'Deepak Rane';
insert into public.payroll (staff_id, month, gross, deductions)
select s.id, date_trunc('month', current_date - interval '1 month'), 72000, 9100
  from public.staff s join public.profiles p on p.id = s.profile_id where p.full_name = 'Kavita Krishnan';

-- ---------- Inventory ----------
insert into public.inventory_items (name, category, quantity, condition) values
  ('Football - size 5', 'Equipment', 24, 'Good'),
  ('Training bibs', 'Kits', 40, 'Good'),
  ('Cones set', 'Training', 18, 'Good'),
  ('Basketball - size 7', 'Equipment', 9, 'Good'),
  ('Goalkeeper gloves', 'Kits', 6, 'Worn'),
  ('Sprint blocks', 'Training', 4, 'Good'),
  ('First-aid kits', 'Medical', 12, 'Good'),
  ('Stopwatches', 'Training', 8, 'Good');

-- ---------- Vendors & purchase orders ----------
insert into public.vendors (name, contact, category) values
  ('SportLine Distributors', '+91 98200 11223', 'Equipment'),
  ('MediPro Supplies', '+91 98200 44556', 'Medical'),
  ('GroundWorks Co.', '+91 98200 77889', 'Maintenance');

insert into public.purchase_orders (vendor_id, items, total, status)
select v.id, '[{"name":"Football - size 5","qty":10,"price":1200}]'::jsonb, 12000, 'Ordered'
  from public.vendors v where v.name = 'SportLine Distributors';
insert into public.purchase_orders (vendor_id, items, total, status)
select v.id, '[{"name":"First-aid kits","qty":5,"price":850}]'::jsonb, 4250, 'Received'
  from public.vendors v where v.name = 'MediPro Supplies';
insert into public.purchase_orders (vendor_id, items, total, status)
select v.id, '[{"name":"Turf repair service","qty":1,"price":15000}]'::jsonb, 15000, 'Draft'
  from public.vendors v where v.name = 'GroundWorks Co.';

-- ---------- Housekeeping ----------
insert into public.housekeeping_tasks (area, task, assigned_to, scheduled_date, status) values
  ('Central Stadium - Changing Room', 'Floor cleaning', 'Ramesh', current_date, 'In Progress'),
  ('Central Stadium - Stands', 'Seating dust-off', 'Suresh', current_date + 1, 'Pending'),
  ('North Ground - Turf', 'Debris removal', 'Ganesh', current_date, 'Done'),
  ('Indoor Arena - Court', 'Court polishing', 'Ramesh', current_date + 2, 'Pending');

-- ---------- Training & camps ----------
insert into public.training_sessions (title, type, sport, coach_id, team_id, venue_id, start_time, end_time, notes)
select 'Evening drill work', 'Session', 'Football', c.id, t.id, v.id,
       now() + interval '1 day 17 hour', now() + interval '1 day 19 hour',
       'Set-piece practice and small-sided games'
  from public.coaches c, public.teams t, public.venues v
  where t.name = 'Falcons U-18' and v.name = 'Central Stadium'
    and c.profile_id = (select id from public.profiles where full_name = 'Rahul Verma');

insert into public.training_sessions (title, type, sport, coach_id, team_id, venue_id, start_time, end_time, notes)
select 'Sprint mechanics camp', 'Camp', 'Athletics', c.id, t.id, v.id,
       now() + interval '6 day 8 hour', now() + interval '8 day 12 hour',
       'Residential camp - blocks and acceleration work'
  from public.coaches c, public.teams t, public.venues v
  where t.name = 'Track Titans' and v.name = 'North Ground'
    and c.profile_id = (select id from public.profiles where full_name = 'Sunita Bose');

insert into public.training_sessions (title, type, sport, coach_id, team_id, venue_id, start_time, end_time)
select 'Scrimmage night', 'Session', 'Basketball', c.id, t.id, v.id,
       now() + interval '2 day 18 hour', now() + interval '2 day 20 hour'
  from public.coaches c, public.teams t, public.venues v
  where t.name = 'Court Kings' and v.name = 'Indoor Arena'
    and c.profile_id = (select id from public.profiles where full_name = 'Imran Qureshi');

-- ---------- Performance ----------
insert into public.performance_records (athlete_id, date, metric, value, notes)
select a.id, current_date - 5, '100m sprint', '11.8s', 'Personal best'
  from public.athletes a join public.profiles p on p.id = a.profile_id where p.full_name = 'Meera Iyer';
insert into public.performance_records (athlete_id, date, metric, value, notes)
select a.id, current_date - 3, 'Beep test', 'Level 12', 'Excellent endurance'
  from public.athletes a join public.profiles p on p.id = a.profile_id where p.full_name = 'Aarav Mehta';
insert into public.performance_records (athlete_id, date, metric, value, notes)
select a.id, current_date - 2, 'Vertical jump', '72cm', 'Team high'
  from public.athletes a join public.profiles p on p.id = a.profile_id where p.full_name = 'Vikram Singh';
insert into public.performance_records (athlete_id, date, metric, value)
select a.id, current_date - 1, '5km run', '19:40'
  from public.athletes a join public.profiles p on p.id = a.profile_id where p.full_name = 'Rohan Gupta';

-- ---------- Medical ----------
insert into public.medical_records (athlete_id, date, type, details, cleared)
select a.id, current_date - 7, 'Checkup', 'Full physical. All parameters normal.', true
  from public.athletes a join public.profiles p on p.id = a.profile_id where p.full_name = 'Ishita Sharma';
insert into public.medical_records (athlete_id, date, type, details, cleared)
select a.id, current_date - 4, 'Injury', 'Grade 1 hamstring strain. Rehab plan issued.', false
  from public.athletes a join public.profiles p on p.id = a.profile_id where p.full_name = 'Sara Thomas';
insert into public.medical_records (athlete_id, date, type, details, cleared)
select a.id, current_date - 1, 'Clearance', 'Cleared for full-contact training.', true
  from public.athletes a join public.profiles p on p.id = a.profile_id where p.full_name = 'Vikram Singh';

-- ---------- Awards ----------
insert into public.awards (athlete_id, title, date, level)
select a.id, 'Golden Boot - Inter-School Cup', current_date - 6, 'School'
  from public.athletes a join public.profiles p on p.id = a.profile_id where p.full_name = 'Aarav Mehta';
insert into public.awards (athlete_id, title, date, level)
select a.id, 'Best Sprinter - District Meet', current_date - 20, 'District'
  from public.athletes a join public.profiles p on p.id = a.profile_id where p.full_name = 'Meera Iyer';
insert into public.awards (athlete_id, title, date, level)
select a.id, 'MVP - City League', current_date - 35, 'State'
  from public.athletes a join public.profiles p on p.id = a.profile_id where p.full_name = 'Vikram Singh';

-- ---------- Events ----------
insert into public.events (title, type, date, venue_id, description)
select 'Annual Sports Day', 'Ceremony', current_date + 9, v.id, 'Opening ceremony, races and prize distribution'
  from public.venues v where v.name = 'Central Stadium';
insert into public.events (title, type, date, venue_id, description)
select 'Coaching Workshop', 'Workshop', current_date + 6, v.id, 'Certification workshop for coaching staff'
  from public.venues v where v.name = 'North Ground';

-- ---------- Transport & accommodation ----------
insert into public.transport (purpose, vehicle, driver, depart_at, return_at, team_id, status)
select 'District Championship travel', 'Bus KA-01-F-2233', 'Manoj', now() + interval '4 day 7 hour',
       now() + interval '4 day 21 hour', t.id, 'Planned'
  from public.teams t where t.name = 'Falcons U-18';
insert into public.transport (purpose, vehicle, driver, depart_at, return_at, team_id, status)
select 'State League away fixture', 'Minivan KA-05-M-9081', 'Prakash', now() + interval '13 day 6 hour',
       now() + interval '14 day 20 hour', t.id, 'Planned'
  from public.teams t where t.name = 'Falcons U-16';

insert into public.accommodation (hotel, location, check_in, check_out, team_id, rooms, status)
select 'Hotel Grand Central', 'City Center', current_date + 4, current_date + 6, t.id, 6, 'Booked'
  from public.teams t where t.name = 'Falcons U-18';

-- ---------- Expenses ----------
insert into public.expenses (category, amount, date, description, approved_by) values
  ('Equipment', 42500, current_date - 2, 'New footballs and training cones', 'Kavita Krishnan'),
  ('Travel', 18500, current_date - 5, 'Bus hire for district fixture', 'Kavita Krishnan'),
  ('Venue', 30000, current_date - 8, 'Indoor Arena monthly upkeep', 'Deepak Rane'),
  ('Salaries', 137000, current_date - 9, 'Coaching staff payroll', 'Kavita Krishnan'),
  ('Other', 6200, current_date - 1, 'Team physio supplies', 'Deepak Rane');

-- ---------- School activities ----------
insert into public.school_activities (title, school, date, participants, description) values
  ('Morning fitness drive', 'Green Valley School', current_date + 2, 120,
   'Mass warm-up and fitness screening for grades 6 to 9'),
  ('Mini football festival', 'Hillview Public School', current_date + 8, 80,
   'Under-12 round-robin festival'),
  ('Athletics talent hunt', 'City Model School', current_date - 3, 65,
   'Sprint and jump trials for new admissions');

-- ---------- Notifications for the six login users ----------
insert into public.notifications (recipient_id, message, read)
select p.id, 'Welcome to SportSphere. Your account is ready.', false
  from public.profiles p
  where p.full_name in ('Admin SportSphere','Athlete One','Coach One','HR Manager','Finance Lead','Venue Manager');

insert into public.notifications (recipient_id, message, read)
select p.id, 'Court Kings vs Falcons U-16 is live now - follow the score.', false
  from public.profiles p
  where p.full_name in ('Admin SportSphere','Athlete One','Coach One');

insert into public.notifications (recipient_id, message, read)
select p.id, 'Payroll for last month has been processed.', true
  from public.profiles p
  where p.full_name in ('HR Manager','Finance Lead');

insert into public.notifications (recipient_id, message, read)
select p.id, 'Indoor Arena is under maintenance until Friday.', true
  from public.profiles p
  where p.full_name in ('Venue Manager','Admin SportSphere');
