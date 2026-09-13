import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import 'attendance_page.dart';
import 'notifications_page.dart';
import 'schedule_page.dart';
import 'profile_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const HomePage(),
      const SchedulePage(),
      const AttendancePage(),
      const NotificationsPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Schedule'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Home dashboard — same metrics, same order as the web admin dashboard:
/// Athletes, Coaches, Teams, Tournaments (then recent match).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _name = '';
  String _role = '';
  bool _loading = true;
  int _athletes = 0;
  int _coaches = 0;
  int _teams = 0;
  int _tournaments = 0;
  List<Map<String, dynamic>> _teamRows = [];
  Map<String, dynamic>? _nextMatch;
  final List<RealtimeChannel> _channels = [];

  @override
  void initState() {
    super.initState();
    SportsCache.instance.addListener(_onSports);
    _channels.add(listen('teams', _load));
    _channels.add(listen('tournaments', _load));
    _channels.add(listen('matches', _load));
    _channels.add(listen('attendance', _load));
    _load();
  }

  void _onSports() => setState(() {});

  @override
  void dispose() {
    SportsCache.instance.removeListener(_onSports);
    for (final c in _channels) {
      Supabase.instance.client.removeChannel(c);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    final results = await Future.wait<dynamic>([
      client.from('profiles').select('full_name, role').eq('id', uid).maybeSingle(),
      client.from('athletes').select('id'),
      client.from('coaches').select('id'),
      client.from('teams').select('id, sport_id'),
      client.from('tournaments').select('id'),
      client
          .from('matches')
          .select(
              '*, team_a:teams!matches_team_a_id_fkey(name), team_b:teams!matches_team_b_id_fkey(name), tournaments(name)')
          .inFilter('status', ['Scheduled', 'Live'])
          .order('scheduled_at')
          .limit(1)
          .maybeSingle(),
    ]);

    if (!mounted) return;
    final profile = results[0] as Map<String, dynamic>?;
    setState(() {
      _name = (profile?['full_name'] ?? '').toString();
      _role = (profile?['role'] ?? '').toString();
      _athletes = (results[1] as List).length;
      _coaches = (results[2] as List).length;
      _teamRows = (results[3] as List).cast<Map<String, dynamic>>();
      _teams = _teamRows.length;
      _tournaments = (results[4] as List).length;
      _nextMatch = results[5] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  /// "Teams by sport" counts, resolved live through the sports cache.
  Map<String, int> get _teamsBySport {
    final m = <String, int>{};
    for (final t in _teamRows) {
      final name = SportsCache.instance.name(t['sport_id'] as String?);
      final key = name.isEmpty ? 'No sport' : name;
      m[key] = (m[key] ?? 0) + 1;
    }
    final entries = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Alerts',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _name.isEmpty ? 'Welcome' : _name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  if (_role.isNotEmpty)
                    Text(_role, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 16),
                  // Stat cards: equal height, equal 16px gaps — mirrors web dashboard order.
                  LayoutBuilder(builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 560 ? 4 : 2;
                    const gap = 16.0;
                    final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
                    final items = [
                      _StatCard(label: 'ATHLETES', value: '$_athletes', sub: 'Active roster'),
                      _StatCard(label: 'COACHES', value: '$_coaches', sub: _teamsBySport.isEmpty ? 'Across all sports' : 'In ${_teamsBySport.length} sport(s)'),
                      _StatCard(label: 'TEAMS', value: '$_teams', sub: 'Registered squads'),
                      _StatCard(label: 'TOURNAMENTS', value: '$_tournaments', sub: 'All levels'),
                    ];
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final item in items)
                          SizedBox(
                            width: itemWidth,
                            child: item,
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  if (_teamsBySport.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TEAMS BY SPORT', style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              letterSpacing: 1, color: Colors.black54)),
                            const SizedBox(height: 10),
                            for (final e in _teamsBySport.entries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(e.key, style: const TextStyle(fontSize: 14))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6A13).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text('${e.value}', style: const TextStyle(
                                        fontSize: 12.5, fontWeight: FontWeight.w700,
                                        color: Color(0xFFB24A00))),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  _NextMatchCard(match: _nextMatch),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  const _StatCard({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
      ),
    );
  }
}

class _NextMatchCard extends StatelessWidget {
  final Map<String, dynamic>? match;
  const _NextMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final m = match;
    if (m == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No upcoming matches scheduled.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.45))),
        ),
      );
    }
    final when = m['scheduled_at']?.toString();
    final dt = when != null ? DateTime.tryParse(when)?.toLocal() : null;
    final status = (m['status'] ?? '').toString();
    final live = status == 'Live';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: live ? const Color(0xFFC62828) : const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ((((m['tournaments'] ?? {}) as Map)['name']) ?? '').toString(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.45)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${(((m['team_a'] ?? {}) as Map)['name'] ?? 'TBD')}  vs  ${(((m['team_b'] ?? {}) as Map)['name'] ?? 'TBD')}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              dt != null
                  ? '${dt.day}/${dt.month} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                  : 'Time TBD',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.5), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
