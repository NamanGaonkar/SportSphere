-- ============================================================
-- SportSphere — users table revamp support
-- 1) admin_list_emails(): admin-only RPC exposing auth emails so the
--    User Management table can show Email + Contact side by side
--    (replaces the vague "Linked record" column).
-- 2) Backfills profiles.phone from contact_info where the legacy field
--    held a phone number.
-- 3) Profile-update policy: users edit their own row, admins edit all —
--    with a trigger guard so a non-admin can never change a role
--    (RLS is row-level, column restrictions need the trigger).
-- ============================================================

create or replace function public.admin_list_emails()
returns table (user_id uuid, email text)
language sql
stable
security definer
set search_path = public, auth
as $$
  select u.id, u.email
  from auth.users u
  where public.is_admin()
$$;

grant execute on function public.admin_list_emails() to authenticated;

-- Admin sets a user's phone number directly.
create or replace function public.admin_set_phone(p_user uuid, p_phone text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin only';
  end if;
  update public.profiles set phone = nullif(p_phone, '') where id = p_user;
end;
$$;

grant execute on function public.admin_set_phone(uuid, text) to authenticated;

-- Legacy contact_info sometimes held a phone number — move it across.
update public.profiles
set phone = contact_info
where phone is null
  and contact_info is not null
  and contact_info ~ '^[0-9+][0-9 ()-]{5,}$';

-- Users can update their own profile basics; admins can update anyone.
drop policy if exists "profiles self update" on public.profiles;
create policy "profiles self update"
  on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- Column guard: only admins may change role (or anything on someone else).
create or replace function public.guard_profile_role_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    if new.role is distinct from old.role then
      raise exception 'Only admins can change roles';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profile_role_guard on public.profiles;
drop trigger if exists trg_guard_profile_role_change on public.profiles;
create trigger trg_guard_profile_role_change
  before update on public.profiles
  for each row execute procedure public.guard_profile_role_change();
