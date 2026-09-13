-- ============================================================
-- SportSphere — full organization seed (idempotent-ish)
-- Every module gets realistic data; the six login users are wired in
-- (Athlete One has records, Coach One coaches teams, etc.)
-- ============================================================

-- ---------- TEAMS (12 across sports, coached) ----------
insert into public.teams (name, sport_id, coach_id)
select v.name, s.id, c.id
from (values
  ('Senior Football XI','Football'),
  ('Junior Football XI','Football'),
  ('Cricket Red Wolves','Cricket'),
  ('Cricket U-16','Cricket'),
  ('Basketball Varsity','Basketball'),
  ('Athletics Sprint Squad','Athletics/Track & Field'),
  ('Badminton A','Badminton'),
  ('Table Tennis A','Table Tennis'),
  ('Hockey XI','Hockey'),
  ('Volleyball A','Volleyball'),
  ('Swimming Squad','Swimming'),
  ('Kabaddi Matadors','Kabaddi')
) as v(name, sport)
join public.sports s on s.name = v.sport
left join lateral (
  select c.id from public.coaches c
  join public.profiles p on p.id = c.profile_id
  order by (p.full_name = 'Coach One') desc, c.created_at
  limit 1
) c on true
where not exists (select 1 from public.teams t where t.name = v.name);

-- ---------- ATHLETES: assign remaining unassigned to teams + multi-sport ----------
with ranked as (
  select a.id as aid, t.id as tid,
         row_number() over (partition by t.id order by a.id) rn
  from public.athletes a
  cross join lateral (select id from public.teams order by hashtext(a.id::text || id::text)) t
  where a.team_id is null
)
update public.athletes aa
set team_id = ranked.tid
from ranked
where aa.id = ranked.aid and ranked.rn <= 6;

-- every athlete tagged to at least one sport
insert into public.athlete_sports (athlete_id, sport_id)
select a.id, s.id
from public.athletes a
left join lateral (
  select s.id from public.sports s
  where not exists (select 1 from public.athlete_sports x where x.athlete_id = a.id and x.sport_id = s.id)
  order by hashtext(a.id::text || s.id::text)
  limit 1
) s on true
where s.id is not null
on conflict (athlete_id, sport_id) do nothing;

-- second sport for a third of the roster (multi-sport)
insert into public.athlete_sports (athlete_id, sport_id)
select a.id, s.id
from (
  select a.id, row_number() over (order by a.id) rn
  from public.athletes a
  where (select count(*) from public.athlete_sports x where x.athlete_id = a.id) = 1
) a
join public.sports s
  on s.id = (select id from public.sports order by hashtext(a.id::text || id::text) limit 1)
where a.rn % 3 = 0
on conflict (athlete_id, sport_id) do nothing;

-- ---------- TOURNAMENTS (6, all levels) ----------
insert into public.tournaments (name, level, start_date, end_date, venue_id, sport_id)
select v.name, v.level::tournament_level, v.sd::date, v.ed::date, ve.id, s.id
from (values
  ('Inter-School Cup','School', current_date - 20, current_date - 12),
  ('District Championship','District', current_date - 5, current_date + 4),
  ('State League','State', current_date + 10, current_date + 24),
  ('National Meet','National', current_date + 40, current_date + 52),
  ('Monsoon Indoor Series','District', current_date + 2, current_date + 9),
  ('Foundation Day Trophy','School', current_date - 60, current_date - 58)
) as v(name, level, sd, ed)
left join lateral (select id from public.venues order by hashtext(v.name || id::text) limit 1) ve on true
left join lateral (select id from public.sports order by hashtext(v.name || id::text) limit 1) s on true
where not exists (select 1 from public.tournaments t where t.name = v.name);

