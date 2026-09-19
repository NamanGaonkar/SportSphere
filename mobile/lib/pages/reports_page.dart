import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../main.dart' show Brand;
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
    // Re-render when sport names arrive ("Teams by Sport" pie parity).
    SportsCache.instance.addListener(_onSports);
  }

  void _onSports() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SportsCache.instance.removeListener(_onSports);
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
        // Roster denominator so sparse days can't read as 100% (same as web).
        client.from('profiles').select('id').inFilter('role', ['Athlete', 'Coach', 'HR', 'Finance', 'VenueManager']),
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
      // Shared rolling 30-day window (same algorithm as web lib/dates.ts).
      // Rate is against the full roster so 1 mark can never read as 100%.
      final window = attendanceWindow(
        (results[2] as List)
            .cast<DbRow>()
            .map((r) => (date: '${r['date']}', status: '${r['status']}'))
            .toList(),
        30,
        roster: (results[4] as List).length,
      );

      setState(() {
        _athleteSports = am.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        _teamSports = tm.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        _attendance = [for (final p in window) (day: p.label, pct: p.pct)];
        _awards = (results[5] as List).cast<DbRow>();
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
            centerChild: true,
            child: DonutPie(_athleteSports),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Teams by Sport',
            centerChild: true,
            child: DonutPie(_teamSports),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Attendance Rate - Last 30 Days (%)',
            child: VBars(
              [for (final a in _attendance) DayPoint('', a.day, 0, 0, a.pct.toInt())],
              barWidth: 9,
              height: 190,
            ),
          ),
          const SizedBox(height: 16),
          // Organization Snapshot — web Reports parity (fills the grid slot).
          SectionCard(
            title: 'Organization Snapshot',
            child: LayoutBuilder(builder: (context, c) {
              const gap = 12.0;
              final w = (c.maxWidth - gap) / 2;
              final teams = _teamSports.fold<int>(0, (s, e) => s + e.value);
              final sportsPlayed =
                  _athleteSports.where((e) => e.key != 'Unassigned').length;
              final entries = _athleteSports.fold<int>(0, (s, e) => s + e.value.toInt());
              final avgAtt = _attendance.isEmpty
                  ? 0
                  : _attendance.fold<int>(0, (s, e) => s + e.pct.toInt()) ~/ _attendance.length;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(width: w, child: _snapshotStat('TEAMS', '$teams', 'Across all sports')),
                  SizedBox(width: w, child: _snapshotStat('SPORTS PLAYED', '$sportsPlayed', 'Active disciplines')),
                  SizedBox(width: w, child: _snapshotStat('ATHLETE ENTRIES', '$entries', 'Athlete-sport registrations')),
                  SizedBox(width: w, child: _snapshotStat('AVG ATTENDANCE', '$avgAtt%', '30-day average')),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Recent Awards & Achievements',
            centerChild: _awards.isEmpty,
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

/// Orange-tinted snapshot stat (web SnapshotStat parity).
Widget _snapshotStat(String label, String value, String sub) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E7),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Brand.primary.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFFB25A1F))),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.15, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 11, color: Colors.black45)),
      ],
    ),
  );
}
