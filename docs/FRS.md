# Functional Requirements Specification (FRS)

---

| Field | Value |
|---|---|
| **Document ID** | SPORT-FRS-001 |
| **Project Name** | SportSphere — Integrated Sports Organization Management Platform |
| **Version** | 1.0 |
| **Document Type** | Functional Requirements Specification |
| **Date** | 2026-09-28 |
| **Status** | IMPLEMENTED (Audited against codebase) |
| **Authoritative Sources** | `web/src/`, `mobile/lib/`, `supabase/schema.sql`, `supabase/modules.sql` |

---

## 1. System Overview

**SportSphere** is a multi-tenant sports organization management platform featuring a React 18 / Material-UI (MUI v5) web administration portal, a Flutter (Material 3) mobile client, and a Supabase (PostgreSQL 15+) cloud backend. The system coordinates operations across 6 user roles (`Admin`, `Coach`, `Athlete`, `HR`, `Finance`, `VenueManager`) utilizing Row Level Security (RLS), database triggers, and stored procedures.

This document specifies the functional requirements implemented across all modules of the platform.

---

## 2. User Roles & Permissions Matrix

| Module / Capability | Admin | Coach | Athlete | HR | Finance | VenueManager |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **User Management & Soft Delete** | Full | None | None | None | None | None |
| **Sports Master Catalog** | Full | Read | Read | Read | Read | Read |
| **Athletes Roster** | Full | Write | Read (Self) | Write | Read | Read |
| **Coaches Directory** | Full | Read | Read | Write | Read | Read |
| **Teams & Squads** | Full | Write | Read | Read | Read | Read |
| **Staff & HR Directory** | Full | Read | Read | Write | Read | Read |
| **Venues & Maintenance** | Full | Read | Read | Read | Read | Full |
| **Venue Booking** | Full | Write | Read | Read | Read | Full |
| **Tournaments & Fixtures** | Full | Write | Read | Read | Read | Read |
| **Match Scorekeeping** | Full | Write | Read | Read | Read | Read |
| **Daily Attendance** | Full | Write | Self-Log | Full | Read | Read |
| **Equipment Inventory** | Full | Read | Read | Read | Read | Read |
| **Purchase Orders & Vendors** | Full | Read | Read | Read | Full | Read |
| **Housekeeping Tasks** | Full | Read | Read | Read | Read | Full |
| **Training Sessions & Camps** | Full | Write | Read | Read | Read | Read |
| **Performance Benchmark Logs** | Full | Write | Read (Self) | Read | Read | Read |
| **Medical Records & Clearances**| Full | Read | Read (Self) | Read | Read | Read |
| **Transport Logistics** | Full | Write | Read | Read | Read | Write |
| **Hotel Accommodation** | Full | Write | Read | Read | Read | Write |
| **Payroll Processing** | Full | None | None | Read | Full | None |
| **Expense Logging** | Full | None | None | Read | Full | None |
| **School Sports Activities** | Full | Write | Read | Read | Read | Read |
| **Executive Reports & KPIs** | Full | Read | None | Read | Read | Read |

---

## 3. Module-Wise Functional Requirements

### 3.1 Authentication & Security (AUTH)

- **FR-001**: The system shall authenticate users using email and password against Supabase GoTrue Auth.
- **FR-002**: Upon user registration, the system shall trigger the creation of a corresponding record in `public.profiles`.
- **FR-003**: The system shall prevent self-assignment of the `Admin` role during registration by intercepting signups and downgrading requested roles to `Athlete` via database triggers.
- **FR-004**: The system shall enforce a single immutable root admin account governed by environment credentials (`ADMIN_EMAIL`).
- **FR-005**: The system shall deliver branded email templates for user invitations, confirmations, and password resets in compliance with the `#FF6A13` palette.
- **FR-006**: The system shall maintain JWT access tokens with automatic renewal in both web and mobile client sessions.
- **FR-007**: The system shall support administrative password resets and account ban flags (`banned_until`).
- **FR-008**: The system shall display a configuration guard screen (`ConfigError.tsx`) if Supabase URL or Anon Key environment variables are missing.

