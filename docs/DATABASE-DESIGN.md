# Relational Database Design

---

| Field | Value |
|---|---|
| **Document ID** | SPORT-DB-001 |
| **Project Name** | SportSphere — Integrated Sports Organization Management Platform |
| **Version** | 1.0 |
| **Document Type** | Relational Database Design Specification |
| **Date** | 2026-09-28 |
| **Status** | IMPLEMENTED (Audited against codebase) |
| **Source Schema Files** | `supabase/schema.sql`, `supabase/modules.sql`, `supabase/migrate_*.sql` |

---

## 1. Database Overview

| Property | Implementation Detail |
|---|---|
| **Database Engine** | PostgreSQL 15+ (Hosted on Supabase Cloud) |
| **Extensions** | `pgcrypto` (UUID generation), `uuid-ossp` |
| **Security Framework** | Supabase Row Level Security (RLS) on all public tables |
| **Authentication Integration** | Foreign key references to Supabase `auth.users` via trigger synchronization |
| **Total Domain Tables** | 27 tables (Core Profiles, Sports, Rosters, Competitions, Facilities, Logistics, Finance) |
| **Custom Enums** | 4 custom Postgres ENUM types (`user_role`, `tournament_level`, `match_status`, `attendance_status`) |
| **Stored Procedures / Functions** | `handle_new_user()`, `current_role()`, `is_admin()`, `is_staff_role()`, `admin_delete_user()`, `admin_restore_user()`, `admin_purge_user()` |

---

## 2. Custom Enumerated Types (ENUMs)

```sql
create type user_role as enum ('Admin', 'Coach', 'Athlete', 'HR', 'Finance', 'VenueManager');
create type tournament_level as enum ('School', 'District', 'State', 'National');
create type match_status as enum ('Scheduled', 'Live', 'Completed', 'Cancelled');
create type attendance_status as enum ('Present', 'Absent', 'Late', 'Leave');
```

---

## 3. Complete Table Catalog (27 Tables)

| # | Table Name | Category | Primary Key | Description & Business Purpose |
|---|---|---|:---:|---|
| 1 | `profiles` | Identity / Core | `id` (uuid) | Master user profile linked to Supabase Auth (`auth.users`) with soft delete support. |
| 2 | `sports` | Master Catalog | `id` (uuid) | Single source of truth for sports disciplines with names and icon identifiers. |
| 3 | `coaches` | Rosters | `id` (uuid) | Coach extension profile storing coaching specializations and qualifications. |
| 4 | `teams` | Rosters | `id` (uuid) | Team and squad definitions linked to sports and supervising head coaches. |
| 5 | `athletes` | Rosters | `id` (uuid) | Athlete extension profile storing DOB, medical notes, and primary team assignment. |
| 6 | `athlete_sports` | Rosters / Junction | `id` (uuid) | Many-to-many junction enabling athletes to participate across multiple sports. |
| 7 | `staff` | Rosters / HR | `id` (uuid) | Non-athletic personnel registry with department and official designations. |
| 8 | `venues` | Facilities | `id` (uuid) | Stadiums, courts, and fields with seating capacities, status, and GPS lat/lng. |
| 9 | `venue_bookings` | Facilities | `id` (uuid) | Ground and court reservation slots with booking purposes and user associations. |
| 10 | `tournaments` | Competitions | `id` (uuid) | Competitive championship brackets across School, District, State, and National levels. |
| 11 | `matches` | Competitions | `id` (uuid) | Fixture pairings between teams with scheduled times, statuses, scores, and results. |
| 12 | `attendance` | Operations | `id` (uuid) | Daily roll-call records with presence statuses and leave justifications. |
| 13 | `payroll` | Finance | `id` (uuid) | Monthly staff salary calculations with gross, deductions, and stored net pay. |
| 14 | `inventory_items` | Operations | `id` (uuid) | Sports equipment and gear catalog with current quantities and condition grades. |
| 15 | `vendors` | Procurement | `id` (uuid) | Suppliers and service providers directory categorized by product lines. |
| 16 | `purchase_orders` | Procurement | `id` (uuid) | Vendor purchase orders with JSON line items, total sums, and lifecycle statuses. |
| 17 | `awards` | Athletic Care | `id` (uuid) | Player honors, tournament medals, trophies, and certifications. |
| 18 | `notifications` | System | `id` (uuid) | User-targeted notifications with read flags and message content. |
| 19 | `housekeeping_tasks`| Facilities | `id` (uuid) | Cleaning, sanitation, and grounds upkeep tasks assigned to custodial staff. |
| 20 | `training_sessions` | Operations | `id` (uuid) | Practice sessions and intensive training camps scheduled by team coaches. |
| 21 | `performance_records`| Athletic Care | `id` (uuid) | Standardized fitness benchmarks (sprints, VO2, strength) tracked over time. |
| 22 | `medical_records` | Athletic Care | `id` (uuid) | Doctor checkups, injury diagnoses, physio notes, and official play clearances. |
| 23 | `events` | Community | `id` (uuid) | Club ceremonies, seminars, workshops, and annual sports days. |
| 24 | `transport` | Logistics | `id` (uuid) | Team travel logistics including bus schedules, drivers, and departure windows. |
| 25 | `accommodation` | Logistics | `id` (uuid) | Out-of-town hotel and hostel bookings for traveling squads and coaches. |
| 26 | `expenses` | Finance | `id` (uuid) | Categorized operational expenditures with expense dates and approving authorities. |
| 27 | `school_activities`| Community | `id` (uuid) | Grassroots school outreach activities, clinics, and student participant counts. |

