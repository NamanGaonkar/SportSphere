import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

/// Profile — photo upload (camera or gallery) + editable name/contact for
/// every role, plus read-only role-specific records from the DB.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  DbRow? _profile;
  String _email = '';
  List<DbRow> _awards = [];
  DbRow? _athlete;
  DbRow? _coach;

  late final TextEditingController _nameCtrl = TextEditingController();
  late final TextEditingController _contactCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
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
      _nameCtrl.text = '${profile?['full_name'] ?? ''}';
      _contactCtrl.text = '${profile?['contact_info'] ?? ''}';

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

  /// Pick a photo, upload to the avatars bucket, save the URL.
  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: Brand.primary),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Brand.primary),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final xfile = await picker.pickImage(source: source, imageQuality: 82, maxWidth: 1024);
      if (xfile == null || !mounted) return;
      setState(() => _saving = true);
      final uid = client.auth.currentUser!.id;
      final ext = xfile.name.split('.').last.toLowerCase();
      final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await File(xfile.path).readAsBytes();
      await client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final publicUrl = client.storage.from('avatars').getPublicUrl(path);
      final url = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      await client.from('profiles').update({'avatar_url': url}).eq('id', uid);
      if (!mounted) return;
      setState(() {
        _profile = {...?_profile, 'avatar_url': url};
        _saving = false;
      });
      showSnack(context, 'Profile photo updated.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Upload failed: $e', error: true);
    }
  }

  Future<void> _save() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    if (_nameCtrl.text.trim().isEmpty) {
      showSnack(context, 'Name cannot be empty.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await client.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'contact_info': _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
      }).eq('id', uid);
      if (!mounted) return;
      setState(() {
        _profile = {...?_profile, 'full_name': _nameCtrl.text.trim()};
        _saving = false;
      });
      showSnack(context, 'Profile saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Save failed: $e', error: true);
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
    final avatarUrl = p['avatar_url']?.toString();
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
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Brand.primary.withValues(alpha: 0.15),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                                _initials('${p['full_name'] ?? ''}'),
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w700, color: Brand.primary),
                              )
                            : null,
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: Brand.primary,
                            ),
                            onPressed: _saving ? null : _uploadPhoto,
                            child: const Icon(Icons.photo_camera, size: 15, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p['full_name'] ?? '-'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
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
            title: 'Personal details',
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline, size: 20)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contactCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Contact (phone / email)', prefixIcon: Icon(Icons.call_outlined, size: 20)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Saving...' : 'Save changes'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Account',
            child: Column(
              children: [
                _kv('Email', _email),
                _kv('Role', role),
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
          // Awards are athlete-specific — only shown on athlete profiles.
          if (_athlete != null) ...[
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
            const SizedBox(height: 16),
          ],
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
