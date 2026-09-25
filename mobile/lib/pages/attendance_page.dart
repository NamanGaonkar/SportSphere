import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../data/sports.dart';
import '../widgets/common.dart' show subT;

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _myDays = [];
  String? _todayStatus;
  RealtimeChannel? _channel;

  static const _statuses = ['Present', 'Late', 'Leave', 'Absent'];

  Color _color(String status) {
    switch (status) {
      case 'Present':
        return const Color(0xFF2E7D32);
      case 'Late':
        return const Color(0xFFB26A00);
      case 'Leave':
        return const Color(0xFF1565C0);
      case 'Absent':
        return const Color(0xFFC62828);
    }
    return Colors.black26;
  }

  @override
  void initState() {
    super.initState();
    _channel = listen('attendance', () { _load(); });
    _load();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    final data = await client
        .from('attendance')
        .select('id, date, status')
        .eq('profile_id', uid)
        .order('date', ascending: false)
        .limit(14);

    final days = (data as List).cast<Map<String, dynamic>>();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (!mounted) return;
    setState(() {
      _myDays = days;
      _todayStatus = days
          .where((d) => d['date'].toString().startsWith(todayKey))
          .cast<Map<String, dynamic>?>()
          .firstOrNull?['status'] as String?;
      _loading = false;
    });
  }

  Future<void> _mark(String status, {String? leaveReason}) async {
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser!.id;
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final existing = _myDays
        .where((d) => d['date'].toString().startsWith(todayKey))
        .cast<Map<String, dynamic>?>()
        .firstOrNull;

    final payload = <String, dynamic>{
      'status': status,
      if (status == 'Leave') 'leave_reason': leaveReason,
    };

    try {
      if (existing != null) {
        await client.from('attendance').update(payload).eq('id', existing['id']);
      } else {
        await client
            .from('attendance')
            .insert({'profile_id': uid, 'date': todayKey, ...payload});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save attendance. Try again.')),
        );
      }
    }
    await _load();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _askLeaveReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave reason'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Mark Leave'),
          ),
        ],
      ),
    );
    if (reason != null) await _mark('Leave', leaveReason: reason.isEmpty ? null : reason);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Mark today',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _statuses.map((s) {
                      final selected = _todayStatus == s;
                      return ChoiceChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: _saving
                            ? null
                            : (_) async {
                                if (s == 'Leave') {
                                  await _askLeaveReason();
                                } else {
                                  await _mark(s);
                                }
                              },
                        selectedColor: _color(s),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black54,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: selected ? _color(s) : const Color(0xFFE5E5E0)),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Last 14 days',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (_myDays.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('No attendance recorded yet.', style: TextStyle(color: subT(context))),
                    ),
                  ..._myDays.map((d) {
                    final status = (d['status'] ?? '').toString();
                    final date = DateTime.tryParse(d['date'].toString());
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                date != null ? DateFormat('EEE, d MMM yyyy').format(date) : d['date'].toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _color(status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w700, color: _color(status)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