---

## 4. Entity Specifications & Column Dictionaries

### 4.1 `profiles`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Matches `auth.users.id` for authenticated signups. |
| `full_name` | `text` | NOT NULL | `''` | User's full display name. |
| `role` | `user_role` | NOT NULL | `'Athlete'` | User role from enum. |
| `avatar_url` | `text` | NULL | `NULL` | Public URL to profile avatar. |
| `contact_info` | `text` | NULL | `NULL` | Email or phone contact. |
| `deleted_at` | `timestamptz`| NULL | `NULL` | Soft delete timestamp; NULL when active. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

*Indexes*: `idx_profiles_deleted (deleted_at)`

---

### 4.2 `sports`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique sport identifier. |
| `name` | `text` | NOT NULL, UNIQUE | — | Official sport name (e.g. Football, Cricket). |
| `icon` | `text` | NULL | `NULL` | Icon identifier or asset reference. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.3 `coaches`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique coach record identifier. |
| `profile_id` | `uuid` | NOT NULL, UNIQUE | `profiles(id) ON DELETE CASCADE` | Associated user profile. |
| `specialization` | `text` | NULL | `NULL` | Coaching domain (e.g. Head Coach, Goalkeeping). |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.4 `teams`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique team identifier. |
| `name` | `text` | NOT NULL | — | Official team/squad name (e.g. Under-19 Football). |
| `sport_id` | `uuid` | NULL | `sports(id) ON DELETE SET NULL` | Primary sport master reference. |
| `sport_legacy` | `text` | NULL | `NULL` | Preserved text sport prior to migration. |
| `coach_id` | `uuid` | NULL | `coaches(id) ON DELETE SET NULL` | Assigned supervising head coach. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

*Indexes*: `idx_teams_sport (sport_id)`

---

### 4.5 `athletes`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique athlete identifier. |
| `profile_id` | `uuid` | NOT NULL, UNIQUE | `profiles(id) ON DELETE CASCADE` | Associated user profile. |
| `dob` | `date` | NULL | `NULL` | Date of birth for age-category validation. |
| `sport` | `text` | NULL | `NULL` | Legacy sport text. |
| `team_id` | `uuid` | NULL | `teams(id) ON DELETE SET NULL` | Assigned team roster. |
| `medical_notes`| `text` | NULL | `NULL` | General medical notes and allergies. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.6 `athlete_sports`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique junction record ID. |
| `athlete_id` | `uuid` | NOT NULL | `athletes(id) ON DELETE CASCADE` | Athlete foreign key. |
| `sport_id` | `uuid` | NOT NULL | `sports(id) ON DELETE CASCADE` | Sport foreign key. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Association timestamp. |

