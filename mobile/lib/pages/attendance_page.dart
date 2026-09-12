import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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

  static const _statuses = ['Present', 'Late', 'Leave', 'Absent'];

  Color _color(String status) {
    switch (status) {
      case 'Present':
        return const Color(0xFF22C55E);
      case 'Late':
        return const Color(0xFFF59E0B);
      case 'Leave':
        return const Color(0xFF4F7CFF);
      case 'Absent':
        return const Color(0xFFEF4444);
    }
    return Colors.white24;
  }

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

  Future<void> _mark(String status) async {
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

    if (existing != null) {
      await client.from('attendance').update({'status': status}).eq('id', existing['id']);
    } else {
      await client
          .from('attendance')
          .insert({'profile_id': uid, 'date': todayKey, 'status': status});
    }
    await _load();
    if (mounted) setState(() => _saving = false);
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _statuses.map((s) {
                      final selected = _todayStatus == s;
                      return ChoiceChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: _saving ? null : (_) => _mark(s),
                        avatar: selected ? null : CircleAvatar(backgroundColor: _color(s), radius: 5),
                        selectedColor: _color(s),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  const Text('Last 14 days',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_myDays.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No attendance recorded yet.',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  ..._myDays.map((d) {
                    final status = (d['status'] ?? '').toString();
                    final date = DateTime.tryParse(d['date'].toString());
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171E2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A3550)),
                      ),
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
                              color: _color(status).withValues(alpha: 0.18),
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
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