### 3.2 User Management & Lifecycle (USER)

- **FR-009**: The system shall provide an administrative user management console displaying Active and Deleted user tabs.
- **FR-010**: The system shall support soft deletion of users via `admin_delete_user` RPC, setting `deleted_at = now()` and banning the GoTrue auth user until year 2099.
- **FR-011**: Soft-deleted users shall be invisible to all non-admin users across all module lists and join queries.
- **FR-012**: The system shall support administrative restoration of soft-deleted users via `admin_restore_user` RPC, clearing the deletion timestamp and unbanning the auth account.
- **FR-013**: The system shall support permanent user purging via `admin_purge_user` RPC, cascading deletions through roster tables, profile records, and auth user accounts.
- **FR-014**: The system shall forbid deletion, role demotion, or purging of the primary admin user account.
- **FR-015**: The system shall allow users to edit their own profile display name, avatar URL, and contact details via `Profile.tsx` / `profile_page.dart`.

### 3.3 Sports Master Catalog (SPORT)

- **FR-016**: The system shall maintain a centralized `sports` table containing 10 default disciplines (Football, Cricket, Basketball, Athletics, Badminton, Table Tennis, Hockey, Volleyball, Swimming, Kabaddi).
- **FR-017**: The system shall enforce UUID references to `sports.id` across teams, tournaments, and training sessions.
- **FR-018**: The system shall support administrative addition, renaming, and icon configuration of sports.
- **FR-019**: The system shall support multi-sport athlete associations through the `athlete_sports` junction table.

### 3.4 Athlete & Roster Management (ATH)

- **FR-020**: The system shall manage athlete records including date of birth, medical notes, primary sport, and team assignment.
- **FR-021**: The system shall display medical clearance badges indicating whether an athlete is cleared for active play.
- **FR-022**: The system shall allow coaches and administrators to filter athletes by sport, team, and clearance status.
- **FR-023**: The system shall support athlete self-viewing of their profile, assigned squad, and medical records.
- **FR-024**: The system shall allow coaches to log athletic awards, medals, and recognitions linked to specific athlete profiles.
- **FR-025**: The system shall cascade-null team assignments if a team is dissolved or deleted.
- **FR-026**: The system shall display age calculation and date-of-birth validation on athlete forms.

### 3.5 Coaches Directory & Assignments (COACH)

- **FR-027**: The system shall maintain coach profiles including specialization, contact info, and team oversight.
- **FR-028**: The system shall link coaches to teams via `teams.coach_id` with foreign key `ON DELETE SET NULL`.
- **FR-029**: Coaches shall have write access to training sessions, match fixtures, attendance logs, and performance records.
- **FR-030**: The system shall provide a dedicated mobile Coach Flow (`coach_flow_page.dart`) with quick actions for attendance, training, and rosters.
- **FR-031**: The system shall restrict coach profile creation and salary editing to `Admin` and `HR` roles.
- **FR-032**: Coaches shall be able to update their own specialization and contact details.

### 3.6 Teams & Squad Administration (TEAM)

- **FR-033**: The system shall manage team entities linked to a specific sport (`sport_id`) and head coach (`coach_id`).
- **FR-034**: The system shall display current squad rosters with athlete counts for each team.
- **FR-035**: The system shall prevent team creation without a designated sport from the master sports catalog.
- **FR-036**: The system shall support team filtering by sport in both web and mobile dropdowns.
- **FR-037**: The system shall allow coaches to reassign athletes between teams.

### 3.7 Staff & Human Resources (STAFF)

- **FR-038**: The system shall maintain non-athletic staff records including department, designation, and hire dates.
- **FR-039**: The system shall restrict staff directory write access to `Admin` and `HR` users.
- **FR-040**: The system shall link staff records to monthly payroll entries in the `payroll` table.
- **FR-041**: Staff members shall be able to view their own designated role and contact information.
- **FR-042**: The system shall track department classifications including Administration, Maintenance, Logistics, and Medical.

