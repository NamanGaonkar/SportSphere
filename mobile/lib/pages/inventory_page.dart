import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart' show listen;
import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

/// Mobile mirror of web/src/pages/Inventory.tsx — detailed equipment
/// management: stat cards, low-stock panel, full item fields, stock
/// movement dialog (RPC), and the movement history tab.
class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<DbRow> _rows = [];
  List<DbRow> _txs = [];
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
    listen('inventory_items', _load);
    listen('stock_transactions', _load);
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        client.from('inventory_items').select('*, teams(name)').order('name'),
        client
            .from('stock_transactions')
            .select('*, inventory_items(name), profiles(full_name)')
            .order('created_at', ascending: false)
            .limit(100),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = (results[0] as List).cast<DbRow>();
        _txs = (results[1] as List).cast<DbRow>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Load failed: $e', error: true);
    }
  }

  List<DbRow> get _lowStock => _rows
      .where((r) => ((r['quantity'] ?? 0) as num) <= ((r['min_stock'] ?? 0) as num? ?? 0))
      .toList();

  num get _totalValue => _rows.fold(0, (s, r) => s + ((r['quantity'] ?? 0) as num? ?? 0) * ((r['unit_cost'] ?? 0) as num? ?? 0));

  @override
  Widget build(BuildContext context) {
    final low = _lowStock;
    final units = _rows.fold<int>(0, (s, r) => s + ((r['quantity'] ?? 0) as num? ?? 0).toInt());
    return DefaultTabController(
      length: 2,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageHead('Inventory & Equipment',
                sub: 'Stock levels, locations, conditions and movements.',
                action: FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Item'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                )),
            LayoutBuilder(builder: (context, constraints) {
              const gap = 12.0;
              final w = (constraints.maxWidth - gap * 2) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(width: w, child: StatCard(label: 'ITEMS', value: '${_rows.length}', sub: '$units units in stock')),
                  SizedBox(width: w, child: StatCard(label: 'LOW STOCK', value: '${low.length}', sub: 'At or below minimum')),
                  SizedBox(width: w, child: StatCard(label: 'VALUE', value: inrCompact(_totalValue), sub: 'Qty x unit cost')),
                ],
              );
            }),
            const SizedBox(height: 12),
            if (low.isNotEmpty && _tab == 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('LOW STOCK (${low.length})',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFFB26A00))),
                    const SizedBox(height: 8),
                    for (final i in low)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text('${i['name']}', style: const TextStyle(fontSize: 13))),
                            BadgeChip('${i['quantity']} left (min ${i['min_stock'] ?? 0})', color: const Color(0xFFB26A00)),
                          ],
                        ),
                      ),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            TabBar(
              tabs: const [
                Tab(text: 'Equipment'),
                Tab(text: 'Stock movements'),
              ],
              labelColor: Brand.primary,
              unselectedLabelColor: Colors.black54,
              indicatorColor: Brand.primary,
              onTap: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LoadingState()
            else if (_tab == 0)
              _itemsTable()
            else
              _txTable(),
          ],
        ),
      ),
    );
  }

  Widget _itemsTable() {
    return Card(
      child: PagedTable(
        items: _rows,
        emptyText: 'No inventory items yet.',
        detailBuilder: (r) => [
          MapEntry('Item', '${r['name'] ?? '-'}'),
          MapEntry('Category', '${r['category'] ?? '-'}'),
          MapEntry('Stock', '${r['quantity'] ?? 0} ${r['unit'] ?? ''} (min ${r['min_stock'] ?? 0})'),
          MapEntry('Condition', '${r['condition'] ?? '-'}'),
          MapEntry('Location', '${r['location'] ?? '-'}'),
          MapEntry('Assigned team', '${((r['teams'] ?? {}) as Map)['name'] ?? '-'}'),
          MapEntry('Unit cost', inr(_n(r['unit_cost']))),
          MapEntry('Total value', inr(_n(r['quantity']) * _n(r['unit_cost']))),
        ],
        chipsBuilder: (r) {
          final qty = _n(r['quantity']).toInt();
          final minq = _n(r['min_stock']).toInt();
          final low = qty <= minq;
          return [
            (low ? 'Low stock' : 'Healthy stock', low ? const Color(0xFFB26A00) : const Color(0xFF2E7D32)),
            ('Stock value ${inr(_n(r['quantity']) * _n(r['unit_cost']))}', Brand.primary),
          ];
        },
        columns: const [
          DataColumn(label: Text('Item')),
          DataColumn(label: Text('Stock')),
          DataColumn(label: Text('Condition')),
          DataColumn(label: Text('Location')),
          DataColumn(label: Text('Team')),
          DataColumn(label: Text('Actions')),
        ],
        rowBuilder: (r) {
          final qty = ((r['quantity'] ?? 0) as num? ?? 0).toInt();
          final minq = ((r['min_stock'] ?? 0) as num? ?? 0).toInt();
          final low = qty <= minq;
          final cond = '${r['condition'] ?? '-'}';
          return DataRow(cells: [
            DataCell(GestureDetector(
              onTap: () => _edit(r),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['name'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${r['category'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
            )),
            DataCell(BadgeChip('$qty ${r['unit'] ?? ''}',
                color: low ? const Color(0xFFB26A00) : const Color(0xFF2E7D32))),
            DataCell(BadgeChip(cond, color: statusColor(cond == 'Good' || cond == 'New' ? 'Active' : cond == 'Worn' ? 'Late' : 'Maintenance'))),
            DataCell(Text('${r['location'] ?? '-'}', overflow: TextOverflow.ellipsis)),
            DataCell(Text('${((r['teams'] ?? {}) as Map)['name'] ?? '-'}', overflow: TextOverflow.ellipsis)),
            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.swap_vert, size: 19),
                color: Brand.primary,
                onPressed: () => _move(r),
                tooltip: 'Stock movement',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _edit(r),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFC62828)),
                onPressed: () => _remove(r),
              ),
            ])),
          ]);
        },
      ),
    );
  }

  Widget _txTable() {
    return Card(
      child: PagedTable(
        items: _txs,
        emptyText: 'No stock movements yet.',
        detailBuilder: (t) => [
          MapEntry('Item', '${((t['inventory_items'] ?? {}) as Map)['name'] ?? '-'}'),
          MapEntry('Type', '${t['tx_type']}'),
          MapEntry('Quantity', '${t['quantity']}'),
          MapEntry('Note', '${t['note'] ?? '-'}'),
          MapEntry('By', '${((t['profiles'] ?? {}) as Map)['full_name'] ?? '-'}'),
          MapEntry('When', fmtDateTime(t['created_at']?.toString())),
        ],
        columns: const [
          DataColumn(label: Text('Item')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Note')),
          DataColumn(label: Text('When')),
        ],
        rowBuilder: (t) {
          final ty = '${t['tx_type']}';
          return DataRow(cells: [
            DataCell(Text('${((t['inventory_items'] ?? {}) as Map)['name'] ?? '-'}', overflow: TextOverflow.ellipsis)),
            DataCell(BadgeChip(ty,
                color: ty == 'IN'
                    ? const Color(0xFF2E7D32)
                    : ty == 'OUT'
                        ? const Color(0xFFB26A00)
                        : const Color(0xFF1565C0))),
            DataCell(Text('${t['quantity']}', style: const TextStyle(fontWeight: FontWeight.w700))),
            DataCell(Text('${t['note'] ?? '-'}', overflow: TextOverflow.ellipsis)),
            DataCell(Text(fmtDateTime(t['created_at']?.toString()), style: const TextStyle(fontSize: 11.5))),
          ]);
        },
      ),
    );
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);

Future<void> _move(DbRow item) async {
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var type = 'IN';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Stock movement - ${item['name']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'IN', child: Text('IN - stock received')),
                DropdownMenuItem(value: 'OUT', child: Text('OUT - issued / consumed')),
                DropdownMenuItem(value: 'MAINTENANCE', child: Text('MAINTENANCE - sent for repair')),
                DropdownMenuItem(value: 'ADJUST', child: Text('ADJUST - set exact count')),
              ],
              onChanged: (v) => setD(() => type = v ?? 'IN'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: numberInput,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note')),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Current stock: ${item['quantity']} ${item['unit'] ?? ''}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final qty = num.tryParse(qtyCtrl.text);
    if (qty == null || qty <= 0) {
      if (mounted) showSnack(context, 'Enter a valid quantity.', error: true);
      return;
    }
    try {
      await client.rpc('stock_move', params: {
        'p_item': item['id'],
        'p_type': type,
        'p_qty': qty.toInt(),
        'p_note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      });
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Movement failed: $e', error: true);
    }
  }

  Future<void> _add() => _itemForm(null);

  Future<void> _edit(DbRow r) => _itemForm(r);

  Future<void> _itemForm(DbRow? editing) async {
    final nameCtrl = TextEditingController(text: '${editing?['name'] ?? ''}');
    final catCtrl = TextEditingController(text: '${editing?['category'] ?? ''}');
    final qtyCtrl = TextEditingController(text: '${editing?['quantity'] ?? ''}');
    final minCtrl = TextEditingController(text: '${editing?['min_stock'] ?? ''}');
    final costCtrl = TextEditingController(text: '${editing?['unit_cost'] ?? ''}');
    final locCtrl = TextEditingController(text: '${editing?['location'] ?? ''}');
    final unitCtrl = TextEditingController(text: '${editing?['unit'] ?? 'pcs'}');
    var condition = '${editing?['condition'] ?? 'Good'}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(editing == null ? 'Add Inventory Item' : 'Edit - ${editing['name']}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category')),
              const SizedBox(height: 10),
              if (editing == null)
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: numberInput,
                  decoration: const InputDecoration(labelText: 'Opening quantity'),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Quantity: ${editing['quantity']} (use stock movements to change)',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: condition,
                decoration: const InputDecoration(labelText: 'Condition'),
                items: const ['New', 'Good', 'Worn', 'Damaged', 'Under maintenance']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setD(() => condition = v ?? 'Good'),
              ),
              const SizedBox(height: 10),
              TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location')),
              const SizedBox(height: 10),
              TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit')),
              const SizedBox(height: 10),
              TextField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: numberInput,
                decoration: const InputDecoration(labelText: 'Minimum stock'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: numberInput,
                decoration: const InputDecoration(labelText: 'Unit cost (INR)'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(editing == null ? 'Add' : 'Save')),
          ],
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;

    final payload = <String, dynamic>{
      'name': nameCtrl.text.trim(),
      'category': catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
      'condition': condition,
      'location': locCtrl.text.trim().isEmpty ? null : locCtrl.text.trim(),
      'unit': unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim(),
      'min_stock': num.tryParse(minCtrl.text)?.toInt() ?? 0,
      'unit_cost': num.tryParse(costCtrl.text) ?? 0,
    };
    try {
      if (editing == null) {
        final created = await client.from('inventory_items').insert({
          ...payload,
          'quantity': num.tryParse(qtyCtrl.text)?.toInt() ?? 0,
        }).select('id').single();
        final qty = num.tryParse(qtyCtrl.text)?.toInt() ?? 0;
        if (qty > 0) {
          await client.rpc('stock_move', params: {
            'p_item': created['id'],
            'p_type': 'IN',
            'p_qty': qty,
            'p_note': 'Opening stock',
          });
        }
      } else {
        await client.from('inventory_items').update(payload).eq('id', editing['id']);
      }
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _remove(DbRow r) async {
    if (!await confirmDelete(context, 'item (and its movement history)')) return;
    try {
      await client.from('inventory_items').delete().eq('id', r['id']);
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }
}
