-- ============================================================
-- migrate_finance_and_roles.sql
-- 1) PO auto-expense trigger now records WHICH vendor and WHAT
--    items were bought (vendor_id + items_note were always
--    empty before, on both web and phone).
-- 2) Backfills those columns on expenses already in the table.
-- 3) Helper RPCs for the mobile athlete/coach flows:
--    my_teams_for_coach() and my_teams_for_athlete().
-- ============================================================

-- ---------- 1) PO trigger fills vendor + items ----------
create or replace function public.po_on_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  it record;
  v_items text;
begin
  if new.status = 'Received' and coalesce(old.status,'') is distinct from 'Received' then
    v_items := '';
    for it in select * from public.purchase_order_items where po_id = new.id loop
      if it.item_id is not null then
        update public.inventory_items set quantity = quantity + it.quantity where id = it.item_id;
      end if;
      insert into public.stock_transactions (item_id, tx_type, quantity, note, created_by)
      values (it.item_id, 'IN', it.quantity, 'PO received: ' || it.description, auth.uid());
      v_items := v_items
        || (case when v_items = '' then '' else ', ' end)
        || coalesce(it.description, 'item')
        || ' x ' || coalesce(it.quantity, 0)::text;
    end loop;
    if new.total > 0 then
      insert into public.expenses (category, amount, date, description, approved_by, vendor_id, items_note)
      values ('Equipment', new.total, current_date, 'Purchase order received', 'System', new.vendor_id, nullif(v_items, ''));
    end if;
  end if;
  return new;
end;
$$;

-- ---------- 2) Backfill: attach vendor + items from the PO ----------
-- Matches on amount + date + the generic 'Purchase order received'
-- description. Only touches rows where vendor_id/items_note are empty.
with po_received as (
  select po.id, po.vendor_id, po.total, po.created_at,
    (
      select string_agg(it.description || ' x ' || coalesce(it.quantity, 0)::text, ', ')
      from public.purchase_order_items it where it.po_id = po.id
    ) as items
  from public.purchase_orders po
  where po.status = 'Received'
),
-- A PO is created BEFORE it is received, so the expense date (booked at
-- receive time) must fall ON/AFTER the PO creation date, not before it.
matched as (
  select distinct on (e.id) e.id as expense_id, po.vendor_id, po.items
  from public.expenses e
  join po_received po
    on po.total = e.amount
   and po.created_at::date <= e.date
   and po.created_at::date >= e.date - 60
  where e.vendor_id is null
    and (e.items_note is null or e.items_note = '' or e.items_note = 'Purchase order received')
    and e.description = 'Purchase order received'
    and e.approved_by = 'System'
  order by e.id, po.created_at desc
)
update public.expenses e
set vendor_id = m.vendor_id,
    items_note = m.items
from matched m
where e.id = m.expense_id;

-- Fallback for anything still unmatched: give it a readable items note
-- derived from its own description so the column never looks broken.
update public.expenses
set items_note = coalesce(nullif(description, ''), category)
where (items_note is null or items_note = '');

-- ---------- 3) Role helpers for the app flows ----------
-- Teams a coach manages (drives the coach home "My Teams" strip and
-- role-scoped match/training lists). Security definer so RLS on teams
-- (readable by everyone) is bypassed consistently.
create or replace function public.my_teams_for_coach()
returns table (team_id uuid, team_name text, sport_id uuid, sport_name text, athlete_count bigint)
language sql
security definer
set search_path = public
stable
as $$
  select t.id,
         t.name,
         t.sport_id,
         s.name,
         count(a.id)::bigint
  from public.teams t
  left join public.sports s on s.id = t.sport_id
  left join public.athletes a on a.team_id = t.id
  where t.coach_id = (
    select c.id from public.coaches c where c.profile_id = auth.uid()
  )
  group by t.id, t.name, t.sport_id, s.name
  order by t.name;
$$;

grant execute on function public.my_teams_for_coach() to authenticated;

-- Teams the signed-in athlete plays for (their sport context).
create or replace function public.my_teams_for_athlete()
returns table (team_id uuid, team_name text, sport_id uuid, sport_name text)
language sql
security definer
set search_path = public
stable
as $$
  select t.id, t.name, t.sport_id, s.name
  from public.athletes a
  join public.teams t on t.id = a.team_id
  left join public.sports s on s.id = t.sport_id
  where a.profile_id = auth.uid()
  order by t.name;
$$;

grant execute on function public.my_teams_for_athlete() to authenticated;
