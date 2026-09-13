-- Notifications: admins full control (compose + manage), users read/update own.
drop policy if exists "notifications admin write" on public.notifications;
drop policy if exists "notifications self update" on public.notifications;
create policy "notifications admin all" on public.notifications for all
  using (public.is_admin()) with check (public.is_admin());
create policy "notifications self update" on public.notifications for update
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
