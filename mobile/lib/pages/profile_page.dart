import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

/// Profile — mirrors the web drawer footer + Reports awards section: live
/// profile fields, role badge, account info and the user's awards from DB.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  String? _error;
  DbRow? _profile;
  String _email = '';
  List<DbRow> _awards = [];
  DbRow? _athlete;
  DbRow? _coach;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _error = 'Not signed in.';
        _loading = false;
      });
      return;
    }
    _email = client.auth.currentUser?.email ?? '';
    try {
      final profile = await client.from('profiles').select('*').eq('id', uid).maybeSingle();
      final role = '${profile?['role'] ?? ''}';

      final futures = <Future<dynamic>>[
        if (role == 'Athlete')
          client
              .from('athletes')
              .select('*, teams(name), athlete_sports(sports(name))')
              .eq('profile_id', uid)
              .maybeSingle()
        else
          Future.value(null),
        if (role == 'Coach')
          client
              .from('coaches')
              .select('*, teams(id, name)')
              .eq('profile_id', uid)
              .maybeSingle()
        else
          Future.value(null),
        client
            .from('awards')
            .select('id, title, level, date, athletes!inner(profile_id)')
            .eq('athletes.profile_id', uid)
            .order('date', ascending: false)
            .limit(8),
      ];
      final results = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _athlete = results[0] as DbRow?;
        _coach = results[1] as DbRow?;
        _awards = (results[2] as List).cast<DbRow>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    if (_error != null) {
      return ErrorRetry(message: _error!, onRetry: _load);
    }
    final p = _profile ?? {};
    final role = '${p['role'] ?? ''}';
    final sportsTags = (_athlete?['athlete_sports'] as List?) ?? const [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Brand.primary.withValues(alpha: 0.15),
                    backgroundImage: p['avatar_url'] != null ? NetworkImage('${p['avatar_url']}') : null,
                    child: p['avatar_url'] == null
                        ? Text(
                            _initials('${p['full_name'] ?? ''}'),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700, color: Brand.primary),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p['full_name'] ?? '-'}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        BadgeChip(role, color: Brand.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Account',
            child: Column(
              children: [
                _kv('Email', _email),
                _kv('Full name', '${p['full_name'] ?? '-'}'),
                _kv('Role', role),
                _kv('Contact', p['contact_info']?.toString()),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_athlete != null) ...[
            SectionCard(
              title: 'Athlete Record',
              child: Column(
                children: [
                  _kv('Team', '${((_athlete?['teams'] ?? {}) as Map)['name'] ?? '-'}'),
                  _kv('Date of birth', fmtDate(_athlete?['dob']?.toString())),
                  _kv(
                    'Sports',
                    sportsTags.isEmpty
                        ? '-'
                        : sportsTags.map((t) => ((t as Map)['sports'] ?? {})['name']).whereType<String>().join(', '),
                  ),
                  _kv('Medical notes', _athlete?['medical_notes']?.toString()),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_coach != null) ...[
            SectionCard(
              title: 'Coaching Record',
              child: Column(
                children: [
                  _kv('Specialization', '${_coach?['specialization'] ?? '-'}'),
                  _kv(
                    'Teams',
                    ((_coach?['teams'] as List?) ?? const [])
                        .map((t) => (t as Map)['name'])
                        .whereType<String>()
                        .join(', '),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SectionCard(
            title: 'Awards & Achievements',
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
                                child: Text('${a['title']}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
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
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
              side: const BorderSide(color: Color(0xFFC62828)),
            ),
            onPressed: () async {
              await client.auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _kv(String key, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(key, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          ),
          Expanded(
            child: Text(value ?? '-',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
