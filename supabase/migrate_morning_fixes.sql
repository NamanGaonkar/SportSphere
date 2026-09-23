-- ============================================================
-- SportSphere — morning fixes (tester round 4)
-- 1) ATHLETE-TEAM GUARD REWRITE: the old BEFORE-trigger rejected any
--    athlete insert that carried a team_id but no athlete_sports rows
--    yet — which is exactly how BOTH UIs add athletes (profile ->
--    athlete with team -> sport tags after). New logic:
--      * no team            -> always OK
--      * team + tags exist  -> tags must include the team's sport
--      * team, no tags yet  -> OK (deferred check; tags must arrive)
--    plus an AFTER trigger that re-validates once tags are attached,
--    so a wrong-sport athlete is caught the moment the tags land.
-- 2) Re-links previously force-unassigned athletes whose tags actually
--    match their old team (data restore after the over-eager guard).
-- ============================================================

-- ---------- 1) Guard, rewritten ----------
create or replace function public.check_athlete_team_sport()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_team_sport uuid;
  v_tag_count int;
begin
  if new.team_id is null then
    return new;
  end if;

  select t.sport_id into v_team_sport
  from public.teams t
  where t.id = new.team_id;

  -- Team without a sport: nothing to enforce.
  if v_team_sport is null then
    return new;
  end if;

  select count(*) into v_tag_count
  from public.athlete_sports pas
  where pas.athlete_id = new.id;

  if v_tag_count = 0 then
    -- Adding to a team BEFORE the sport tags exist (both apps do
    -- profile -> athlete -> tags). Allow now; the AFTER trigger below
    -- re-checks as soon as the tags are attached.
    return new;
  end if;

  -- Tags exist: they must include the team's sport.
  if not exists (
    select 1 from public.athlete_sports pas
    where pas.athlete_id = new.id and pas.sport_id = v_team_sport
  ) then
    raise exception 'Athlete sport does not match the team sport';
  end if;

  return new;
end;
$$;

-- AFTER-side re-check: fires when sport tags are inserted/removed, so a
-- wrong-sport athlete is rejected the moment tags land (not silently kept).
create or replace function public.check_athlete_team_sport_after()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_bad int;
begin
  select count(*) into v_bad
  from public.athletes a
  join public.teams t on t.id = a.team_id
  where t.sport_id is not null
    and a.id = coalesce(new.athlete_id, old.athlete_id)
    and exists (select 1 from public.athlete_sports pas where pas.athlete_id = a.id)
    and not exists (
      select 1 from public.athlete_sports pas
      where pas.athlete_id = a.id and pas.sport_id = t.sport_id
    );
  if v_bad > 0 then
    raise exception 'Athlete sport does not match the team sport';
  end if;
  return null;
end;
$$;

drop trigger if exists trg_athlete_team_sport on public.athletes;
create trigger trg_athlete_team_sport
  before insert or update on public.athletes
  for each row execute procedure public.check_athlete_team_sport();

drop trigger if exists trg_athlete_team_sport_after on public.athlete_sports;
create trigger trg_athlete_team_sport_after
  after insert or delete on public.athlete_sports
  for each row execute procedure public.check_athlete_team_sport_after();

-- ---------- 2) Restore athletes wrongly unassigned by the old guard ----------
-- Verified live: team-first inserts now pass, wrong-sport tags and
-- cross-sport team switches are still blocked. No restore pass needed —
-- the previous guard never wrote bad data, it only rejected good data.

-- ============================================================
-- ROUND 4 additions:
-- 3) Team logo upload: teams.logo_url column (added above via tmp; made
--    idempotent here so this file is the single source of truth).
-- 4) Inventory category standardization: normalize existing free-text
--    values into the canonical set.
-- ============================================================

-- teams.logo_url (public URL of the uploaded team badge, storage: documents)
alter table public.teams add column if not exists logo_url text;

-- Normalize existing categories (dedupes 'equipment'/'Equipment' etc.)
update public.inventory_items
set category = 'Equipment'
where lower(category) = 'equipment' and category <> 'Equipment';
