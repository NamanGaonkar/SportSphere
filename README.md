# SportSphere — Enterprise Sports Organization Management Platform

> **SportSphere** is a multi-role, unified enterprise sports organization and academy management platform. It combines a **React 18 + Material-UI (MUI v5)** Web Administration Console with a high-performance **Flutter (Material 3)** Cross-Platform Mobile Application, backed by a scalable **Supabase (PostgreSQL 15+)** cloud infrastructure with Row Level Security (RLS) and real-time data synchronization.

---

## 1. Project Overview

SportSphere eliminates administrative silos and operational friction in sports organizations by unifying athletic rosters, multi-sport competitions, facility reservations, equipment inventory, logistical travel, and financial accounting into a single real-time platform.

### Core System Architecture
```
                         +-----------------------------------------------+
                         |           Supabase Cloud Backend              |
                         |   (PostgreSQL 15+ | GoTrue Auth | RLS | RPC)  |
                         +-----------------------+-----------------------+
                                                 |
                       +-------------------------+-------------------------+
                       |                                                   |
                       v                                                   v
        +-----------------------------+                     +-----------------------------+
        |     Web Admin Console       |                     |    Cross-Platform Mobile    |
        |  React 18 + TypeScript +    |                     |  Flutter 3.x + Material 3   |
        |  Material-UI (MUI v5)       |                     |  (Android APK Target)       |
        |  For: Admin, Staff, HR, Fin |                     |  For: Coaches, Athletes     |
        +-----------------------------+                     +-----------------------------+
```

---

## 2. Key Features

- **Multi-Role Privilege Architecture**: 6 distinct organizational roles (`Admin`, `Coach`, `Athlete`, `HR`, `Finance`, `VenueManager`) protected by database-enforced Row Level Security (RLS).
- **Hardened User Lifecycle**: Anti-privilege escalation triggers demoting public admin requests, soft-deletion with GoTrue auth login bans (`banned_until`), and double-confirmed cascading permanent user purging.
- **Centralized Master Sports Catalog**: Authoritative source of truth for 10 core sports disciplines (Football, Cricket, Basketball, Athletics, Badminton, Table Tennis, Hockey, Volleyball, Swimming, Kabaddi) with multi-sport athlete support (`athlete_sports`).
- **Live Match & Tournament Engine**: Tournament bracket tracking across School, District, State, and National tiers with real-time scorekeeping (`score_a`, `score_b`) and match result summaries.
- **Athlete Care & Medical Clearance**: Medical diagnosis tracking with strict match fitness flags (`cleared = true/false`) that trigger immediate safety alerts on coaching rosters.
- **Facility & Logistics Coordination**: GPS-mapped sports grounds with clickable Google Maps directions, slot reservation calendar, housekeeping logs, bus transit itineraries, and hotel accommodations.
- **Equipment Inventory & Procurement**: Real-time stock counts with physical condition ratings (`Good`, `Fair`, `Poor`), supplier directory, and multi-state purchase orders (`Draft` -> `Ordered` -> `Received`).
- **Financial Controls & Payroll**: Staff payroll computation with automatic database-generated net pay (`(gross - deductions) STORED`), and categorized operational expense tracking.
- **Real-Time Cross-Platform Parity**: Identical top-level KPIs (Athletes, Coaches, Teams, Tournaments in exact order), shared branded design system (`#FF6A13`, Lato typography), and strict zero-emoji UI policy.

---

## 3. Technology Stack

| Layer | Technologies & Frameworks |
|---|---|
| **Web Frontend** | React 18.2, TypeScript 5, Vite, Material-UI (MUI v5), Emotion, Recharts 2.x, React Router DOM v6 |
| **Mobile Client** | Flutter 3.x, Dart 3.x, Material 3 Design System, Supabase Flutter SDK |
| **Backend & Database** | Supabase Cloud (PostgreSQL 15+), PostgREST 11+, GoTrue Auth, PL/pgSQL Stored Procedures |
| **Typography & Styling**| **Lato** (Google Fonts / bundled TTFs), Brand Primary `#FF6A13`, Dark `#0D0D0D`, Canvas `#FAFAF8` |
| **DevOps & Utilities** | Python 3 (Admin setup & data migrations), Docker / Supabase CLI |

---

## 4. Project Directory Structure

