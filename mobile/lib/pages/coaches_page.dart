import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

class CoachesPage extends StatefulWidget {
  const CoachesPage({super.key});

  @override
  State<CoachesPage> createState() => _CoachesPageState();
}

class _CoachesPageState extends State<CoachesPage> {
  List<DbRow> _rows = [];
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await client
          .from('coaches')
          .select('*, profile:profiles(id, full_name, contact_info), teams(id, name)')
          .order('created_at');
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

  List<DbRow> get _filtered => _q.isEmpty
      ? _rows
      : _rows
          .where((r) => '${((r['profile'] ?? {}) as Map)['full_name'] ?? ''}'
              .toLowerCase()
              .contains(_q.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHead('Coaches',
              sub: 'Coaching staff and their specializations.',
              action: FilledButton.icon(
                onPressed: () => _showForm(null),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Coach'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              )),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                  hintText: 'Search by name', prefixIcon: Icon(Icons.search, size: 20), isDense: true),
            ),
          ),
          Card(
            child: _loading
                ? const LoadingState()
                : PagedTable(
                    items: _filtered,
                    emptyText: 'No coaches found.',
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Specialization')),
                      DataColumn(label: Text('Sport')),
                      DataColumn(label: Text('Teams')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rowBuilder: (r) {
                      final teams = (r['teams'] as List?) ?? const [];
                      return DataRow(cells: [
                        DataCell(Text('${((r['profile'] ?? {}) as Map)['full_name'] ?? '-'}')),
                        DataCell(Text('${r['specialization'] ?? '-'}')),
                        DataCell(Text(SportsCache.instance.name(r['sport_id']?.toString()))),
                        DataCell(
                          teams.isEmpty
                              ? const Text('-', style: TextStyle(color: Colors.black26))
                              // Team chips instead of a comma blob — each
                              // assignment is scannable at a glance.
                              : Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    for (final t in teams)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0x14FF6A13),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: const Color(0x40FF6A13)),
                                        ),
                                        child: Text(
                                          '${(t as Map)['name'] ?? '-'}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB24A00)),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_outlined, size: 19),
                            onPressed: () => _showForm(r),
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
          ),
        ],
      ),
    );
  }

  Future<void> _showForm(DbRow? editing) async {
    final nameCtrl = TextEditingController(text: '${((editing?['profile'] ?? {}) as Map)['full_name'] ?? ''}');
    final specCtrl = TextEditingController(text: '${editing?['specialization'] ?? ''}');
    final certCtrl = TextEditingController(text: '${editing?['certification'] ?? ''}');
    final expCtrl = TextEditingController(text: '${editing?['experience_years'] ?? ''}');
    String? sportId = editing?['sport_id']?.toString();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(editing == null ? 'Add Coach' : 'Edit Coach',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 14),
              TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Specialization')),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: (sportId?.isEmpty ?? true) ? null : sportId,
                decoration: const InputDecoration(labelText: 'Sport'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: '', child: Text('None')),
                  for (final s in SportsCache.instance.rows)
                    DropdownMenuItem(value: s['id'] as String, child: Text('${s['name']}')),
                ],
                onChanged: (v) => setModal(() => sportId = v),
              ),
              const SizedBox(height: 14),
              TextField(controller: certCtrl, decoration: const InputDecoration(labelText: 'Certification')),
              const SizedBox(height: 14),
              TextField(controller: expCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Experience (years)')),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(editing == null ? 'Add' : 'Save'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final spec = specCtrl.text.trim();
    final payload = <String, dynamic>{
      'specialization': spec.isEmpty ? null : spec,
      'sport_id': (sportId?.isEmpty ?? true) ? null : sportId,
      'certification': certCtrl.text.trim().isEmpty ? null : certCtrl.text.trim(),
      'experience_years': expCtrl.text.trim().isEmpty ? null : num.tryParse(expCtrl.text.trim()),
    };
    try {
      if (editing != null) {
        final profileId = ((editing['profile'] ?? {}) as Map)['id'];
        if (profileId != null) {
          await client.from('profiles').update({'full_name': name}).eq('id', profileId);
        }
        await client.from('coaches').update(payload).eq('id', editing['id']);
      } else {
        final profile = await client.from('profiles').insert({'full_name': name, 'role': 'Coach'}).select('id').single();
        await client.from('coaches').insert({'profile_id': profile['id'], ...payload});
      }
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _remove(DbRow r) async {
    if (!await confirmDelete(context, 'coach')) return;
    await client.from('coaches').delete().eq('id', r['id']);
    _load();
  }
}
