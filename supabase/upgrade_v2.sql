-- ============================================================
-- SportSphere — platform upgrade (apply via scripts/apply_sql.py)
-- 1) FIX swapped roles (admin login had role Athlete)
-- 2) Realtime publication: every table both apps subscribe to
-- 3) Inventory revamp: categories, locations, condition, units,
--    min_stock, unit_cost, assigned team + stock_transactions log
-- 4) Purchase orders: real line items, auto stock-in on Received
-- 5) Performance: structured metric records (numeric value, unit,
--    session type) + legacy text kept
-- 6) Medical: detailed logging (height/weight, injury, severity,
--    treatment, follow-up) on one records table
-- 7) Admin user management: role/permission RPCs
-- ============================================================

-- ---------- 1) FIX SWAPPED ROLES ----------
update public.profiles set role = 'Athlete'
where id = (select id from auth.users where email = 'venuemanager@sportsphere.app');

update public.profiles set role = 'Admin'
where id = (select id from auth.users where email = 'admin@sportsphere.app');

-- Harden: admins can never be demoted through the client APIs either
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
  return new;
end;
$$;

drop trigger if exists protect_admin_row on public.profiles;
create trigger protect_admin_row
  before update or delete on public.profiles
  for each row execute procedure public.protect_admin_row();

-- Admin exists check for the user-management screen
create or replace function public.has_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$ select exists (select 1 from public.profiles where role = 'Admin') $$;

-- ---------- 2) REALTIME: ALL APP TABLES (added at end, after new tables exist) ----------

-- ---------- 3) INVENTORY & EQUIPMENT REVAMP ----------
alter table public.inventory_items
  add column if not exists location text,
  add column if not exists unit text default 'pcs',
  add column if not exists min_stock int default 0,
  add column if not exists unit_cost numeric(12,2) default 0,
  add column if not exists assigned_team_id uuid references public.teams(id) on delete set null;

create table if not exists public.stock_transactions (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.inventory_items(id) on delete cascade,
  tx_type text not null check (tx_type in ('IN','OUT','ADJUST','MAINTENANCE')),
  quantity int not null default 0,
  note text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.stock_transactions enable row level security;
drop policy if exists "stock_tx read" on public.stock_transactions;
create policy "stock_tx read" on public.stock_transactions for select using (true);
drop policy if exists "stock_tx write" on public.stock_transactions;
create policy "stock_tx write" on public.stock_transactions for all
  using (public.is_admin() or public.current_role() in ('Coach','HR','Finance'))
  with check (public.is_admin() or public.current_role() in ('Coach','HR','Finance'));

-- one atomic RPC for stock movement (apps never update quantity by hand)
create or replace function public.stock_move(
  p_item uuid, p_type text, p_qty int, p_note text default null
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_role user_role := public.current_role();
  v_q int;
begin
  if v_role is null or v_role not in ('Admin','Coach','HR','Finance') then
    raise exception 'Not allowed to move stock';
  end if;
  if p_qty <= 0 then raise exception 'Quantity must be positive'; end if;
  if p_type not in ('IN','OUT','ADJUST','MAINTENANCE') then
    raise exception 'Unknown transaction type';
  end if;

  select quantity into v_q from public.inventory_items where id = p_item for update;
  if not found then raise exception 'Item not found'; end if;

  if p_type = 'IN' then
    update public.inventory_items set quantity = quantity + p_qty where id = p_item;
  elsif p_type = 'OUT' then
    if v_q < p_qty then raise exception 'Only % in stock', v_q; end if;
    update public.inventory_items set quantity = quantity - p_qty where id = p_item;
  elsif p_type = 'MAINTENANCE' then
    if v_q < p_qty then raise exception 'Only % in stock', v_q; end if;
    update public.inventory_items set quantity = quantity - p_qty, condition = 'Under maintenance' where id = p_item;
  else -- ADJUST
    update public.inventory_items set quantity = p_qty where id = p_item;
  end if;

  insert into public.stock_transactions (item_id, tx_type, quantity, note, created_by)
  values (p_item, p_type, p_qty, p_note, auth.uid());
end;
$$;

-- ---------- 4) PURCHASE ORDERS: REAL LINE ITEMS + AUTO STOCK-IN ----------
create table if not exists public.purchase_order_items (
  id uuid primary key default gen_random_uuid(),
  po_id uuid not null references public.purchase_orders(id) on delete cascade,
  item_id uuid references public.inventory_items(id) on delete set null,
  description text not null,
  quantity int not null default 1,
  unit_cost numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

alter table public.purchase_order_items enable row level security;
drop policy if exists "poi read" on public.purchase_order_items;
create policy "poi read" on public.purchase_order_items for select using (true);
drop policy if exists "poi write" on public.purchase_order_items;
create policy "poi write" on public.purchase_order_items for all
  using (public.is_admin() or public.current_role() in ('Finance','HR'))
  with check (public.is_admin() or public.current_role() in ('Finance','HR'));

-- line items auto-stock when a PO is marked Received (also auto-expenses)
create or replace function public.po_on_status_change()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  it record;
begin
  if new.status = 'Received' and coalesce(old.status,'') is distinct from 'Received' then
    for it in select * from public.purchase_order_items where po_id = new.id loop
      if it.item_id is not null then
        update public.inventory_items set quantity = quantity + it.quantity where id = it.item_id;
      end if;
      insert into public.stock_transactions (item_id, tx_type, quantity, note, created_by)
      values (it.item_id, 'IN', it.quantity, 'PO received: ' || it.description, auth.uid());
    end loop;
    if new.total > 0 then
      insert into public.expenses (category, amount, date, description, approved_by)
      values ('Equipment', new.total, current_date, 'Purchase order received', 'System');
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists po_status_change on public.purchase_orders;
drop trigger if exists po_status_change_tr on public.purchase_orders;
create trigger po_status_change_tr
  after update of status on public.purchase_orders
  for each row execute procedure public.po_on_status_change();

-- ---------- 5) PERFORMANCE: STRUCTURED METRICS ----------
alter table public.performance_records
  add column if not exists value_num numeric(10,3),
  add column if not exists unit text,
  add column if not exists session_type text default 'Test',
  add column if not exists coach_note text;

-- ---------- 6) MEDICAL: DETAILED LOGGING ----------
alter table public.medical_records
  add column if not exists height_cm numeric(5,1),
  add column if not exists weight_kg numeric(5,1),
  add column if not exists severity text default 'None',
  add column if not exists treatment text,
  add column if not exists follow_up_date date;