### 3.8 Venues & Facility Management (VENUE)

- **FR-043**: The system shall maintain sports facilities and grounds with name, location, seating capacity, and status (`Active`/`Maintenance`).
- **FR-044**: The system shall store latitude and longitude coordinates for venues and provide interactive map viewing links.
- **FR-045**: The system shall manage venue bookings with start time, end time, purpose, and booking user tracking.
- **FR-046**: The system shall detect and prevent overlapping venue reservations for the same time interval.
- **FR-047**: Venue Managers and Admins shall have exclusive write access to venue records and maintenance tickets.
- **FR-048**: The system shall support venue maintenance issue logging with priority levels and resolution statuses.

### 3.9 Tournaments & Competitions (TOURN)

- **FR-049**: The system shall manage tournaments categorized by competitive level: `School`, `District`, `State`, `National`.
- **FR-050**: The system shall link tournaments to host venues and primary sports.
- **FR-051**: The system shall track tournament dates with validation ensuring `end_date >= start_date`.
- **FR-052**: The system shall group match fixtures under specific tournament parent entities.
- **FR-053**: The system shall display upcoming and past tournament listings with status indicators.

### 3.10 Match Fixtures & Scoring (MATCH)

- **FR-054**: The system shall schedule matches between Team A and Team B with assigned date, time, and venue.
- **FR-055**: The system shall manage match lifecycles through four states: `Scheduled`, `Live`, `Completed`, `Cancelled`.
- **FR-056**: The system shall record real-time scores (`score_a`, `score_b`) and text summary of results.
- **FR-057**: The system shall support sport-specific score formats (e.g., sets, goals, runs/wickets) via score helper utilities.
- **FR-058**: Coaches and Admins shall have permission to update match scores and finalize match results.
- **FR-059**: The system shall display recent match outcomes on both web and mobile executive dashboards.

### 3.11 Attendance & Leave Tracking (ATTEND)

- **FR-060**: The system shall record daily attendance for profiles with status: `Present`, `Absent`, `Late`, `Leave`.
- **FR-061**: The system shall enforce a uniqueness constraint ensuring one attendance record per user per day.
- **FR-062**: The system shall capture leave reasons when status is marked as `Leave` or `Absent`.
- **FR-063**: Athletes and staff shall have permission to self-log their own daily presence or leave.
- **FR-064**: Coaches, HR, and Admins shall have bulk marking capabilities across entire squads or departments.
- **FR-065**: The system shall provide 14-day and 30-day historical attendance trend summaries.

### 3.12 Equipment Inventory (INV)

- **FR-066**: The system shall track sports equipment and items with category, quantity, and condition rating (`Good`, `Fair`, `Poor`, `Damaged`).
- **FR-067**: The system shall alert users when equipment quantities fall below configurable threshold levels.
- **FR-068**: The system shall categorize items into Training Gear, Match Equipment, Protective Wear, and Facilities.
- **FR-069**: Admins and Venue Managers shall have write permissions to update stock quantities and conditions.
- **FR-070**: The system shall log equipment checkouts and returns associated with specific teams or venues.

### 3.13 Vendors & Purchase Orders (PURCH)

- **FR-071**: The system shall maintain a directory of equipment vendors with contact details and product categories.
- **FR-072**: The system shall generate purchase orders with vendor links, JSON line items (`name`, `qty`, `price`), and calculated total.
- **FR-073**: The system shall track purchase order status through: `Draft`, `Ordered`, `Received`, `Cancelled`.
- **FR-074**: The mobile dashboard shall surface pending purchase orders awaiting delivery as high-priority alert cards.
- **FR-075**: The system shall restrict PO creation and approval to `Admin` and `Finance` roles.
- **FR-076**: The system shall automatically update inventory stock when a purchase order is marked as `Received`.

### 3.14 Facility Housekeeping & Maintenance (HOUSE)

