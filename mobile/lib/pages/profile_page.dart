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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
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
                    backgroundColor: const Color(0xFFFF6A13).withValues(alpha: 0.12),
                    child: Text(
                      (p?['full_name'] ?? '').toString().isNotEmpty
                          ? (p?['full_name']).toString().substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFFFF6A13)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text((p?['full_name'] ?? '-').toString(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  Center(
                    child: Text(email,
                        style: TextStyle(fontSize: 13, color: Colors.black.withValues(alpha: 0.45))),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6A13).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text((p?['role'] ?? '').toString(),
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFFF6A13))),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (a != null) ...[
                    _tile(Icons.sports_soccer, 'Sport', (a['sport'] ?? '-').toString()),
                    _tile(Icons.groups, 'Team', ((((a['teams'] ?? {}) as Map)['name']) ?? '-').toString()),
                    _tile(Icons.cake, 'Date of birth', (a['dob'] ?? '-').toString()),
                    _tile(Icons.medical_services_outlined, 'Medical notes',
                        (a['medical_notes'] ?? 'None').toString()),
                  ] else ...[
                    _tile(Icons.badge_outlined, 'Contact', (p?['contact_info'] ?? '-').toString()),
                  ],
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tile(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFFFF6A13)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11.5, color: Colors.black.withValues(alpha: 0.4))),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
