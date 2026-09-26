import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/scoring.dart';
import '../data/sports.dart';
import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

class MatchesAdminPage extends StatefulWidget {
  const MatchesAdminPage({super.key});

  @override
  State<MatchesAdminPage> createState() => _MatchesAdminPageState();
}

class _MatchesAdminPageState extends State<MatchesAdminPage> {
  List<DbRow> _rows = [];
  List<DbRow> _teams = [];
  List<DbRow> _tournaments = [];
  List<DbRow> _venues = [];
  bool _loading = true;
  String _tournamentFilter = '';
  String? _sportFilter;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    // Live sync: score edits from web (or the dashboard) update this list
    // instantly, and vice versa.
    _channel = listen('matches', _load);
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
            .from('matches')
            .select(
                '*, team_a:teams!matches_team_a_id_fkey(id, name, sport_id), team_b:teams!matches_team_b_id_fkey(id, name), tournaments(name), venues(name)')
            .order('scheduled_at', ascending: false),
        client.from('teams').select('id, name, sport_id').order('name'),
        client.from('tournaments').select('id, name, sport_id').order('name'),
        client.from('venues').select('id, name').order('name'),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = (results[0] as List).cast<DbRow>();
        _teams = (results[1] as List).cast<DbRow>();
        _tournaments = (results[2] as List).cast<DbRow>();
        _venues = (results[3] as List).cast<DbRow>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Load failed: $e', error: true);
    }
  }

  List<DbRow> get _filtered => _rows.where((r) {
        final tOk = _tournamentFilter.isEmpty || '${r['tournament_id'] ?? ''}' == _tournamentFilter;
        final sOk = _sportFilter == null ||
            '${((r['team_a'] ?? {}) as Map)['sport_id'] ?? ''}' == _sportFilter;
        return tOk && sOk;
      }).toList();

  // Sport-aware score entry: cricket = runs/wickets, volleyball = sets,
  // badminton/TT = games, races = time/position. The database composes the
  // sport-correct result string and score_display — identical on web.
  Future<void> _recordScore(DbRow m) async {
    final sports = SportsCache.instance;
    final kind = scoreKind(sports.name(((m['team_a'] ?? {}) as Map)['sport_id']?.toString()));
    final defs = scoreFieldsFor(kind);
    final ctrls = {
      for (final d in defs) d.key: TextEditingController(text: '${m[d.key] ?? ''}'),
    };
    String status = '${m['status'] ?? 'Scheduled'}';
    if (status == 'Scheduled') status = 'Completed';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setM) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Record result', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '${((m['team_a'] ?? {}) as Map)['name'] ?? 'TBD'} vs ${((m['team_b'] ?? {}) as Map)['name'] ?? 'TBD'}'
                ' - enter ${kindLabel(kind)}',
                style: TextStyle(fontSize: 12.5, color: subT(context)),
              ),
              const SizedBox(height: 14),
              for (final d in defs) ...[
                TextField(
                  controller: ctrls[d.key],
                  keyboardType: d.numeric ? TextInputType.number : TextInputType.text,
                  decoration: InputDecoration(labelText: d.label, hintText: d.numeric ? null : 'e.g. 00:58.32 or 1st'),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [for (final s in ['Completed', 'Scheduled', 'Cancelled']) DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => setM(() => status = v ?? status),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save result'))),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final payload = <String, dynamic>{'status': status};
      for (final d in defs) {
        final raw = ctrls[d.key]!.text.trim();
        payload[d.key] = raw.isEmpty ? null : (d.numeric ? (int.tryParse(raw) ?? 0) : raw);
      }
      await client.from('matches').update(payload).eq('id', m['id']);
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _setStatus(DbRow m, String status) async {
    // Result/score_display are composed by database triggers per sport.
    await client.from('matches').update({'status': status}).eq('id', m['id']);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final sports = SportsCache.instance;
    final filtered = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHead('Fixtures & Results',
              sub: 'Schedule matches, record scores per sport, log results.',
              action: FilledButton.icon(
                onPressed: () => _showForm(null),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Match'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              )),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _tournamentFilter,
                  hint: const Text('All tournaments', style: TextStyle(fontSize: 13)),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All tournaments', style: TextStyle(fontSize: 13))),
                    for (final t in _tournaments)
                      DropdownMenuItem(value: '${t['id']}', child: Text('${t['name']}', style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) => setState(() => _tournamentFilter = v ?? ''),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _sportFilter,
                  hint: const Text('All sports', style: TextStyle(fontSize: 13)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All sports', style: TextStyle(fontSize: 13))),
                    for (final s in sports.rows)
                      DropdownMenuItem(value: '${s['id']}', child: Text('${s['name']}', style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) => setState(() => _sportFilter = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: _loading
                ? const LoadingState()
                : filtered.isEmpty
                    ? const EmptyState('No matches found.')
                    : Column(
                        children: [
                          for (final m in filtered) _matchTile(m),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _matchTile(DbRow m) {
    final sports = SportsCache.instance;
    final status = '${m['status'] ?? 'Scheduled'}';
    final when = DateTime.tryParse('${m['scheduled_at'] ?? ''}')?.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '${((m['team_a'] ?? {}) as Map)['name'] ?? 'TBD'} vs ${((m['team_b'] ?? {}) as Map)['name'] ?? 'TBD'}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              BadgeChip(status, color: statusColor(status)),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'score', child: Text('Record result')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit match')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete match')),
                ],
                onSelected: (v) async {
                  if (v == 'score') _recordScore(m);
                  if (v == 'edit') _showForm(m);
                  if (v == 'delete') {
                    if (!await confirmDelete(context, 'match')) return;
                    await client.from('matches').delete().eq('id', m['id']);
                    _load();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${m['match_type'] ?? 'League Match'} - '
            '${sports.name(((m['team_a'] ?? {}) as Map)['sport_id']?.toString())} - '
            '${((m['tournaments'] ?? {}) as Map)['name'] ?? '-'} - '
            '${((m['venues'] ?? {}) as Map)['name'] ?? '-'} - '
            '${when == null ? '-' : fmtDateTime(when.toIso8601String())}',
            style: TextStyle(fontSize: 11.5, color: subT(context)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Sport-correct score line: the DB's score_display when present,
              // otherwise the same sport-aware formatter web uses. Empty or
              // scheduled matches show '-', never a fake 0 : 0.
              Expanded(
                child: Text(
                  (m['score_display'] as String?)?.isNotEmpty == true
                      ? m['score_display'].toString()
                      : formatScore(
                          scoreKind(sports.name(((m['team_a'] ?? {}) as Map)['sport_id']?.toString())),
                          m,
                          scheduled: status == 'Scheduled' || status == 'Cancelled',
                        ),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Brand.primary),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Record result',
                icon: const Icon(Icons.scoreboard_outlined, size: 20),
                onPressed: () => _recordScore(m),
              ),
              // Status dropdown: matches the status buttons' width and uses
              // the shared SmartDropdown (dark menu, capped+scrollable).
              SizedBox(
                width: 132,
                child: SmartDropdown<String>(
                  value: status,
                  items: [
                    // No Live option — scores are final results (web parity).
                    for (final s in ['Scheduled', 'Completed', 'Cancelled'])
                      DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) => v != null && v != status ? _setStatus(m, v) : null,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  Future<void> _showForm(DbRow? editing) async {
    String tournamentId = '${editing?['tournament_id'] ?? ''}';
    String teamAId = '${((editing?['team_a'] ?? {}) as Map)['id'] ?? ''}';
    String teamBId = '${((editing?['team_b'] ?? {}) as Map)['id'] ?? ''}';
    String venueId = '${editing?['venue_id'] ?? ''}';
    String matchType = editing?['match_type']?.toString() ?? 'League Match';
    final roundCtrl = TextEditingController(text: '${editing?['round_note'] ?? ''}');
    String status = editing != null && '${editing['status']}' == 'Live' ? 'Scheduled' : (editing != null ? '${editing['status']}' : 'Scheduled');
    String? scheduledAt = editing?['scheduled_at']?.toString();

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
                    child: Text(editing == null ? 'Add Match' : 'Edit Match',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: tournamentId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Tournament'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('None (friendly / practice)')),
                          for (final t in _tournaments)
                            DropdownMenuItem(value: '${t['id']}', child: Text('${t['name']}')),
                        ],
                        onChanged: (v) => setM(() {
                          tournamentId = v ?? '';
                          // Sport-scoped teams: re-pick when the tournament changes.
                          teamAId = '';
                          teamBId = '';
                        }),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: matchType,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Match type'),
                        items: [
                          for (final s in ['League Match', 'Tournament Match', 'Quarter Final', 'Semi Final', 'Final', 'Friendly', 'Practice Match'])
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: (v) => setM(() => matchType = v ?? 'League Match'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: roundCtrl,
                        decoration: const InputDecoration(labelText: 'Round note (e.g. Leg 2)'),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          // No Live option — scores are final results (web parity).
                          for (final s in ['Scheduled', 'Completed', 'Cancelled'])
                            DropdownMenuItem(value: s, child: Text(s)),
                        ],
                        onChanged: (v) => setM(() => status = v ?? 'Scheduled'),
                      ),
                      const SizedBox(height: 14),
                      Builder(builder: (ctx) {
                        // Only teams eligible for the tournament's sport.
                        final tSport = _tournaments
                            .where((t) => '${t['id']}' == tournamentId)
                            .map((t) => '${t['sport_id'] ?? ''}')
                            .firstOrNull ?? '';
                        final eligible = tSport.isEmpty
                            ? _teams
                            : _teams.where((t) => '${t['sport_id'] ?? ''}' == tSport).toList();
                        return Column(children: [
                          DropdownButtonFormField<String>(
                            initialValue: teamAId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Team A'),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('None')),
                              for (final t in eligible)
                                if ('${t['id']}' != teamBId)
                                  DropdownMenuItem(value: '${t['id']}', child: Text('${t['name']}')),
                            ],
                            onChanged: (v) => setM(() => teamAId = v ?? ''),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: teamBId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Team B'),
                            items: [
                              const DropdownMenuItem(value: '', child: Text('None')),
                              for (final t in eligible)
                                if ('${t['id']}' != teamAId)
                                  DropdownMenuItem(value: '${t['id']}', child: Text('${t['name']}')),
                            ],
                            onChanged: (v) => setM(() => teamBId = v ?? ''),
                          ),
                        ]);
                      }),
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
                      const SizedBox(height: 14),
                      DateTimeField(
                        label: 'Scheduled at',
                        value: scheduledAt,
                        onChanged: (v) => setM(() => scheduledAt = v),
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
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(editing == null ? 'Add' : 'Save'))),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final payload = {
        'tournament_id': tournamentId.isEmpty ? null : tournamentId,
        'team_a_id': teamAId.isEmpty ? null : teamAId,
        'team_b_id': teamBId.isEmpty ? null : teamBId,
        'scheduled_at': scheduledAt,
        'venue_id': venueId.isEmpty ? null : venueId,
        'match_type': matchType,
        'round_note': roundCtrl.text.trim().isEmpty ? null : roundCtrl.text.trim(),
        'status': status,
      };
      if (editing != null) {
        await client.from('matches').update(payload).eq('id', editing['id']);
      } else {
        await client.from('matches').insert(payload);
      }
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }
}