-- athletes get a clearance status from their latest medical record
create or replace function public.athlete_clearance(p_athlete uuid)
returns text
language sql stable security definer
set search_path = public
as $$
  select case when cleared then 'Cleared' else 'Not cleared' end
  from public.medical_records
  where athlete_id = p_athlete
  order by date desc, created_at desc
  limit 1;
$$;

-- ---------- 7) ADMIN USER MANAGEMENT RPCs ----------
create or replace function public.admin_set_role(p_user uuid, p_role text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if public.current_role() <> 'Admin' then
    raise exception 'Only admins can change roles';
  end if;
  if p_role not in ('Admin','Coach','Athlete','HR','Finance','VenueManager') then
    raise exception 'Unknown role';
  end if;
  update public.profiles set role = p_role::user_role where id = p_user;
end;
$$;

create or replace function public.admin_rename_user(p_user uuid, p_name text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if public.current_role() <> 'Admin' then
    raise exception 'Only admins can rename users';
  end if;
  update public.profiles set full_name = p_name where id = p_user;
end;
$$;

create or replace function public.admin_set_contact(p_user uuid, p_contact text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if public.current_role() <> 'Admin' then
    raise exception 'Only admins can edit contacts';
  end if;
  update public.profiles set contact_info = p_contact where id = p_user;
end;
$$;

grant execute on function public.stock_move(uuid, text, int, text) to authenticated;
grant execute on function public.admin_set_role(uuid, text) to authenticated;
grant execute on function public.admin_rename_user(uuid, text) to authenticated;
grant execute on function public.admin_set_contact(uuid, text) to authenticated;

-- ---------- 2) REALTIME: ALL APP TABLES ----------
do $$
declare t text;
begin
  foreach t in array array[
    'teams','tournaments','matches','venues','venue_bookings','athletes','coaches',
    'staff','attendance','payroll','inventory_items','stock_transactions','vendors',
    'purchase_orders','purchase_order_items','awards','notifications','housekeeping_tasks',
    'training_sessions','performance_records','medical_records','events','transport',
    'accommodation','expenses','school_activities','sports','athlete_sports','profiles'
  ]
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
