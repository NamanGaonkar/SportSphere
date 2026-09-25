import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/scoring.dart';
import '../data/sports.dart';
import '../main.dart' show Brand, ThemeController;
import '../widgets/common.dart';
import 'athlete_flow_page.dart';
import 'athletes_page.dart';
import 'coach_flow_page.dart';
import 'attendance_admin_page.dart';
import 'coaches_page.dart';
import 'crud_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
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
    // Role-scoped homes: athletes and coaches get their own flow screens
    // (same DB, filtered to what they own). Hidden for every other role.
    _NavItem('My Sport', Icons.sports_soccer_outlined, _athleteFlow, roles: ['Athlete']),
    _NavItem('Coach Desk', Icons.assignment_outlined, _coachFlow, roles: ['Coach']),
    _NavItem('Dashboard', Icons.dashboard_outlined, _dashboard, ),
    _NavItem('Reports', Icons.bar_chart_outlined, _reports),
  ]),
  _NavSection('My Account', [
    _NavItem('My Profile', Icons.account_circle_outlined, _profilePage),
    _NavItem('User Management', Icons.manage_accounts_outlined, _users, roles: ['Admin']),
  ]),
  _NavSection('People', [
    _NavItem('Athletes', Icons.groups_outlined, _athletes, roles: ['Admin', 'Coach', 'HR']),
    _NavItem('Coaches', Icons.sports_outlined, _coaches, roles: ['Admin', 'HR']),
    _NavItem('Teams', Icons.shield_outlined, _teams),
    _NavItem('Staff & HR', Icons.badge_outlined, _staff, roles: ['Admin', 'HR']),
  ]),
  _NavSection('Competitions', [
    _NavItem('Tournaments', Icons.emoji_events_outlined, _tournaments),
    _NavItem('Fixtures & Results', Icons.sports_score_outlined, _matches),
    _NavItem('Venues', Icons.stadium_outlined, _venues),
  ]),
  _NavSection('Operations', [
    _NavItem('Attendance & Leave', Icons.fact_check_outlined, _attendance),
    _NavItem('Inventory', Icons.inventory_2_outlined, _inventory),
    _NavItem('Housekeeping', Icons.cleaning_services_outlined, _housekeeping,
        roles: ['Admin', 'VenueManager']),
    _NavItem('Venue Maintenance', Icons.build_outlined, _maintenance,
        roles: ['Admin', 'VenueManager']),
    _NavItem('Venue Booking', Icons.event_available_outlined, _bookings),
    _NavItem('Vendors & Purchases', Icons.shopping_cart_outlined, _purchases,
        roles: ['Admin', 'Finance', 'HR']),
    _NavItem('Payroll', Icons.payments_outlined, _payroll,
        roles: ['Admin', 'Finance', 'HR']),
    _NavItem('Finance & Expenses', Icons.receipt_long_outlined, _expenses,
        roles: ['Admin', 'Finance', 'HR']),
  ]),
  _NavSection('Programs & Logistics', [
    _NavItem('Training & Camps', Icons.fitness_center_outlined, _training, roles: ['Admin', 'Coach']),
    _NavItem('School Activities', Icons.school_outlined, _activities, roles: ['Admin', 'Coach']),
    _NavItem('Events', Icons.event_outlined, _events),
    _NavItem('Transport', Icons.directions_bus_outlined, _transport,
        roles: ['Admin', 'VenueManager', 'Coach']),
    _NavItem('Accommodation', Icons.hotel_outlined, _accommodation,
        roles: ['Admin', 'VenueManager', 'Coach']),
  ]),
  _NavSection('Athlete Care', [
    // Visible to every staff role — mirrors web App.tsx so the section
    // shows in the sidebar for all of them.
    _NavItem('Performance', Icons.speed_outlined, _performance,
        roles: ['Admin', 'Coach', 'HR', 'Finance', 'VenueManager']),
    _NavItem('Medical', Icons.medical_services_outlined, _medical,
        roles: ['Admin', 'Coach', 'HR', 'Finance', 'VenueManager']),
  ]),
];

Widget _athleteFlow() => const AthleteFlowPage();
Widget _coachFlow() => const CoachFlowPage();

