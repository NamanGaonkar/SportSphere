import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

/// Mobile mirror of web/src/pages/Reports.tsx — same datasets, same pie
/// charts (donuts with legend), same 30-day attendance bars, awards table.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _loading = true;
  List<MapEntry<String, int>> _athleteSports = [];
  List<MapEntry<String, int>> _teamSports = [];
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
        _athleteSports = am.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        _teamSports = tm.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
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
            child: DonutPie(_athleteSports),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Teams by Sport',
            child: DonutPie(_teamSports),
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
                      // header row — proper table layout
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('ATHLETE', style: _headStyle)),
                            Expanded(flex: 4, child: Text('AWARD', style: _headStyle)),
                            Expanded(flex: 2, child: Text('LEVEL', style: _headStyle)),
                            Expanded(flex: 2, child: Text('DATE', style: _headStyle)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final a in _awards)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                    ((((a['athletes'] ?? {}) as Map)['profile'] ?? {})['full_name'] ?? '-')
                                        .toString(),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5)),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text('${a['title']}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ),
                              Expanded(
                                flex: 2,
                                child: BadgeChip('${a['level'] ?? '-'}',
                                    color: levelColor('${a['level'] ?? ''}')),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(fmtDate(a['date']?.toString()),
                                    style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                              ),
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

const _headStyle = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.black54);

/// Shared dashboard/reports table header style.
const dashHeadStyle = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.black54);