-- ---------- MATCHES (14: finished, live, upcoming) ----------
insert into public.matches (tournament_id, team_a_id, team_b_id, scheduled_at, status, score_a, score_b, result)
select tou.id, a.id, b.id, v.whenx::timestamptz, v.st::match_status, v.sa, v.sb, v.res
from (values
  ('Inter-School Cup', 0, 1, current_date - 14, 'Completed', 3, 1, 'Team A won'),
  ('Inter-School Cup', 2, 3, current_date - 13, 'Completed', 2, 2, 'Draw'),
  ('Inter-School Cup', 4, 5, current_date - 12, 'Completed', 0, 4, 'Team B won'),
  ('Foundation Day Trophy', 6, 7, current_date - 59, 'Completed', 5, 3, 'Team A won'),
  ('Foundation Day Trophy', 8, 9, current_date - 58, 'Completed', 1, 0, 'Team A won'),
  ('District Championship', 10, 11, now() - interval '2 hours', 'Completed', 68, 61, 'Team A won'),
  ('District Championship', 0, 2, now() - interval '20 minutes', 'Live', 1, 1, null),
  ('District Championship', 3, 5, now() + interval '40 minutes', 'Live', 0, 0, null),
  ('District Championship', 6, 8, current_date + 1, 'Scheduled', 0, 0, null),
  ('District Championship', 9, 1, current_date + 2, 'Scheduled', 0, 0, null),
  ('Monsoon Indoor Series', 4, 7, current_date + 3, 'Scheduled', 0, 0, null),
  ('Monsoon Indoor Series', 10, 2, current_date + 4, 'Scheduled', 0, 0, null),
  ('State League', 5, 11, current_date + 12, 'Scheduled', 0, 0, null),
  ('National Meet', 8, 0, current_date + 42, 'Scheduled', 0, 0, null)
) as v(tour, ai, bi, whenx, st, sa, sb, res)
join public.tournaments tou on tou.name = v.tour
join lateral (select id from public.teams order by created_at offset v.ai limit 1) a on true
join lateral (select id from public.teams order by created_at offset v.bi limit 1) b on true
where not exists (
  select 1 from public.matches m
  where m.tournament_id = tou.id and m.scheduled_at = v.whenx::timestamptz
);

-- ---------- VENUES + BOOKINGS ----------
insert into public.venues (name, location, capacity, status)
select v.name, v.loc, v.cap, v.st
from (values
  ('Main Stadium','North Campus', 5000, 'Active'),
  ('Indoor Arena','East Campus', 1200, 'Active'),
  ('Aquatic Center','West Campus', 800, 'Active'),
  ('Practice Ground B','North Campus', 400, 'Maintenance'),
  ('Multi-purpose Hall','Central Block', 600, 'Active')
) as v(name, loc, cap, st)
where not exists (select 1 from public.venues ve where ve.name = v.name);

insert into public.venue_bookings (venue_id, booked_by, start_time, end_time, purpose)
select ve.id, p.id, v.st::timestamptz, v.st::timestamptz + interval '2 hours', v.pur
from (values
  ('Main Stadium', current_date + 1, 'Football practice'),
  ('Indoor Arena', current_date + 1, 'Badminton drills'),
  ('Aquatic Center', current_date + 2, 'Swimming time trials'),
  ('Practice Ground B', current_date + 3, 'Cricket nets'),
  ('Multi-purpose Hall', current_date + 4, 'Table tennis camp'),
  ('Main Stadium', current_date + 5, 'Athletics trials'),
  ('Indoor Arena', current_date + 6, 'Volleyball friendly'),
  ('Multi-purpose Hall', current_date + 7, 'Kabaddi workshop')
) as v(vname, st, pur)
join public.venues ve on ve.name = v.vname
cross join lateral (select id from public.profiles where full_name = 'Coach One') p
where not exists (
  select 1 from public.venue_bookings b
  where b.venue_id = ve.id and b.start_time = v.st::timestamptz
);

-- ---------- ATTENDANCE: 30 days for every profile ----------
insert into public.attendance (profile_id, date, status, leave_reason)
select p.id, d::date, st::attendance_status, case when st = 'Leave' then 'Personal / family commitment' else null end
from public.profiles p,
     generate_series(current_date - 29, current_date, interval '1 day') d,
     lateral (
       select case
         when extract(dow from d) in (0) then 'Leave'
         when abs(hashtext(p.id::text || d::text)) % 13 = 0 then 'Absent'
         when abs(hashtext(p.id::text || d::text)) % 9 = 0 then 'Late'
         when abs(hashtext(p.id::text || d::text)) % 15 = 0 then 'Leave'
         else 'Present'
       end as st
     ) x
on conflict (profile_id, date) do nothing;

-- ---------- STAFF + 6 MONTHS PAYROLL ----------
insert into public.staff (profile_id, department, designation)
select p.id, v.dep, v.des
from (values
  ('HR Manager','Human Resources','HR Manager'),
  ('Finance Lead','Finance','Finance Lead'),
  ('Venue Manager','Facilities','Venue Manager')
) as v(full_name, dep, des)
join public.profiles p on p.full_name = v.full_name
where not exists (select 1 from public.staff s where s.profile_id = p.id);

