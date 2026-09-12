-- ============================================================
-- SportSphere — demo rows for the Phase 2/3 module tables
-- Run AFTER modules.sql. References seed data by name.
-- ============================================================

delete from public.purchase_orders where vendor_id is not null;
delete from public.housekeeping_tasks where area like '%Stadium%' or area like '%Arena%' or area like '%Ground%';
delete from public.training_sessions where title like '%Camp%' or title like '%Drill%' or title like '%Practice%';
delete from public.performance_records where metric in ('100m Sprint (s)','Beep Test (level)','Vertical Jump (cm)');
delete from public.medical_records where details like '%Ankle%';
delete from public.events where title in ('Annual Awards Night','Coaching Workshop');
delete from public.transport where purpose like '%State Meet%' or purpose like '%District Cup%';
delete from public.accommodation where hotel in ('Grand Sports Inn','Arena Residency');
delete from public.expenses where category in ('Equipment','Travel','Salaries');
delete from public.school_activities where title like '%Sports Day%' or title like '%Mini Meet%';

-- Purchase orders
insert into public.purchase_orders (vendor_id, items, total, status)
select id, '[{"name":"Match footballs","qty":10,"price":1500},{"name":"Training bibs","qty":20,"price":250}]'::jsonb, 20000, 'Ordered'
from public.vendors where name = 'SportMart Pvt Ltd';

insert into public.purchase_orders (vendor_id, items, total, status)
select id, '[{"name":"Cricket kit bags","qty":6,"price":3200}]'::jsonb, 19200, 'Received'
from public.vendors where name = 'ProGear Supplies';

-- Housekeeping
insert into public.housekeeping_tasks (area, task, assigned_to, scheduled_date, status) values
  ('Main Stadium - Changing Rooms','Floor cleaning + sanitization','Ramesh H.', current_date, 'Done'),
  ('Main Stadium - Turf','Debris removal','Grounds crew', current_date + 1, 'In Progress'),
  ('Indoor Arena - Courts','Court mopping','Suresh P.', current_date + 1, 'Pending'),
  ('Practice Ground - Nets','Net inspection & repair','Grounds crew', current_date + 2, 'Pending');

-- Training sessions & camps
insert into public.training_sessions (title, type, sport, coach_id, team_id, venue_id, start_time, end_time, notes)
select 'Pre-State Meet Training Camp','Camp','Athletics', c.id, t.id, v.id,
       now() + interval '3 days', now() + interval '5 days',
       'Residential camp for Titans before State Level Meet'
from public.coaches c, public.teams t, public.venues v
where c.specialization like '%Athletics%' and t.name = 'Titans' and v.name = 'Indoor Arena';

insert into public.training_sessions (title, type, sport, coach_id, team_id, venue_id, start_time, end_time, notes)
select 'Passing Drills & Set Pieces','Session','Football', c.id, t.id, v.id,
       now() + interval '1 day', now() + interval '1 day 2 hours',
       'Focus on corners and free kicks'
from public.coaches c, public.teams t, public.venues v
where c.specialization like '%Football%' and t.name = 'Falcon Strikers' and v.name = 'Main Stadium';

insert into public.training_sessions (title, type, sport, coach_id, team_id, venue_id, start_time, end_time, notes)
select 'Shooting Practice','Session','Basketball', c.id, t.id, v.id,
       now() + interval '2 days', now() + interval '2 days 2 hours', null
from public.coaches c, public.teams t, public.venues v
where c.specialization like '%Basketball%' and t.name = 'Tiger Smash' and v.name = 'Indoor Arena';

-- Performance records
insert into public.performance_records (athlete_id, date, metric, value, notes)
select a.id, current_date - 5, '100m Sprint (s)', '12.4', 'Personal best'
from public.athletes a where a.sport = 'Athletics';
insert into public.performance_records (athlete_id, date, metric, value, notes)
select a.id, current_date - 5, 'Beep Test (level)', '11.2', null
from public.athletes a where a.sport = 'Football';
insert into public.performance_records (athlete_id, date, metric, value, notes)
select a.id, current_date - 3, 'Vertical Jump (cm)', '58', 'Improving'
from public.athletes a where a.sport = 'Basketball';

-- Medical records
insert into public.medical_records (athlete_id, date, type, details, cleared)
select a.id, current_date - 20, 'Injury', 'Ankle sprain during practice — RICE protocol, rest 2 weeks', false
from public.athletes a where a.sport = 'Athletics';
insert into public.medical_records (athlete_id, date, type, details, cleared)
select a.id, current_date - 60, 'Checkup', 'Annual fitness checkup — all parameters normal', true
from public.athletes a where a.sport = 'Football';

-- Events
insert into public.events (title, type, date, venue_id, description) values
  ('Annual Awards Night','Ceremony', current_date + 20, (select id from public.venues where name='Main Stadium'),
   'Yearly awards distribution for athletes and coaches'),
  ('Coaching Workshop','Workshop', current_date + 9, (select id from public.venues where name='Indoor Arena'),
   'Certification workshop for assistant coaches');

-- Transport
insert into public.transport (purpose, vehicle, driver, depart_at, return_at, team_id, status)
select 'Team bus to State Level Meet','Bus KA-01-F-4521','Mahesh K.',
       now() + interval '12 days', now() + interval '16 days', t.id, 'Planned'
from public.teams t where t.name = 'Titans';
insert into public.transport (purpose, vehicle, driver, depart_at, return_at, team_id, status)
select 'Travel to District Cup','Minibus KA-05-M-1102','Ravi S.',
       now() - interval '30 days', now() - interval '25 days', t.id, 'Completed'
from public.teams t where t.name = 'Falcon Strikers';

-- Accommodation
insert into public.accommodation (hotel, location, check_in, check_out, team_id, rooms, status)
select 'Grand Sports Inn','Mysore Road, Bengaluru', current_date + 12, current_date + 16, t.id, 6, 'Booked'
from public.teams t where t.name = 'Titans';
insert into public.accommodation (hotel, location, check_in, check_out, team_id, rooms, status)
select 'Arena Residency','City Centre', current_date - 30, current_date - 25, t.id, 4, 'Completed'
from public.teams t where t.name = 'Falcon Strikers';

-- Expenses
insert into public.expenses (category, amount, date, description, approved_by) values
  ('Equipment', 20000, current_date - 12, 'Footballs and training bibs (PO #1)', 'Jaya Sharma'),
  ('Travel', 14500, current_date - 25, 'District Cup team transport + fuel', 'Jaya Sharma'),
  ('Salaries', 85000, current_date - 1, 'HR Manager monthly salary', 'Finance'),
  ('Other', 3200, current_date - 4, 'Turf maintenance supplies', 'Jaya Sharma');

-- School sports activities
insert into public.school_activities (title, school, date, participants, description) values
  ('Annual Sports Day','Greenfield Public School', current_date + 6, 320,
   'Track events, relay and exhibition matches for grades 6-12'),
  ('Mini Football Meet','St. Joseph''s High School', current_date - 15, 120,
   'Inter-house football tournament, Falcon Strikers coached the finalists');
