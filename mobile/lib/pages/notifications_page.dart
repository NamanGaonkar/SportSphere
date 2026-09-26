import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/common.dart' show faintT, subT;
import '../data/sports.dart' show listen;
import '../main.dart' show Brand;

/// Alerts / notification center — realtime: new notifications appear the
/// moment they are inserted from web or mobile (no pull-to-refresh needed).
/// "Clear all" deletes every alert for the user; "Mark all read" just
/// silences them.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  RealtimeChannel? _channel;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Realtime: the notifications table is in the supabase_realtime
    // publication, so any insert from the web app lands here instantly.
    _channel = listen('notifications', _load);
  }

  @override
  void dispose() {
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final data = await client
          .from('notifications')
          .select('id, message, read, created_at')
          .eq('recipient_id', uid)
          .order('created_at', ascending: false)
          .limit(100);

      if (!mounted) return;
      setState(() {
        _items = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null || _busy) return;
    setState(() => _busy = true);
    await client
        .from('notifications')
        .update({'read': true})
        .eq('recipient_id', uid)
        .eq('read', false);
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  /// Deletes every notification for this user (web parity: Clear all).
  Future<void> _clearAll() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all alerts'),
        content: const Text('This permanently removes all your notifications. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await client.from('notifications').delete().eq('recipient_id', uid);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Clear failed: $e'), backgroundColor: const Color(0xFFC62828)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => n['read'] == false).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _busy ? null : _markAllRead,
              child: Text('Mark all read ($unread)',
                  style: const TextStyle(fontSize: 12.5, color: Brand.primary)),
            ),
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _busy ? null : _clearAll,
              child: const Text('Clear all',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFFC62828))),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(Icons.notifications_none,
                                  size: 40, color: faintT(context)),
                              const SizedBox(height: 12),
                              Text('No notifications.',
                                  style: TextStyle(color: subT(context))),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final n = _items[i];
                        final read = n['read'] == true;
                        final created = DateTime.tryParse(n['created_at'].toString())?.toLocal();
                        return Dismissible(
                          key: ValueKey('notif-${n['id']}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC62828),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          onDismissed: (_) async {
                            final item = n;
                            setState(() => _items.removeAt(i));
                            await Supabase.instance.client
                                .from('notifications')
                                .delete()
                                .eq('id', item['id']);
                          },
                          child: Card(
                            child: ListTile(
                              onTap: read
                                  ? null
                                  : () async {
                                      await Supabase.instance.client
                                          .from('notifications')
                                          .update({'read': true})
                                          .eq('id', n['id']);
                                      _load();
                                    },
                              leading: Icon(
                                read ? Icons.notifications_none : Icons.notifications_active,
                                size: 22,
                                color: read ? faintT(context) : Brand.primary,
                              ),
                              title: Text(
                                n['message'].toString(),
                                style: TextStyle(
                                    fontSize: 13.5,
                                    color: read
                                        ? subT(context)
                                        : Theme.of(context).colorScheme.onSurface),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  created != null
                                      ? "${created.day}/${created.month} - ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}"
                                      : '',
                                  style: TextStyle(fontSize: 11, color: faintT(context))),
                              ),
                              trailing: read
                                  ? null
                                  : Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Brand.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
