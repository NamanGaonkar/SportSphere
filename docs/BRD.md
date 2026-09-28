# Business Requirements Document (BRD)

---

| Field | Value |
|---|---|
| **Document ID** | SPORT-BRD-001 |
| **Project Name** | SportSphere — Integrated Sports Organization Management Platform |
| **Version** | 1.0 |
| **Document Type** | Business Requirements Document |
| **Date** | 2026-09-28 |
| **Status** | IMPLEMENTED (Audited against codebase) |
| **Target Audience** | Executive Leadership, Athletic Directors, Coaches, Operations Managers, Developers |

---

## 1. Executive Summary

**SportSphere** is a multi-role, unified enterprise sports organization and academy management platform. It addresses the operational, administrative, athletic, and logistical challenges faced by modern sports clubs, training academies, collegiate athletic departments, and tournament organizations.

Built with a unified cloud architecture, SportSphere connects a **React 18 + Material-UI (MUI v5)** Web Administration Console with a high-performance **Flutter (Material 3)** Cross-Platform Mobile Application, powered by a scalable **Supabase (PostgreSQL 15+)** backend with Row Level Security (RLS) and real-time event synchronization.

The platform unifies 27 relational domain entities across 8 operational pillars: athlete lifecycle management, coach operations, team and competition administration, facility and venue booking, logistical transport and accommodation, financial and payroll controls, equipment inventory, and medical clearance tracking.

---

## 2. Business Problem & Market Need

Sports organizations and academies frequently operate in a fragmented technological environment characterized by:

1. **Information Silos**: Athletic records, physical fitness benchmarks, and medical clearances are maintained in spreadsheets, paper files, or disconnected third-party apps.
2. **Delayed Operational Workflows**: Coaches, venue managers, and transport coordinators communicate via ad-hoc messaging, causing scheduling conflicts and double-booked facilities.
3. **Privilege Escalation Risks**: Legacy internal tools lack granular role-based access control (RBAC), exposing sensitive athlete health records and confidential payroll data.
4. **Disjointed Competition Tracking**: Tournament brackets, live match fixtures, and multi-sport scoring systems are rarely linked directly to player attendance and injury statuses.
5. **Inefficient Logistics Coordination**: Team travel, hotel accommodations, vehicle routing, and vendor purchase approvals lack unified audit trails, increasing operational overhead.
6. **Mobile Field Accessibility**: Coaches on the pitch and athletes in transit lack real-time access to daily schedules, attendance rosters, and notifications without logging into desktop web portals.

---

## 3. Business Opportunity & Strategic Value

SportSphere eliminates operational friction by providing:

- **Centralized Single Source of Truth**: Unified Supabase database storing athletes, staff, teams, fixtures, inventory, and finances with zero duplication.
- **Role-Centric Web & Mobile Synergy**: High-density management console for administrative and financial executives on web; agile, low-latency mobile interfaces for coaches and athletes.
- **Hardened Multi-Role Security Model**: Strict database-level Row Level Security (RLS) combined with anti-privilege escalation triggers and soft-delete safeguards.
- **Live Match & Competition Engine**: Multi-sport scoring, tournament ladder progression, and venue allocation engine.
- **Holistic Athlete Care**: Comprehensive logging of medical diagnoses, physio notes, clearance certifications, and fitness performance metrics.
- **Financial & Operational Traceability**: Granular tracking of vendor purchase orders, payroll disbursements, expense approvals, and facility maintenance tasks.

---

## 4. Business Objectives

The business objectives for SportSphere are categorized with unique identifiers and verified against active system implementations:

| ID | Business Objective | Target Metric / Outcome | Priority |
|---|---|---|:---:|
| **BO-001** | **Centralize Athletic & Roster Operations** | Unify all athlete, coach, and staff profiles with sport-specific assignments and team affiliations in one system. | High |
| **BO-002** | **Enforce Role-Based Access & Data Privacy** | Isolate medical, payroll, and administrative data using database-enforced RLS across 6 defined organizational roles. | Critical |
| **BO-003** | **Streamline Competitions & Match Fixtures** | Automate tournament scheduling, match status lifecycles, multi-sport scorekeeping, and venue reservations. | High |
| **BO-004** | **Digitize Daily Attendance & Leave** | Provide self-service attendance for athletes/staff and rapid multi-student roll-call marking for coaches and administrators. | High |
| **BO-005** | **Automate Facility & Logistics Management** | Coordinate venue bookings, preventive maintenance logs, vehicle transport rosters, and team hotel stays. | Medium |
| **BO-006** | **Ensure Medical Clearance Compliance** | Prevent non-cleared or injured athletes from participating in matches and training through mandatory medical flags. | Critical |
| **BO-007** | **Standardize Inventory & Purchase Orders** | Monitor equipment stock levels, condition ratings, vendor catalogs, and multi-tier purchase order statuses. | High |
| **BO-008** | **Deliver Real-Time Cross-Platform Parity** | Maintain identical live statistics, navigation structure, and brand aesthetic across desktop web and mobile clients. | High |
| **BO-009** | **Audit Trail & Safe User Lifecycle** | Support soft deletion, account suspension, and permanent cascading purge with strict protection of the root admin. | Critical |