/// Muted text color that adapts to the app theme (dark mode flips the
/// hardcoded black54 grays used across the dashboard).
Color subText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54;
Widget _dashboard() => const DashboardHome();
Widget _reports() => const ReportsPage();
Widget _profilePage() => const ProfilePage();
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
Widget _maintenance() => modulePages()[9]();
Widget _payroll() => modulePages()[10]();
Widget _bookings() => modulePages()[11]();

/// Session-scoped prefs holder (set once at login, shared by the shell).
SharedPreferences? _prefsHolder;
Future<void> initShellPrefs() async {
  _prefsHolder = await SharedPreferences.getInstance();
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

/// Sport-correct score line for dashboard fixture rows — DB score_display
/// when present, sport-aware fallback otherwise; '-' when unplayed.
String scoreDisplayFor(Map m) {
  final sportId = ((m['team_a'] ?? {}) as Map)['sport_id']?.toString();
  final k = scoreKind(SportsCache.instance.name(sportId));
  final scheduled = '${m['status'] ?? ''}' == 'Scheduled' || '${m['status'] ?? ''}' == 'Cancelled';
  if ((m['score_display'] as String?)?.isNotEmpty == true) return m['score_display'].toString();
  return formatScore(k, m, scheduled: scheduled);
}

/// The drawer's scrollable nav list. Rebuilt per drawer-open (keyed by
/// session) with a fresh controller that jumps straight to the last saved
/// offset — the scroll position survives open/close cycles.
class _DrawerNavList extends StatefulWidget {
  final List<_NavSection> sections;
  final String current;
  final void Function(String label) onSelect;
  final double initialOffset;
  /// True when the app is in dark mode: the rail is orange and the
  /// selected item flips to black (light mode: black rail, orange item).
  final bool dark;
  const _DrawerNavList({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelect,
    required this.initialOffset,
    required this.dark,
  });

  @override
  State<_DrawerNavList> createState() => _DrawerNavListState();
}

class _DrawerNavListState extends State<_DrawerNavList> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && widget.initialOffset > 0) {
        _scroll.jumpTo(widget.initialOffset.clamp(0.0, _scroll.position.maxScrollExtent));
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final s in widget.sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 0, 4),
            child: Text(s.section.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: widget.dark ? 0.6 : 0.42))),
          ),
          for (final item in s.items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => widget.onSelect(item.label),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    // Dark mode: orange rail with a BLACK selected pill.
                    // Light mode: black rail with the orange selected pill.
                    color: widget.current == item.label
                        ? (widget.dark ? const Color(0xFF141414) : Brand.primary)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon,
                          size: 20,
                          color: widget.current == item.label
                              ? (widget.dark ? Brand.primary : Colors.white)
                              : Colors.white.withValues(alpha: widget.dark ? 0.92 : 0.7)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(item.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(
                                    alpha: widget.current == item.label
                                        ? 1
                                        : (widget.dark ? 0.92 : 0.72)),
                                fontWeight: widget.current == item.label
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
    );
  }
}

class _HomeShellState extends State<HomeShell> {
  String? _role;
  String _current = 'Dashboard';
  List<_NavSection> _sections = const [];
  final Map<String, Widget> _pageCache = {};
  // Drawer nav scroll memory: the offset is continuously saved while the
  // user scrolls, and each drawer open creates a FRESH controller starting
  // at the saved offset — so closing and reopening the drawer lands exactly
  // where you left it instead of snapping back to the top.
  double _drawerOffset = 0.0;
  int _drawerSession = 0;

  void _openDrawer(BuildContext scaffoldContext) {
    setState(() => _drawerSession++); // fresh controller -> restores offset
    // MUST use the Builder's context (inside the Scaffold). The State's own
    // context sits ABOVE the Scaffold and Scaffold.of() throws on it —
    // which silently killed every menu tap.
    Scaffold.of(scaffoldContext).openDrawer();
  }

  static const _kPrefKey = 'sportsphere.nav.last';

  Widget _pageFor(String label) {
    return _pageCache.putIfAbsent(label, () {
      // The dashboard receives the quick-link callback so its stat cards
      // can switch pages (same behavior as the web dashboard).
      if (label == 'Dashboard') return DashboardHome(onOpenPage: openFromDashboard);
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
    // Restore the last section this user opened (survives app restarts).
    final saved = _prefs?.getString(_kPrefKey);
    if (saved != null && _sections.expand((s) => s.items).any((i) => i.label == saved)) {
      setState(() => _current = saved);
    }
  }

  SharedPreferences? get _prefs => _prefsHolder;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    _prefs?.remove(_kPrefKey);
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(builder: (_) => const SplashPage()),
    );
  }