*Constraints*: `UNIQUE(athlete_id, sport_id)`  
*Indexes*: `idx_athlete_sports_athlete (athlete_id)`, `idx_athlete_sports_sport (sport_id)`

---

### 4.7 `staff`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique staff record ID. |
| `profile_id` | `uuid` | NOT NULL, UNIQUE | `profiles(id) ON DELETE CASCADE` | Associated profile. |
| `department` | `text` | NULL | `NULL` | Department (Operations, HR, Medical, Logistics). |
| `designation` | `text` | NULL | `NULL` | Official employee title. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.8 `venues`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique venue identifier. |
| `name` | `text` | NOT NULL | — | Facility or stadium name. |
| `location` | `text` | NULL | `NULL` | Physical street address / location. |
| `capacity` | `int` | NULL | `NULL` | Maximum seating / spectator capacity. |
| `status` | `text` | NOT NULL | `'Active'` | Operational status (`Active`, `Maintenance`). |
| `latitude` | `numeric(9,6)`| NULL | `NULL` | GPS latitude for map integration. |
| `longitude` | `numeric(9,6)`| NULL | `NULL` | GPS longitude for map integration. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.9 `venue_bookings`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Booking slot identifier. |
| `venue_id` | `uuid` | NOT NULL | `venues(id) ON DELETE CASCADE` | Target facility reference. |
| `booked_by` | `uuid` | NULL | `profiles(id) ON DELETE SET NULL`| User initiating the booking. |
| `start_time` | `timestamptz`| NOT NULL | — | Reservation start timestamp. |
| `end_time` | `timestamptz`| NOT NULL | — | Reservation end timestamp. |
| `purpose` | `text` | NULL | `NULL` | Event / practice purpose description. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.10 `tournaments`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique tournament identifier. |
| `name` | `text` | NOT NULL | — | Official competition name. |
| `level` | `tournament_level`| NOT NULL | `'School'` | Level (School, District, State, National). |
| `sport_id` | `uuid` | NULL | `sports(id) ON DELETE SET NULL` | Associated sport. |
| `start_date` | `date` | NULL | `NULL` | Tournament commencement date. |
| `end_date` | `date` | NULL | `NULL` | Tournament conclusion date. |
| `venue_id` | `uuid` | NULL | `venues(id) ON DELETE SET NULL` | Host stadium / ground. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

*Indexes*: `idx_tournaments_sport (sport_id)`

---

### 4.11 `matches`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique match fixture identifier. |
| `tournament_id`| `uuid` | NULL | `tournaments(id) ON DELETE CASCADE`| Parent tournament bracket. |
| `team_a_id` | `uuid` | NULL | `teams(id) ON DELETE CASCADE` | Team A / Home squad. |
| `team_b_id` | `uuid` | NULL | `teams(id) ON DELETE CASCADE` | Team B / Away squad. |
| `scheduled_at` | `timestamptz`| NULL | `NULL` | Scheduled match kickoff time. |
| `status` | `match_status` | NOT NULL | `'Scheduled'` | Match status lifecycle. |
| `score_a` | `int` | NULL | `0` | Team A points/goals/score. |
| `score_b` | `int` | NULL | `0` | Team B points/goals/score. |
| `result` | `text` | NULL | `NULL` | Result summary text. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

*Indexes*: `idx_matches_tournament (tournament_id)`, `idx_matches_status (status)`

---

### 4.12 `attendance`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique attendance record ID. |
| `profile_id` | `uuid` | NOT NULL | `profiles(id) ON DELETE CASCADE` | Individual user profile. |
| `date` | `date` | NOT NULL | `current_date` | Date of attendance roll-call. |
| `status` | `attendance_status`| NOT NULL | `'Present'` | Roll-call status (Present, Absent, Late, Leave). |
| `leave_reason` | `text` | NULL | `NULL` | Mandatory note if Absent/Leave. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

