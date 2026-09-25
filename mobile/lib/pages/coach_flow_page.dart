import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'athletes_page.dart';
import 'attendance_admin_page.dart';
import 'crud_page.dart' show DbRow;
import 'matches_admin_page.dart';
import 'teams_page.dart';

/// Home tab for the signed-in COACH. Shows only their world: their teams,
/// their athletes, their sport's fixtures and training sessions, plus
/// shortcuts to mark attendance and enter results (the admin pages already
/// scope correctly via RLS — coaches can write attendance/matches/
/// performance, and cannot reach finance/inventory/staff screens).
class CoachFlowPage extends StatefulWidget {
  const CoachFlowPage({super.key});

  @override
  State<CoachFlowPage> createState() => _CoachFlowPageState();
}

class _CoachFlowPageState extends State<CoachFlowPage> {
  bool _loading = true;
  String _name = '';
  List<DbRow> _myTeams = [];
  List<DbRow> _myAthletes = [];
  List<DbRow> _myMatches = [];
  List<DbRow> _myTraining = [];
  int _markedToday = 0;
  RealtimeChannel? _chTeams;
  RealtimeChannel? _chMatches;
  RealtimeChannel? _chAtt;

  @override
  void initState() {
    super.initState();
    _load();
    _chTeams = listen('teams', _load);
    _chMatches = listen('matches', _load);
    _chAtt = listen('attendance', _load);
  }

  @override
  void dispose() {
    for (final c in [_chTeams, _chMatches, _chAtt]) {
      if (c != null) Supabase.instance.client.removeChannel(c);
    }
    super.dispose();
  }

  bool _sportsBound = false;

