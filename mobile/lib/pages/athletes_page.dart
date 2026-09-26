import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

class AthletesPage extends StatefulWidget {
  const AthletesPage({super.key});

  @override
  State<AthletesPage> createState() => _AthletesPageState();
}

class _AthletesPageState extends State<AthletesPage> {
  List<DbRow> _rows = [];
  List<DbRow> _teams = [];
  bool _loading = true;
  String _q = '';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = listen('athletes', _load);
  }

  @override
  void dispose() {
    if (_channel != null) client.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        client
            .from('athletes')
            .select('*, profile:profiles(id, full_name, contact_info, avatar_url), teams(name), athlete_sports(sports(name))')
            .order('created_at'),
        client.from('teams').select('id, name').order('name'),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = (results[0] as List).cast<DbRow>();
        _teams = (results[1] as List).cast<DbRow>();
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

  int? _age(dynamic dob) {
    final d = DateTime.tryParse('${dob ?? ''}');
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return age;
  }

  String _sportNames(DbRow r) {
    final tags = r['athlete_sports'];
    if (tags is! List) return '-';
    final names = [
      for (final t in tags) ((t as Map)['sports'] ?? {})['name'],
    ].whereType<String>().toList();
    return names.isEmpty ? '-' : names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHead('Athletes',
              sub: 'Roster management - profiles, sports, team and medical notes.',
              action: FilledButton.icon(
                onPressed: () => _showForm(null),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Athlete'),
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
                    emptyText: 'No athletes found.',
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Sports')),
                      DataColumn(label: Text('Team')),
                      DataColumn(label: Text('Age')),
                      DataColumn(label: Text('Medical')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rowBuilder: (r) {
                      final medical = r['medical_notes']?.toString() ?? '';
                      final fullName = '${((r['profile'] ?? {}) as Map)['full_name'] ?? '-'}';
                      final avatarUrl = ((r['profile'] ?? {}) as Map)['avatar_url']?.toString();
                      return DataRow(cells: [
                        DataCell(Row(
                          children: [
                            // Uploaded profile photo with initial fallback —
                            // same data the web table shows.
                            CircleAvatar(
                              radius: 14,
                              backgroundImage:
                                  (avatarUrl?.isNotEmpty ?? false) ? NetworkImage(avatarUrl!) : null,
                              backgroundColor: const Color(0x2EFF6A13),
                              child: (avatarUrl?.isNotEmpty ?? false)
                                  ? null
                                  : Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB25A1F))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(fullName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        )),
                        DataCell(Text(_sportNames(r))),
                        DataCell(Text('${((r['teams'] ?? {}) as Map)['name'] ?? '-'}')),
                        DataCell(Text('${_age(r['dob']) ?? '-'}')),
                        // No note = no badge at all (a blank note used to
                        // read as a fake "OK" status — misleading).
                        if (medical.isNotEmpty)
                          DataCell(BadgeChip(medical.length > 24 ? '${medical.substring(0, 24)}...' : medical,
                              color: const Color(0xFFB26A00)))
                        else
                          DataCell(Text('-', style: TextStyle(color: faintT(context)))),
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
    String name = '${((editing?['profile'] ?? {}) as Map)['full_name'] ?? ''}';
    String dob = (editing?['dob']?.toString() ?? '').split('T').first;
    String teamId = editing?['team_id']?.toString() ?? '';
    String medical = editing?['medical_notes']?.toString() ?? '';
    Set<String> sportIds = {};
    if (editing != null) {
      final tags = await client.from('athlete_sports').select('sport_id').eq('athlete_id', editing['id']);
      sportIds = (tags as List).map((t) => t['sport_id'].toString()).toSet();
    }
    final sports = SportsCache.instance.rows;
    final nameCtrl = TextEditingController(text: name);
    final medicalCtrl = TextEditingController(text: medical);
    if (!mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          // Plain scrollable sheet: title on top, fields below, buttons fixed
          // at the bottom. No DraggableScrollableSheet — its collapsed height
          // could hide the Sports chips entirely on tall screens.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(children: [
                  Expanded(
                    child: Text(editing == null ? 'Add Athlete' : 'Edit Athlete',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    const SizedBox(height: 16),
                    // Sports section — always visible, header shows the count.
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Sports',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                        if (sportIds.isNotEmpty)
                          TextButton(
                            onPressed: () => setM(() => sportIds.clear()),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    if (sports.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Loading sports...',
                            style: TextStyle(fontSize: 12.5, color: subT(ctx))),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(ctx).brightness == Brightness.dark
                                  ? Brand.darkBorder
                                  : Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in sports)
                              FilterChip(
                                label: Text('${s['name']}'),
                                labelStyle: TextStyle(
                                  color: sportIds.contains('${s['id']}')
                                      ? const Color(0xFF8A3D00)
                                      : Theme.of(ctx).colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                                selected: sportIds.contains('${s['id']}'),
                                showCheckmark: true,
                                onSelected: (v) => setM(() => v
                                    ? sportIds.add('${s['id']}')
                                    : sportIds.remove('${s['id']}')),
                                selectedColor: const Color(0x40FF6A13),
                                checkmarkColor: const Color(0xFF8A3D00),
                              ),
                          ],
                        ),
                      ),
                    if (sportIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                            '${sportIds.length} sport${sportIds.length == 1 ? '' : 's'} selected',
                            style: TextStyle(fontSize: 11.5, color: subT(ctx))),
                      ),
                    const SizedBox(height: 16),
                    DateField(
                      label: 'Date of birth',
                      value: dob,
                      // DOB is always in the past — allow from 2000.
                      firstDate: DateTime(2000),
                      onChanged: (v) => setM(() => dob = v ?? ''),
                    ),
                    const SizedBox(height: 14),
                    SmartDropdown<String>(
                      value: teamId,
                      labelText: 'Team',
                      items: [
                        const DropdownMenuItem(value: '', child: Text('None')),
                        for (final t in _teams)
                          DropdownMenuItem(value: '${t['id']}', child: Text('${t['name']}')),
                      ],
                      onChanged: (v) => setM(() => teamId = v ?? ''),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: medicalCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Medical notes'),
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
                        medical = medicalCtrl.text.trim();
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
    );
    if (ok != true) return;
    try {
      if (editing != null) {
        final profileId = ((editing['profile'] ?? {}) as Map)['id'];
        if (profileId != null) {
          await client.from('profiles').update({'full_name': name}).eq('id', profileId);
        }
        await client.from('athletes').update({
          'dob': dob.isEmpty ? null : dob,
          'team_id': teamId.isEmpty ? null : teamId,
          'medical_notes': medical.isEmpty ? null : medical,
        }).eq('id', editing['id']);
        await client.from('athlete_sports').delete().eq('athlete_id', editing['id']);
        if (sportIds.isNotEmpty) {
          await client
              .from('athlete_sports')
              .insert([for (final sid in sportIds) {'athlete_id': editing['id'], 'sport_id': sid}]);
        }
      } else {
        final profile = await client
            .from('profiles')
            .insert({'full_name': name, 'role': 'Athlete'})
            .select('id')
            .single();
        final athlete = await client
            .from('athletes')
            .insert({
              'profile_id': profile['id'],
              'dob': dob.isEmpty ? null : dob,
              'team_id': teamId.isEmpty ? null : teamId,
              'medical_notes': medical.isEmpty ? null : medical,
            })
            .select('id')
            .single();
        if (sportIds.isNotEmpty) {
          await client
              .from('athlete_sports')
              .insert([for (final sid in sportIds) {'athlete_id': athlete['id'], 'sport_id': sid}]);
        }
      }
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _remove(DbRow r) async {
    if (!await confirmDelete(context, 'athlete')) return;
    await client.from('athletes').delete().eq('id', r['id']);
    _load();
  }
}