*Constraints*: `UNIQUE(profile_id, date)`

---

### 4.13 `payroll`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique payroll slip ID. |
| `staff_id` | `uuid` | NULL | `staff(id) ON DELETE CASCADE` | Associated staff employee. |
| `month` | `date` | NOT NULL | — | Month of disbursement. |
| `gross` | `numeric(12,2)` | NULL | `0` | Gross compensation amount. |
| `deductions` | `numeric(12,2)` | NULL | `0` | Tax and statutory deductions. |
| `net` | `numeric(12,2)` | GENERATED | `(gross - deductions) STORED` | Stored calculated net payout. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.14 `inventory_items`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Equipment asset ID. |
| `name` | `text` | NOT NULL | — | Equipment name (e.g., Match Soccer Ball). |
| `category` | `text` | NULL | `NULL` | Gear classification category. |
| `quantity` | `int` | NULL | `0` | Current on-hand quantity. |
| `condition` | `text` | NULL | `'Good'` | Physical condition (`Good`, `Fair`, `Poor`). |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.15 `vendors`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique vendor identifier. |
| `name` | `text` | NOT NULL | — | Supplier company name. |
| `contact` | `text` | NULL | `NULL` | Representative phone or email. |
| `category` | `text` | NULL | `NULL` | Goods / services category. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.16 `purchase_orders`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique PO number. |
| `vendor_id` | `uuid` | NULL | `vendors(id) ON DELETE SET NULL` | Associated vendor. |
| `items` | `jsonb` | NOT NULL | `'[]'` | JSON array of line items (`name`, `qty`, `price`). |
| `total` | `numeric(12,2)` | NULL | `0` | Total order financial value. |
| `status` | `text` | NOT NULL | `'Draft'` | Status (`Draft`, `Ordered`, `Received`, `Cancelled`). |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Order creation timestamp. |

---

### 4.17 `awards`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique award ID. |
| `athlete_id` | `uuid` | NULL | `athletes(id) ON DELETE CASCADE`| Recipient athlete. |
| `title` | `text` | NOT NULL | — | Award title (e.g. Most Valuable Player). |
| `date` | `date` | NULL | `NULL` | Date of conferral. |
| `level` | `text` | NULL | `NULL` | Recognition level (Club, State, National). |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.18 `notifications`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique notification ID. |
| `recipient_id` | `uuid` | NOT NULL | `profiles(id) ON DELETE CASCADE`| Targeted user profile. |
| `message` | `text` | NOT NULL | — | In-app alert message content. |
| `read` | `boolean` | NOT NULL | `false` | Read acknowledgment flag. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Notification timestamp. |

*Indexes*: `idx_notifications_recipient (recipient_id, read)`

---

### 4.19 `housekeeping_tasks`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique task ID. |
| `area` | `text` | NOT NULL | — | Facility location (e.g. Pavilion Changing Room). |
| `task` | `text` | NOT NULL | — | Required custodial work. |
| `assigned_to` | `text` | NULL | `NULL` | Custodial personnel name. |
| `scheduled_date`| `date` | NULL | `NULL` | Target execution date. |
| `status` | `text` | NOT NULL | `'Pending'` | Status (`Pending`, `In Progress`, `Done`). |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.20 `training_sessions`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique session ID. |
| `title` | `text` | NOT NULL | — | Training session or camp title. |
| `type` | `text` | NOT NULL | `'Session'` | Type (`Session`, `Camp`). |
| `sport_id` | `uuid` | NULL | `sports(id) ON DELETE SET NULL` | Associated sport. |
| `sport` | `text` | NULL | `NULL` | Legacy sport text. |
| `coach_id` | `uuid` | NULL | `coaches(id) ON DELETE SET NULL` | Supervising coach. |
| `team_id` | `uuid` | NULL | `teams(id) ON DELETE SET NULL` | Participating team. |
| `venue_id` | `uuid` | NULL | `venues(id) ON DELETE SET NULL` | Training venue ground. |
| `start_time` | `timestamptz`| NULL | `NULL` | Practice start timestamp. |
| `end_time` | `timestamptz`| NULL | `NULL` | Practice end timestamp. |
| `notes` | `text` | NULL | `NULL` | Tactical / drills notes. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

