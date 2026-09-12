# SportSphere

Sports-organization management platform — one shared Supabase backend, two frontends:

| App | Stack | For | Folder |
|---|---|---|---|
| **Web admin** | React + Vite + TypeScript + Recharts | Admin / Staff / HR | `web/` |
| **Mobile app** | Flutter (Android) | Coaches / Athletes | `mobile/` |
| **Database** | Supabase (Postgres + Auth + RLS) | both | `supabase/` |

---

## 1. Environment (already configured)

All secrets live in the **root `.env`** (gitignored). Fields:

```
SUPABASE_URL=            # project URL
SUPABASE_ANON_KEY=       # anon public key
SUPABASE_ACCESS_TOKEN=   # management token (DB pushes via CLI/API)
VITE_SUPABASE_URL=...    # auto-forwarded, do not edit
VITE_SUPABASE_ANON_KEY=...
```

`.env.example` is the committed template. `do not touch.txt` is also gitignored.

- **Project ref:** `bkozdelbgxezaewoxwqs` (SportsSphere, Singapore)
- **CLI linked:** `supabase/` → this project

## 2. Database

Schema lives in three files, **all already applied** to the project:

| File | Contents |
|---|---|
| `supabase/schema.sql` | Core tables (people, teams, tournaments, matches, venues, attendance…), RLS, signup trigger |
| `supabase/modules.sql` | Phase 2/3 tables: purchases, housekeeping, training, performance, medical, events, transport, accommodation, expenses, school activities |
| `supabase/seed.sql` / `modules_seed.sql` | Demo data |
| `supabase/relink.sql` | One-off fix that linked demo data to real auth users |

To re-apply after edits:

```bash
TOKEN=$(grep -o 'sbp_[a-f0-9]*' .env | head -1)
python -c "import json;print(json.dumps({'query': open('supabase/schema.sql', encoding='utf-8').read()}))" > /tmp/p.json
curl -s -X POST "https://api.supabase.com/v1/projects/bkozdelbgxezaewoxwqs/database/query" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d @/tmp/p.json
# repeat for the other .sql files
```

**Auth notes (important):**
- Demo users are created via the **official admin API** (`scripts/create_demo_users.py`) — do NOT insert into `auth.users` directly; hosted GoTrue rejects those rows.
- `mailer_autoconfirm` is ON → sign-ups work instantly with no email verification (perfect for the demo).
- Demo accounts (password `Passw0rd!`): `admin@`, `coach@`, `coach2@`, `athlete@`, `athlete2@`, `athlete3@`, `athlete4@`, `hr@` — all `@sportsphere.app`.

## 3. Web app

```bash
cd web
npm install        # first time only
npm run dev        # dev server
npx tsc -b         # typecheck
npx vite build     # production build → dist/
```

Reads `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` from root `.env`.

Modules: Dashboard, Reports (charts), Athletes, Coaches, Teams, Staff & HR,
Tournaments, Fixtures & Results (live score editing), Venues, Attendance &
Leave (daily marking), Inventory, Vendors & Purchases, Housekeeping,
Finance & Expenses, Training & Camps, School Activities, Events, Transport,
Accommodation, Athlete Performance, Athlete Medical — **all 21 modules**.

## 4. Mobile app (per the Android build playbook)

```bash
cd mobile
export PATH="/c/Users/Naman Gaonkar/flutter/bin:$PATH"

flutter analyze                                   # must be clean

flutter build apk --release --target-platform android-arm64 \
  --dart-define=SUPABASE_URL="https://bkozdelbgxezaewoxwqs.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="<anon key from .env>"
# → build/app/outputs/flutter-apk/app-release.apk (~17.5MB)
```

Install on USB-connected phone:

```bash
ADB="/c/Users/Naman Gaonkar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
"$ADB" devices                                                    # must show "device"
"$ADB" install -r build/app/outputs/flutter-apk/app-release.apk
"$ADB" shell am start -n com.sportsphere.sportsphere/.MainActivity
```

Screens: Home (profile + next match), Schedule (fixtures/results),
Attendance (mark today + 14-day history), Alerts (notification center),
Profile (details + sign out).

## 5. Build status (as of today)

- [x] Supabase: schema + RLS + all module tables applied; logins verified via REST
- [x] Sign-up works on web and mobile (autoconfirm enabled, no email round-trip)
- [x] Release APK has INTERNET permission (root cause of the earlier SocketException — fixed)
- [x] Web: typecheck clean, production build OK, all 21 modules
- [x] Flutter: analyze clean, APK rebuilt (17.5MB) and installed on phone
- [ ] Optional next: push notifications, storage buckets for athlete documents
