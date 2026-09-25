import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'attendance_page.dart';
import 'crud_page.dart' show DbRow;
import 'schedule_page.dart';

/// Home tab for the signed-in ATHLETE. Everything is filtered to their own
/// row: their sport + team, their attendance rate, their latest performance
/// tests and medical status. Live-updated via the same tables the admin
/// side uses, so web edits appear here instantly.
///
/// Role scoping (item 8 of the fix list): the athlete never sees the
/// finance/inventory/staff machinery — only what a player needs.
class AthleteFlowPage extends StatefulWidget {
  const AthleteFlowPage({super.key});

  @override
  State<AthleteFlowPage> createState() => _AthleteFlowPageState();
}

class _AthleteFlowPageState extends State<AthleteFlowPage> {
  bool _loading = true;
  String _name = '';
  String? _myAthleteId;
  List<DbRow> _myTeams = [];
  List<DbRow> _myMatches = [];
  List<DbRow> _myTraining = [];
  List<DbRow> _myPerf = [];
  List<DbRow> _myMedical = [];
  List<DbRow> _myAwards = [];
  List<DbRow> _myAttendance = [];
  RealtimeChannel? _chAtt;
  RealtimeChannel? _chPerf;
  RealtimeChannel? _chMed;
  RealtimeChannel? _chMatches;

  @override
  void initState() {
    super.initState();
    _load();
    _chAtt = listen('attendance', _load);
    _chPerf = listen('performance_records', _load);
    _chMed = listen('medical_records', _load);
    _chMatches = listen('matches', _load);
  }

