-- Drop legacy text sport columns (superseded by sport_id + athlete_sports)
do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='teams' and column_name='sport_legacy') then
    alter table public.teams drop column sport_legacy;
  end if;
end $$;

do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='athletes' and column_name='sport_legacy') then
    alter table public.athletes drop column sport_legacy;
  end if;
end $$;

do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='training_sessions' and column_name='sport_legacy') then
    alter table public.training_sessions drop column sport_legacy;
  end if;
end $$;