with gross as (
  select s.id,
         52000 + (abs(hashtext(s.id::text)) % 5) * 4000 as g
  from public.staff s
)
insert into public.payroll (staff_id, month, gross, deductions)
select g.id, m::date, g.g, 6200
from gross g,
     generate_series(date_trunc('month', current_date) - interval '5 months', date_trunc('month', current_date), interval '1 month') m
where not exists (
  select 1 from public.payroll px where px.staff_id = g.id and px.month = m::date
);

-- ---------- INVENTORY & EQUIPMENT (18 items, detailed) ----------
insert into public.inventory_items (name, category, quantity, condition, location, unit, min_stock, unit_cost, assigned_team_id)
select v.name, v.cat, v.qty, v.cond, v.loc, v.unit, v.minq, v.cost, t.id
from (values
  ('Football Size 5','Balls', 42, 'Good', 'Equipment Room A', 'pcs', 15, 1200, 'Senior Football XI'),
  ('Football Size 4','Balls', 8, 'Good', 'Equipment Room A', 'pcs', 12, 950, 'Junior Football XI'),
  ('Cricket Bat (Full size)','Bats', 18, 'Good', 'Equipment Room B', 'pcs', 8, 3400, 'Cricket Red Wolves'),
  ('Cricket Bat (Kashmir)','Bats', 5, 'Worn', 'Equipment Room B', 'pcs', 6, 1800, 'Cricket U-16'),
  ('Cricket Leather Ball','Balls', 60, 'Good', 'Equipment Room B', 'pcs', 24, 850, 'Cricket Red Wolves'),
  ('Basketball Indoor','Balls', 22, 'Good', 'Indoor Arena Store', 'pcs', 10, 1500, 'Basketball Varsity'),
  ('Badminton Racket','Rackets', 30, 'Good', 'Indoor Arena Store', 'pcs', 12, 2100, 'Badminton A'),
  ('Badminton Shuttle (Tube)','Consumables', 14, 'Good', 'Indoor Arena Store', 'tube', 10, 1100, 'Badminton A'),
  ('Table Tennis Racket','Rackets', 16, 'Good', 'Multi-purpose Hall Store', 'pcs', 8, 1300, 'Table Tennis A'),
  ('TT Balls (Pack of 6)','Consumables', 9, 'Good', 'Multi-purpose Hall Store', 'pack', 10, 450, 'Table Tennis A'),
  ('Hockey Stick','Sticks', 20, 'Good', 'Equipment Room A', 'pcs', 10, 2600, 'Hockey XI'),
  ('Volleyball','Balls', 12, 'Good', 'Equipment Room A', 'pcs', 8, 1400, 'Volleyball A'),
  ('Swim Kickboard','Training Aids', 25, 'Good', 'Aquatic Center Store', 'pcs', 10, 600, 'Swimming Squad'),
  ('Swim Lane Rope','Pool Equipment', 8, 'Worn', 'Aquatic Center Store', 'pcs', 4, 3200, 'Swimming Squad'),
  ('Kabaddi Mat','Mats', 6, 'Good', 'Multi-purpose Hall Store', 'pcs', 3, 15000, 'Kabaddi Matadors'),
  ('Starting Blocks','Track Equipment', 4, 'Good', 'Track Store', 'pcs', 4, 8000, 'Athletics Sprint Squad'),
  ('Stopwatch Digital','Timing', 10, 'Good', 'Track Store', 'pcs', 5, 900, null),
  ('First Aid Kit (Full)','Medical', 7, 'Good', 'Infirmary', 'kit', 5, 1800, null)
) as v(name, cat, qty, cond, loc, unit, minq, cost, team)
left join public.teams t on t.name = v.team
where not exists (select 1 from public.inventory_items i where i.name = v.name);

