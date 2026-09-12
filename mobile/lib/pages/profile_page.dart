import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _athlete;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    final profile = await client.from('profiles').select('*').eq('id', uid).maybeSingle();
    final athlete = await client
        .from('athletes')
        .select('sport, dob, medical_notes, teams(name)')
        .eq('profile_id', uid)
        .maybeSingle();

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _athlete = athlete;
      _loading = false;
    });
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final a = _athlete;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: const Color(0xFF1E2740),
                    child: Text(
                      (p?['full_name'] ?? '?').toString().isNotEmpty
                          ? (p?['full_name']).toString().substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF4F7CFF)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text((p?['full_name'] ?? '—').toString(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  Center(
                    child: Text(email, style: const TextStyle(fontSize: 13, color: Colors.white54)),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F7CFF).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text((p?['role'] ?? '').toString(),
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF4F7CFF))),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (a != null) ...[
                    _tile(Icons.sports_soccer, 'Sport', (a['sport'] ?? '—').toString()),
                    _tile(Icons.groups, 'Team', ((((a['teams'] ?? {}) as Map)['name']) ?? '—').toString()),
                    _tile(Icons.cake, 'Date of birth', (a['dob'] ?? '—').toString()),
                    _tile(Icons.medical_services_outlined, 'Medical notes',
                        (a['medical_notes'] ?? 'None').toString()),
                  ] else ...[
                    _tile(Icons.badge_outlined, 'Contact', (p?['contact_info'] ?? '—').toString()),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3550)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4F7CFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.white38)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
