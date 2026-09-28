# User Stories Specification

---

| Field | Value |
|---|---|
| **Document ID** | SPORT-US-001 |
| **Project Name** | SportSphere — Integrated Sports Organization Management Platform |
| **Version** | 1.0 |
| **Document Type** | User Stories Specification |
| **Date** | 2026-09-28 |
| **Status** | IMPLEMENTED (Audited against codebase) |
| **Roles Covered** | Admin, Coach, Athlete, HR, Finance, VenueManager |

---

## 1. Overview

This document specifies the complete set of user stories implemented in **SportSphere**. Each user story follows the standardized agile format (`As a... I want to... So that...`), defines concrete acceptance criteria verified against the codebase, and maps directly to the corresponding Functional Requirements (from `FRS.md`).

---

## 2. User Stories by Persona

### 2.1 Super Administrator (Admin)

#### US-001: System Authentication & Environment Guard
- **As an** Administrator,
- **I want to** authenticate securely and be alerted if backend environment variables are missing,
- **So that** I can prevent unauthorized access and safeguard system integrity.
- **Acceptance Criteria**:
  1. Valid credentials in `Login.tsx` establish a Supabase session and redirect to `/`.
  2. Missing `VITE_SUPABASE_URL` or `VITE_SUPABASE_ANON_KEY` renders `ConfigError.tsx`.
  3. Demotion triggers prevent self-registered users from assuming the `Admin` role.
- **Traceability**: `FR-001`, `FR-003`, `FR-004`, `FR-008`

#### US-002: User Lifecycle & Account Soft Deletion
- **As an** Administrator,
- **I want to** soft delete inactive users and ban their login,
- **So that** they cannot access the system while preserving historical records.
- **Acceptance Criteria**:
  1. Clicking "Delete" invokes `admin_delete_user` RPC, setting `deleted_at = now()`.
  2. The target auth user is banned until `2099-01-01T00:00:00Z` in GoTrue.
  3. Soft-deleted users are moved to the "Deleted" tab in `Users.tsx` and hidden from regular lists.
  4. Attempting to delete the primary admin account raises an exception.
- **Traceability**: `FR-009`, `FR-010`, `FR-011`, `FR-014`

#### US-003: User Restoration & Permanent Purging
- **As an** Administrator,
- **I want to** either restore a soft-deleted user or permanently purge them,
- **So that** I have full control over user accounts and compliance data removal.
- **Acceptance Criteria**:
  1. "Restore" invokes `admin_restore_user`, clearing `deleted_at` and unbanning the auth account.
  2. "Permanent Delete" requires double-confirmation and invokes `admin_purge_user`.
  3. Permanent purge deletes the user's roster rows, profile row, and auth record with cascading cleanups.
- **Traceability**: `FR-012`, `FR-013`, `FR-014`

#### US-004: Centralized Sports Catalog Management
- **As an** Administrator,
- **I want to** manage the master list of official sports,
- **So that** all teams, tournaments, and training sessions reference consistent sport definitions.
- **Acceptance Criteria**:
  1. Admin can add, edit, or delete sports in `Sports.tsx`.
  2. Deleting a sport sets foreign keys in teams/tournaments to NULL.
  3. Default 10 sports are loaded via migration seed (`migrate_sports.sql`).
- **Traceability**: `FR-016`, `FR-017`, `FR-018`

---

### 2.2 Team Coach (Coach)

#### US-005: Squad Roster & Athlete Profile Inspection
- **As a** Coach,
- **I want to** view and manage athletes assigned to my squads,
- **So that** I can track player development and assign appropriate training positions.
- **Acceptance Criteria**:
  1. Coach can filter athletes by sport and team in `Athletes.tsx` / `athletes_page.dart`.
  2. Coach can add new athletes or edit player DOB and medical notes.
  3. Multi-sport participation is visible via `athlete_sports` badges.
- **Traceability**: `FR-020`, `FR-022`, `FR-026`

#### US-006: Medical Clearance Verification
- **As a** Coach,
- **I want to** see real-time medical clearance indicators for every athlete,
- **So that** I never field an injured or uncleared player in training or matches.
- **Acceptance Criteria**:
  1. Athletes with `cleared = false` in `medical_records` display a red clearance badge.
  2. Uncleared athletes appear in the "Athletes Not Cleared" dashboard alert card.
  3. Selecting an uncleared player displays a warning modal.
- **Traceability**: `FR-021`, `FR-084`, `FR-085`, `FR-107`