*Indexes*: `idx_training_sport (sport_id)`

---

### 4.21 `performance_records`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique record ID. |
| `athlete_id` | `uuid` | NOT NULL | `athletes(id) ON DELETE CASCADE`| Target athlete. |
| `date` | `date` | NOT NULL | `current_date` | Assessment test date. |
| `metric` | `text` | NOT NULL | — | Tested physical metric (e.g. VO2 Max, 100m Sprint). |
| `value` | `text` | NOT NULL | — | Measured score or timing value. |
| `notes` | `text` | NULL | `NULL` | Coaching observations. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Assessment timestamp. |

---

### 4.22 `medical_records`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique medical file ID. |
| `athlete_id` | `uuid` | NOT NULL | `athletes(id) ON DELETE CASCADE`| Target athlete. |
| `date` | `date` | NOT NULL | `current_date` | Clinical consultation date. |
| `type` | `text` | NOT NULL | `'Checkup'` | Type (`Checkup`, `Injury`, `Physio`, `Clearance`). |
| `details` | `text` | NOT NULL | — | Clinical diagnosis and treatment notes. |
| `cleared` | `boolean` | NOT NULL | `true` | Official match fitness clearance flag. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Entry timestamp. |

---

### 4.23 `events`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique event ID. |
| `title` | `text` | NOT NULL | — | Event title. |
| `type` | `text` | NOT NULL | `'General'` | Classification (`General`, `Ceremony`, `Workshop`). |
| `date` | `date` | NULL | `NULL` | Event scheduled date. |
| `venue_id` | `uuid` | NULL | `venues(id) ON DELETE SET NULL` | Host venue facility. |
| `description` | `text` | NULL | `NULL` | Agenda and event summary. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.24 `transport`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique transport itinerary ID. |
| `purpose` | `text` | NOT NULL | — | Travel objective (e.g. State Meet Travel). |
| `vehicle` | `text` | NULL | `NULL` | Vehicle model / registration number. |
| `driver` | `text` | NULL | `NULL` | Assigned driver contact. |
| `depart_at` | `timestamptz`| NULL | `NULL` | Departure timestamp. |
| `return_at` | `timestamptz`| NULL | `NULL` | Expected return timestamp. |
| `team_id` | `uuid` | NULL | `teams(id) ON DELETE SET NULL` | Traveling team squad. |
| `status` | `text` | NOT NULL | `'Planned'` | Transit status (`Planned`, `In Transit`, `Completed`). |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

### 4.25 `accommodation`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique accommodation record ID. |
| `hotel` | `text` | NOT NULL | — | Hotel or lodging establishment name. |
| `location` | `text` | NULL | `NULL` | City / area address. |
| `check_in` | `date` | NULL | `NULL` | Scheduled check-in date. |
| `check_out` | `date` | NULL | `NULL` | Scheduled check-out date. |
| `team_id` | `uuid` | NULL | `teams(id) ON DELETE SET NULL` | Accommodated team. |
| `rooms` | `int` | NULL | `0` | Reserved room count. |
| `status` | `text` | NOT NULL | `'Booked'` | Status (`Booked`, `Checked-in`, `Completed`). |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Reservation timestamp. |

---

### 4.26 `expenses`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique expense voucher ID. |
| `category` | `text` | NOT NULL | — | Category (Equipment, Travel, Salary, Other). |
| `amount` | `numeric(12,2)` | NOT NULL | `0` | Expense financial amount. |
| `date` | `date` | NOT NULL | `current_date` | Transaction date. |
| `description` | `text` | NULL | `NULL` | Expense justification details. |
| `approved_by` | `text` | NULL | `NULL` | Name of approving finance controller. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Voucher creation timestamp. |

