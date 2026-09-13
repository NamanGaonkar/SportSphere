import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart' show listen;
import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

const _roles = ['Admin', 'Coach', 'Athlete', 'HR', 'Finance', 'VenueManager'];

Color _roleColor(String r) {
  switch (r) {
    case 'Admin':
      return const Color(0xFFC62828);
    case 'Coach':
      return const Color(0xFF1565C0);
    case 'HR':
      return const Color(0xFFB26A00);
    case 'Finance':
      return const Color(0xFF2E7D32);
    default:
      return const Color(0xFF757575);
  }
}

/// Admin-only user management on the phone: same powers as the web page —
/// rename, contact edit, role change — through the same security-definer
/// RPCs so changes land identically on both platforms.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<DbRow> _rows = [];
  bool _loading = true;
  String _q = '';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = listen('profiles', _load);
  }

  @override
  void dispose() {
    if (_channel != null) client.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await client
          .from('profiles')
          .select('id, full_name, role, contact_info, created_at, athletes(id), coaches(id), staff(id)')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = (data as List).cast<DbRow>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Load failed: $e', error: true);
    }
  }

  List<DbRow> get _filtered {
    if (_q.isEmpty) return _rows;
    return _rows
        .where((r) => '${r['full_name']} ${r['role']} ${r['contact_info'] ?? ''}'
            .toLowerCase()
            .contains(_q.toLowerCase()))
        .toList();
  }

  Future<void> _setRole(DbRow r, String role) async {
    if ('${r['role']}' == 'Admin' && role != 'Admin') {
      showSnack(context, 'The fixed admin account cannot be demoted here.', error: true);
      return;
    }
    try {
      await client.rpc('admin_set_role', params: {'p_user': r['id'], 'p_role': role});
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Role change failed: $e', error: true);
    }
  }

  Future<void> _rename(DbRow r) async {
    final ctrl = TextEditingController(text: '${r['full_name']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename user'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Full name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty || ctrl.text.trim() == r['full_name']) return;
    try {
      await client.rpc('admin_rename_user', params: {'p_user': r['id'], 'p_name': ctrl.text.trim()});
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Rename failed: $e', error: true);
    }
  }

  Future<void> _setContact(DbRow r) async {
    final ctrl = TextEditingController(text: '${r['contact_info'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit contact'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Contact (email / phone)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await client.rpc('admin_set_contact', params: {
        'p_user': r['id'],
        'p_contact': ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
      });
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Update failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PageHead('User Management',
              sub: 'Manage every account: names, roles and contacts. Applies on web and mobile instantly.'),
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Search users',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: _loading
                ? const LoadingState()
                : rows.isEmpty
                    ? const EmptyState('No users found.')
                    : Column(
                        children: [
                          for (final r in rows)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _roleColor('${r['role']}').withValues(alpha: 0.15),
                                child: Text(
                                  '${r['full_name']}'.isNotEmpty ? '${r['full_name']}'.trim().split(RegExp(r'\\s+')).map((p) => p[0]).take(2).join().toUpperCase() : '?',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _roleColor('${r['role']}')),
                                ),
                              ),
                              title: Text('${r['full_name']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              subtitle: Text('${r['contact_info'] ?? '-'}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              trailing: SizedBox(
                                width: 148,
                                child: DropdownButtonFormField<String>(
                                  initialValue: '${r['role']}',
                                  isDense: true,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                  items: [for (final x in _roles) DropdownMenuItem(value: x, child: Text(x, style: const TextStyle(fontSize: 12)))],
                                  onChanged: (v) => v == null ? null : _setRole(r, v),
                                ),
                              ),
                              onTap: () => _openUserSheet(r),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  void _openUserSheet(DbRow r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _rename(r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail_outlined),
              title: const Text('Edit contact'),
              onTap: () {
                Navigator.pop(ctx);
                _setContact(r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined, color: Brand.primary),
              title: const Text('Change role'),
              subtitle: Text('Current: ${r['role']}', style: const TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showRolePicker(r);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRolePicker(DbRow r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(12), child: Text('Change role', style: TextStyle(fontWeight: FontWeight.w700))),
            for (final role in _roles)
              ListTile(
                dense: true,
                title: Text(role),
                trailing: '${r['role']}' == role ? const Icon(Icons.check, color: Brand.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _setRole(r, role);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
