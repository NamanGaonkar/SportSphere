import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

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

    final data = await client
        .from('notifications')
        .select('id, message, read, created_at')
        .eq('recipient_id', uid)
        .order('created_at', ascending: false)
        .limit(30);

    if (!mounted) return;
    setState(() {
      _items = (data as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
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
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF4F7CFF))),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: Text('No notifications yet.',
                                style: TextStyle(color: Colors.white54)),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final n = _items[i];
                        final read = n['read'] == true;
                        final created = DateTime.tryParse(n['created_at'].toString())?.toLocal();
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: read ? const Color(0xFF171E2E) : const Color(0xFF1E2740),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: read ? const Color(0xFF2A3550) : const Color(0xFF4F7CFF),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                read ? Icons.notifications_none : Icons.notifications_active,
                                size: 20,
                                color: read ? Colors.white38 : const Color(0xFF4F7CFF),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n['message'].toString(),
                                      style: TextStyle(
                                          fontSize: 13.5,
                                          color: read ? Colors.white60 : Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      created != null
                                          ? '${created.day}/${created.month} · ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}'
                                          : '',
                                      style: const TextStyle(fontSize: 11, color: Colors.white38),
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
    );
  }
}
