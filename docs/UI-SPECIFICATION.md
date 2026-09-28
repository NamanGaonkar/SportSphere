# Screen List & UI Specification

---

| Field | Value |
|---|---|
| **Document ID** | SPORT-UI-001 |
| **Project Name** | SportSphere — Integrated Sports Organization Management Platform |
| **Version** | 1.0 |
| **Document Type** | Screen List & UI Specification |
| **Date** | 2026-09-28 |
| **Status** | IMPLEMENTED (Audited against codebase) |
| **Frontends Inspected** | Web (`web/src/`), Mobile (`mobile/lib/`) |

---

## 1. Design System & Visual Guidelines

SportSphere enforces a unified design system shared across both web and mobile clients:

| Design Token | Specification | Implementation Detail |
|---|---|---|
| **Primary Typography** | **Lato** (Google Fonts / Bundled TTFs) | Clean, athletic sans-serif bundled in `mobile/assets/fonts/` and imported in `web/index.html`. |
| **Primary Brand Color** | `#FF6A13` | Vibrant athletic orange used for CTAs, active states, and brand highlights. |
| **Hover / Focus Orange** | `#FF8A42` | Brightened orange for button hover states, focus rings, and active tab indicators. |
| **Dark Neutral / Charcoal** | `#0D0D0D` | Deep black used for sidebar navigation background and dark headers. |
| **Light Canvas / Surface** | `#FAFAF8` | Off-white canvas for data tables, cards, and mobile screen backgrounds. |
| **Spacing Grid** | 8px, 16px, 24px, 32px | Strict 8-point baseline grid for margins, paddings, and component rhythm. |
| **Iconography Standard** | Material Icons (MUI Icons / Flutter Material) | Professional glyphs only. **Strict zero-emoji policy** across all UI screens. |

---

## 2. Navigation Architecture & Shell Hierarchy

### 2.1 Web Application Layout (`App.tsx`)
The web console features a persistent collapsible sidebar navigation drawer divided into 7 logical operational sections:

```
[ Top App Bar: Brand Logo | Current Section Title | Profile Pill | Logout Button ]
+-------------------+-------------------------------------------------------------+
| SIDEBAR           | MAIN CONTENT VIEW (Animated with PageTransition)            |
|                   |                                                             |
| > OVERVIEW        | [Breadcrumbs / Page Header]                                 |
|   Dashboard       |                                                             |
|   Reports         | [Top Action Bar: Search Input | Filter Dropdowns | Add CTA] |
|                   |                                                             |
| > MY ACCOUNT      | [Data Table / Grid / Card Container]                        |
|   My Profile      | - Pagination controls (Rows per page, page selector)       |
|   User Management | - Sorting column headers                                    |
|                   | - Row action icons (Edit, View, Delete)                     |
| > PEOPLE          |                                                             |
|   Athletes, Coach |                                                             |
|   Teams, Staff    |                                                             |
|                   |                                                             |
| > COMPETITIONS    |                                                             |
|   Tourneys, Match |                                                             |
|   Venues, Sports  |                                                             |
|                   |                                                             |
| > OPERATIONS      |                                                             |
| > LOGISTICS       |                                                             |
| > ATHLETE CARE    |                                                             |
+-------------------+-------------------------------------------------------------+
```

### 2.2 Mobile Application Layout (`home_shell.dart`)
The Flutter mobile client features an adaptive layout:
- **Bottom Navigation Bar** with high-frequency quick-access tabs:
  1. `Dashboard` (Live metrics, alerts, quick links)
  2. `Matches & Schedule` (Live fixtures and scorecards)
  3. `Roster / Athletes` (Team lists and player cards)
  4. `My Profile` (Personal schedule, attendance, and health clearance)
- **Top App Bar** with notifications bell badge, current user avatar, and drawer trigger for extended operational modules (Inventory, Purchases, Venues, Staff).

---

## 3. Web Screen Catalog (29 Screens)

