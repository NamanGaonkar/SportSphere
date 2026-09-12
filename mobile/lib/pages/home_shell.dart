import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _name = '';
  String _role = '';
  String _team = '';
  String _sport = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    final profile = await client.from('profiles').select('full_name, role').eq('id', uid).maybeSingle();
    String team = '';
    String sport = '';
    final athlete = await client
        .from('athletes')
        .select('sport, teams(name)')
        .eq('profile_id', uid)
        .maybeSingle();
    if (athlete != null) {
      sport = (athlete['sport'] ?? '').toString();
      team = (((athlete['teams'] ?? {}) as Map)['name'] ?? '').toString();
    }
    if (!mounted) return;
    setState(() {
      _name = (profile?['full_name'] ?? 'Athlete').toString();
      _role = (profile?['role'] ?? '').toString();
      _team = team;
      _sport = sport;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SportSphere')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Hi, $_name 👋',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(_role.isEmpty ? 'Welcome back' : '$_role${_team.isNotEmpty ? ' • $_team' : ''}${_sport.isNotEmpty ? ' • $_sport' : ''}',
                      style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 20),
                  _NextMatchCard(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _quickStat(context, Icons.fact_check, 'Attendance', 'Mark today', 0)),
                      const SizedBox(width: 12),
                      Expanded(child: _quickStat(context, Icons.emoji_events_outlined, 'Awards', 'Your achievements', 3)),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _quickStat(BuildContext context, IconData icon, String title, String sub, int tabIndex) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF4F7CFF)),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextMatchCard extends StatefulWidget {
  @override
  State<_NextMatchCard> createState() => _NextMatchCardState();
}

class _NextMatchCardState extends State<_NextMatchCard> {
  Map<String, dynamic>? _match;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final data = await client
        .from('matches')
        .select('*, team_a:teams!matches_team_a_id_fkey(name), team_b:teams!matches_team_b_id_fkey(name), tournaments(name)')
        .inFilter('status', ['Scheduled', 'Live'])
        .order('scheduled_at', ascending: true)
        .limit(1)
        .maybeSingle();
    if (!mounted) return;
    setState(() => _match = data);
  }

  @override
  Widget build(BuildContext context) {
    final m = _match;
    if (m == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No upcoming matches scheduled.', style: TextStyle(color: Colors.white54)),
        ),
      );
    }
    final when = m['scheduled_at']?.toString();
    final dt = when != null ? DateTime.tryParse(when)?.toLocal() : null;
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
                    color: m['status'] == 'Live' ? const Color(0xFFEF4444) : const Color(0xFF4F7CFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text((m['status'] ?? '').toString(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(((((m['tournaments'] ?? {}) as Map)['name']) ?? '').toString(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white54)),
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
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