  /// Every allowed page, in stable order — mounted once inside an
  /// IndexedStack so all of them fetch their data at startup (no "loading
  /// after I tap something") and realtime keeps them fresh while hidden.
  List<Widget> get _allPages {
    final labels = _sections.expand((s) => s.items).map((i) => i.label).toList();
    return [for (final l in labels) _pageFor(l)];
  }

  /// Quick-link target used by the dashboard's tappable stat cards.
  void openFromDashboard(String label) {
    final exists = _sections.expand((s) => s.items).any((i) => i.label == label);
    if (!exists) return;
    setState(() => _current = label);
    _prefs?.setString(_kPrefKey, label);
  }

  @override
  Widget build(BuildContext context) {
    final items = _sections.expand((s) => s.items).toList();
    final hasSelected = items.any((i) => i.label == _current);
    final currentLabel = hasSelected ? _current : 'Dashboard';
    final currentIndex =
        items.indexWhere((i) => i.label == currentLabel).clamp(0, items.isEmpty ? 0 : items.length - 1);

    return Scaffold(
      // Floating detached drawer — same look as the web sidebar: a rounded
      // black rail inset from every edge with a soft shadow, never touching
      // the screen border.
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),              child: Builder(builder: (context) {
                // Dark mode: the rail flips to brand orange and the selected
                // item becomes black (light mode keeps the black rail).
                final dark = ThemeController.instance.isDark;
                final railColor = dark ? Brand.primary : Brand.black;
                return Container(
                  decoration: BoxDecoration(
                    color: railColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: dark
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
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
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollUpdateNotification) {
                          _drawerOffset = n.metrics.pixels;
                        }
                        return false;
                      },
                      child: _DrawerNavList(
                        key: ValueKey(_drawerSession),
                        initialOffset: _drawerOffset,
                        sections: _sections,
                        current: _current,
                        onSelect: (label) {
                          setState(() => _current = label);
                          // Remember the user's choice across sessions.
                          _prefs?.setString(_kPrefKey, label);
                          Navigator.pop(context);
                        },
                        dark: ThemeController.instance.isDark,
                      ),
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
                        // Pill-shaped sign out (matches the web rail button).
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _signOut,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.logout, color: Colors.white70, size: 19),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Dark-mode toggle — APP ONLY (the web app stays light).
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => setState(() => ThemeController.instance.toggle()),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: Icon(
                              ThemeController.instance.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                              color: Colors.white70,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(currentLabel),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _openDrawer(ctx),
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
      body: items.isEmpty
          ? const LoadingState()
          : AnimatedSwitcher(
              // Circle-in transition when the section changes: the page is
              // clipped in through an expanding circle (web parity).
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => ClipPath(
                clipper: _CircleRevealClipper(reveal: anim),
                child: child,
              ),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topLeft,
                children: [...previousChildren, ?currentChild],
              ),
              child: KeyedSubtree(
                key: ValueKey(currentLabel),
                child: IndexedStack(
                  index: currentIndex,
                  children: _allPages,
                ),
              ),
            ),
    );
  }
}

/// Clip that opens from the top-left (where the menu button sits) with an
/// expanding radius driven by the switch animation.
class _CircleRevealClipper extends CustomClipper<Path> {
  final Animation<double> reveal;
  _CircleRevealClipper({required this.reveal});

  @override
  Path getClip(Size size) {
    final t = reveal.value;
    // Diagonal length so the circle always covers the whole screen at t=1.
    final maxR = (size.width * size.width + size.height * size.height);
    final r = maxR * Curves.easeOut.transform(t.clamp(0.0, 1.0));
    return Path()
      ..addOval(Rect.fromCircle(center: const Offset(56, 48), radius: r));
  }

  @override
  bool shouldReclip(_CircleRevealClipper old) => old.reveal.value != reveal.value;
}

