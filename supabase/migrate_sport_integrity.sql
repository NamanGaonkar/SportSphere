-- ============================================================
-- SportSphere — cross-sport fixture integrity + per-sport scores
-- 1) A fixture may only pit two teams of the SAME sport against each
--    other, and (when there is one) the tournament's sport must match.
--    A football team never plays a tennis/badminton team again.
-- 2) score_display: precomputed, sport-correct score string stored on
--    every match so web + phone + dashboard all render the SAME text:
--      Cricket            184/7 vs 176/9 (runs/wickets)
--      Volleyball         3 : 1 (sets)
--      Badminton/TT       2 : 0 (games)
--      Athletics/Swimming Final position / time — no head-to-head score
--      Goal/point sports  2 : 1
-- ============================================================

-- ---------- 1) CROSS-SPORT GUARD (function only; trigger created after cleanup) ----------
create or replace function public.check_match_sport()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_a uuid;
  v_b uuid;
  v_tournament uuid;
begin
  v_a := coalesce(new.team_a_id, old.team_a_id);
  v_b := coalesce(new.team_b_id, old.team_b_id);
  v_tournament := coalesce(new.tournament_id, old.tournament_id);

  if v_a is not null and v_b is not null and v_a = v_b then
    raise exception 'A team cannot play against itself';
  end if;

  if v_a is not null and v_b is not null then
    if exists (
      select 1 from public.teams ta, public.teams tb
      where ta.id = v_a and tb.id = v_b and ta.sport_id is distinct from tb.sport_id
    ) then
      raise exception 'Teams must belong to the same sport for a fixture';
    end if;
  end if;

  if v_tournament is not null and v_a is not null then
    if exists (
      select 1 from public.tournaments t, public.teams ta
      where t.id = v_tournament and ta.id = v_a
        and t.sport_id is not null and t.sport_id is distinct from ta.sport_id
    ) then
      raise exception 'Team sport does not match the tournament sport';
    end if;
  end if;

  return new;
end;
$$;

-- (trg_match_sport is created in section 6, after the cleanup)

-- ---------- 2) SCORE_DISPLAY COLUMN + FORMATTER ----------
alter table public.matches add column if not exists score_display text;

create or replace function public.compute_score_display(
  p_sport text,
  p_score_a numeric, p_score_b numeric,
  p_wickets_a int, p_wickets_b int,
  p_sets_a int, p_sets_b int,
  p_status text
)
returns text
language sql
stable
as $$
  select case
    -- Race/measurement sports: no head-to-head score exists.
    when p_sport in ('Athletics/Track & Field', 'Swimming') then null
    when p_status in ('Scheduled', 'Cancelled') then null
    when p_sport = 'Cricket' then
      coalesce(p_score_a, 0)::text || '/' || coalesce(p_wickets_a, 0)::text ||
      ' vs ' ||
      coalesce(p_score_b, 0)::text || '/' || coalesce(p_wickets_b, 0)::text || ' (runs/wkts)'
    when p_sport = 'Volleyball' then
      coalesce(p_sets_a, 0)::text || ' : ' || coalesce(p_sets_b, 0)::text || ' (sets)'
    when p_sport in ('Badminton', 'Table Tennis') then
      coalesce(p_sets_a, 0)::text || ' : ' || coalesce(p_sets_b, 0)::text || ' (games)'
    else
      coalesce(p_score_a, 0)::text || ' : ' || coalesce(p_score_b, 0)::text
  end
$$;

create or replace function public.refresh_score_display()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_sport text;
begin
  select s.name into v_sport
  from public.teams t join public.sports s on s.id = t.sport_id
  where t.id = coalesce(new.team_a_id, old.team_a_id);

  new.score_display := public.compute_score_display(
    v_sport,
    coalesce(new.score_a, old.score_a),
    coalesce(new.score_b, old.score_b),
    coalesce(new.wickets_a, old.wickets_a),
    coalesce(new.wickets_b, old.wickets_b),
    coalesce(new.sets_a, old.sets_a),
    coalesce(new.sets_b, old.sets_b),
    coalesce(new.status, old.status)::text
  );
  return new;
end;
$$;

drop trigger if exists trg_score_display on public.matches;
create trigger trg_score_display
  before insert or update on public.matches
  for each row execute procedure public.refresh_score_display();

-- Backfill every existing match.
update public.matches m
set score_display = public.compute_score_display(
      (select s.name from public.teams t join public.sports s on s.id = t.sport_id where t.id = m.team_a_id),
      m.score_a::numeric, m.score_b::numeric, m.wickets_a, m.wickets_b, m.sets_a, m.sets_b, m.status::text);

-- ---------- 3) RESULT COMPOSER — replace the naive one ----------
drop trigger if exists trg_compose_result on public.matches;
create or replace function public.compose_match_result()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_sport text;
  v_a text;
  v_b text;
