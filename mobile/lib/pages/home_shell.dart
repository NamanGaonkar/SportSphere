import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'athletes_page.dart';
import 'attendance_admin_page.dart';
import 'coaches_page.dart';
import 'crud_page.dart';
import 'notifications_page.dart';
import 'inventory_page.dart';
import 'matches_admin_page.dart';
import 'purchases_page.dart';
import 'reports_page.dart';
import 'splash_page.dart';
import 'staff_admin_page.dart';
import 'teams_page.dart';
import 'tournaments_page.dart';
import 'users_page.dart';
import 'venues_admin_page.dart';

/// Navigation is 1:1 with web App.tsx NAV_SECTIONS — same sections, same
/// order, same role gating (including Admin-only Sports).
class _NavItem {
  final String label;
  final IconData icon;
  final List<String>? roles;
  final Widget Function() page;
  const _NavItem(this.label, this.icon, this.page, {this.roles});
}

class _NavSection {
  final String section;
  final List<_NavItem> items;
  const _NavSection(this.section, this.items);
}

const _navSections = <_NavSection>[
  _NavSection('Overview', [
    _NavItem('Dashboard', Icons.dashboard_outlined, _dashboard, ),
    _NavItem('Reports', Icons.bar_chart_outlined, _reports),
  ]),
  _NavSection('People', [
    _NavItem('Athletes', Icons.groups_outlined, _athletes),
    _NavItem('Coaches', Icons.sports_outlined, _coaches),
    _NavItem('Teams', Icons.shield_outlined, _teams),
    _NavItem('Staff & HR', Icons.badge_outlined, _staff, roles: ['Admin', 'HR']),
    _NavItem('User Management', Icons.manage_accounts_outlined, _users, roles: ['Admin']),
  ]),
  _NavSection('Competitions', [
    _NavItem('Tournaments', Icons.emoji_events_outlined, _tournaments),
    _NavItem('Fixtures & Results', Icons.sports_score_outlined, _matches),
    _NavItem('Venues', Icons.stadium_outlined, _venues),
  ]),
  _NavSection('Operations', [
    _NavItem('Attendance & Leave', Icons.fact_check_outlined, _attendance),
    _NavItem('Inventory', Icons.inventory_2_outlined, _inventory),
    _NavItem('Housekeeping', Icons.cleaning_services_outlined, _housekeeping),
    _NavItem('Vendors & Purchases', Icons.shopping_cart_outlined, _purchases),
    _NavItem('Finance & Expenses', Icons.payments_outlined, _expenses,
        roles: ['Admin', 'Finance', 'HR']),
  ]),
  _NavSection('Programs & Logistics', [
    _NavItem('Training & Camps', Icons.fitness_center_outlined, _training),
    _NavItem('School Activities', Icons.school_outlined, _activities),
    _NavItem('Events', Icons.event_outlined, _events),
    _NavItem('Transport', Icons.directions_bus_outlined, _transport),
    _NavItem('Accommodation', Icons.hotel_outlined, _accommodation),
  ]),
  _NavSection('Athlete Care', [
    _NavItem('Performance', Icons.speed_outlined, _performance),
    _NavItem('Medical', Icons.medical_services_outlined, _medical),
  ]),
];

