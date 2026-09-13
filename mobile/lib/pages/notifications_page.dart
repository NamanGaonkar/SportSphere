import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart' show listen;

/// Alerts / notification center — realtime: new notifications appear the
/// moment they are inserted from web or mobile (no pull-to-refresh needed).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  RealtimeChannel? _channel;

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
          .limit(50);

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
    if (uid == null) return;
    await client.from('notifications').update({'read': true}).eq('recipient_id', uid).eq('read', false);
    await _load();
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
              onPressed: _markAllRead,
              child: Text('Mark all read ($unread)',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFFFF6A13))),
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
                                  size: 40, color: Colors.black.withValues(alpha: 0.25)),
                              const SizedBox(height: 12),
                              Text('No notifications yet.',
                                  style: TextStyle(color: Colors.black.withValues(alpha: 0.45))),
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
                        return Card(
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
                              color: read ? Colors.black26 : const Color(0xFFFF6A13),
                            ),
                            title: Text(
                              n['message'].toString(),
                              style: TextStyle(
                                  fontSize: 13.5, color: read ? Colors.black45 : Colors.black),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                created != null
                                    ? "${created.day}/${created.month} - ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}"
                                    : '',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.black.withValues(alpha: 0.35)),
                              ),
                            ),
                            trailing: read
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF6A13),
                                      shape: BoxShape.circle,
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