| Screen ID | Route / Path | Screen Name | Roles Permitted | Key Components & Functionality |
|---|---|---|---|---|
| **SCR-W01** | `/login` | Authentication Portal | Public | Email/password form, password reveal, loading indicators, auth error banner. |
| **SCR-W02** | `/config-error`| Configuration Guard | Public | Diagnostic message when Supabase URL or Anon key is unconfigured. |
| **SCR-W03** | `/` | Executive Dashboard | All Roles | 4 KPI cards (Athletes, Coaches, Teams, Tournaments), alert cards, recent matches. |
| **SCR-W04** | `/reports` | Analytics & Reports | Admin, HR, Finance, Coach | Recharts visualizations: Teams by Sport, Attendance Distribution, Expense breakdown. |
| **SCR-W05** | `/profile` | User Profile & Settings| All Roles | Display name, avatar preview, password reset, personal schedule/leave logs. |
| **SCR-W06** | `/users` | User Management | Admin | Active vs Deleted tabs, soft delete action, restore action, permanent purge modal. |
| **SCR-W07** | `/athletes` | Athletes Management | Admin, Coach, HR | Player list, DOB/age calculation, medical clearance badge, multi-sport chips. |
| **SCR-W08** | `/coaches` | Coaches Directory | Admin, HR | Coach list, coaching specialization, assigned squad badges. |
| **SCR-W09** | `/teams` | Teams & Squads | All Roles | Squad list, sport category filter, supervising coach name, athlete count. |
| **SCR-W10** | `/staff` | Staff & HR | Admin, HR | Non-athletic personnel registry, department dropdown, employee titles. |
| **SCR-W11** | `/tournaments`| Tournaments | All Roles | Tournament brackets, level chips (School, District, State, National), venue link. |
| **SCR-W12** | `/matches` | Fixtures & Scoring | All Roles | Match schedule cards, status toggles (Live/Completed), score entry inputs. |
| **SCR-W13** | `/venues` | Venues & Grounds | All Roles | Stadium profiles, seating capacity, status badge, clickable Google Maps links. |
| **SCR-W14** | `/sports` | Sports Master Catalog| Admin | Master catalog table, add/edit modal, icon selector. |
| **SCR-W15** | `/attendance` | Attendance & Leave | All Roles | 14-day attendance matrix, Present/Absent/Late/Leave buttons, leave reason input. |
| **SCR-W16** | `/inventory` | Equipment Inventory | All Roles | Gear list, category chips, condition status (`Good`/`Damaged`), low stock warning. |
| **SCR-W17** | `/housekeeping`| Housekeeping Tasks | Admin, VenueManager | Cleaning task cards, facility area filter, status pills (`Pending`/`Done`). |
| **SCR-W18** | `/maintenance`| Facility Maintenance | Admin, VenueManager | Repair tickets, severity indicator, scheduled maintenance dates. |
| **SCR-W19** | `/bookings` | Venue Reservations | All Roles | Ground booking calendar, start/end time pickers, reservation approval. |
| **SCR-W20** | `/purchases` | Vendors & Purchase Orders| Admin, Finance, HR | PO list, line-item builder (`name`, `qty`, `price`), PO status stepper. |
| **SCR-W21** | `/payroll` | Staff Payroll | Admin, Finance, HR | Monthly salary table, gross and deduction inputs, calculated net pay. |
| **SCR-W22** | `/expenses` | Financial Expenses | Admin, Finance, HR | Expenditure vouchers, category pie chart, receipt notes, approval manager. |
| **SCR-W23** | `/training` | Training Sessions & Camps| Admin, Coach | Practice session scheduler, drills notes, camp date ranges. |
| **SCR-W24** | `/activities`| School Sports Outreach| Admin, Coach | Grassroots clinics, partner school name, student participant counter. |
| **SCR-W25** | `/events` | Club Events & Ceremonies| All Roles | Event announcements, venue assignment, agenda description. |
| **SCR-W26** | `/transport` | Transport Logistics | Admin, VenueManager, Coach | Team bus itineraries, driver contact, departure/return time stamps. |
| **SCR-W27** | `/accommodation`| Lodging & Hotels | Admin, VenueManager, Coach | Hotel room reservations, squad check-in dates, lodging addresses. |
| **SCR-W28** | `/performance`| Athlete Benchmarks | All Staff Roles | Physical performance metric tables, test scores, progression logs. |
| **SCR-W29** | `/medical` | Medical & Injuries | All Staff Roles | Doctor consultations, injury diagnoses, physio notes, match clearance toggle. |

---

## 4. Mobile Screen Catalog (23 Screens)

