import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';

class MatchItem {
  final String id;
  final String status;
  final String teamA;
  final String teamB;
  final String tournament;
  final String? sportId;
  final int scoreA;
  final int scoreB;
  final DateTime? when;
  MatchItem({
    required this.id,
    required this.status,
    required this.teamA,
    required this.teamB,
    required this.tournament,
    this.sportId,
    required this.scoreA,
    required this.scoreB,
    this.when,
  });

  factory MatchItem.fromRow(Map<String, dynamic> row) {
    final whenStr = row['scheduled_at']?.toString();
    final ta = (row['team_a'] ?? {}) as Map<String, dynamic>;
    return MatchItem(
      id: row['id'].toString(),
      status: (row['status'] ?? 'Scheduled').toString(),
      teamA: ((ta['name']) ?? 'TBD').toString(),
      teamB: ((((row['team_b'] ?? {}) as Map)['name']) ?? 'TBD').toString(),
      tournament: ((((row['tournaments'] ?? {}) as Map)['name']) ?? '').toString(),
      sportId: (ta['sport_id'])?.toString(),
      scoreA: (row['score_a'] ?? 0) as int,
      scoreB: (row['score_b'] ?? 0) as int,
      when: whenStr != null ? DateTime.tryParse(whenStr)?.toLocal() : null,
    );
  }
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<MatchItem> _upcoming = [];
  List<MatchItem> _results = [];
  bool _loading = true;
  String? _sportFilter;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    SportsCache.instance.addListener(_onSports);
    _channel = listen('matches', () { _load(); });
    _load();
  }

  void _onSports() => setState(() {});

  @override
  void dispose() {
    SportsCache.instance.removeListener(_onSports);
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final data = await client
        .from('matches')
        .select('*, team_a:teams!matches_team_a_id_fkey(name, sport_id), team_b:teams!matches_team_b_id_fkey(name), tournaments(name)')
        .order('scheduled_at', ascending: false)
        .limit(50);

    final rows = (data as List).map((e) => MatchItem.fromRow(e as Map<String, dynamic>)).toList();
    if (!mounted) return;
    setState(() {
      _upcoming = rows.where((m) => m.status == 'Scheduled' || m.status == 'Live').toList()
        ..sort((a, b) => (a.when ?? DateTime.now()).compareTo(b.when ?? DateTime.now()));
      _results = rows.where((m) => m.status == 'Completed').toList();
      _loading = false;
    });
  }

  List<MatchItem> get _filteredUpcoming => _sportFilter == null
      ? _upcoming
      : _upcoming.where((m) => m.sportId == _sportFilter).toList();
  List<MatchItem> get _filteredResults => _sportFilter == null
      ? _results
      : _results.where((m) => m.sportId == _sportFilter).toList();

  String _fmt(DateTime? dt) {
    if (dt == null) return 'Time TBD';
    return "${dt.day}/${dt.month} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Live':
        return const Color(0xFFC62828);
      case 'Completed':
        return const Color(0xFF2E7D32);
      case 'Scheduled':
        return const Color(0xFF1565C0);
      default:
        return Colors.black45;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sports = SportsCache.instance.rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Sport filter chips — fed live from the sports table
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('All'),
                            selected: _sportFilter == null,
                            onSelected: (_) => setState(() => _sportFilter = null),
                            selectedColor: const Color(0xFFFF6A13),
                            labelStyle: TextStyle(
                              color: _sportFilter == null ? Colors.white : Colors.black54,
                              fontWeight: _sportFilter == null ? FontWeight.w700 : FontWeight.w400,
                            ),
                            showCheckmark: false,
                          ),
                        ),
                        for (final s in sports)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(s['name'] as String),
                              selected: _sportFilter == s['id'],
                              onSelected: (_) => setState(() => _sportFilter = s['id'] as String),
                              selectedColor: const Color(0xFFFF6A13),
                              labelStyle: TextStyle(
                                color: _sportFilter == s['id'] ? Colors.white : Colors.black54,
                                fontWeight: _sportFilter == s['id'] ? FontWeight.w700 : FontWeight.w400,
                              ),
                              showCheckmark: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Upcoming & Live', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (_filteredUpcoming.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No upcoming matches.',
                          style: TextStyle(color: Colors.black.withValues(alpha: 0.45))),
                    ),
                  ..._filteredUpcoming.map(_matchCard),
                  const SizedBox(height: 24),
                  const Text('Recent Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (_filteredResults.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No results yet.',
                          style: TextStyle(color: Colors.black.withValues(alpha: 0.45))),
                    ),
                  ..._filteredResults.take(10).map(_matchCard),
                ],
              ),
            ),
    );
  }

  Widget _matchCard(MatchItem m) {
    final sportName = SportsCache.instance.name(m.sportId);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(m.status),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(m.status,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                if (sportName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6A13).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(sportName,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB24A00))),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(m.tournament,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.45))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(m.teamA, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${m.scoreA} : ${m.scoreB}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFFFF6A13))),
                Expanded(
                  child: Text(m.teamB,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_fmt(m.when), style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }
}
