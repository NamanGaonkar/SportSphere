import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchItem {
  final String id;
  final String status;
  final String teamA;
  final String teamB;
  final String tournament;
  final int scoreA;
  final int scoreB;
  final DateTime? when;
  MatchItem({
    required this.id,
    required this.status,
    required this.teamA,
    required this.teamB,
    required this.tournament,
    required this.scoreA,
    required this.scoreB,
    this.when,
  });

  factory MatchItem.fromRow(Map<String, dynamic> row) {
    final whenStr = row['scheduled_at']?.toString();
    return MatchItem(
      id: row['id'].toString(),
      status: (row['status'] ?? 'Scheduled').toString(),
      teamA: ((((row['team_a'] ?? {}) as Map)['name']) ?? 'TBD').toString(),
      teamB: ((((row['team_b'] ?? {}) as Map)['name']) ?? 'TBD').toString(),
      tournament: ((((row['tournaments'] ?? {}) as Map)['name']) ?? '').toString(),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final data = await client
        .from('matches')
        .select('*, team_a:teams!matches_team_a_id_fkey(name), team_b:teams!matches_team_b_id_fkey(name), tournaments(name)')
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

  String _fmt(DateTime? dt) {
    if (dt == null) return 'Time TBD';
    return '${dt.day}/${dt.month} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Upcoming & Live', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (_upcoming.isEmpty)
                    const Text('No upcoming matches.', style: TextStyle(color: Colors.white54)),
                  ..._upcoming.map(_matchCard),
                  const SizedBox(height: 20),
                  const Text('Recent Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (_results.isEmpty)
                    const Text('No results yet.', style: TextStyle(color: Colors.white54)),
                  ..._results.take(10).map(_matchCard),
                ],
              ),
            ),
    );
  }

  Widget _matchCard(MatchItem m) {
    final live = m.status == 'Live';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: live
                        ? const Color(0xFFEF4444)
                        : m.status == 'Completed'
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF4F7CFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(m.status,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(m.tournament,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white54)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(m.teamA, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${m.scoreA} : ${m.scoreB}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF4F7CFF))),
                Expanded(
                  child: Text(m.teamB,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_fmt(m.when), style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