-- ---------- STOCK TRANSACTIONS (history for several items) ----------
insert into public.stock_transactions (item_id, tx_type, quantity, note, created_by)
select i.id, v.ty, v.q, v.note, p.id
from (values
  ('Football Size 5','IN', 20, 'Season restock'),
  ('Football Size 5','OUT', 6, 'Issued to Senior squad'),
  ('Cricket Leather Ball','IN', 24, 'Tournament supply'),
  ('Cricket Leather Ball','OUT', 12, 'District Championship'),
  ('Badminton Shuttle (Tube)','OUT', 6, 'Weekly training'),
  ('TT Balls (Pack of 6)','OUT', 3, 'Camp consumption'),
  ('Hockey Stick','IN', 10, 'New order received'),
  ('Swim Lane Rope','MAINTENANCE', 2, 'Sent for repair')
) as v(iname, ty, q, note)
join public.inventory_items i on i.name = v.iname
cross join lateral (select id from public.profiles where full_name = 'Admin SportSphere') p
where not exists (select 1 from public.stock_transactions st where st.item_id = i.id and st.note = v.note);

-- ---------- VENDORS (6) ----------
insert into public.vendors (name, contact, category)
select v.name, v.contact, v.cat
from (values
  ('Sportiva Wholesale','+91 98220 11223','Equipment'),
  ('Prime Athletic Gear','+91 98220 44556','Apparel'),
  ('GroundWorks India','+91 98220 77889','Grounds'),
  ('MedSport Supplies','+91 98220 33445','Medical'),
  ('PoolPro Systems','+91 98220 66778','Pool Equipment'),
  ('TeamWear Co.','+91 98220 99001','Apparel')
) as v(name, contact, cat)
where not exists (select 1 from public.vendors x where x.name = v.name);

-- ---------- PURCHASE ORDERS + LINE ITEMS ----------
insert into public.purchase_orders (vendor_id, status, total, items)
select ve.id, v.st, v.tot,
       jsonb_build_array(jsonb_build_object('name', v.descr, 'qty', v.q, 'price', v.price))
from (values
  ('Sportiva Wholesale','Received', 56000, 'Football Size 5', 20, 2800),
  ('Prime Athletic Gear','Ordered', 38500, 'Team jersey sets', 35, 1100),
  ('MedSport Supplies','Received', 12600, 'First Aid Kit (Full)', 7, 1800),
  ('PoolPro Systems','Ordered', 9600, 'Swim Lane Rope', 3, 3200),
  ('Sportiva Wholesale','Draft', 15000, 'Hockey Stick', 10, 1500),
  ('GroundWorks India','Cancelled', 22000, 'Turf repair service', 1, 22000)
) as v(vname, st, tot, descr, q, price)
join public.vendors ve on ve.name = v.vname
where not exists (select 1 from public.purchase_orders po where po.items->0->>'name' = v.descr);

insert into public.purchase_order_items (po_id, item_id, description, quantity, unit_cost)
select po.id, i.id, v.descr, v.q, v.price
from (values
  ('Football Size 5', 'Football Size 5', 20, 1200),
  ('First Aid Kit (Full)', 'First Aid Kit (Full)', 7, 1800),
  ('Swim Lane Rope', 'Swim Lane Rope', 3, 3200),
  ('Hockey Stick', 'Hockey Stick', 10, 1500)
) as v(pname, descr, q, price)
join public.purchase_orders po on po.items->0->>'name' = v.pname
left join public.inventory_items i on i.name = v.descr
where not exists (select 1 from public.purchase_order_items x where x.po_id = po.id);

-- ---------- AWARDS (10) ----------
insert into public.awards (athlete_id, title, date, level)
select a.id, v.title, v.d::date, v.level
from (values
  ('Best Athlete of the Year', current_date - 30, 'State'),
  ('Inter-School Gold - 100m', current_date - 20, 'School'),
  ('District Championship MVP', current_date - 5, 'District'),
  ('State League Top Scorer', current_date - 60, 'State'),
  ('Best Defender Award', current_date - 45, 'District'),
  ('Swimming Trials Winner', current_date - 15, 'School'),
  ('Fair Play Award', current_date - 10, 'School'),
  ('National Qualifier Certificate', current_date - 90, 'National'),
  ('Kabaddi Raider of the Season', current_date - 25, 'District'),
  ('Badminton Doubles Champion', current_date - 18, 'District')
) as v(title, d, level)
join lateral (
  select a.id from public.athletes a
  where not exists (select 1 from public.awards aw where aw.title = v.title and aw.athlete_id = a.id)
  order by hashtext(v.title || a.id::text)
  limit 1
) a on true
where not exists (select 1 from public.awards aw where aw.title = v.title);

