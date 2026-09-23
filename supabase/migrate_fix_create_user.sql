-- ============================================================
-- SportSphere — fix admin_create_user: gen_salt not found
-- The function ran with `set search_path = public`, which hid the
-- pgcrypto extension (it lives in `extensions`). Adding extensions to
-- the search path so crypt()/gen_salt() resolve again — "add user"
-- works on web and phone.
-- ============================================================

create or replace function public.admin_create_user(
  p_email text,
  p_password text,
  p_name text,
  p_role text,
  p_department text default null,
  p_designation text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid;
  v_req user_role;
begin
  if public.current_role() <> 'Admin' then
    raise exception 'Only admins can create accounts';
  end if;
  if p_role not in ('Admin','Coach','Athlete','HR','Finance','VenueManager') then
    raise exception 'Unknown role';
  end if;
  if length(p_password) < 6 then
    raise exception 'Password must be at least 6 characters';
  end if;
  v_req := p_role::user_role;

  insert into auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at, raw_app_meta_data,
    raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new,
    email_change, email_change_token_current
  ) values (
    '00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated',
    lower(trim(p_email)),
    crypt(p_password, gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('full_name', p_name, 'role', v_req::text),
    now(), now(), '', '', '', '', ''
  )
  returning id into v_uid;

  -- roster row for coaches/staff so management pages can link records
  if v_req = 'Coach' then
    insert into public.coaches (profile_id) values (v_uid) on conflict do nothing;
  elsif v_req in ('HR','Finance','VenueManager') then
    insert into public.staff (profile_id, department, designation)
    values (v_uid, p_department, coalesce(p_designation, p_role)) on conflict do nothing;
  end if;

  return v_uid;
end;
$$;

grant execute on function public.admin_create_user(text, text, text, text, text, text) to authenticated;