---

## 5. Stakeholder Groups

| Stakeholder | Description & Primary Interest |
|---|---|
| **Executive Leadership** | Athletic Directors, General Managers, and Club Owners requiring high-level analytics, headcount oversight, and compliance auditing. |
| **Head Coaches & Training Staff** | On-field coaches and trainers requiring attendance rosters, fixture management, training camp schedules, and performance logs. |
| **Athletes & Players** | Club members tracking personal training schedules, match rosters, attendance records, and personal health clearance. |
| **Human Resources (HR)** | Personnel officers managing staff employment, designations, employee attendance, and leave requests. |
| **Finance & Procurement Officers** | Accountants handling payroll disbursements, expense claim validations, vendor invoices, and purchase orders. |
| **Venue & Facilities Managers** | Field superintendents coordinating ground bookings, housekeeping tasks, equipment inventory, and facility repairs. |

---

## 6. User Roles & Access Architecture

SportSphere enforces six canonical roles defined in the database `user_role` enum (`schema.sql`):

| Role Value | Display Name | Core Responsibilities & System Privileges |
|---|---|---|
| `Admin` | Super Administrator | Absolute system control. User creation/suspension/purge, sports master catalog, system-wide configuration, and full destructive rights. |
| `Coach` | Team Coach | Squad selection, training sessions, match scorekeeping, performance evaluations, and school sports activities. |
| `Athlete` | Registered Player | Personal profile management, daily attendance logging, schedule viewing, and personal medical/performance review. |
| `HR` | Human Resources | Staff roster administration, employee contracts, attendance auditing, and department management. |
| `Finance` | Financial Controller | Payroll calculation/generation, operational expense tracking, vendor purchase order management, and financial summaries. |
| `VenueManager`| Facilities Supervisor | Venue profile creation, GPS coordinate mapping, booking reservations, maintenance scheduling, and housekeeping tasks. |

---

## 7. Business Workflows & Operational Processes

### 7.1 Competition & Match Day Workflow
```
[Admin / Coach] creates Tournament (Level, Dates, Venue, Sport)
      |
      v
[Admin / Coach] schedules Match between Team A & Team B
      |
      v
[System] checks Athlete Medical Clearance & Roster Eligibility
      |
      v
[Venue Manager] reserves Venue Slot (Venue Bookings)
      |
      v
[Transport Manager] schedules Team Bus / Logistics
      |
      v
[Coach] marks Match Status: Scheduled -> Live -> Completed
      |
      v
[Coach] records Final Scores & Match Result Details
      |
      v
[System] updates Tournament standings & athlete performance logs
```

### 7.2 User Onboarding & Privilege Lockdown Workflow
```
User Signs Up via Web or Mobile Client
      |
      v
Database Trigger `on_auth_user_created` fires
      |
      +---> Checks Requested Role in Metadata
      |        |
      |        +-- 'Admin' requested? -> Demoted automatically to 'Athlete'
      |        +-- Valid public role? -> Profile created with requested role
      |
      v
User Account is Active (Profile linked via UUID to auth.users)
      |
      v
Admin can upgrade/modify roles via Web Admin Console
(Trigger blocks any direct non-admin promotion)
```