---

### 4.27 `school_activities`
| Column | Type | Constraints | References / Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Unique activity ID. |
| `title` | `text` | NOT NULL | — | Outreach program or clinic title. |
| `school` | `text` | NULL | `NULL` | Partner educational institution. |
| `date` | `date` | NULL | `NULL` | Activity date. |
| `participants` | `int` | NULL | `0` | Total participating students. |
| `description` | `text` | NULL | `NULL` | Event overview and outcomes. |
| `created_at` | `timestamptz`| NOT NULL | `now()` | Record creation timestamp. |

---

## 5. Stored Procedures & Security Definer Functions

```sql
-- Returns current user's role from public.profiles
create or replace function public.current_role()
returns user_role language sql stable security definer
set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

-- Returns true if current user is an Admin
create or replace function public.is_admin()
returns boolean language sql stable security definer
set search_path = public as $$
  select public.current_role() = 'Admin'
$$;

-- Soft-deletes user and bans auth account until 2099
create or replace function public.admin_delete_user(p_user uuid)
returns void language plpgsql security definer
set search_path = public as $$
declare
  t_target_role public.user_role;
begin
  if not public.is_admin() then raise exception 'Only admins can delete users'; end if;
  select role into t_target_role from public.profiles where id = p_user;
  if not found then raise exception 'User not found'; end if;
  if t_target_role = 'Admin' then raise exception 'The fixed admin account cannot be deleted'; end if;
  update public.profiles set deleted_at = now() where id = p_user;
  update auth.users set banned_until = '2099-01-01T00:00:00Z'::timestamptz, updated_at = now() where id = p_user;
end;
$$;

-- Restores soft-deleted user and clears auth ban
create or replace function public.admin_restore_user(p_user uuid)
returns void language plpgsql security definer
set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Only admins can restore users'; end if;
  update public.profiles set deleted_at = null where id = p_user;
  update auth.users set banned_until = null, updated_at = now() where id = p_user;
end;
$$;

-- Cascades permanent purge across roster tables, profile, and auth.users
create or replace function public.admin_purge_user(p_user uuid)
returns void language plpgsql security definer
set search_path = public as $$
declare
  t_target_role public.user_role;
begin
  if not public.is_admin() then raise exception 'Only admins can permanently delete users'; end if;
  select role into t_target_role from public.profiles where id = p_user;
  if not found then raise exception 'User not found'; end if;
  if t_target_role = 'Admin' then raise exception 'The fixed admin account cannot be purged'; end if;
  delete from public.athletes where profile_id = p_user;
  delete from public.coaches  where profile_id = p_user;
  delete from public.staff    where profile_id = p_user;
  delete from public.profiles where id = p_user;
  delete from auth.users      where id = p_user;
end;
$$;
```

---

## 6. Row Level Security (RLS) Policy Overview

Every table in SportSphere has RLS enabled (`alter table ... enable row level security;`).
Policies enforce strict organizational isolation:

1. **`profiles`**: Public read for active users (`deleted_at is null`), self-update permitted, Admin writes all and views soft-deleted accounts.
2. **`athletes` & `teams`**: Org-wide read; write restricted to `Admin` and `Coach`.
3. **`coaches` & `staff`**: Org-wide read; write restricted to `Admin` and `HR`.
4. **`attendance`**: Admin/Coach/HR read and write all; Athletes insert and update their own records only.
5. **`payroll` & `expenses`**: Restricted to `Admin` and `Finance` (staff read own slips).
6. **`medical_records`**: Visible to `Admin`, `Coach`, and the owning athlete only.
7. **`purchase_orders` & `vendors`**: Admin/Finance manage; org-wide read.
8. **`venues` & `housekeeping_tasks`**: `Admin` and `VenueManager` have full control.
9. **`tournaments` & `matches`**: Admin/Coach have fixture and score updating privileges.
