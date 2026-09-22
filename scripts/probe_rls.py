#!/usr/bin/env python
"""Probe RLS as a real Admin user to find which dashboard query fails.
Creates a temp probe account (role Admin via SQL), runs the exact queries the
phone dashboard makes, prints OK/FAIL per query, then deletes the probe.
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
env = {}
for line in open(os.path.join(ROOT, ".env"), encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k] = v

BASE = env["SUPABASE_URL"].rstrip("/")
ANON = env["SUPABASE_ANON_KEY"]
ACCESS = env["SUPABASE_ACCESS_TOKEN"]
PROJ = BASE.split("//")[1].split(".")[0]

PROBE_EMAIL = "rls-probe@sportsphere.local"
PROBE_PW = "probe-Temp-9137"


def http(method, url, token=None, body=None, headers=None):
    data = json.dumps(body).encode() if body is not None else None
    h = {"Content-Type": "application/json"}
    if token:
        h["apikey"] = token
        h["Authorization"] = "Bearer " + token
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            raw = r.read()
            return r.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")[:400]


def mgmt(method, path, body=None):
    url = f"https://api.supabase.com/v1/projects/{PROJ}/{path}"
    return http(method, url, token=ACCESS, body=body)


# 1) create probe via admin API
st, r = http("POST", BASE + "/auth/v1/admin/users", token=ANON, headers={"X-Supabase-Service-Role": "skip"}, body={})
# (that call fails without service key — use the management SQL endpoint instead)

# Create the probe purely in SQL: auth.users insert + profiles row.
sql = f"""
do $$
declare
  uid uuid;
begin
  select id into uid from auth.users where email = '{PROBE_EMAIL}';
  if uid is null then
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change, email_change_token_new)
    values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
      '{PROBE_EMAIL}', crypt('{PROBE_PW}', gen_salt('bf')), now(), '{{}}', '{{}}', now(), now(), '', '', '', '')
    returning id into uid;
  end if;
  insert into public.profiles (id, full_name, role) values (uid, 'RLS Probe', 'Admin')
  on conflict (id) do update set role = 'Admin';
end $$;
"""
st, r = mgmt("POST", "database/query", {"query": sql})
print("probe create:", st)
if st not in (200, 201):
    print(r)
    sys.exit(1)

# 2) login as probe
st, r = http("POST", BASE + "/auth/v1/token?grant_type=password", token=ANON,
             body={"email": PROBE_EMAIL, "password": PROBE_PW})
if st != 200:
    print("probe login failed:", st, r)
    sys.exit(1)
jwt = r["access_token"]
print("probe login OK")

QUERIES = [
    ("athletes", "/rest/v1/athletes?select=id"),
    ("coaches", "/rest/v1/coaches?select=id"),
    ("teams", "/rest/v1/teams?select=id,sport_id"),
    ("tournaments", "/rest/v1/tournaments?select=id"),
    ("matches", "/rest/v1/matches?select=id,status,score_a,score_b,score_display,scheduled_at,team_a:teams!matches_team_a_id_fkey(name,sport_id),team_b:teams!matches_team_b_id_fkey(name),tournaments(name)&order=scheduled_at.desc&limit=6"),
    ("attendance", "/rest/v1/attendance?select=date,status&limit=5"),
    ("profiles-role", "/rest/v1/profiles?select=id&role=in.(Athlete,Coach,HR,Finance,VenueManager)"),
    ("payroll", "/rest/v1/payroll?select=id,month,net,staff_id,coach_id,staff:staff_id(profile:profiles(full_name)),coach:coach_id(profile:profiles(full_name))&order=month.desc&limit=6"),
    ("inventory", "/rest/v1/inventory_items?select=id,name,quantity,min_stock,condition"),
    ("purchase_orders", "/rest/v1/purchase_orders?select=id,status"),
    ("medical", "/rest/v1/medical_records?select=id,athlete_id,type,cleared,date,athletes(profile:profiles(full_name))&order=date.desc&limit=8"),
    ("awards", "/rest/v1/awards?select=id,title,date,level,athletes(profile:profiles(full_name))&order=date.desc&limit=6"),
]

fails = 0
for label, path in QUERIES:
    # PostgREST: apikey = anon key, Authorization = user JWT (as the SDKs do).
    st, r = http("GET", BASE + path, token=jwt, headers={"apikey": ANON})
    ok = st == 200
    n = len(r) if ok and isinstance(r, list) else "-"
    print(f"{label:16s} {'OK ' if ok else 'FAIL'} {st}  n={n}" + ("" if ok else "  " + str(r)[:200]))
    if not ok:
        fails += 1

# 3) delete probe
sql = f"delete from auth.users where email = '{PROBE_EMAIL}';"
st, r = mgmt("POST", "database/query", {"query": sql})
print("probe delete:", st, "(profiles row cascades)")
print("RESULT:", "ALL QUERIES PASS" if fails == 0 else f"{fails} QUERIES FAIL")
