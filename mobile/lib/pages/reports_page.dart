import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

/// Mobile mirror of web/src/pages/Reports.tsx — same datasets: athletes by
/// sport, teams by sport, 30-day attendance rate, recent awards.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _loading = true;
  Map<String, int> _athleteSports = {};
  Map<String, int> _teamSports = {};
  List<({String day, num pct})> _attendance = [];
  List<DbRow> _awards = [];
  RealtimeChannel? _c1;
  RealtimeChannel? _c2;

  @override
  void initState() {
    super.initState();
    _load();
    _c1 = listen('athlete_sports', _load);
    _c2 = listen('teams', _load);
  }

  @override
  void dispose() {
    if (_c1 != null) client.removeChannel(_c1!);
    if (_c2 != null) client.removeChannel(_c2!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        client.from('athlete_sports').select('sports(name)'),
        client.from('teams').select('sport_id'),
        client
            .from('attendance')
            .select('date, status')
            .gte('date', DateTime.now().subtract(const Duration(days: 30)).toIso8601String().split('T').first),
        client
            .from('awards')
            .select('id, title, level, date, athletes(profile:profiles(full_name))')
            .order('date', ascending: false)
            .limit(8),
      ]);
      if (!mounted) return;

      final am = <String, int>{};
      for (final s in (results[0] as List).cast<DbRow>()) {
        final key = '${((s['sports'] ?? {}) as Map)['name'] ?? 'Unassigned'}';
        am[key] = (am[key] ?? 0) + 1;
      }
      final tm = <String, int>{};
      for (final t in (results[1] as List).cast<DbRow>()) {
        final name = SportsCache.instance.name(t['sport_id']?.toString());
        final key = name.isEmpty ? 'No sport' : name;
        tm[key] = (tm[key] ?? 0) + 1;
      }
      final byDay = <String, List<int>>{};
      for (final r in (results[2] as List).cast<DbRow>()) {
        final day = '${r['date']}'.split('T').first;
        final e = byDay.putIfAbsent(day, () => [0, 0]);
        e[1] += 1;
        final st = '${r['status']}';
        if (st == 'Present' || st == 'Late') e[0] += 1;
      }
      final days = byDay.keys.toList()..sort();

      setState(() {
        _athleteSports = am;
        _teamSports = tm;
        _attendance = [
          for (final d in days)
            (
              day: '${int.parse(d.split('-')[2])} ${months[int.parse(d.split('-')[1]) - 1]}',
              pct: byDay[d]![1] == 0 ? 0 : (byDay[d]![0] * 100 ~/ byDay[d]![1]),
            ),
        ];
        _awards = (results[3] as List).cast<DbRow>();
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
    if (_loading) return const LoadingState();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PageHead('Reports',
              sub: 'Organization analytics - rosters, attendance and achievements.'),
          SectionCard(
            title: 'Athletes by Sport',
            child: HBars(_athleteSports.entries.map((e) => MapEntry(e.key, e.value)).toList()),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Teams by Sport',
            child: HBars(_teamSports.entries.map((e) => MapEntry(e.key, e.value)).toList()),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Attendance Rate - Last 30 Days (%)',
            child: VBars([for (final a in _attendance) MapEntry(a.day, a.pct)]),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Recent Awards & Achievements',
            child: _awards.isEmpty
                ? const EmptyState('No awards recorded yet.')
                : Column(
                    children: [
                      for (final a in _awards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                    ((((a['athletes'] ?? {}) as Map)['profile'] ?? {})['full_name'] ?? '-')
                                        .toString(),
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('${a['title']}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              Text('${a['level'] ?? '-'}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(width: 8),
                              Text(fmtDate(a['date']?.toString()),
                                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
