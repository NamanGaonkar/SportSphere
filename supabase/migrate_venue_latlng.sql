-- SportSphere — venues.lat / venues.lng as plain numeric columns.
-- Plain decimals (not PostGIS) keep both frontends' JSON mapping trivial.
alter table public.venues
  add column if not exists lat double precision,
  add column if not exists lng double precision;