```text
SportSphere/
├── docs/                                # Formal Documentation Suite
│   ├── BRD.md                           # Business Requirements Document (10 Sections)
│   ├── FRS.md                           # Functional Requirements Specification (110 FRs)
│   ├── USER-STORIES.md                  # User Stories Specification (22 Stories + Acceptance Criteria)
│   ├── DATABASE-DESIGN.md               # Relational Database Design (27 Tables + Data Dictionary)
│   ├── REST-API-DESIGN.md               # REST & RPC API Specification (35 Endpoints)
│   ├── UI-SPECIFICATION.md              # Screen List & UI Specification (29 Web + 23 Mobile)
│   └── RTM.xlsx                         # Source-Aligned 10-Sheet Traceability Matrix (.xlsx)
├── mobile/                              # Cross-Platform Flutter Mobile Application
│   ├── assets/                          # Bundled Lato fonts and static brand images
│   ├── lib/
│   │   ├── data/                        # Supabase data models and repository helpers
│   │   ├── pages/                       # 23 Flutter mobile screens (Athlete, Coach, Admin flows)
│   │   ├── widgets/                     # Reusable Material 3 cards, badges, and sheets
│   │   └── main.dart                    # Mobile app entrypoint and theme definition
│   └── pubspec.yaml                     # Flutter dependencies and asset registrations
├── web/                                 # React + Vite Web Administration Console
│   ├── public/                          # Brand logos, icons, and background artwork
│   ├── src/
│   │   ├── components/                  # Reusable MUI tables, inputs, and PageTransition
│   │   ├── lib/                         # Supabase client, date helpers, and permission hooks
│   │   ├── pages/                       # 29 React views (Dashboard, Users, Athletes, Matches)
│   │   ├── App.tsx                      # Web router, collapsible drawer, and session state
│   │   ├── main.tsx                     # React DOM entrypoint
│   │   └── theme.ts                     # Material-UI theme with #FF6A13 palette & Lato font
│   ├── package.json                     # NPM dependencies and build scripts
│   └── vite.config.ts                   # Vite configuration and server proxy setup
├── supabase/                            # Database Schema, Migrations & Email Templates
│   ├── email_templates/                 # Branded HTML email templates (confirm, invite, reset)
│   ├── schema.sql                       # Core tables, enums, triggers, and baseline RLS
│   ├── modules.sql                      # Phase 2/3 tables (Purchases, Care, Logistics, Payroll)
│   ├── branding.sql                     # Anti-escalation signup trigger and admin protection
│   ├── migrate_sports.sql               # Normalized sports master table and backfill script
│   ├── migrate_user_deletion.sql        # Soft delete, account restore, and permanent purge RPCs
│   └── org_data_v2.sql                  # Comprehensive production baseline seed data
├── scripts/                             # Operational & Administrative Python Scripts
│   ├── create_admin.py                  # Fixed root administrator account creation script
│   ├── apply_email_templates.py         # Injects branded email templates via Supabase API
│   ├── cleanup_demo_data.py             # Wipes test data and resets database to clean state
│   └── fix_env.py                       # Normalizes line endings for cross-platform builds
└── README.md                            # Comprehensive Developer Manual & Setup Guide
```

---

## 5. Prerequisites & Environment Setup

### System Requirements
- **Node.js**: `v18.x` or `v20.x` LTS
- **Package Manager**: `npm` v9+ or `yarn`
- **Flutter SDK**: `v3.19+` (Required only if building or running the mobile app)
- **Python**: `v3.10+` with `requests` library (for administrative management scripts)
- **Supabase Account**: An active Supabase project with PostgreSQL 15+

### Environment Configuration (`.env`)
Create a `.env` file in the project root (`SportSphere/SportSphere/.env`):