Widget _dashboard() => const DashboardHome();
Widget _reports() => const ReportsPage();
Widget _athletes() => const AthletesPage();
Widget _coaches() => const CoachesPage();
Widget _teams() => const TeamsPage();
Widget _staff() => const StaffAdminPage();
Widget _users() => const UsersPage();
Widget _tournaments() => const TournamentsPage();
Widget _matches() => const MatchesAdminPage();
Widget _venues() => const VenuesAdminPage();
Widget _attendance() => const AttendanceAdminPage();
Widget _inventory() => const InventoryPage();
Widget _housekeeping() => modulePages()[0]();
Widget _purchases() => const PurchasesPage();
Widget _expenses() => modulePages()[7]();
Widget _training() => modulePages()[1]();
Widget _activities() => modulePages()[8]();
Widget _events() => modulePages()[4]();
Widget _transport() => modulePages()[5]();
Widget _accommodation() => modulePages()[6]();
Widget _performance() => modulePages()[2]();
Widget _medical() => modulePages()[3]();

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String? _role;
  String _current = 'Dashboard';
  List<_NavSection> _sections = const [];
  final Map<String, Widget> _pageCache = {};

  Widget _pageFor(String label) {
    return _pageCache.putIfAbsent(label, () {
      final item = _sections.expand((s) => s.items).where((i) => i.label == label).first;
      return item.page();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final row = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    if (!mounted) return;
    final role = (row?['role'] ?? 'Athlete').toString();
    setState(() {
      _role = role;
      _sections = [
        for (final s in _navSections)
          _NavSection(
            s.section,
            [
              for (final i in s.items)
                if (i.roles == null || i.roles!.contains(role)) i,
            ],
          ),
      ];
    });
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(builder: (_) => const SplashPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelected = _sections.expand((s) => s.items).any((i) => i.label == _current);
    final body = hasSelected ? _pageFor(_current) : const DashboardHome();

    return Scaffold(
      drawer: Drawer(
        backgroundColor: Brand.black,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(
          child: Column(
            children: [
              // Header: logo + app name (fixed drawer, no collapse toggle).
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Row(
                  children: [
                    Image.asset('assets/images/logo.png', width: 28, height: 32, fit: BoxFit.contain),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('SportSphere',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.2)),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final s in _sections) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 0, 4),
                        child: Text(s.section.toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: Colors.white.withValues(alpha: 0.42))),
                      ),
                      for (final item in s.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() => _current = item.label);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 11),
                              margin: const EdgeInsets.symmetric(vertical: 1),
                              decoration: BoxDecoration(
                                color: _current == item.label
                                    ? Brand.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(item.icon,
                                      size: 20,
                                      color: _current == item.label
                                          ? Colors.white
                                          : Colors.white70),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(item.label,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white
                                                .withValues(alpha: _current == item.label ? 1 : 0.72),
                                            fontWeight: _current == item.label
                                                ? FontWeight.w700
                                                : FontWeight.w400)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Supabase.instance.client.auth.currentUser?.email ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          Text(_role ?? '',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
                      onPressed: _signOut,
                      tooltip: 'Sign out',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(_current),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Alerts',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

// ------------------------------------------------------------------
// Dashboard home — mirrors web/src/pages/Dashboard.tsx exactly:
// 4 stat cards (Athletes, Coaches, Teams, Tournaments) + Recent Matches
// table + Teams by Sport bars + Attendance last-7-days bars + Payroll
// and Recent Awards cards (data identical to the web app).
// ------------------------------------------------------------------
class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  bool _loading = true;
  int _athletes = 0;
  int _coaches = 0;
  int _teams = 0;
  int _tournaments = 0;
  List<DbRow> _matches = [];
  List<DbRow> _teamRows = [];
  List<({String day, num pct})> _attendance = [];
  List<DbRow> _payroll = [];
  List<DbRow> _awards = [];
  List<DbRow> _equip = [];
  List<DbRow> _med = [];
  int _pendingPO = 0;
  String _name = '';
  String _role = '';
  RealtimeChannel? _cTeams;
  RealtimeChannel? _cMatches;
  RealtimeChannel? _cAtt;
  RealtimeChannel? _cSports;
  RealtimeChannel? _cInv;
  RealtimeChannel? _cPO;
  RealtimeChannel? _cMed;

  @override
  void initState() {
    super.initState();
    _load();
    _cTeams = listen('teams', _load);
    _cMatches = listen('matches', _load);
    _cAtt = listen('attendance', _load);
    _cSports = listen('sports', _load);
    _cInv = listen('inventory_items', _load);
    _cPO = listen('purchase_orders', _load);
    _cMed = listen('medical_records', _load);
  }

  @override
  void dispose() {
    for (final c in [_cTeams, _cMatches, _cAtt, _cSports, _cInv, _cPO, _cMed]) {
      if (c != null) Supabase.instance.client.removeChannel(c);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final c = Supabase.instance.client;
    final uid = c.auth.currentUser?.id;
    try {
      final results = await Future.wait<dynamic>([
        c.from('athletes').select('id'),
        c.from('coaches').select('id'),
        c.from('teams').select('id, sport_id'),
        c.from('tournaments').select('id'),
        c
            .from('matches')
            .select(
                'id, status, score_a, score_b, scheduled_at, team_a:teams!matches_team_a_id_fkey(name), team_b:teams!matches_team_b_id_fkey(name), tournaments(name)')
            .order('scheduled_at', ascending: false)
            .limit(6),
        c
            .from('attendance')
            .select('date, status')
            .gte('date', DateTime.now().subtract(const Duration(days: 7)).toIso8601String().split('T').first),
        if (uid != null)
          c.from('profiles').select('full_name, role').eq('id', uid).maybeSingle()
        else
          Future.value(null),
        c.from('payroll').select('id, month, net, staff(profile:profiles(full_name))').order('month', ascending: false).limit(6),
        c
            .from('awards')
            .select('id, title, level, date, athletes(profile:profiles(full_name))')
            .order('date', ascending: false)
            .limit(6),
        c.from('inventory_items').select('id, name, quantity, min_stock, condition'),
        c.from('purchase_orders').select('id, status'),
        c
            .from('medical_records')
            .select('id, athlete_id, type, cleared, date, athletes(profile:profiles(full_name))')
            .order('date', ascending: false)
            .limit(8),
      ]);
      if (!mounted) return;

      final attRows = (results[5] as List).cast<DbRow>();
      final byDay = <String, List<int>>{};
      for (final r in attRows) {
        final day = '${r['date']}'.split('T').first;
        final e = byDay.putIfAbsent(day, () => [0, 0]);
        e[1] += 1;
        final s = '${r['status']}';
        if (s == 'Present' || s == 'Late') e[0] += 1;
      }
      final days = byDay.keys.toList()..sort();
      final profile = results[6] as DbRow?;

      setState(() {
        _athletes = (results[0] as List).length;
        _coaches = (results[1] as List).length;
        _teamRows = (results[2] as List).cast<DbRow>();
        _teams = _teamRows.length;
        _tournaments = (results[3] as List).length;
        _matches = (results[4] as List).cast<DbRow>();
        _attendance = [
          for (final d in days)
            (
              day: '${int.parse(d.split('-')[2])} ${months[int.parse(d.split('-')[1]) - 1]}',
              pct: byDay[d]![1] == 0 ? 0 : (byDay[d]![0] * 100 ~/ byDay[d]![1]),
            ),
        ];
        _name = '${profile?['full_name'] ?? ''}';
        _role = '${profile?['role'] ?? ''}';
        _payroll = (results[7] as List).cast<DbRow>();
        _awards = (results[8] as List).cast<DbRow>();
        _equip = (results[9] as List).cast<DbRow>();
        _pendingPO = (results[10] as List)
            .cast<DbRow>()
            .where((r) => r['status'] == 'Ordered')
            .length;
        _med = (results[11] as List).cast<DbRow>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Dashboard load failed: $e', error: true);
    }
  }

  Map<String, int> get _teamsBySport {
    final m = <String, int>{};
    for (final t in _teamRows) {
      final name = SportsCache.instance.name(t['sport_id']?.toString());
      final key = name.isEmpty ? 'No sport' : name;
      m[key] = (m[key] ?? 0) + 1;
    }
    final entries = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_name.isNotEmpty) ...[
            Text(_name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text(_role, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            const SizedBox(height: 14),
          ],
          LayoutBuilder(builder: (context, constraints) {
            const gap = 16.0;
            final cols = constraints.maxWidth >= 560 ? 4 : 2;
            final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
            final values = [
              ('ATHLETES', '$_athletes', 'Active roster'),
              ('COACHES', '$_coaches', 'Across all sports'),
              ('TEAMS', '$_teams', 'Registered squads'),
              ('TOURNAMENTS', '$_tournaments', 'All levels'),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final v in values)
                  SizedBox(
                    width: itemWidth,
                    child: StatCard(label: v.$1, value: v.$2, sub: v.$3),
                  ),
              ],
            );
          }),
          const SizedBox(height: 16),
          _Card(
            title: 'Recent Matches',
            child: _matches.isEmpty
                ? const EmptyState('No matches scheduled yet.')
                : Column(
                    children: [
                      for (final m in _matches)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '${((m['team_a'] ?? {}) as Map)['name'] ?? 'TBD'} vs ${((m['team_b'] ?? {}) as Map)['name'] ?? 'TBD'}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('${(m['tournaments'] ?? {})['name'] ?? '-'}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ),
                              Text('${m['score_a'] ?? 0} : ${m['score_b'] ?? 0}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              BadgeChip('${m['status']}',
                                  color: statusColor('${m['status']}')),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: 'Teams by Sport',
            child: HBars(_teamsBySport.entries.map((e) => MapEntry(e.key, e.value)).toList()),
          ),
          const SizedBox(height: 16),
          _Card(
            title: 'Attendance - Last 7 Days (%)',
            child: VBars([for (final a in _attendance) MapEntry(a.day, a.pct)]),
          ),
          const SizedBox(height: 16),
          _Card(
            title: 'Latest Payroll',
            child: _payroll.isEmpty
                ? const EmptyState('No payroll recorded yet.')
                : Column(
                    children: [
                      for (final p in _payroll)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                    (((p['staff'] ?? {}) as Map)['profile'] ?? {})['full_name']?.toString() ?? '-',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Text('${p['month']}'.split('T').first,
                                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(width: 6),
                              Text(inr(_toNum(p['net'])),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: 'Recent Awards',
            child: _awards.isEmpty
                ? const EmptyState('No awards recorded yet.')
                : Column(
                    children: [
                      const Row(children: [
                        Expanded(flex: 3, child: Text('ATHLETE', style: dashHeadStyle)),
                        Expanded(flex: 4, child: Text('AWARD', style: dashHeadStyle)),
                        Expanded(flex: 2, child: Text('LEVEL', style: dashHeadStyle)),
                        Expanded(flex: 2, child: Text('DATE', style: dashHeadStyle)),
                      ]),
                      const SizedBox(height: 6),
                      for (final a in _awards)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                    ((((a['athletes'] ?? {}) as Map)['profile'] ?? {})['full_name'] ?? '-').toString(),
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
          const SizedBox(height: 16),
          _Card(
            title: 'Equipment Watchlist',
            child: _equip.isEmpty
                ? const EmptyState('No inventory items yet.')
                : Column(
                    children: [
                      for (final e in _lowestStock)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text('${e['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                              Text('${e['quantity'] ?? 0} left', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              BadgeChip(
                                ((e['quantity'] ?? 0) as num) <= ((e['min_stock'] ?? 0) as num? ?? 0)
                                    ? 'Low'
                                    : '${e['condition'] ?? '-'}',
                                color: ((e['quantity'] ?? 0) as num) <= ((e['min_stock'] ?? 0) as num? ?? 0)
                                    ? const Color(0xFFB26A00)
                                    : const Color(0xFF2E7D32),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _Card(
            title: 'Medical Watchlist',
            child: _med.isEmpty
                ? const EmptyState('No medical records yet.')
                : Column(
                    children: [
                      for (final m in _med)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                    ((((m['athletes'] ?? {}) as Map)['profile'] ?? {})['full_name'] ?? '-').toString(),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Text('${m['type'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(width: 8),
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
          _Card(
            title: 'Procurement',
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$_pendingPO', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Brand.primary)),
                    const Text('POs awaiting delivery', style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                  ]),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_equip.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const Text('Equipment items tracked', style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<DbRow> get _lowestStock {
    final sorted = [..._equip];
    sorted.sort((a, b) => ((a['quantity'] ?? 0) as num).compareTo((b['quantity'] ?? 0) as num));
    return sorted.take(6).toList();
  }

  num? _toNum(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');
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
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.black54)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