| Screen ID | Mobile Source File | Screen Name | Functionality & Key Interactions |
|---|---|---|---|
| **SCR-M01** | `splash_page.dart` | Animated Splash Screen | Branded launch screen displaying SportSphere logo in `#FF6A13` on `#0D0D0D`. |
| **SCR-M02** | `onboarding_page.dart` | Welcome & Role Intro | Feature carousel introducing Athlete, Coach, and Management workflows. |
| **SCR-M03** | `login_page.dart` | Mobile Login | Clean authentication interface with input validation and password toggle. |
| **SCR-M04** | `home_shell.dart` | App Shell & Bottom Bar | Bottom navigation tabs, floating action buttons, and slide-out drawer. |
| **SCR-M05** | `home_shell.dart` | Mobile Dashboard | Top metric cards in exact order: Athletes, Coaches, Teams, Tournaments. Alert cards. |
| **SCR-M06** | `athlete_flow_page.dart`| Athlete Personal Portal | Personal upcoming matches, daily attendance status, and doctor clearance card. |
| **SCR-M07** | `coach_flow_page.dart` | Coach Field Hub | Squad selector, quick-tap attendance roll-call, and training session creator. |
| **SCR-M08** | `athletes_page.dart` | Mobile Athletes List | Searchable athlete list with sport chips, team badges, and medical alert dots. |
| **SCR-M09** | `coaches_page.dart` | Mobile Coaches Directory | Coach contact cards with tap-to-call and team responsibility tags. |
| **SCR-M10** | `teams_page.dart` | Mobile Teams List | Team cards with roster expanders and sport categorization. |
| **SCR-M11** | `tournaments_page.dart`| Mobile Tournaments | Tournament schedule cards with level chips and venue directions. |
| **SCR-M12** | `matches_admin_page.dart`| Mobile Match Scoring | Live match scorekeeping with quick +/- buttons and status transition sheet. |
| **SCR-M13** | `venues_admin_page.dart` | Mobile Venues & Maps | Venue details with direct one-tap opening in Google Maps or Apple Maps. |
| **SCR-M14** | `attendance_page.dart` | Self-Attendance Marking | One-tap daily roll-call marking for athletes and employees. |
| **SCR-M15** | `attendance_admin_page.dart`| Coach Roll-Call Grid | Fast multi-player roster roll-call check-off for training practices. |
| **SCR-M16** | `inventory_page.dart` | Mobile Inventory Sheet | Equipment counter with rapid increment/decrement stock adjustments. |
| **SCR-M17** | `purchases_page.dart` | Mobile Purchase Orders | Purchase order tracking sheet with delivery receipt confirmation. |
| **SCR-M18** | `users_page.dart` | Mobile User Management | Active/Deleted tab bar with bottom sheet for soft delete and account restoration. |
| **SCR-M19** | `staff_admin_page.dart` | Mobile Staff Directory | Employee department list with designation cards. |
| **SCR-M20** | `reports_page.dart` | Mobile Analytics & KPIs | Mobile-optimized charts displaying teams by sport and attendance trends. |
| **SCR-M21** | `schedule_page.dart` | Training Calendar | Chronological timeline of daily practice drills, matches, and team meetings. |
| **SCR-M22** | `notifications_page.dart`| Notifications Center | List of system alerts and match notifications with mark-as-read gestures. |
| **SCR-M23** | `profile_page.dart` | Mobile Profile & Theme | User avatar, name editing, role badge, and secure sign-out. |

---

## 5. UI States & Responsive Behavior

1. **Loading State**:
   - Web: Top-level `LinearProgress` indicator across the view container and skeleton placeholders for table rows.
   - Mobile: Material 3 circular progress indicator centered in the canvas.
2. **Empty State**:
   - Clean, friendly SVG graphic with informative header (e.g. "No fixtures scheduled") and prominent "Schedule Match" action button.
3. **Error State**:
   - Non-blocking snackbar toast for transient network glitches; full-screen error card with retry button for primary query failures.
4. **Responsive Breakpoints (Web)**:
   - `xs` (< 600px): Sidebar collapses into an overlay drawer; data tables convert to expandable stacked cards.
   - `sm` (600px - 960px): Sidebar defaults to mini-variant (icons only); charts stack vertically.
   - `md` & `lg` (> 960px): Full persistent sidebar (260px); multi-column grid dashboard layout.
