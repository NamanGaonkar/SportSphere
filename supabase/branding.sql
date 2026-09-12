-- ============================================================
-- SportSphere — signup trigger hardening (run after schema.sql)
-- Public signup may ONLY create Coach / Athlete / HR / Finance /
-- VenueManager. 'Admin' can only be granted by SQL (see below).
-- ============================================================

-- Roles the public signup form may request
create or replace function public.allowed_signup_roles()
returns user_role[]
language sql
stable
as $$
  select array['Coach','Athlete','HR','Finance','VenueManager']::user_role[];
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  req_role user_role;
begin
  req_role := coalesce(
    (new.raw_user_meta_data->>'role')::user_role,
    'Athlete'::user_role
  );

  -- Admin is never created through public signup; force it to Athlete.
  if req_role = 'Admin' then
    req_role := 'Athlete';
  end if;

  insert into public.profiles (id, full_name, role, contact_info)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    req_role,
    new.email
  )
  on conflict (id) do update
    set contact_info = excluded.contact_info,
        full_name = case when profiles.full_name = '' then excluded.full_name else profiles.full_name end;
  return new;
end;
$$;

-- Recreate trigger (drop first so the new function version is bound)
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Defense in depth: even a direct profiles insert/update can never self-assign Admin
create or replace function public.forbid_self_admin()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if lower(current_setting('request.jwt.claims', true)::json->>'role') = 'authenticated' then
    if new.role = 'Admin' and (
      coalesce(old.role, 'Admin'::user_role) is distinct from 'Admin'
      or old.id is distinct from new.id
    ) then
      raise exception 'Admin role can only be assigned by the organization';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists forbid_self_admin on public.profiles;
create trigger forbid_self_admin
  before insert or update on public.profiles
  for each row execute procedure public.forbid_self_admin();

-- Grant Admin manually (run in SQL Editor, NOT from any app):
--   update public.profiles set role = 'Admin' where id = (
--     select id from auth.users where email = 'you@example.com'
--   );
