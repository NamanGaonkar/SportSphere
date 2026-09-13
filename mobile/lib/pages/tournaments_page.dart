import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

const _levels = ['School', 'District', 'State', 'National'];

class TournamentsPage extends StatefulWidget {
  const TournamentsPage({super.key});

  @override
  State<TournamentsPage> createState() => _TournamentsPageState();
}

class _TournamentsPageState extends State<TournamentsPage> {
  List<DbRow> _rows = [];
  List<DbRow> _venues = [];
  bool _loading = true;
  String? _sportFilter;
  int _page = 0;
  final int _perPage = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        client
            .from('tournaments')
            .select('*, sports(name), venues(name), matches(count)')
            .order('start_date', ascending: false),
        client.from('venues').select('id, name').order('name'),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = ((results[0] as List).cast<DbRow>())
          ..sort((a, b) => '${a['name'] ?? ''}'.compareTo('${b['name'] ?? ''}'));
        _venues = (results[1] as List).cast<DbRow>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Load failed: $e', error: true);
    }
  }

  List<DbRow> get _filtered => _sportFilter == null
      ? _rows
      : _rows.where((r) => '${r['sport_id'] ?? ''}' == _sportFilter).toList();

  @override
  Widget build(BuildContext context) {
    final sports = SportsCache.instance.rows;
    final filtered = _filtered;
    final total = filtered.length;
    if (_page > (total - 1) ~/ _perPage) _page = total == 0 ? 0 : (total - 1) ~/ _perPage;
    final slice = filtered.skip(_page * _perPage).take(_perPage).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHead('Tournaments',
              sub: 'Competitions across School, District, State and National levels.',
              action: FilledButton.icon(
                onPressed: () => _showForm(null),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Tournament'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              )),
          Align(
            alignment: Alignment.centerLeft,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _sportFilter,
                hint: const Text('All sports', style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All sports', style: TextStyle(fontSize: 13))),
                  for (final s in sports)
                    DropdownMenuItem(value: '${s['id']}', child: Text('${s['name']}', style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => setState(() {
                  _sportFilter = v;
                  _page = 0;
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: _loading
                ? const LoadingState()
                : total == 0
                    ? const EmptyState('No tournaments yet.')
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 22,
                            headingRowHeight: 44,
                            headingTextStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
                            headingRowColor: const WidgetStatePropertyAll(Color(0xFFF5F5F0)),
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Sport')),
                              DataColumn(label: Text('Level')),
                              DataColumn(label: Text('Dates')),
                              DataColumn(label: Text('Venue')),
                              DataColumn(label: Text('Matches')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: [
                              for (final t in slice)
                                DataRow(cells: [
                                  DataCell(Text('${t['name'] ?? '-'}')),
                                  DataCell(Text('${((t['sports'] ?? {}) as Map)['name'] ?? '-'}')),
                                  DataCell(BadgeChip('${t['level'] ?? '-'}',
                                      color: levelColor('${t['level'] ?? ''}'))),
                                  DataCell(Text(
                                      '${fmtDate(t['start_date']?.toString())} to ${fmtDate(t['end_date']?.toString())}')),
                                  DataCell(Text('${((t['venues'] ?? {}) as Map)['name'] ?? '-'}')),
                                  DataCell(Text(
                                      '${((t['matches'] as List?) ?? const []).isNotEmpty ? (t['matches'] as List)[0]['count'] : 0}')),
                                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.edit_outlined, size: 19),
                                      onPressed: () => _showForm(t),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.delete_outline,
                                          size: 19, color: Color(0xFFC62828)),
                                      onPressed: () => _remove(t),
                                    ),
                                  ])),
                                ]),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _page > 0 ? () => setState(() => _page--) : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('${_page + 1}', style: const TextStyle(fontSize: 12.5)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: (_page + 1) * _perPage < total ? () => setState(() => _page++) : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ]),
                        ),
                      ]),
          ),
        ],
      ),
    );
  }

  Future<void> _showForm(DbRow? editing) async {
    String name = '${editing?['name'] ?? ''}';
    String level = '${editing?['level'] ?? 'School'}';
    String sportId = '${editing?['sport_id'] ?? ''}';
    String startDate = (editing?['start_date']?.toString() ?? '').split('T').first;
    String endDate = (editing?['end_date']?.toString() ?? '').split('T').first;
    String venueId = '';
    final nameCtrl = TextEditingController(text: name);
    final sports = SportsCache.instance.rows;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          builder: (ctx, scrollCtrl) => StatefulBuilder(
            builder: (ctx, setM) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(editing == null ? 'Add Tournament' : 'Edit Tournament',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: level,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Level'),
                        items: [for (final l in _levels) DropdownMenuItem(value: l, child: Text(l))],
                        onChanged: (v) => setM(() => level = v ?? 'School'),
                      ),
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
                      DateField(label: 'Start date', value: startDate, onChanged: (v) => setM(() => startDate = v ?? '')),
                      const SizedBox(height: 14),
                      DateField(label: 'End date', value: endDate, onChanged: (v) => setM(() => endDate = v ?? '')),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: venueId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Venue'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('None')),
                          for (final v in _venues)
                            DropdownMenuItem(value: '${v['id']}', child: Text('${v['name']}')),
                        ],
                        onChanged: (v) => setM(() => venueId = v ?? ''),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.of(ctx).padding.bottom),
                  child: Row(children: [
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
                ),
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
        'level': level,
        'sport_id': sportId.isEmpty ? null : sportId,
        'start_date': startDate.isEmpty ? null : startDate,
        'end_date': endDate.isEmpty ? null : endDate,
        'venue_id': venueId.isEmpty ? null : venueId,
      };
      if (editing != null) {
        await client.from('tournaments').update(payload).eq('id', editing['id']);
      } else {
        await client.from('tournaments').insert(payload);
      }
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _remove(DbRow t) async {
    if (!await confirmDelete(context, 'tournament and its matches')) return;
    await client.from('tournaments').delete().eq('id', t['id']);
    _load();
  }
}
