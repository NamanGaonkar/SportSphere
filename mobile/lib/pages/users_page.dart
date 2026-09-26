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
  // False = Active tab, true = Deleted (soft-deleted accounts).
  bool _showDeleted = false;
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
          .select('id, full_name, role, contact_info, phone, avatar_url, created_at, deleted_at, athletes(id), coaches(id), staff(id)')
          .order('created_at', ascending: false);
      // Auth emails live outside profiles; admin-only RPC surfaces them.
      final emails = await client.rpc('admin_list_emails');
      final emailMap = <String, String>{
        for (final e in (emails as List)) '${e['user_id']}': '${e['email']}',
      };
      if (!mounted) return;
      setState(() {
        _rows = (data as List).map<DbRow>((r) => {...(r as DbRow), 'email': emailMap['${r['id']}']}).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Load failed: $e', error: true);
    }
  }

  List<DbRow> get _filtered {
    // Tab first: Active hides soft-deleted users, Deleted shows only them.
    final tabbed = _rows.where((r) => _showDeleted ? r['deleted_at'] != null : r['deleted_at'] == null).toList();
    if (_q.isEmpty) return tabbed;
    return tabbed
        .where((r) => '${r['full_name']} ${r['role']} ${r['contact_info'] ?? ''} ${r['phone'] ?? ''} ${r['email'] ?? ''}'
            .toLowerCase()
            .contains(_q.toLowerCase()))
        .toList();
  }

  int get _deletedCount => _rows.where((r) => r['deleted_at'] != null).length;

  // --- Deletion (tester round 3): soft delete hides the account and bans
  // its login; restore undoes both; permanent delete removes profile,
  // roster rows and the auth login FOR GOOD. Server-side admin RPCs.
  Future<void> _softDelete(DbRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user'),
        content: Text(
            '${r['full_name']} will be signed out, hidden from every list and unable to sign in. You can restore them anytime from the Deleted tab.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await client.rpc('admin_delete_user', params: {'p_user': r['id']});
      if (mounted) showSnack(context, 'Deleted - restore from the Deleted tab.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }

  Future<void> _restore(DbRow r) async {
    try {
      await client.rpc('admin_restore_user', params: {'p_user': r['id']});
      if (mounted) showSnack(context, 'Restored - they can sign in again.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Restore failed: $e', error: true);
    }
  }

  Future<void> _purge(DbRow r) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently'),
        content: Text('PERMANENTLY delete ${r['full_name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (first != true) return;
    if (!mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final check'),
        content: const Text(
            'Their login, profile and all their records (attendance, awards, medical) are removed FOREVER. This cannot be undone.\n\nContinue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (second != true) return;
    try {
      await client.rpc('admin_purge_user', params: {'p_user': r['id']});
      if (mounted) showSnack(context, 'Permanently deleted.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
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

  /// Shared dialog action row: Cancel + Save get IDENTICAL heights and
  /// padding (side-by-side Expanded buttons — text-only Cancel next to a
  /// filled Save read as uneven, tester round 3 #3).
  List<Widget> _dialogActions(VoidCallback onCancel) {
    return [
      Row(children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ),
      ]),
    ];
  }

  Future<void> _rename(DbRow r) async {
    final ctrl = TextEditingController(text: '${r['full_name']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename user'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Full name')),
        actions: _dialogActions(() => Navigator.pop(ctx)),
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

  Future<void> _setPhone(DbRow r) async {
    final ctrl = TextEditingController(text: '${r['phone'] ?? r['contact_info'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit phone'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Phone number')),
        actions: _dialogActions(() => Navigator.pop(ctx)),
      ),
    );
    if (ok != true) return;
    try {
      await client.rpc('admin_set_phone', params: {
        'p_user': r['id'],
        'p_phone': ctrl.text.trim(),
      });
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Update failed: $e', error: true);
    }
  }

  Future<void> _createAccount() async {
    final email = TextEditingController();
    final pw = TextEditingController();
    final name = TextEditingController();
    final dept = TextEditingController();
    String role = 'HR';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Create account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 10),
                  TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'Password (min 6 chars)')),
                  const SizedBox(height: 10),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: [for (final x in _roles) DropdownMenuItem(value: x, child: Text(x))],
                    onChanged: (v) => setSheet(() => role = v ?? 'HR'),
                  ),
                  if (role == 'HR' || role == 'Finance' || role == 'VenueManager') ...[
                    const SizedBox(height: 10),
                    TextField(controller: dept, decoration: const InputDecoration(labelText: 'Department')),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create'))),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true || email.text.trim().isEmpty || pw.text.length < 6) {
      if (ok == true && mounted) {
        showSnack(context, 'Password must be at least 6 characters.', error: true);
      }
      return;
    }
    if (!mounted) return;
    try {
      final createdEmail = email.text.trim();
      await client.rpc('admin_create_user', params: {
        'p_email': createdEmail,
        'p_password': pw.text,
        'p_name': name.text.trim(),
        'p_role': role,
        'p_department': dept.text.trim().isEmpty ? null : dept.text.trim(),
        'p_designation': null,
      });
      if (!mounted) return;
      showSnack(context, 'Account created for $createdEmail');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Create failed: $e', error: true);
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
          PageHead(
            'User Management',
            sub: 'Manage accounts and create staff logins. Applies on web and mobile instantly.',
            action: FilledButton.icon(
              onPressed: _createAccount,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Add'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ),
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Search users',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          // Active / Deleted tabs — parity with the web User Management.
          TabBar(
            tabs: [
              const Tab(text: 'Active'),
              Tab(text: _deletedCount > 0 ? 'Deleted ($_deletedCount)' : 'Deleted'),
            ],
            labelColor: Brand.primary,
            unselectedLabelColor: subT(context),
            indicatorColor: Brand.primary,
            onTap: (i) => setState(() => _showDeleted = i == 1),
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
                                // Uploaded profile photo when present (web parity),
                                // initials otherwise.
                                backgroundImage:
                                    (r['avatar_url'] as String?)?.isNotEmpty == true ? NetworkImage(r['avatar_url'] as String) : null,
                                child: (r['avatar_url'] as String?)?.isNotEmpty == true
                                    ? null
                                    : Text(
                                        '${r['full_name']}'.isNotEmpty ? '${r['full_name']}'.trim().split(RegExp(r'\\s+')).map((p) => p[0]).take(2).join().toUpperCase() : '?',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _roleColor('${r['role']}')),
                                      ),
                              ),
                              title: Text('${r['full_name']}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                              subtitle: Text('${r['email'] ?? '-'} - ${r['phone'] ?? r['contact_info'] ?? 'no phone'}',
                                  style: TextStyle(fontSize: 12, color: subT(context)), overflow: TextOverflow.ellipsis),
                              trailing: _showDeleted
                                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Restore - sign-in works again',
                                        icon: const Icon(Icons.restore, size: 20, color: Color(0xFF2E7D32)),
                                        onPressed: () => _restore(r),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Delete permanently',
                                        icon: const Icon(Icons.delete_forever_outlined, size: 20, color: Color(0xFFC62828)),
                                        onPressed: () => _purge(r),
                                      ),
                                    ])
                                  : SizedBox(
                                      width: 148,
                                      child: SmartDropdown<String>(
                                        value: '${r['role']}',
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
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Edit phone'),
              onTap: () {
                Navigator.pop(ctx);
                _setPhone(r);
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
            ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: Color(0xFFC62828)),
              title: const Text('Delete (can be restored)', style: TextStyle(color: Color(0xFFC62828))),
              onTap: () {
                Navigator.pop(ctx);
                _softDelete(r);
              },
            ),
            // Permanent delete: also reachable for an ACTIVE user, but it
            // asks one extra confirmation before the unrecoverable purge.
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: Color(0xFFC62828)),
              title: const Text('Delete permanently', style: TextStyle(color: Color(0xFFC62828))),
              onTap: () {
                Navigator.pop(ctx);
                _purge(r);
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
