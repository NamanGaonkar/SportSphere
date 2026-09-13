import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

class VenuesAdminPage extends StatefulWidget {
  const VenuesAdminPage({super.key});

  @override
  State<VenuesAdminPage> createState() => _VenuesAdminPageState();
}

class _VenuesAdminPageState extends State<VenuesAdminPage> {
  List<DbRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await client.from('venues').select('*, venue_bookings(count)').order('name');
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHead('Venues',
              sub: 'Grounds, arenas and facilities.',
              action: FilledButton.icon(
                onPressed: () => _showForm(null),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Venue'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              )),
          if (_loading)
            const Card(child: LoadingState())
          else if (_rows.isEmpty)
            const Card(child: EmptyState('No venues yet.'))
          else
            LayoutBuilder(builder: (context, constraints) {
              const gap = 16.0;
              final cols = constraints.maxWidth >= 640 ? 3 : (constraints.maxWidth >= 420 ? 2 : 1);
              final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final v in _rows)
                    SizedBox(
                      width: w,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text('${v['name'] ?? '-'}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                                ),
                                BadgeChip('${v['status'] ?? '-'}',
                                    color: statusColor('${v['status'] ?? ''}')),
                              ]),
                              const SizedBox(height: 4),
                              Text('${v['location'] ?? '-'}',
                                  style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                              const SizedBox(height: 8),
                              Text(
                                'Capacity: ${v['capacity'] ?? '-'} - Bookings: ${((v['venue_bookings'] as List?) ?? const []).isNotEmpty ? (v['venue_bookings'] as List)[0]['count'] : 0}',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              const SizedBox(height: 6),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit_outlined, size: 19),
                                  onPressed: () => _showForm(v),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFC62828)),
                                  onPressed: () => _remove(v),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showForm(DbRow? editing) async {
    final nameCtrl = TextEditingController(text: '${editing?['name'] ?? ''}');
    final locCtrl = TextEditingController(text: '${editing?['location'] ?? ''}');
    final capCtrl = TextEditingController(text: '${editing?['capacity'] ?? ''}');
    String status = editing != null ? '${editing['status']}' : 'Active';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: Text(editing == null ? 'Add Venue' : 'Edit Venue'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location')),
            const SizedBox(height: 12),
            TextField(
              controller: capCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: numberInput,
              decoration: const InputDecoration(labelText: 'Capacity'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final s in ['Active', 'Maintenance', 'Closed']) DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) => setM(() => status = v ?? 'Active'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx, true);
                },
                child: Text(editing == null ? 'Add' : 'Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final payload = {
        'name': nameCtrl.text.trim(),
        'location': locCtrl.text.trim().isEmpty ? null : locCtrl.text.trim(),
        'capacity': capCtrl.text.isEmpty ? null : num.tryParse(capCtrl.text),
        'status': status,
      };
      if (editing != null) {
        await client.from('venues').update(payload).eq('id', editing['id']);
      } else {
        await client.from('venues').insert(payload);
      }
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _remove(DbRow v) async {
    if (!await confirmDelete(context, 'venue')) return;
    await client.from('venues').delete().eq('id', v['id']);
    _load();
  }
}
