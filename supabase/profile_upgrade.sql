-- ============================================================
-- SportSphere: profile photos + notifications clear-all support
-- ============================================================

-- ---- Avatars storage bucket (public read, owner-only write) ----
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Anyone signed in can read avatars (bucket is public anyway, belt & braces)
drop policy if exists "avatars read" on storage.objects;
create policy "avatars read" on storage.objects
  for select using (bucket_id = 'avatars');

-- Each user manages files inside their own uid/ folder
drop policy if exists "avatars own insert" on storage.objects;
create policy "avatars own insert" on storage.objects
  for insert with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars own update" on storage.objects;
create policy "avatars own update" on storage.objects
  for update using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars own delete" on storage.objects;
create policy "avatars own delete" on storage.objects
  for delete using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Admin can manage anyone's avatar files
drop policy if exists "avatars admin all" on storage.objects;
create policy "avatars admin all" on storage.objects
  for all using (public.is_admin()) with check (public.is_admin());

-- ---- Notifications: users can clear their own rows ----
drop policy if exists "notifications self delete" on storage.objects;
drop policy if exists "notifications self delete" on public.notifications;
create policy "notifications self delete" on public.notifications
  for delete using (recipient_id = auth.uid());

-- ---- Make sure every app table is on the realtime publication ----
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','athletes','coaches','staff','teams','tournaments','matches',
    'venues','venue_bookings','attendance','payroll','inventory_items',
    'stock_transactions','vendors','purchase_orders','purchase_order_items',
    'awards','events','expenses','notifications','sports','athlete_sports',
    'housekeeping_tasks','training_sessions','performance_records',
    'medical_records','transport','accommodation','school_activities'
  ]
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