-- ---------- HOUSEKEEPING (8) ----------
insert into public.housekeeping_tasks (area, task, assigned_to, scheduled_date, status)
select v.area, v.task, v.who, v.d::date, v.st
from (values
  ('Main Stadium - Changing Rooms','Floor cleaning','Suresh K.', current_date, 'In Progress'),
  ('Main Stadium - Stands','Seat wipe-down','Ganesh P.', current_date + 1, 'Pending'),
  ('Indoor Arena - Courts','Court mopping','Ravi S.', current_date, 'Done'),
  ('Indoor Arena - Store','Inventory dusting','Ravi S.', current_date + 2, 'Pending'),
  ('Aquatic Center - Deck','Deck wash','Manoj T.', current_date, 'In Progress'),
  ('Aquatic Center - Filters','Filter check','Manoj T.', current_date + 3, 'Pending'),
  ('Multi-purpose Hall','Mat sanitization','Suresh K.', current_date + 1, 'Pending'),
  ('Practice Ground B','Turf debris removal','Ganesh P.', current_date + 2, 'Pending')
) as v(area, task, who, d, st)
where not exists (select 1 from public.housekeeping_tasks h where h.area = v.area and h.task = v.task);

-- ---------- TRAINING & CAMPS (10) ----------
insert into public.training_sessions (title, type, sport_id, coach_id, team_id, venue_id, start_time, end_time, notes)
select v.title, v.ty, s.id, c.id, t.id, ve.id, v.day::timestamptz, (v.day::timestamptz + interval '2 hours'), v.note
from (values
  ('Morning Football Drills','Session','Football', current_date + 1, 'Ball control and passing patterns.'),
  ('Evening Football Tactics','Session','Football', current_date + 2, 'Set-piece rehearsal.'),
  ('Cricket Net Practice','Session','Cricket', current_date + 1, 'Focus on seam bowling.'),
  ('Cricket Conditioning','Session','Cricket', current_date + 4, 'Fielding agility ladder.'),
  ('Basketball Scrimmage','Session','Basketball', current_date + 1, 'Full-court press practice.'),
  ('Sprint Technique Lab','Session','Athletics/Track & Field', current_date + 2, 'Block starts video review.'),
  ('Badminton Footwork Camp','Camp','Badminton', current_date + 6, 'Two-day residential camp.'),
  ('Swimming Endurance Camp','Camp','Swimming', current_date + 8, 'Long-distance sets, all squads.'),
  ('Hockey Penalty Corners','Session','Hockey', current_date + 3, 'Drag-flick accuracy.'),
  ('Kabaddi Raid Practice','Session','Kabaddi', current_date + 2, 'Ankle-hold defense drills.')
) as v(title, ty, sport, day, note)
join public.sports s on s.name = v.sport
left join lateral (
  select c.id from public.coaches c
  join public.profiles p on p.id = c.profile_id
  order by (p.full_name = 'Coach One') desc, c.created_at limit 1
) c on true
left join lateral (
  select t.id from public.teams t join public.sports s2 on s2.id = t.sport_id
  where s2.name = v.sport limit 1
) t on true
left join lateral (select ve.id from public.venues ve order by hashtext(v.title || ve.id::text) limit 1) ve on true
where not exists (select 1 from public.training_sessions tr where tr.title = v.title);

-- ---------- PERFORMANCE RECORDS (structured, ~24) ----------
insert into public.performance_records (athlete_id, date, metric, value, value_num, unit, session_type, coach_note)
select a.id, dd.d, v.metric, v.val::text, v.val, v.unit, v.sess, v.note
from (values
  ('100m Sprint', 12.8, 'sec', 'Test', 'Strong start, taper the finish'),
  ('100m Sprint', 12.4, 'sec', 'Test', 'Improved by 0.4s'),
  ('800m Run', 165.0, 'sec', 'Test', 'Pacing even throughout'),
  ('Vertical Jump', 52.0, 'cm', 'Test', null),
  ('Broad Jump', 210.0, 'cm', 'Test', 'Good hip drive'),
  ('VO2 Max Estimate', 48.0, 'ml/kg/min', 'Assessment', null),
  ('Yo-Yo Test Level', 18.2, 'level', 'Assessment', 'Above squad average'),
  ('Push-ups (2 min)', 42.0, 'reps', 'Test', null),
  ('Sit-ups (2 min)', 48.0, 'reps', 'Test', null),
  ('Shuttle Run 5-10-5', 4.9, 'sec', 'Test', 'Tight turns needed'),
  ('Deadlift', 95.0, 'kg', 'Gym', 'Form corrected'),
  ('Squat', 110.0, 'kg', 'Gym', null),
  ('Bench Press', 70.0, 'kg', 'Gym', null),
  ('Pull-ups (max)', 12.0, 'reps', 'Test', null),
  ('40m Dash', 5.6, 'sec', 'Test', null),
  ('Flexibility Sit & Reach', 32.0, 'cm', 'Assessment', null)
) as v(metric, val, unit, sess, note)
join lateral (
  select a.id, (row_number() over (order by a.id)) rn from public.athletes a
) a on (a.rn % 4) = (hashtext(v.metric) % 4)
cross join lateral (select current_date - ((a.rn % 12) * interval '1 day') as d) dd
where not exists (
  select 1 from public.performance_records pr
  where pr.athlete_id = a.id and pr.metric = v.metric
);