begin
  if new.status is distinct from 'Completed' then
    return new;
  end if;

  select s.name into v_sport
  from public.teams t join public.sports s on s.id = t.sport_id
  where t.id = new.team_a_id;

  v_a := coalesce((select name from public.teams where id = new.team_a_id), 'Team A');
  v_b := coalesce((select name from public.teams where id = new.team_b_id), 'Team B');

  new.result := case
    when v_sport = 'Cricket' then
      v_a || ' ' || coalesce(new.score_a, 0) || '/' || coalesce(new.wickets_a, 0) ||
      ' vs ' || v_b || ' ' || coalesce(new.score_b, 0) || '/' || coalesce(new.wickets_b, 0) ||
      ' (runs/wickets)'
    when v_sport = 'Volleyball' then
      v_a || ' ' || coalesce(new.sets_a, 0) || '-' || coalesce(new.sets_b, 0) || ' sets (' ||
      coalesce(new.score_a, 0) || '-' || coalesce(new.score_b, 0) || ' points)'
    when v_sport in ('Badminton', 'Table Tennis') then
      v_a || ' ' || coalesce(new.sets_a, 0) || '-' || coalesce(new.sets_b, 0) || ' games (' ||
      coalesce(new.score_a, 0) || '-' || coalesce(new.score_b, 0) || ' points)'
    when v_sport in ('Athletics/Track & Field', 'Swimming') then
      v_a || ' finished ahead of ' || v_b ||
      ' (time ' || coalesce(new.score_a::text, '-') || ' vs ' || coalesce(new.score_b::text, '-') || ')'
    else
      v_a || ' ' || coalesce(new.score_a, 0) || ' - ' || coalesce(new.score_b, 0) || ' ' || v_b
  end;

  return new;
end;
$$;
create trigger trg_compose_result
  before update on public.matches
  for each row execute procedure public.compose_match_result();

-- ---------- 4) CLEAN UP INVALID SEEDED FIXTURES ----------
-- Run BEFORE creating the guard trigger (below, in section 6) so the
-- bad seed rows don't trip the new rules while we delete them.
delete from public.matches m
using public.teams ta, public.teams tb
where ta.id = m.team_a_id and tb.id = m.team_b_id
  and ta.sport_id is distinct from tb.sport_id;

delete from public.matches m
where m.team_a_id = m.team_b_id;

delete from public.matches m
using public.tournaments t, public.teams ta
where m.tournament_id = t.id
  and t.sport_id is not null
  and ta.id = m.team_a_id
  and ta.sport_id is distinct from t.sport_id;

-- ---------- 5) VENUE SPORT CHECK (function; trigger created in section 6) ----------
create or replace function public.check_fixture_venue_sport()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.venue_id is null or new.team_a_id is null then
    return new;
  end if;
  if exists (
    select 1
    from public.teams t
    join public.sports s on s.id = t.sport_id
    where t.id = new.team_a_id
      and not exists (
        select 1 from public.venue_sports vs where vs.venue_id = new.venue_id and vs.sport_id = s.id
      )
  ) then
    raise exception 'That venue does not host this sport';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_fixture_venue_sport on public.matches;
create trigger trg_fixture_venue_sport
  before insert or update on public.matches
  for each row execute procedure public.check_fixture_venue_sport();

-- ---------- 7) RESULT COMPOSER also fires on INSERT ----------
create or replace function public.compose_match_result_ins()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_sport text;
  v_a text;
  v_b text;
begin
  if new.status is distinct from 'Completed' then
    return new;
  end if;

  select s.name into v_sport
  from public.teams t join public.sports s on s.id = t.sport_id
  where t.id = new.team_a_id;

  v_a := coalesce((select name from public.teams where id = new.team_a_id), 'Team A');
  v_b := coalesce((select name from public.teams where id = new.team_b_id), 'Team B');

  new.result := case
    when v_sport = 'Cricket' then
      v_a || ' ' || coalesce(new.score_a, 0) || '/' || coalesce(new.wickets_a, 0) ||
      ' vs ' || v_b || ' ' || coalesce(new.score_b, 0) || '/' || coalesce(new.wickets_b, 0) ||
      ' (runs/wickets)'
    when v_sport = 'Volleyball' then
      v_a || ' ' || coalesce(new.sets_a, 0) || '-' || coalesce(new.sets_b, 0) || ' sets (' ||
      coalesce(new.score_a, 0) || '-' || coalesce(new.score_b, 0) || ' points)'
    when v_sport in ('Badminton', 'Table Tennis') then
      v_a || ' ' || coalesce(new.sets_a, 0) || '-' || coalesce(new.sets_b, 0) || ' games (' ||
      coalesce(new.score_a, 0) || '-' || coalesce(new.score_b, 0) || ' points)'
    when v_sport in ('Athletics/Track & Field', 'Swimming') then
      v_a || ' finished ahead of ' || v_b ||
      ' (time ' || coalesce(new.score_a::text, '-') || ' vs ' || coalesce(new.score_b::text, '-') || ')'
    else
      v_a || ' ' || coalesce(new.score_a, 0) || ' - ' || coalesce(new.score_b, 0) || ' ' || v_b
  end;

  return new;
end;
$$;

drop trigger if exists trg_compose_result_ins on public.matches;
create trigger trg_compose_result_ins
  after insert on public.matches
  for each row execute procedure public.compose_match_result_ins();

-- ---------- 8) ATHLETE-TEAM SPORT MATCH ----------
-- An athlete on a Football roster cannot be added to a Badminton team.
-- Coaching cross-sport is legitimate, so coaches stay unrestricted.
create or replace function public.check_athlete_team_sport()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.team_id is null then
    return new;
  end if;
  if exists (
    select 1
    from public.teams t
    where t.id = new.team_id
      and t.sport_id is not null
      and not exists (
        select 1 from public.athlete_sports pas
        where pas.athlete_id = new.id and pas.sport_id = t.sport_id
      )
  ) then
    raise exception 'Athlete sport does not match the team sport';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_athlete_team_sport on public.athletes;
create trigger trg_athlete_team_sport
  before insert or update on public.athletes
  for each row execute procedure public.check_athlete_team_sport();

-- Existing mismatches are unassigned (roster kept, team cleared).
update public.athletes a
set team_id = null
from public.teams t
where a.team_id = t.id
  and t.sport_id is not null
  and not exists (
    select 1 from public.athlete_sports pas
    where pas.athlete_id = a.id and pas.sport_id = t.sport_id
  );