### 7.3 User Suspension, Soft-Delete & Purge Lifecycle
```
[Admin] selects User in Web/Mobile User Management Console
      |
      +---> [Option 1: Soft Delete]
      |        |
      |        +-- Sets `profiles.deleted_at = now()`
      |        +-- Calls `admin_delete_user` RPC
      |        +-- Sets `auth.users.banned_until = 2099-01-01`
      |        +-- User hidden from all standard queries via RLS
      |        \-- User appears in Admin "Deleted" Tab for potential Restore
      |
      +---> [Option 2: Restore]
      |        |
      |        +-- Calls `admin_restore_user` RPC
      |        +-- Clears `deleted_at` timestamp & clears `banned_until`
      |        \-- Account restored with original roster links intact
      |
      \---> [Option 3: Permanent Purge]
               |
               +-- Calls `admin_purge_user` RPC
               +-- Removes roster entries (athletes/coaches/staff)
               +-- Deletes `profiles` record (cascading dependent records)
               \-- Deletes `auth.users` authentication record permanently
```

---

## 8. Major Business Requirements

| Requirement ID | Module | Business Requirement Description | Priority |
|---|---|---|:---:|
| **BR-001** | Identity & Security | The system shall provide secure authentication with email/password and restrict self-registration to non-admin roles. | Critical |
| **BR-002** | Master Catalog | The system shall maintain a unified catalog of sports (10 default sports) as the authoritative reference for teams and events. | High |
| **BR-003** | Roster Management | The system shall manage full profiles for athletes, coaches, and staff members, supporting multi-sport athlete assignments. | High |
| **BR-004** | Competition Engine | The system shall track tournaments across School, District, State, and National levels with complete fixture scoring. | High |
| **BR-005** | Facility Logistics | The system shall manage venue listings, GPS coordinates, interactive booking slots, and maintenance tickets. | High |
| **BR-006** | Roll-Call & Leave | The system shall record daily attendance statuses (Present, Absent, Late, Leave) with monthly reporting. | High |
| **BR-007** | Athletic Care | The system shall track medical examinations, clearance statuses, and athletic performance benchmarks over time. | Critical |
| **BR-008** | Inventory & POs | The system shall monitor sports equipment inventory levels, condition states, and multi-status purchase orders. | High |
| **BR-009** | Travel Logistics | The system shall coordinate bus/transport itineraries and hotel accommodation bookings for traveling squads. | Medium |
| **BR-010** | Financial Controls | The system shall calculate gross/net payroll for staff and record categorized operational expenditures. | High |
| **BR-011** | Community Outreach | The system shall catalog grassroots school sports activities, workshops, and participation metrics. | Medium |
| **BR-012** | Mobile & Offline | The system shall deliver native mobile workflows for on-field coaches and traveling athletes. | High |

---

## 9. Scope Boundaries

### In-Scope (Implemented & Audited)
- Web admin portal built in React 18, Vite, TypeScript, and Material-UI.
- Mobile client built in Flutter with Material 3 design and Android APK target.
- Backend architecture running on Supabase PostgreSQL with 27 tables and RLS policies.
- Role management across 6 distinct personas with privilege gating.
- Full competition, tournament, match scorekeeping, and venue scheduling engines.
- Comprehensive athlete performance and medical clearance tracking.
- Operational housekeeping, equipment inventory, and purchase order tracking.
- Travel, transport, and hotel accommodation logistics.
- Payroll generation and categorized expense logging.
- Branded email notification templates for onboarding and password recovery.

### Out-of-Scope (Not Implemented / Future Roadmap)
- Direct integration with payment gateways (e.g., Stripe, Razorpay) for automated payroll bank transfers.
- Native GPS background tracking of transport buses in real-time.
- Automated optical character recognition (OCR) for paper medical clearance forms.
- Public fan-facing ticketing or live streaming video infrastructure.

---

## 10. Business Rules & Compliance Constraints

1. **Root Admin Immutability**: The primary administrative account (`ADMIN_EMAIL`) cannot be soft-deleted, modified to a non-admin role, or permanently purged under any circumstance (`migrate_user_deletion.sql`, `branding.sql`).
2. **Medical Clearance Mandate**: An athlete flagged as `cleared = false` in `medical_records` must be highlighted as a medical alert on dashboards and roster selections.
3. **Sports Normalization**: Teams, tournaments, and training sessions must reference valid UUIDs from the centralized `sports` master table; legacy string representations are strictly deprecated.
4. **Attendance Uniqueness**: An individual user profile can have at most one attendance record per calendar date (`unique(profile_id, date)` constraint).
5. **Brand & UI Compliance**: Both web and mobile applications must strictly adhere to the designated brand palette (`#FF6A13` primary orange, `#0D0D0D` dark background, `#FAFAF8` light background, Lato typography) with zero informal emojis across UI components.