#### US-007: Training Sessions & Camp Scheduling
- **As a** Coach,
- **I want to** schedule practice sessions and training camps with venue allocations,
- **So that** my team adheres to structured physical preparation routines.
- **Acceptance Criteria**:
  1. Coach can create sessions with title, date, start/end time, venue, and team link.
  2. Session types support both "Session" and "Camp".
  3. Training schedules sync to the mobile schedule view (`schedule_page.dart`).
- **Traceability**: `FR-030`, `FR-032`, `FR-089`

#### US-008: Live Match Scorekeeping & Fixture Updates
- **As a** Coach,
- **I want to** update match scores and finalize results on match day,
- **So that** tournament brackets and team records reflect live game outcomes.
- **Acceptance Criteria**:
  1. Coach can update `score_a` and `score_b` during match play in `Matches.tsx`.
  2. Match status can transition through Scheduled -> Live -> Completed -> Cancelled.
  3. Result text summary can be entered upon completion.
- **Traceability**: `FR-054`, `FR-055`, `FR-056`, `FR-058`

#### US-009: Athletic Performance Logging
- **As a** Coach,
- **I want to** record objective physical performance metrics for athletes,
- **So that** I can quantitatively evaluate player endurance and skill gains.
- **Acceptance Criteria**:
  1. Coach can log metric name (e.g. "VO2 Max", "100m Sprint"), test value, and date.
  2. Records are linked to the athlete via foreign key in `performance_records`.
  3. Historical benchmarks are visible in the athlete's detail view.
- **Traceability**: `FR-082`, `FR-088`

---

### 2.3 Athlete / Player (Athlete)

#### US-010: Daily Attendance & Leave Self-Logging
- **As an** Athlete,
- **I want to** mark my daily attendance or submit a leave notice,
- **So that** coaching staff are informed of my availability for practice.
- **Acceptance Criteria**:
  1. Athlete can log Present, Absent, Late, or Leave for the current date.
  2. Selecting "Leave" prompts for a mandatory text explanation in `leave_reason`.
  3. The system enforces the database constraint of one record per date.
- **Traceability**: `FR-060`, `FR-061`, `FR-062`, `FR-063`

#### US-011: Personal Profile & Medical Status Review
- **As an** Athlete,
- **I want to** inspect my personal training schedule, awards, and medical clearance,
- **So that** I can track my fitness progress and match readiness.
- **Acceptance Criteria**:
  1. Athlete can view their assigned team, sport, and upcoming matches in `Profile.tsx`.
  2. Athlete can view their own medical clearance status and doctor notes.
  3. Athlete is restricted from viewing medical records of other teammates.
- **Traceability**: `FR-015`, `FR-023`, `FR-086`

---

### 2.4 Human Resources (HR)

#### US-012: Staff Directory & Personnel Records
- **As an** HR Manager,
- **I want to** maintain records of non-athletic staff across departments,
- **So that** all administrative and operations personnel are tracked.
- **Acceptance Criteria**:
  1. HR user can create, edit, or archive staff in `Staff.tsx`.
  2. Department and designation fields are mandatory.
  3. Staff profiles link directly to `public.profiles`.
- **Traceability**: `FR-038`, `FR-039`, `FR-042`

#### US-013: Organization-Wide Attendance Auditing
- **As an** HR Manager,
- **I want to** audit attendance records across all coaches, staff, and athletes,
- **So that** I can verify working hours, compliance, and leave balances.
- **Acceptance Criteria**:
  1. HR user has read and write access to all attendance records in `Attendance.tsx`.
  2. Historical roll-calls can be filtered by date range and department.
  3. Unexcused absences can be flagged for disciplinary follow-up.
- **Traceability**: `FR-060`, `FR-064`, `FR-065`

---

### 2.5 Finance Officer (Finance)

#### US-014: Monthly Staff Payroll Computation
- **As a** Finance Officer,
- **I want to** generate and review monthly payroll for club personnel,
- **So that** salaries are accurately calculated with statutory deductions.
- **Acceptance Criteria**:
  1. Finance user enters staff ID, gross pay, deductions, and payroll month in `PayrollPage`.
  2. The system computes `net` pay automatically as `(gross - deductions)`.
  3. Payroll slips can be viewed by individual staff members for their own record only.
- **Traceability**: `FR-040`, `FR-095`, `FR-096`, `FR-097`, `FR-098`

