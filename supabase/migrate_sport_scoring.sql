-- ============================================================
-- SportSphere — sport-aware scoring
-- Different sports count differently:
--   Cricket        : runs + wickets   ("184/7")
--   Football/Hockey/Kabaddi/Basketball etc.: goals/points ("2 : 1")
--   Volleyball     : sets ("3 : 1")
--   Badminton/TT   : games ("2 : 0")
--   Athletics/Swimming: times/positions, not head-to-head scores
-- Adds raw wicket/sets/games columns and a formatter used at result time.
-- ============================================================

alter table public.matches add column if not exists wickets_a int;
alter table public.matches add column if not exists wickets_b int;
alter table public.matches add column if not exists sets_a int;
alter table public.matches add column if not exists sets_b int;

-- Display a match's score the way its sport is actually counted.
-- (Called from SQL: select format_match_score(sport, score_a, score_b, wickets_a, wickets_b, sets_a, sets_b))
create or replace function public.format_match_score(
  p_sport text,
  p_score_a numeric, p_score_b numeric,
  p_wickets_a int default null, p_wickets_b int default null,
  p_sets_a int default null, p_sets_b int default null
)
returns text
language sql
stable
as $$
  select case
    when p_sport = 'Cricket' then
      coalesce(p_score_a, 0)::text || coalesce('/' || nullif(p_wickets_a::text, ''), '') ||
      ' vs ' ||
      coalesce(p_score_b, 0)::text || coalesce('/' || nullif(p_wickets_b::text, ''), '') || ' (runs/wkts)'
    when p_sport = 'Volleyball' then
      coalesce(p_sets_a, 0)::text || ' : ' || coalesce(p_sets_b, 0)::text || ' (sets)'
    when p_sport in ('Badminton', 'Table Tennis') then
      coalesce(p_sets_a, 0)::text || ' : ' || coalesce(p_sets_b, 0)::text || ' (games)'
    else
      coalesce(p_score_a, 0)::text || ' : ' || coalesce(p_score_b, 0)::text
  end
$$;

-- Result string written when a match is marked Completed — now sport-aware.
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
    when v_sport in ('Volleyball') then
      v_a || ' ' || coalesce(new.sets_a, 0) || '-' || coalesce(new.sets_b, 0) || ' sets, ' ||
      coalesce(new.score_a, 0) || '-' || coalesce(new.score_b, 0) || ' points'
    when v_sport in ('Badminton', 'Table Tennis') then
      v_a || ' ' || coalesce(new.sets_a, 0) || '-' || coalesce(new.sets_b, 0) || ' games, ' ||
      coalesce(new.score_a, 0) || '-' || coalesce(new.score_b, 0) || ' points'
    else
      v_a || ' ' || coalesce(new.score_a, 0) || ' - ' || coalesce(new.score_b, 0) || ' ' || v_b
  end;

  return new;
end;
$$;

drop trigger if exists trg_compose_result on public.matches;
create trigger trg_compose_result
  before update on public.matches
  for each row execute procedure public.compose_match_result();

-- Safety net: never let a stale score linger on a cancelled match.
create or replace function public.clear_scores_on_cancel()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'Cancelled' and new.scheduled_at is not null then
    new.score_a := null;
    new.score_b := null;
    new.wickets_a := null;
    new.wickets_b := null;
    new.sets_a := null;
    new.sets_b := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_clear_scores on public.matches;
create trigger trg_clear_scores
  before update on public.matches
  for each row execute procedure public.clear_scores_on_cancel();

-- Zero-scores only make sense once play actually happened.
update public.matches
set score_a = null, score_b = null
where status in ('Scheduled', 'Cancelled')
  and coalesce(score_a, 0) = 0
  and coalesce(score_b, 0) = 0;