-- ---------- MEDICAL RECORDS (detailed, ~12) ----------
insert into public.medical_records (athlete_id, date, type, details, cleared, height_cm, weight_kg, severity, treatment, follow_up_date)
select a.id, dd.d, v.ty, v.det, v.clr, v.h, v.w, v.sev, v.treat, v.fud::date
from (values
  ('Checkup','Annual fitness screening - all vitals normal', true, 172.0, 63.5, 'None', null, null),
  ('Injury','Left ankle sprain during scrimmage', false, 170.0, 62.0, 'Moderate', 'RICE protocol, ankle brace', current_date + 10),
  ('Physio','Shoulder mobility session', true, 175.0, 68.0, 'Mild', 'Band exercises x10 daily', current_date + 5),
  ('Clearance','Post-injury clearance assessment', true, 168.0, 60.5, 'None', null, null),
  ('Checkup','Pre-tournament medical card update', true, 180.0, 71.2, 'None', null, null),
  ('Injury','Grade 1 hamstring strain', false, 176.0, 66.0, 'Mild', 'Physio 3x weekly', current_date + 7)
) as v(ty, det, clr, h, w, sev, treat, fud)
join lateral (
  select a.id, (row_number() over (order by a.id)) rn from public.athletes a
) a on a.rn <= 12
cross join lateral (select current_date - (((a.rn * 3) % 40) * interval '1 day') as d) dd
where not exists (
  select 1 from public.medical_records mr where mr.athlete_id = a.id and mr.details = v.det
);

-- ---------- EVENTS (6) ----------
insert into public.events (title, type, date, venue_id, description)
select v.title, v.ty, v.d::date, ve.id, v.descr
from (values
  ('Annual Sports Day','Ceremony', current_date + 15, 'Full-day athletics showcase.'),
  ('Coaching Workshop: Periodization','Workshop', current_date + 7, 'Guest lecturer for all coaches.'),
  ('Foundation Day Ceremony','Ceremony', current_date - 60, 'Flag march and awards.'),
  ('Inter-House Draw','General', current_date + 3, 'Fixture draw for house league.'),
  ('Parent Orientation: Sports Program','Workshop', current_date + 9, 'Program overview for new parents.'),
  ('Equipment Audit Day','Other', current_date + 12, 'Full stock-take with Finance.')
) as v(title, ty, d, descr)
left join lateral (select id from public.venues order by hashtext(v.title || id::text) limit 1) ve on true
where not exists (select 1 from public.events e where e.title = v.title);

-- ---------- TRANSPORT (6) ----------
insert into public.transport (purpose, vehicle, driver, depart_at, return_at, team_id, status)
select v.pur, v.veh, v.drv, v.dep::timestamptz, (v.dep::timestamptz + interval '8 hours'), t.id, v.st
from (values
  ('Team bus to District Championship','Bus KA-01-F-2233','Mahesh N.', now() + interval '1 day 6 hours', 'In Transit'),
  ('Away match travel - State League','Mini bus KA-05-G-8891','Prakash D.', now() + interval '10 days 5 hours', 'Planned'),
  ('Airport pickup - guest coach','Innova KA-03-M-1122','Ramesh B.', now() + interval '2 days 3 hours', 'Planned'),
  ('Training camp return trip','Bus KA-01-F-2233','Mahesh N.', now() + interval '9 days 7 hours', 'Planned'),
  ('Equipment van to Indoor Arena','Tempo KA-02-H-5566','Suresh L.', now() - interval '1 day', 'Completed'),
  ('National Meet advance party','Mini bus KA-05-G-8891','Prakash D.', now() + interval '39 days 4 hours', 'Planned')
) as v(pur, veh, drv, dep, st)
left join lateral (select id from public.teams order by hashtext(v.pur || id::text) limit 1) t on true
where not exists (select 1 from public.transport tr where tr.purpose = v.pur);