#### US-015: Operational Expense Tracking & Categorization
- **As a** Finance Officer,
- **I want to** log and categorize operational expenditures,
- **So that** club budgets for travel, equipment, and facilities remain balanced.
- **Acceptance Criteria**:
  1. Expenses are logged with category (Equipment, Travel, Salary, Other), amount, and date.
  2. Approving authority is recorded in `approved_by`.
  3. Expense analytics render breakdown visualizations in `Reports.tsx`.
- **Traceability**: `FR-099`, `FR-100`, `FR-108`

#### US-016: Equipment Vendor & Purchase Order Lifecycle
- **As a** Finance Officer,
- **I want to** issue purchase orders to approved vendors and track delivery,
- **So that** sports equipment procurement is transparent and audited.
- **Acceptance Criteria**:
  1. PO contains vendor reference, JSON item array (`name`, `qty`, `price`), and total cost.
  2. Status transitions through: Draft -> Ordered -> Received -> Cancelled.
  3. Pending POs awaiting delivery generate alert cards on the dashboard.
- **Traceability**: `FR-071`, `FR-072`, `FR-073`, `FR-074`, `FR-075`

---

### 2.6 Venue & Facilities Manager (VenueManager)

#### US-017: Sports Facility Profiles & GPS Geolocation
- **As a** Venue Manager,
- **I want to** maintain facility specifications with capacity and GPS coordinates,
- **So that** visiting teams and organizers can navigate to the correct grounds.
- **Acceptance Criteria**:
  1. Venue creation captures name, address, seating capacity, latitude, and longitude.
  2. `Venues.tsx` displays clickable map links opening Google Maps at exact coordinates.
  3. Facility status can be toggled between `Active` and `Maintenance`.
- **Traceability**: `FR-043`, `FR-044`, `FR-047`

#### US-018: Facility Booking Slot Coordination
- **As a** Venue Manager,
- **I want to** manage ground reservations and prevent conflicting bookings,
- **So that** facilities are efficiently shared between training and official tournaments.
- **Acceptance Criteria**:
  1. Venue bookings record venue ID, booking profile, start time, end time, and purpose.
  2. The booking calendar visually distinguishes scheduled matches from team training.
  3. Venue Managers and Admins can approve or cancel reservation slots.
- **Traceability**: `FR-045`, `FR-046`

#### US-019: Housekeeping Task Scheduling & Status Tracking
- **As a** Venue Manager,
- **I want to** assign housekeeping tasks to custodial teams,
- **So that** changing rooms, pitches, and stands meet cleanliness standards.
- **Acceptance Criteria**:
  1. Task creation specifies facility area, description, assigned worker, and target date.
  2. Status updates flow from `Pending` -> `In Progress` -> `Done`.
  3. Overdue housekeeping items are flagged on facility management screens.
- **Traceability**: `FR-077`, `FR-078`, `FR-079`, `FR-080`, `FR-081`

#### US-020: Team Travel & Transit Coordination
- **As a** Venue Manager or Logistics Coordinator,
- **I want to** arrange bus transport for away matches and tournaments,
- **So that** athletes and coaching staff arrive safely and punctually.
- **Acceptance Criteria**:
  1. Transport entry records vehicle number, driver name, route purpose, and departure time.
  2. Transit status tracks `Planned`, `In Transit`, and `Completed`.
  3. Transport itinerary links directly to the traveling team via `team_id`.
- **Traceability**: `FR-089`, `FR-090`, `FR-093`, `FR-094`

#### US-021: Hotel & Squad Lodging Management
- **As a** Venue Manager or Logistics Coordinator,
- **I want to** book and monitor team hotel accommodations,
- **So that** out-of-town squads have verified lodging during multi-day tournaments.
- **Acceptance Criteria**:
  1. Accommodation record captures hotel name, address, room allocation, and check-in/out dates.
  2. Reservation status transitions from `Booked` to `Checked-in` to `Completed`.
  3. Lodging records link to the traveling squad.
- **Traceability**: `FR-091`, `FR-092`, `FR-093`, `FR-094`

---

### 2.7 Cross-Role & System Analytics

#### US-022: Executive KPI Dashboard & Real-Time Sync
- **As an** Executive or Athletic Director,
- **I want to** monitor live organization metrics on web and mobile devices,
- **So that** I have an instant overview of organizational health and pending alerts.
- **Acceptance Criteria**:
  1. Top stat row presents counts in canonical sequence: Athletes, Coaches, Teams, Tournaments.
  2. Alert cards immediately surface pending PO deliveries and uncleared athletes.
  3. Supabase Realtime channels push live fixture and score updates across connected devices.
- **Traceability**: `FR-106`, `FR-107`, `FR-108`, `FR-109`
