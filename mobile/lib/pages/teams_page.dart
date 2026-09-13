import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

class TeamsPage extends StatefulWidget {
  const TeamsPage({super.key});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  List<DbRow> _rows = [];
  List<DbRow> _coaches = [];
  bool _loading = true;
  String _q = '';
  String? _sportFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        client
            .from('teams')
            .select('*, sports(name), coaches(*, profile:profiles(full_name)), athletes(count)')
            .order('name'),
        client.from('coaches').select('id, profile:profiles(full_name)').order('id'),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = (results[0] as List).cast<DbRow>();
        _coaches = (results[1] as List).cast<DbRow>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Load failed: $e', error: true);
    }
  }

  List<DbRow> get _filtered => _rows.where((r) {
        final nameOk = '${r['name'] ?? ''}'.toLowerCase().contains(_q.toLowerCase());
        final sportOk = _sportFilter == null || '${r['sport_id'] ?? ''}' == _sportFilter;
        return nameOk && sportOk;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final sports = SportsCache.instance.rows;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHead('Teams',
              sub: 'Squads by sport, with coach assignment and roster size.',
              action: FilledButton.icon(
                onPressed: () => _showForm(null),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Team'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              )),
          Row(children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                    hintText: 'Search teams', prefixIcon: Icon(Icons.search, size: 20), isDense: true),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _sportFilter,
                hint: const Text('All sports', style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All sports', style: TextStyle(fontSize: 13))),
                  for (final s in sports)
                    DropdownMenuItem(value: '${s['id']}', child: Text('${s['name']}', style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => setState(() => _sportFilter = v),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Card(
            child: _loading
                ? const LoadingState()
                : PagedTable(
                    items: _filtered,
                    emptyText: 'No teams found.',
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Sport')),
                      DataColumn(label: Text('Coach')),
                      DataColumn(label: Text('Roster')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rowBuilder: (t) => DataRow(cells: [
                      DataCell(Text('${t['name'] ?? '-'}')),
                      DataCell(Text('${((t['sports'] ?? {}) as Map)['name'] ?? '-'}')),
                      DataCell(Text('${(((t['coaches'] ?? {}) as Map)['profile'] ?? {})['full_name'] ?? '-'}')),
                      DataCell(Text('${(((t['athletes'] as List?) ?? const []).isNotEmpty ? (t['athletes'] as List)[0]['count'] : 0)} athletes')),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () => _showForm(t),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFC62828)),
                          onPressed: () => _remove(t),
                        ),
                      ])),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showForm(DbRow? editing) async {
    String name = '${editing?['name'] ?? ''}';
    String sportId = '${editing?['sport_id'] ?? ''}';
    String coachId = '${editing?['coach_id'] ?? ''}';
    final nameCtrl = TextEditingController(text: name);
    final sports = SportsCache.instance.rows;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: StatefulBuilder(
            builder: (ctx, setM) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(editing == null ? 'Add Team' : 'Edit Team',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: sportId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sport'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('No sport')),
                    for (final s in sports)
                      DropdownMenuItem(value: '${s['id']}', child: Text('${s['name']}')),
                  ],
                  onChanged: (v) => setM(() => sportId = v ?? ''),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: coachId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Coach'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('None')),
                    for (final c in _coaches)
                      DropdownMenuItem(
                          value: '${c['id']}',
                          child: Text('${((c['profile'] ?? {}) as Map)['full_name'] ?? 'Coach'}')),
                  ],
                  onChanged: (v) => setM(() => coachId = v ?? ''),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        name = nameCtrl.text.trim();
                        Navigator.pop(ctx, true);
                      },
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
    if (ok != true || name.isEmpty) return;
    try {
      final payload = {
        'name': name,
        'sport_id': sportId.isEmpty ? null : sportId,
        'coach_id': coachId.isEmpty ? null : coachId,
      };
      if (editing != null) {
        await client.from('teams').update(payload).eq('id', editing['id']);
      } else {
        await client.from('teams').insert(payload);
      }
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _remove(DbRow t) async {
    if (!await confirmDelete(context, 'team? Athletes will be unlinked')) return;
    await client.from('teams').delete().eq('id', t['id']);
    _load();
  }
}
