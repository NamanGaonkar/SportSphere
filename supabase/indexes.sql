create index if not exists idx_notifications_recipient_created on public.notifications(recipient_id, created_at desc);
create index if not exists idx_stock_tx_item on public.stock_transactions(item_id, created_at desc);
create index if not exists idx_po_items_po on public.purchase_order_items(po_id);
create index if not exists idx_attendance_date on public.attendance(date);
