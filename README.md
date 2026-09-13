# SportSphere

Sports-organization management platform — one shared Supabase backend, two frontends:

| App | Stack | For | Folder |
|---|---|---|---|
| **Web admin** | React + Vite + TypeScript + MUI (Material) + Recharts | Admin / Staff / HR | `web/` |
| **Mobile app** | Flutter (Android) with Material 3 | Coaches / Athletes | `mobile/` |
| **Database** | Supabase (Postgres + Auth + RLS) | both | `supabase/` |

Design system (shared across web, mobile and email): **Lato** font, orange `#FF6A13`,
hover orange `#FF8A42`, black `#0D0D0D`, background `#FAFAF8`, 8/16/24/32 spacing grid.
No emojis anywhere in the UI.

---

## 1. Environment (root `.env`, gitignored)

```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
SUPABASE_ACCESS_TOKEN=...   # for management API scripts
ADMIN_EMAIL=...             # single admin account
ADMIN_PASSWORD=...
```

`VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` lines at the bottom forward credentials
to the web app. The mobile app receives them at build time via `--dart-define`.

## 2. Auth model

- **One fixed admin account.** Create/reset it with `python scripts/create_admin.py`
  (uses `ADMIN_EMAIL` + `ADMIN_PASSWORD` from `.env`).
- Public signup offers only: Athlete, Coach, HR, Finance, VenueManager.
  The signup trigger (`supabase/branding.sql`) force-demotes any 'Admin' request,
  and a DB trigger blocks self-assigning Admin even directly.
- Admin can be granted only from the SQL editor:
  `update public.profiles set role='Admin' where id=(select id from auth.users where email='...');`
- Email templates are branded (black/orange/Lato) in `supabase/email_templates/`,
  applied to the project via `python scripts/apply_email_templates.py`.

## 3. Database

- `supabase/schema.sql` — core tables, RLS, signup trigger.
- `supabase/modules.sql` — Phase 2/3 module tables.
- `supabase/branding.sql` — signup-role hardening + admin protection.
- `scripts/cleanup_demo_data.py` — wipes all rows + auth users (production reset).

Both apps read/write the same live Supabase tables. There is no seed/demo data,
no mock datasets, and no cached duplicates anywhere.

## 4. Run the web app

```bash
cd web
npm install
npm run dev        # http://localhost:5173
npm run build      # typecheck + production build
```

## 5. Build + install the mobile app

```bash
export PATH="/c/Users/Naman Gaonkar/flutter/bin:$PATH"
cd mobile
flutter analyze
python ../scripts/fix_env.py   # normalize .env to LF — CRLF breaks the dart-define values
flutter build apk --release --target-platform android-arm64 \
  --dart-define=SUPABASE_URL="$(grep '^SUPABASE_URL=' ../.env | cut -d= -f2-)" \
  --dart-define=SUPABASE_ANON_KEY="$(grep '^SUPABASE_ANON_KEY=' ../.env | cut -d= -f2-)"

ADB="/c/Users/Naman Gaonkar/AppData/Local/Android/Sdk/platform-tools/adb.exe"
"$ADB" install -r build/app/outputs/flutter-apk/app-release.apk
"$ADB" shell am start -n com.sportsphere.sportsphere/.MainActivity
```

Notes (this PC):
- The fake-NDK workaround (`llvm-strip`/`llvm-objcopy` + `strip_elf.py`) lives in the
  SDK folders, outside this repo — keep it intact or release builds fail on strip steps.
- Lato is bundled as TTFs (`mobile/assets/fonts/`), not fetched at runtime.
- The dashboard metrics (Athletes / Coaches / Teams / Tournaments, in that order) are
  identical on web and mobile; both query live Supabase.