-- ---------- ACCOMMODATION (4) ----------
insert into public.accommodation (hotel, location, check_in, check_out, team_id, rooms, status)
select v.hotel, v.loc, v.ci::date, v.co::date, t.id, v.rooms, v.st
from (values
  ('City Grand Hotel','Station Road', current_date + 9, current_date + 12, 6, 'Booked'),
  ('Sports hostel - Block C','Campus East', current_date + 5, current_date + 8, 12, 'Booked'),
  ('Lakeside Residency','Lake View Road', current_date + 39, current_date + 44, 8, 'Booked'),
  ('Transit Inn','Highway Junction', current_date - 2, current_date + 1, 4, 'Checked-in')
) as v(hotel, loc, ci, co, rooms, st)
left join lateral (select id from public.teams order by hashtext(v.hotel || id::text) limit 1) t on true
where not exists (select 1 from public.accommodation a where a.hotel = v.hotel);

-- ---------- EXPENSES (12) ----------
insert into public.expenses (category, amount, date, description, approved_by)
select v.cat, v.amt, v.d::date, v.descr, 'Finance Lead'
from (values
  ('Equipment', 56000, current_date - 20, 'Football restock PO'),
  ('Travel', 18500, current_date - 14, 'District Championship bus hire'),
  ('Venue', 12000, current_date - 30, 'Floodlight maintenance'),
  ('Salaries', 312000, current_date - 5, 'Staff payroll batch'),
  ('Equipment', 12600, current_date - 8, 'First aid kits'),
  ('Travel', 9200, current_date - 3, 'Airport transfers'),
  ('Other', 5400, current_date - 2, 'Team nutrition snacks'),
  ('Venue', 7800, current_date - 10, 'Indoor arena court resurfacing'),
  ('Equipment', 9600, current_date - 4, 'Swim lane ropes PO'),
  ('Travel', 21000, current_date - 25, 'State League advance party'),
  ('Other', 3200, current_date - 1, 'Printing fixtures and programs'),
  ('Salaries', 312000, current_date - 35, 'Staff payroll batch')
) as v(cat, amt, d, descr)
where not exists (select 1 from public.expenses e where e.description = v.descr and e.date = v.d::date);

-- ---------- SCHOOL ACTIVITIES (6) ----------
insert into public.school_activities (title, school, date, participants, description)
select v.title, v.school, v.d::date, v.part, v.descr
from (values
  ('Morning Yoga Week','Sunrise Public School', current_date + 2, 240, 'Whole-school morning sessions.'),
  ('Mini Football Festival','Green Valley School', current_date + 6, 120, 'U-12 five-a-side jamboree.'),
  ('Athletics Talent Hunt','City Model School', current_date - 5, 180, 'Sprint and jump scouting.'),
  ('Table Tennis Intro Day','Little Flower School', current_date + 9, 60, 'Basic grips and rallies.'),
  ('Kabaddi Awareness Camp','Government High School', current_date + 12, 90, 'Rules and safety clinic.'),
  ('Inter-School Chess Round','St. Mary''s Academy', current_date - 12, 45, 'Qualifier round.')
) as v(title, school, d, part, descr)
where not exists (select 1 from public.school_activities sa where sa.title = v.title);

-- ---------- NOTIFICATIONS for the six users ----------
insert into public.notifications (recipient_id, message, read)
select p.id, v.msg, v.read
from (values
  ('District Championship fixtures are live now.', false),
  ('Attendance for today is incomplete for your team.', false),
  ('New purchase order was marked Received and stock updated.', false),
  ('Payroll for this month has been published.', true),
  ('Training camp schedule updated - check Training & Camps.', false),
  ('Your medical clearance certificate was recorded.', true)
) as v(msg, read)
cross join public.profiles p
where p.contact_info in ('admin@sportsphere.app','athlete@sportsphere.app','coach@sportsphere.app','hr@sportsphere.app','finance@sportsphere.app','venuemanager@sportsphere.app')
  and not exists (select 1 from public.notifications n where n.recipient_id = p.id and n.message = v.msg);