  @override
  void dispose() {
    for (final c in [_chAtt, _chPerf, _chMed, _chMatches]) {
      if (c != null) Supabase.instance.client.removeChannel(c);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final c = Supabase.instance.client;
    final uid = c.auth.currentUser?.id;
    if (uid == null) return;
    try {
      if (!_sportsBound) {
        _sportsBound = true;
        await SportsCache.instance.ready;
      }
      // Own athlete row.
      final me = await c.from('athletes').select('id').eq('profile_id', uid).maybeSingle();
      final athleteId = me?['id']?.toString();

      // Teams via the RPC (same shape as coach helper); falls back to a
      // direct query if the RPC is missing.
      List<DbRow> teams = [];
      try {
        final t = await c.rpc('my_teams_for_athlete');
        teams = (t as List).cast<DbRow>();
      } catch (_) {
        final t = await c
            .from('athletes')
            .select('team_id, teams(id, name, sport_id, sports(name))')
            .eq('profile_id', uid);
        teams = [
          for (final r in (t as List).cast<DbRow>())
            if (r['teams'] != null)
              {
                'team_id': (r['teams'] as Map)['id'],
                'team_name': (r['teams'] as Map)['name'],
                'sport_id': (r['teams'] as Map)['sport_id'],
                'sport_name': ((r['teams'] as Map)['sports'] ?? {})['name'],
              }
        ];
      }

      final sportIds = [
        for (final t in teams)
          if (t['sport_id'] != null) t['sport_id'].toString()
      ];

      // Matches for my sport(s), nearest first. Filtered client-side by
      // team_a's sport (same trick as the coach flow — safe + simple).
      final matchesRaw = await c
          .from('matches')
          .select(
              'id, status, score_a, score_b, score_display, scheduled_at, team_a:teams!matches_team_a_id_fkey(name, sport_id), team_b:teams!matches_team_b_id_fkey(name), tournaments(name)')
          .order('scheduled_at', ascending: false)
          .limit(30);
      final matches = sportIds.isEmpty
          ? matchesRaw
          : (matchesRaw as List)
              .cast<DbRow>()
              .where((m) => sportIds.contains((((m['team_a'] ?? {}) as Map)['sport_id'] ?? '').toString()))
              .toList();

      // Training sessions for my sport(s).
      var trainingQuery =
          c.from('training_sessions').select('id, title, type, start_time, end_time, frequency, teams(name), sports(name), venues(name)');
      if (sportIds.isNotEmpty) trainingQuery = trainingQuery.inFilter('sport_id', sportIds);
      final training = await trainingQuery.order('start_time', ascending: false).limit(10);

      // Personal stats + history.
      final perf = athleteId == null
          ? <DbRow>[]
          : await c
              .from('performance_records')
              .select('id, date, metric, value, unit, session_type, coach_note')
              .eq('athlete_id', athleteId)
              .order('date', ascending: false)
              .limit(8);
      final med = athleteId == null
          ? <DbRow>[]
          : await c
              .from('medical_records')
              .select('id, date, type, details, cleared, severity, follow_up_date')
              .eq('athlete_id', athleteId)
              .order('date', ascending: false)
              .limit(5);
      final awards = athleteId == null
          ? <DbRow>[]
          : await c
              .from('awards')
              .select('id, title, date, level')
              .eq('athlete_id', athleteId)
              .order('date', ascending: false)
              .limit(5);
      final att = await c
          .from('attendance')
          .select('date, status')
          .eq('profile_id', uid)
          .order('date', ascending: false)
          .limit(30);
      final profile = await c.from('profiles').select('full_name').eq('id', uid).maybeSingle();

      if (!mounted) return;
      setState(() {
        _name = '${profile?['full_name'] ?? ''}';
        _myAthleteId = athleteId;
        _myTeams = teams;
        _myMatches = (matches as List).cast<DbRow>();
        _myTraining = (training as List).cast<DbRow>();
        _myPerf = (perf as List).cast<DbRow>();
        _myMedical = (med as List).cast<DbRow>();
        _myAwards = (awards as List).cast<DbRow>();
        _myAttendance = (att as List).cast<DbRow>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Load failed: $e', error: true);
    }
  }

  bool _sportsBound = false;

  double get _attRate {
    if (_myAttendance.isEmpty) return 0;
    final marked = _myAttendance.where((a) => '${a['status']}' == 'Present' || '${a['status']}' == 'Late').length;
    return marked * 100 / _myAttendance.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sportName = _myTeams.isNotEmpty ? '${_myTeams.first['sport_name'] ?? ''}' : '';
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
                    _name.isNotEmpty ? _name.characters.first.toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name.isEmpty ? 'Welcome' : _name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                        sportName.isEmpty ? 'Athlete' : 'Athlete - $sportName',
                        style: TextStyle(fontSize: 12.5, color: subT(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ---------- My teams ----------
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
                      '${t['team_name'] ?? '?'}',
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
                    MaterialPageRoute(builder: (_) => const AttendancePage()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BigAction(
                  icon: Icons.sports_score_outlined,
                  label: 'My Fixtures',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SchedulePage()),
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
                  icon: Icons.favorite_outline,
                  label: 'Log Health',
                  onTap: _logHealth,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BigAction(
                  icon: Icons.speed_outlined,
                  label: 'My Stats',
                  onTap: _showStats,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---------- Attendance rate ----------
          if (_myAttendance.isNotEmpty) ...[
            _Card(
              title: 'Attendance - last 30 days',
              child: Row(
                children: [
                  Text('${_attRate.round()}%',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Brand.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(height: 12, color: dark ? Brand.darkSurfaceAlt : const Color(0xFFF0F0EA)),
                          FractionallySizedBox(
                            widthFactor: _attRate / 100,
                            child: Container(height: 12, color: Brand.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

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
          const SizedBox(height: 16),

          // ---------- Upcoming matches ----------
          _Card(
            title: 'My matches',
            child: _myMatches.isEmpty
                ? const EmptyState('No matches scheduled yet.')
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

          // ---------- Medical ----------
          _Card(
            title: 'Medical status',
            child: _myMedical.isEmpty
                ? const EmptyState('No medical records yet.')
                : Column(
                    children: [
                      for (final m in _myMedical)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('${m['type'] ?? '-'} - ${fmtDate(m['date']?.toString())}',
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              BadgeChip(
                                m['cleared'] == true ? 'Cleared' : 'Not cleared',
                                color: m['cleared'] == true ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // ---------- Awards ----------
          _Card(
            title: 'My awards',
            child: _myAwards.isEmpty
                ? const EmptyState('No awards recorded yet.')
                : Column(
                    children: [
                      for (final a in _myAwards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.emoji_events_outlined, size: 18, color: Color(0xFFB26A00)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('${a['title'] ?? '-'}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              BadgeChip('${a['level'] ?? '-'}', color: levelColor('${a['level'] ?? ''}')),
                              const SizedBox(width: 8),
                              Text(fmtDate(a['date']?.toString()),
                                  style: TextStyle(fontSize: 11.5, color: subT(context))),
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

  // ---------- Self-service health log (goes to medical_records) ----------
  Future<void> _logHealth() async {
    if (_myAthleteId == null) {
      showSnack(context, 'No athlete profile linked to this account', error: true);
      return;
    }
    final typeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String severity = 'Minor';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: const Text('Log a health issue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'What is it? (e.g. Knee pain)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: ['Minor', 'Moderate', 'Severe']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setM(() => severity = v ?? 'Minor'),
              ),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Details (optional)'), maxLines: 2),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    if (typeCtrl.text.trim().isEmpty) {
      showSnack(context, 'Please describe the issue', error: true);
      return;
    }
    try {
      await Supabase.instance.client.from('medical_records').insert({
        'athlete_id': _myAthleteId,
        'date': localDateKey(DateTime.now()),
        'type': typeCtrl.text.trim(),
        'severity': severity,
        'details': noteCtrl.text.trim(),
        'cleared': false,
      });
      if (!mounted) return;
      showSnack(context, 'Health issue logged - the coach/medical staff can see it now');
      _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Could not save: $e', error: true);
    }
  }

  // ---------- My performance stats ----------
  Future<void> _showStats() async {
    if (_myPerf.isEmpty) {
      showSnack(context, 'No performance tests recorded yet - your coach will add them');
      return;
    }
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('My performance'),
        content: SizedBox(
          width: 340,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final p in _myPerf)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${p['metric'] ?? '-'} (${p['session_type'] ?? 'Test'})',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            if ('${p['coach_note'] ?? ''}'.isNotEmpty)
                              Text('Coach: ${p['coach_note']}',
                                  style: TextStyle(fontSize: 11.5, color: subT(context))),
                          ],
                        ),
                      ),
                      Text('${p['value'] ?? '-'}${p['unit'] ?? ''}',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Brand.primary)),
                      const SizedBox(width: 8),
                      Text(fmtDate(p['date']?.toString()), style: TextStyle(fontSize: 11, color: subT(context))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}

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