// ------------------------------------------------------------------
// Dashboard home — mirrors web/src/pages/Dashboard.tsx exactly:
// 4 stat cards (Athletes, Coaches, Teams, Tournaments) + Recent Matches
// table + Teams by Sport bars + Attendance last-7-days bars + Payroll
// and Recent Awards cards (data identical to the web app).
// ------------------------------------------------------------------
class DashboardHome extends StatefulWidget {
  /// Lets the dashboard's stat cards act as quick links into modules
  /// (parity with the web dashboard's clickable cards).
  final void Function(String label)? onOpenPage;
  const DashboardHome({super.key, this.onOpenPage});

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
  List<DayPoint> _attendance = [];
  List<DbRow> _payroll = [];
  List<DbRow> _equip = [];
  List<DbRow> _med = [];
  List<DbRow> _awards = [];
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

  bool _sportsBound = false;

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
    // Sport names load async — re-render when the cache fills so
    // "Teams by Sport" shows real names instead of "No sport".
    SportsCache.instance.addListener(_onSports);
  }

  void _onSports() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SportsCache.instance.removeListener(_onSports);
    for (final c in [_cTeams, _cMatches, _cAtt, _cSports, _cInv, _cPO, _cMed]) {
      if (c != null) Supabase.instance.client.removeChannel(c);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final c = Supabase.instance.client;
    final uid = c.auth.currentUser?.id;
    // One failing query can never blank the whole dashboard again: each
    // future runs in its own error zone and yields [] / null on failure.
    Future<dynamic> zone(Future<dynamic> f) async {
      try {
        return await f;
      } catch (_) {
        return <DbRow>[];
      }
    }
    try {
      // Guarantee sport names are in memory before the chart computes.
      if (!_sportsBound) {
        _sportsBound = true;
        await SportsCache.instance.ready;
      }
      final results = await Future.wait<dynamic>([
        zone(c.from('athletes').select('id')),
        zone(c.from('coaches').select('id')),
        zone(c.from('teams').select('id, sport_id')),
        zone(c.from('tournaments').select('id')),
        zone(c
            .from('matches')
            .select(
                'id, status, score_a, score_b, score_display, scheduled_at, team_a:teams!matches_team_a_id_fkey(name, sport_id), team_b:teams!matches_team_b_id_fkey(name), tournaments(name)')
            .order('scheduled_at', ascending: false)),
        zone(c
            .from('attendance')
            .select('date, status')
            .gte('date', DateTime.now().subtract(const Duration(days: 7)).toIso8601String().split('T').first)),
        // Roster = everyone attendance applies to (same as web).
        zone(c.from('profiles').select('id').inFilter('role', ['Athlete', 'Coach', 'HR', 'Finance', 'VenueManager'])),
        if (uid != null)
          zone(c.from('profiles').select('full_name, role').eq('id', uid).maybeSingle())
        else
          Future.value(null),
        zone(c.from('payroll').select('id, month, net, staff_id, coach_id, staff:staff_id(profile:profiles(full_name)), coach:coach_id(profile:profiles(full_name))').order('month', ascending: false).limit(6)),
        zone(c.from('inventory_items').select('id, name, quantity, min_stock, condition')),
        zone(c.from('purchase_orders').select('id', ) ),
        zone(c
            .from('medical_records')
            .select('id, athlete_id, type, cleared, date, athletes(profile:profiles(full_name))')
            .order('date', ascending: false)
            .limit(8)),
        // Recent Awards & Achievements — same query/shape as web Dashboard.
        zone(c
            .from('awards')
            .select('id, title, date, level, athletes(profile:profiles(full_name))')
            .order('date', ascending: false)
            .limit(6)),
      ]);
      if (!mounted) return;

      // Shared rolling 7-day window (same algorithm as web lib/dates.ts).
      // Rate is against the full roster so 1 mark can never read as 100%.
      final window = attendanceWindow(
        (results[5] as List)
            .cast<DbRow>()
            .map((r) => (date: '${r['date']}', status: '${r['status']}'))
            .toList(),
        7,
        roster: (results[6] as List).length,
      );
      // results: 0 athletes, 1 coaches, 2 teams, 3 tournaments, 4 matches,
      // 5 attendance, 6 roster profiles, 7 own profile, 8 payroll,
      // 9 inventory, 10 POs, 11 medical, 12 awards.
      final profile = results[7] as DbRow?;

      setState(() {
        _athletes = (results[0] as List).length;
        _coaches = (results[1] as List).length;
        _teamRows = (results[2] as List).cast<DbRow>();
        _teams = _teamRows.length;
        _tournaments = (results[3] as List).length;
        _matches = (results[4] as List).cast<DbRow>();
        // Full DayPoints kept — charts need marked/present/total, not just pct.
        _attendance = window;
        _name = '${profile?['full_name'] ?? ''}';
        _role = '${profile?['role'] ?? ''}';
        _payroll = (results[8] as List).cast<DbRow>();
        _equip = (results[9] as List).cast<DbRow>();
        _pendingPO = (results[10] as List)
            .cast<DbRow>()
            .where((r) => r['status'] == 'Ordered')
            .length;
        _med = (results[11] as List).cast<DbRow>();
        _awards = (results[12] as List).cast<DbRow>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Dashboard load failed: $e', error: true);
    }
  }

  /// Tournament + date line for a Recent Matches tile (compact, ellipsized).
  String _matchMeta(DbRow m) {
    final t = DateTime.tryParse('${m['scheduled_at'] ?? ''}')?.toLocal();
    final date = t == null ? '-' : fmtDateTime(t.toIso8601String());
    final tour = ((m['tournaments'] ?? {}) as Map)['name']?.toString();
    return tour == null || tour.isEmpty ? date : '$tour - $date';
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
            Text(_role, style: TextStyle(fontSize: 12.5, color: subText(context))),
            const SizedBox(height: 14),
          ],
          LayoutBuilder(builder: (context, constraints) {
            const gap = 16.0;
            final cols = constraints.maxWidth >= 560 ? 4 : 2;
            final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
            final values = [
              ('ATHLETES', '$_athletes', 'Active roster', 'Athletes', 0),
              ('COACHES', '$_coaches', 'Across all sports', 'Coaches', 1),
              ('TEAMS', '$_teams', 'Registered squads', 'Teams', 2),
              ('TOURNAMENTS', '$_tournaments', 'All levels', 'Tournaments', 3),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final v in values)
                  SizedBox(
                    width: itemWidth,
                    child: InkWell(
                      onTap: () => widget.onOpenPage?.call(v.$4),
                      borderRadius: BorderRadius.circular(12),
                      child: StatCard(label: v.$1, value: v.$2, sub: v.$3, variant: v.$5),
                    ),
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
                      // Two-line tile per match: teams + status on top,
                      // score + tournament + date below. Long names and
                      // score strings get their own line — no more cramped
                      // single-row squeezing.
                      for (final m in _matches)
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
                                  const SizedBox(width: 8),
                                  BadgeChip('${m['status']}',
                                      color: statusColor('${m['status']}')),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    scoreDisplayFor(m),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: scoreIsEmpty(m)
                                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)
                                          : Brand.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _matchMeta(m),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontSize: 11.5, color: subText(context)),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 14),
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
            child: VBars(
              _attendance,
              barWidth: 24,
              height: 190,
            ),
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
                                    _payrollName(p),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Text('${p['month']}'.split('T').first,
                                  style: TextStyle(fontSize: 12, color: subText(context))),
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
          const SizedBox(height: 16),
          // Recent Awards & Achievements — parity with web Dashboard.
          _Card(
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
                                    ((((a['athletes'] ?? {}) as Map)['profile'] ?? {})['full_name'] ?? '-').toString(),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text('${a['title'] ?? '-'}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              ),
                              BadgeChip('${a['level'] ?? '-'}',
                                  color: statusColor('${a['level'] ?? ''}')),
                              const SizedBox(width: 8),
                              Text(fmtDate(a['date']?.toString()),
                                  style: TextStyle(fontSize: 12, color: subText(context))),
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
                              Text('${m['type'] ?? '-'}', style: TextStyle(fontSize: 12, color: subText(context))),
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
                    Text('POs awaiting delivery', style: TextStyle(fontSize: 11.5, color: subText(context))),
                  ]),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_equip.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    Text('Equipment items tracked', style: TextStyle(fontSize: 11.5, color: subText(context))),
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

  String _payrollName(DbRow p) {
    final staff = p['staff'] as Map?;
    if (staff != null && staff['profile'] != null) {
      return ((((staff['profile'] as Map)['full_name']) ?? '-')).toString();
    }
    final coach = p['coach'] as Map?;
    if (coach != null && coach['profile'] != null) {
      return ((((coach['profile'] as Map)['full_name']) ?? '-')).toString();
    }
    return '-';
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
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white60
                        : Colors.black54)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
