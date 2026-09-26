import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart' show listen;
import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

const _poStatuses = ['Draft', 'Ordered', 'Received', 'Cancelled'];

/// Mobile mirror of web/src/pages/Purchases.tsx — connected vendors +
/// purchase orders with real line items; "Received" auto-stocks inventory.
class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  List<DbRow> _pos = [];
  List<DbRow> _items = [];
  List<DbRow> _vendors = [];
  List<DbRow> _inventory = [];
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
    listen('purchase_orders', _load);
    listen('purchase_order_items', _load);
    listen('vendors', _load);
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        client.from('purchase_orders').select('id, status, total, created_at, vendors(name)').order('created_at', ascending: false),
        client.from('purchase_order_items').select('*, inventory_items(name), purchase_orders(status, vendors(name))').order('created_at', ascending: false),
        client.from('vendors').select('*').order('name'),
        client.from('inventory_items').select('id, name, unit_cost').order('name'),
      ]);
      if (!mounted) return;
      setState(() {
        _pos = (results[0] as List).cast<DbRow>();
        _items = (results[1] as List).cast<DbRow>();
        _vendors = (results[2] as List).cast<DbRow>();
        _inventory = (results[3] as List).cast<DbRow>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Load failed: $e', error: true);
    }
  }

  num _poValue(String id) => _items
      .where((i) => i['po_id'] == id)
      .fold(0, (s, i) => s + ((i['quantity'] ?? 0) as num? ?? 0) * ((i['unit_cost'] ?? 0) as num? ?? 0));

  @override
  Widget build(BuildContext context) {
    final pending = _pos.where((p) => p['status'] == 'Ordered').toList();
    final pendingValue = pending.fold<num>(0, (s, p) => s + _poValue('${p['id']}'));
    return DefaultTabController(
      length: 3,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageHead('Vendor & Purchase Management',
                sub: 'Orders with linked line items; receiving auto-updates stock.',
                action: FilledButton.icon(
                  onPressed: _tab == 2 ? _addVendor : _newPO,
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(_tab == 2 ? 'Add Vendor' : 'New Order'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                )),
            LayoutBuilder(builder: (context, constraints) {
              const gap = 12.0;
              final w = (constraints.maxWidth - gap * 2) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(width: w, child: StatCard(label: 'ORDERS', value: '${_pos.length}', sub: '${_pos.where((p) => p['status'] == 'Received').length} received', variant: 0)),
                  SizedBox(width: w, child: StatCard(label: 'PENDING', value: '${pending.length}', sub: '${inr(pendingValue)} on order', variant: 4)),
                  SizedBox(width: w, child: StatCard(label: 'VENDORS', value: '${_vendors.length}', sub: 'Active suppliers', variant: 2)),
                ],
              );
            }),
            const SizedBox(height: 12),
            TabBar(
              tabs: const [
                Tab(text: 'Orders'),
                Tab(text: 'Line items'),
                Tab(text: 'Vendors'),
              ],
              labelColor: Brand.primary,
              // Theme-aware: black54 was invisible in dark mode (round 3 #13).
              unselectedLabelColor: subT(context),
              indicatorColor: Brand.primary,
              onTap: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LoadingState()
            else if (_tab == 0)
              _ordersTable()
            else if (_tab == 1)
              _itemsTable()
            else
              _vendorsTable(),
          ],
        ),
      ),
    );
  }

  Widget _ordersTable() {
    return Card(
      child: PagedTable(
        items: _pos,
        emptyText: 'No purchase orders yet.',
        columns: const [
          DataColumn(label: Text('Vendor')),
          DataColumn(label: Text('Lines')),
          DataColumn(label: Text('Total')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Change')),
        ],
        rowBuilder: (p) {
          final status = '${p['status']}';
          final lines = _items.where((i) => i['po_id'] == p['id']).length;
          return DataRow(cells: [
            DataCell(Text('${((p['vendors'] ?? {}) as Map)['name'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text('$lines')),
            DataCell(Text(inr(_poValue('${p['id']}')), style: const TextStyle(fontWeight: FontWeight.w700))),
            DataCell(BadgeChip(status,
                color: status == 'Received'
                    ? const Color(0xFF2E7D32)
                    : status == 'Ordered'
                        ? const Color(0xFF1565C0)
                        : status == 'Cancelled'
                            ? const Color(0xFFC62828)
                            : const Color(0xFF757575))),
            DataCell(SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: status,
                isDense: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                items: [for (final s in _poStatuses) DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))],
                onChanged: (v) async {
                  if (v == null || v == status) return;
                  try {
                    await client.from('purchase_orders').update({'status': v}).eq('id', p['id']);
                    _load();
                  } catch (e) {
                    if (mounted) showSnack(context, 'Update failed: $e', error: true);
                  }
                },
              ),
            )),
          ]);
        },
      ),
    );
  }

  Widget _itemsTable() {
    return Card(
      child: PagedTable(
        items: _items,
        emptyText: 'No line items yet.',
        columns: const [
          DataColumn(label: Text('Description')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Unit cost')),
          DataColumn(label: Text('Line total')),
          DataColumn(label: Text('Order')),
        ],
        rowBuilder: (i) {
          final qty = ((i['quantity'] ?? 0) as num? ?? 0).toInt();
          final cost = (i['unit_cost'] ?? 0) as num? ?? 0;
          final po = (i['purchase_orders'] ?? {}) as Map;
          return DataRow(cells: [
            DataCell(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i['description']}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
              Text('${((i['inventory_items'] ?? {}) as Map)['name'] ?? 'Unlinked'}',
                  style: TextStyle(fontSize: 11, color: subT(context))),
            ])),
            DataCell(Text('$qty')),
            DataCell(Text(inr(cost))),
            DataCell(Text(inr(qty * cost), style: const TextStyle(fontWeight: FontWeight.w700))),
            DataCell(Text('${po['vendors']?['name'] ?? '-'} (${po['status'] ?? ''})', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          ]);
        },
      ),
    );
  }

  Widget _vendorsTable() {
    return Card(
      child: PagedTable(
        items: _vendors,
        emptyText: 'No vendors yet.',
        columns: const [
          DataColumn(label: Text('Vendor')),
          DataColumn(label: Text('Contact')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Orders')),
          DataColumn(label: Text('Actions')),
        ],
        rowBuilder: (v) => DataRow(cells: [
          DataCell(Text('${v['name'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text('${v['contact'] ?? '-'}')),
          DataCell(Text('${v['category'] ?? '-'}')),
          DataCell(Text('${_pos.where((p) => ((p['vendors'] ?? {}) as Map)['name'] == v['name']).length}')),
          DataCell(IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFC62828)),
            onPressed: () => _removeVendor(v),
          )),
        ]),
      ),
    );
  }

  Future<void> _newPO() async {
    String? vendorId;
    var status = 'Draft';
    final lines = <({String itemId, String descr, String qty, String cost})>[];

    Future<void> addLine() async {
      String? itemId;
      final descrCtrl = TextEditingController();
      final qtyCtrl = TextEditingController(text: '1');
      final costCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('Add line item'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              SmartDropdown<String>(
                value: itemId ?? '',
                labelText: 'Inventory item (optional link)',
                items: [
                  const DropdownMenuItem(value: '', child: Text('Custom (no stock link)')),
                  for (final i in _inventory) DropdownMenuItem(value: '${i['id']}', child: Text('${i['name']}')),
                ],
                onChanged: (v) => setD(() {
                  itemId = v;
                  final inv = _inventory.where((i) => '${i['id']}' == v).toList();
                  if (inv.isNotEmpty && costCtrl.text.isEmpty) costCtrl.text = '${inv.first['unit_cost'] ?? ''}';
                  descrCtrl.text = inv.isNotEmpty ? '${inv.first['name']}' : descrCtrl.text;
                }),
              ),
              const SizedBox(height: 10),
              TextField(controller: descrCtrl, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 10),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, inputFormatters: numberInput, decoration: const InputDecoration(labelText: 'Quantity')),
              const SizedBox(height: 10),
              TextField(controller: costCtrl, keyboardType: TextInputType.number, inputFormatters: numberInput, decoration: const InputDecoration(labelText: 'Unit cost (INR)')),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add line')),
            ],
          ),
        ),
      );
      if (ok == true && descrCtrl.text.trim().isNotEmpty) {
        lines.add((
          itemId: itemId ?? '',
          descr: descrCtrl.text.trim(),
          qty: qtyCtrl.text,
          cost: costCtrl.text,
        ));
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New purchase order'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmartDropdown<String>(
                  value: vendorId ?? '',
                  labelText: 'Vendor',
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Select vendor')),
                    for (final v in _vendors) DropdownMenuItem(value: '${v['id']}', child: Text('${v['name']}')),
                  ],
                  onChanged: (v) => setD(() => vendorId = (v == null || v.isEmpty) ? null : v),
                ),
                const SizedBox(height: 10),
                SmartDropdown<String>(
                  value: status,
                  labelText: 'Status',
                  items: [for (final s in _poStatuses) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) => setD(() => status = v ?? 'Draft'),
                ),
                const SizedBox(height: 14),
                Text('Line items (${lines.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('- ${l.descr} x${l.qty} @ ${l.cost}',
                        style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85))),
                  ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    await addLine();
                    setD(() {});
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add line item'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create order')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    if (vendorId == null || lines.isEmpty) {
      if (mounted) showSnack(context, 'Pick a vendor and add at least one line item.', error: true);
      return;
    }
    final total = lines.fold<num>(0, (s, l) => s + (num.tryParse(l.qty) ?? 0) * (num.tryParse(l.cost) ?? 0));
    try {
      final created = await client.from('purchase_orders').insert({
        'vendor_id': vendorId,
        'status': status,
        'total': total,
        'items': [
          for (final l in lines)
            {'name': l.descr, 'qty': num.tryParse(l.qty) ?? 1, 'price': num.tryParse(l.cost) ?? 0},
        ],
      }).select('id').single();
      await client.from('purchase_order_items').insert([
        for (final l in lines)
          {
            'po_id': created['id'],
            'item_id': l.itemId.isEmpty ? null : l.itemId,
            'description': l.descr,
            'quantity': num.tryParse(l.qty)?.toInt() ?? 1,
            'unit_cost': num.tryParse(l.cost) ?? 0,
          },
      ]);
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _addVendor() async {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add vendor'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact')),
          const SizedBox(height: 10),
          TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await client.from('vendors').insert({
        'name': nameCtrl.text.trim(),
        'contact': contactCtrl.text.trim().isEmpty ? null : contactCtrl.text.trim(),
        'category': catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
      });
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _removeVendor(DbRow v) async {
    if (!await confirmDelete(context, 'vendor')) return;
    try {
      await client.from('vendors').delete().eq('id', v['id']);
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }
}