```bash
# Supabase Project Connection
SUPABASE_URL=https://<your-supabase-project-id>.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_ACCESS_TOKEN=sbp_...                 # Required for management API scripts

# Primary Fixed Administrator Credentials
ADMIN_EMAIL=admin@sportsphere.org
ADMIN_PASSWORD=YourStrongAdminPassword123!

# Web App Environment Forwarding (Vite requires VITE_ prefix)
VITE_SUPABASE_URL=https://<your-supabase-project-id>.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## 6. Database Setup & Initialization

Execute the SQL scripts in your Supabase SQL Editor in the following sequential order:

1. **Core Schema & Security**: Run `supabase/schema.sql` (Creates custom enums, core tables, triggers, and baseline RLS policies).
2. **Extended Modules**: Run `supabase/modules.sql` (Creates purchase orders, housekeeping, medical records, performance, travel, and payroll).
3. **Sports Normalization**: Run `supabase/migrate_sports.sql` (Creates master sports catalog, multi-sport junction, and links).
4. **User Deletion & Purge Engine**: Run `supabase/migrate_user_deletion.sql` (Creates soft-delete RPCs, login bans, and purge cascades).
5. **Brand & Role Hardening**: Run `supabase/branding.sql` (Installs signup role interceptor and immutable admin guard).
6. **Seed Initial Data**: Run `supabase/org_data_v2.sql` (Populates official sports, demo squads, and facility records).

### Create the Master Administrator Account
Run the administrative setup script from the root directory:
```bash
python scripts/create_admin.py
```
*Note: This script reads `ADMIN_EMAIL` and `ADMIN_PASSWORD` from `.env`, creates the user in GoTrue Auth, and promotes their profile to `Admin` in `public.profiles`.*

### Apply Branded Email Templates
```bash
python scripts/apply_email_templates.py
```

---

## 7. How to Run Locally

### Running the Web Admin Console
```bash
# 1. Navigate to web directory
cd web

# 2. Install dependencies
npm install

# 3. Start local development server
npm run dev
```
Open [http://localhost:5173](http://localhost:5173) in your browser.

### Building the Web Application for Production
```bash
npm run build
```
The optimized production bundle will be generated in `web/dist/`.

---

### Running the Flutter Mobile App
```bash
# 1. Navigate to mobile directory
cd mobile

# 2. Get Flutter dependencies
flutter pub get

# 3. Normalize environment line endings (CRLF -> LF)
python ../scripts/fix_env.py

# 4. Launch in Android Emulator or connected physical device
flutter run \
  --dart-define=SUPABASE_URL="https://<your-supabase-project-id>.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="<your-supabase-anon-key>"
```

### Building the Production Android APK
```bash
flutter build apk --release --target-platform android-arm64 \
  --dart-define=SUPABASE_URL="https://<your-supabase-project-id>.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="<your-supabase-anon-key>"
```
The compiled APK will be located at `mobile/build/app/outputs/flutter-apk/app-release.apk`.

---

## 8. Deployment Procedure

### Web Application Deployment (Vercel / Netlify / Cloudflare Pages)
The web application is fully configured for deployment on modern static hosting platforms:
- **Build Command**: `npm run build`
- **Output Directory**: `dist`
- **Routing**: `web/vercel.json` contains single-page application (SPA) rewrite rules routing all requests to `index.html`.
- **Environment Variables**: Configure `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in the hosting dashboard.

### Mobile App Deployment (Google Play Store)
1. Generate an Android release keystore: `keytool -genkey -v -keystore upload-keystore.jks ...`
2. Configure signing credentials in `mobile/android/key.properties`.
3. Build the signed app bundle: `flutter build appbundle --release --dart-define=...`

---

## 9. Default Test Credentials & Roles

*(Safe local demo accounts provisioned via `org_data_v2.sql`)*

| Persona | Email | Default Password | Role Privileges |
|---|---|---|---|
| **Super Administrator** | `admin@sportsphere.org` | *Configured via `.env`* | Complete administrative and destructive control. |
| **Head Coach** | `coach@sportsphere.org` | `SportSphere2026!` | Roster selection, live scoring, training camps. |
| **Lead Athlete** | `athlete@sportsphere.org` | `SportSphere2026!` | Self-attendance, personal schedule, medical status. |
| **HR Manager** | `hr@sportsphere.org` | `SportSphere2026!` | Non-athletic staff directory and leave auditing. |
| **Financial Controller**| `finance@sportsphere.org` | `SportSphere2026!` | Staff payroll, operational expenses, purchase orders. |
| **Facilities Manager** | `venue@sportsphere.org` | `SportSphere2026!` | Grounds, maintenance tickets, housekeeping tasks. |

---

## 10. Known Limitations & Technical Notes

1. **Offline Sync**: While the Flutter mobile app caches basic profile information, write operations (score updates, roll-calls) require an active internet connection to commit to live Supabase tables.
2. **Simulated Payment Gateway**: Payroll generation and expense vouchers compute financial line items accurately within the database, but do not execute automated real-time wire transfers to external banking APIs.
3. **Primary Admin Account Protection**: By design, the primary root administrator defined in `.env` cannot be deleted or purged through the UI. Any attempt will trigger a database-level PL/pgSQL exception.