- **FR-077**: The system shall schedule facility housekeeping tasks with designated areas (e.g., "Main Stadium - Changing Room").
- **FR-078**: The system shall track housekeeping task statuses: `Pending`, `In Progress`, `Done`.
- **FR-079**: The system shall assign housekeeping tasks to specific custodial staff or service teams.
- **FR-080**: The system shall record scheduled cleaning dates and log completion timestamps.
- **FR-081**: Venue Managers shall receive dashboard alerts for overdue housekeeping tasks.

### 3.15 Athlete Care: Performance & Medical (CARE)

- **FR-082**: The system shall record physical performance metrics (e.g., "100m sprint", "VO2 max", "Bench Press") with date, value, and coach notes.
- **FR-083**: The system shall track medical examinations with record types: `Checkup`, `Injury`, `Physio`, `Clearance`.
- **FR-084**: The system shall enforce a boolean `cleared` flag on medical records indicating match fitness.
- **FR-085**: Athletes with `cleared = false` shall trigger an immediate non-cleared alert on team selection screens.
- **FR-086**: Medical records shall be visible only to Admins, Coaches, medical staff, and the specific athlete themselves.
- **FR-087**: The system shall maintain historical injury rehabilitation timelines and physio treatment sessions.
- **FR-088**: The system shall display performance metric progress charts across sequential test dates.

### 3.16 Logistics: Transport & Accommodation (LOGIST)

- **FR-089**: The system shall manage team transport itineraries with purpose, vehicle description, driver name, and departure/return times.
- **FR-090**: The system shall track transit status: `Planned`, `In Transit`, `Completed`.
- **FR-091**: The system shall coordinate hotel and lodging accommodations with hotel name, location, room counts, and check-in/out dates.
- **FR-092**: The system shall track accommodation reservation statuses: `Booked`, `Checked-in`, `Completed`.
- **FR-093**: Transport and accommodation records shall be linked to travelling teams via `team_id`.
- **FR-094**: Venue Managers, Coaches, and Admins shall have collaborative access to logistics schedules.

### 3.17 Financial Controls: Payroll & Expenses (FIN)

- **FR-095**: The system shall calculate monthly staff payroll with gross pay, deductions, and automatically generated net pay.
- **FR-096**: Net pay shall be enforced as a database-generated stored column (`net numeric(12,2) generated always as (gross - deductions) stored`).
- **FR-097**: The system shall restrict payroll generation and modification strictly to `Admin` and `Finance` roles.
- **FR-098**: Individual staff members shall be permitted to view only their own historical payroll slips via RLS.
- **FR-099**: The system shall record operational expenditures categorized under Equipment, Travel, Salary, and Other.
- **FR-100**: Expense records shall capture expenditure amount, date, description, and approving authority name.

### 3.18 School Activities & Events (EVENT)

- **FR-101**: The system shall log grassroots school sports outreach activities with partner school name, date, and participant count.
- **FR-102**: The system shall catalog organization-wide events (Ceremonies, Workshops, Annual Day) with venue links.
- **FR-103**: The system shall manage event classifications: `General`, `Ceremony`, `Workshop`, `Other`.
- **FR-104**: Coaches and Admins shall have authority to register and modify school outreach programs.
- **FR-105**: School activity participation numbers shall feed into organizational KPI reporting.

### 3.19 Analytics, Reports & Dashboards (REP)

- **FR-106**: The system shall display top-level metrics on web and mobile dashboards: Total Athletes, Coaches, Teams, Tournaments.
- **FR-107**: The dashboard shall surface actionable alert cards: Non-Cleared Athletes and Pending Purchase Orders.
- **FR-108**: The system shall render interactive analytical charts (Teams by Sport, Attendance Distribution, Expense Breakdown) using Recharts.
- **FR-109**: The system shall ensure consistent metric ordering and values across both React Web and Flutter Mobile dashboards.
- **FR-110**: The system shall support filtering and date-range selection across analytical reports.