  Future<void> _load() async {
    final c = Supabase.instance.client;
    final uid = c.auth.currentUser?.id;
    if (uid == null) return;
    try {
      if (!_sportsBound) {
        _sportsBound = true;
        await SportsCache.instance.ready;
      }

      // My teams (via RPC; falls back to a direct query).
      List<DbRow> teams = [];
      try {
        final t = await c.rpc('my_teams_for_coach');
        teams = (t as List).cast<DbRow>();
      } catch (_) {
        final t = await c
            .from('teams')
            .select('id, name, sport_id, sports(name), athletes(id)')
            .eq('coaches.profile_id', uid);
        teams = [
          for (final r in (t as List).cast<DbRow>())
            {
              'team_id': r['id'],
              'team_name': r['name'],
              'sport_id': r['sport_id'],
              'sport_name': (r['sports'] ?? {})['name'],
              'athlete_count': ((r['athletes'] ?? []) as List).length,
            }
        ];
      }

      final teamIds = [for (final t in teams) t['team_id'].toString()];
      final sportIds = [
        for (final t in teams)
          if (t['sport_id'] != null) t['sport_id'].toString()
      ];

      // My athletes: everyone in my teams.
      List<DbRow> athletes = [];
      if (teamIds.isNotEmpty) {
        final a = await c
            .from('athletes')
            .select('id, team_id, profiles(id, full_name)')
            .inFilter('team_id', teamIds)
            .order('created_at');
        athletes = (a as List).cast<DbRow>();
      }

      // Fixtures for my teams (home or away).
      List<DbRow> matches = [];
      if (teamIds.isNotEmpty) {
        final m = await c
            .from('matches')
            .select(
                'id, status, score_a, score_b, score_display, scheduled_at, team_a:teams!matches_team_a_id_fkey(id, name, sport_id), team_b:teams!matches_team_b_id_fkey(id, name), tournaments(name)')
            .order('scheduled_at', ascending: false)
            .limit(30);
        matches = (m as List).cast<DbRow>().where((m) {
          final aId = ((m['team_a'] ?? {}) as Map)['id']?.toString();
          final bId = ((m['team_b'] ?? {}) as Map)['id']?.toString();
          return teamIds.contains(aId) || teamIds.contains(bId);
        }).toList();
      }

      // Training sessions for my sport(s).
      var trainingQuery = c.from('training_sessions').select('id, title, type, start_time, teams(name), venues(name)');
      if (sportIds.isNotEmpty) trainingQuery = trainingQuery.inFilter('sport_id', sportIds);
      final training = await trainingQuery.order('start_time', ascending: false).limit(10);

      // Who is marked today across my athletes.
      int markedToday = 0;
      if (athletes.isNotEmpty) {
        final todayKey = localDateKey(DateTime.now());
        final profileIds = [
          for (final a in athletes)
            if (((a['profiles'] ?? {}) as Map)['id'] != null) ((a['profiles'] ?? {}) as Map)['id'].toString()
        ];
        if (profileIds.isNotEmpty) {
          final att = await c
              .from('attendance')
              .select('profile_id, status')
              .eq('date', todayKey)
              .inFilter('profile_id', profileIds);
          markedToday = (att as List).length;
        }
      }

      final profile = await c.from('profiles').select('full_name').eq('id', uid).maybeSingle();

      if (!mounted) return;
      setState(() {
        _name = '${profile?['full_name'] ?? ''}';
        _myTeams = teams;
        _myAthletes = athletes;
        _myMatches = matches;
        _myTraining = (training as List).cast<DbRow>();
        _markedToday = markedToday;
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sportName = _myTeams.isNotEmpty ? '${_myTeams.first['sport_name'] ?? ''}' : '';
    final totalAthletes = _myAthletes.length;
    final unmarked = totalAthletes - _markedToday;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- Hero ----------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: dark ? Brand.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dark ? Brand.darkBorder : const Color(0xFFE5E5E0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Brand.primary, shape: BoxShape.circle),
                  child: Text(
                    _name.isNotEmpty ? _name.characters.first.toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name.isEmpty ? 'Coach' : _name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                        sportName.isEmpty ? 'Coach' : 'Coach - $sportName',
                        style: TextStyle(fontSize: 12.5, color: subT(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ---------- Team chips ----------
          if (_myTeams.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _myTeams)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Brand.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${t['team_name'] ?? '?'} (${t['athlete_count'] ?? 0})',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFB24A00)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // ---------- Quick actions ----------
          Row(
            children: [
              Expanded(
                child: _BigAction(
                  icon: Icons.fact_check_outlined,
                  label: 'Mark Attendance',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AttendanceAdminPage()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BigAction(
                  icon: Icons.sports_score_outlined,
                  label: 'Enter Results',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MatchesAdminPage()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BigAction(
                  icon: Icons.groups_outlined,
                  label: 'My Athletes',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AthletesPage()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BigAction(
                  icon: Icons.fitness_center_outlined,
                  label: 'Training',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TeamsPage()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---------- Attendance progress today ----------
          if (totalAthletes > 0) ...[
            _Card(
              title: "Today's attendance",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('$_markedToday / $totalAthletes',
                          style:
                              const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Brand.primary)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          unmarked == 0 ? 'Everyone marked' : '$unmarked still to mark',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 12.5, color: subT(context)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(height: 12, color: dark ? Brand.darkSurfaceAlt : const Color(0xFFF0F0EA)),
                        FractionallySizedBox(
                          widthFactor: _markedToday / totalAthletes,
                          child: Container(height: 12, color: Brand.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---------- My athletes ----------
          _Card(
            title: 'My athletes (${_myAthletes.length})',
            child: _myAthletes.isEmpty
                ? const EmptyState('No athletes in your teams yet.')
                : Column(
                    children: [
                      for (final a in _myAthletes.take(12))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: Brand.primary.withValues(alpha: 0.15),
                                child: Text(
                                  ((((a['profiles'] ?? {}) as Map)['full_name'] ?? '?') as String)
                                      .characters
                                      .first
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB24A00)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${((a['profiles'] ?? {}) as Map)['full_name'] ?? '-'}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_myAthletes.length > 12)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('+${_myAthletes.length - 12} more',
                              style: TextStyle(fontSize: 12, color: subT(context))),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // ---------- Fixtures ----------
          _Card(
            title: 'My fixtures',
            child: _myMatches.isEmpty
                ? const EmptyState('No fixtures for your teams yet.')
                : Column(
                    children: [
                      for (final m in _myMatches.take(6))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${((m['team_a'] ?? {}) as Map)['name'] ?? 'TBD'} vs ${((m['team_b'] ?? {}) as Map)['name'] ?? 'TBD'}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  BadgeChip('${m['status']}', color: statusColor('${m['status']}')),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(fmtDateTime(m['scheduled_at']?.toString()),
                                  style: TextStyle(fontSize: 11.5, color: subT(context))),
                              const Divider(height: 12),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // ---------- Training ----------
          _Card(
            title: 'Training sessions',
            child: _myTraining.isEmpty
                ? const EmptyState('No training scheduled yet.')
                : Column(
                    children: [
                      for (final t in _myTraining)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.fitness_center, size: 18, color: Brand.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${t['title'] ?? 'Training'}',
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                    Text(
                                      '${t['teams']?['name'] ?? ''} ${t['start_time'] != null ? '- ${fmtDateTime(t['start_time'].toString())}' : ''}',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: subT(context)),
                                    ),
                                  ],
                                ),
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

/// Big tappable quick-action tile (shared look with the athlete flow).
class _BigAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BigAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? Brand.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: dark ? Brand.darkBorder : const Color(0xFFE5E5E0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Brand.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 19, color: Brand.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: subT(context))),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
