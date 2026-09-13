import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<DbRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await client.from('inventory_items').select('*').order('name');
      if (!mounted) return;
      setState(() {
        _rows = (data as List).cast<DbRow>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Load failed: $e', error: true);
    }
  }

  List<DbRow> get _lowStock =>
      _rows.where((r) => ((r['quantity'] ?? 0) as num) < 10).toList();

  @override
  Widget build(BuildContext context) {
    final low = _lowStock;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHead('Inventory & Equipment',
              sub: 'Kit and equipment stock levels.',
              action: FilledButton.icon(
                onPressed: () => _add(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Item'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              )),
          if (low.isNotEmpty)
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
                          BadgeChip('${i['quantity']} left', color: const Color(0xFFB26A00)),
                        ],
                      ),
                    ),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: _loading
                ? const LoadingState()
                : PagedTable(
                    items: _rows,
                    emptyText: 'No inventory items yet.',
                    columns: const [
                      DataColumn(label: Text('Item')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Quantity')),
                      DataColumn(label: Text('Condition')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rowBuilder: (r) => DataRow(cells: [
                      DataCell(Text('${r['name'] ?? '-'}')),
                      DataCell(Text('${r['category'] ?? '-'}')),
                      DataCell(Text('${r['quantity'] ?? 0}')),
                      DataCell(Text('${r['condition'] ?? '-'}')),
                      DataCell(IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFC62828)),
                        onPressed: () => _remove(r),
                      )),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Inventory Item'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category')),
          const SizedBox(height: 12),
          TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: numberInput,
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    try {
      await client.from('inventory_items').insert({
        'name': nameCtrl.text.trim(),
        'category': catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
        'quantity': qtyCtrl.text.isEmpty ? 0 : num.tryParse(qtyCtrl.text) ?? 0,
      });
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _remove(DbRow r) async {
    if (!await confirmDelete(context, 'item')) return;
    await client.from('inventory_items').delete().eq('id', r['id']);
    _load();
  }
}
