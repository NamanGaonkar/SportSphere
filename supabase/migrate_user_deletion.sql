-- ============================================================
-- USER DELETION: soft delete + restore + permanent purge (admin)
-- Soft delete = profiles.deleted_at set; auth login blocked; user hidden
--   from every list (profiles select policies) and all modules that join
--   profiles (attendance, users, staff, coaches, athletes lists).
-- Restore = clears the flag, login works again, everything reappears.
-- Permanent delete = removes the roster row(s) + profile row + auth.users
--   row; FK cascades clean attendance/notifications/athlete data.
-- The primary admin account is immutable (existing triggers/role lock).
-- ============================================================

-- 1) Soft-delete flag
alter table public.profiles add column if not exists deleted_at timestamptz;
create index if not exists idx_profiles_deleted on public.profiles (deleted_at);

-- 2) Auth gate: sign-in enforcement is done in admin_delete_user (bans the
-- auth account) and admin_restore_user / the unban trigger below clear it.

-- 3) Profiles: deleted users invisible to everyone except admins (who need
-- them listed for the "Deleted" tab).
drop policy if exists "profiles select" on public.profiles;
drop policy if exists "profiles read" on public.profiles;
drop policy if exists "profiles select own or staff" on public.profiles;
drop policy if exists "profiles select visible" on public.profiles;
create policy "profiles select visible" on public.profiles for select
  using (
    deleted_at is null
    or public.is_admin()
    or id = auth.uid()
  );

-- 4) Soft delete: disable the auth account (ban_until far future) + stamp.
create or replace function public.admin_delete_user(p_user uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  t_target_role public.user_role;
begin
  if not public.is_admin() then
    raise exception 'Only admins can delete users';
  end if;

  select role into t_target_role from public.profiles where id = p_user;
  if not found then
    raise exception 'User not found';
  end if;
  if t_target_role = 'Admin' then
    raise exception 'The fixed admin account cannot be deleted';
  end if;

  update public.profiles set deleted_at = now() where id = p_user;

  -- Block login: ban the auth account (GoTrue refuses banned users).
  update auth.users
     set banned_until = '2099-01-01T00:00:00Z'::timestamptz,
         updated_at = now()
   where id = p_user;
end;
$$;

-- 5) Restore: unban + clear the flag.
create or replace function public.admin_restore_user(p_user uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can restore users';
  end if;

  update public.profiles set deleted_at = null where id = p_user;

  update auth.users
     set banned_until = null,
         updated_at = now()
   where id = p_user;
end;
$$;

-- 6) Permanent delete: roster row(s) -> profile -> auth user. Cascades
-- handle dependents (attendance, notifications, athlete_sports, awards,
-- medical/performance via athletes; teams/trainings null their coach).
create or replace function public.admin_purge_user(p_user uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  t_target_role public.user_role;
begin
  if not public.is_admin() then
    raise exception 'Only admins can permanently delete users';
  end if;

  select role into t_target_role from public.profiles where id = p_user;
  if not found then
    raise exception 'User not found';
  end if;
  if t_target_role = 'Admin' then
    raise exception 'The fixed admin account cannot be deleted';
  end if;

  -- Roster rows first (their deletes cascade athlete data).
  delete from public.athletes   where profile_id = p_user;
  delete from public.coaches    where profile_id = p_user;
  delete from public.staff      where profile_id = p_user;

  -- Profile BEFORE the auth purge: GoTrue's internal trigger is
  -- "on conflict do nothing", so any error here would be swallowed and
  -- roll back ONLY the auth delete — deleting profile first keeps the
  -- statement sequence verifiable.
  delete from public.profiles   where id = p_user;

  if exists (select 1 from public.profiles where id = p_user) then
    raise exception 'Profile delete was blocked by a trigger or policy';
  end if;

  -- Auth identity last — GONE means the login is gone for good.
  delete from auth.users        where id = p_user;
end;
$$;

grant execute on function public.admin_delete_user(uuid)  to authenticated;
grant execute on function public.admin_restore_user(uuid) to authenticated;
grant execute on function public.admin_purge_user(uuid)   to authenticated;

-- 7) FIX the admin-row protection trigger: its final `return new` returned
-- NULL on DELETE (new is NULL for delete ops), which silently CANCELED every
-- profile delete — the purge never worked and raised no error. Return the
-- row the operation actually needs: new for insert/update, old for delete.
create or replace function public.protect_admin_row()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op in ('UPDATE','DELETE') then
    if old.role = 'Admin' and public.current_role() <> 'Admin' then
      raise exception 'Only admins can modify the admin account';
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

-- 8) Auto-unban whenever a deleted profile is restored manually.
create or replace function public.profile_unban_on_restore()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.deleted_at is null and old.deleted_at is not null then
    update auth.users set banned_until = null, updated_at = now() where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profile_unban on public.profiles;
create trigger trg_profile_unban
  after update of deleted_at on public.profiles
  for each row execute procedure public.profile_unban_on_restore();

-- 8) Health check: list currently soft-deleted users (run as admin).
-- select id, full_name, role, deleted_at from profiles where deleted_at is not null;
