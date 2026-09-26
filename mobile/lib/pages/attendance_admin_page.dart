import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

const _statuses = ['Present', 'Absent', 'Late', 'Leave'];

class AttendanceAdminPage extends StatefulWidget {
  const AttendanceAdminPage({super.key});

  @override
  State<AttendanceAdminPage> createState() => _AttendanceAdminPageState();
}

class _AttendanceAdminPageState extends State<AttendanceAdminPage> {
  List<DbRow> _rows = [];
  bool _loading = true;
  bool _saving = false;
  String _date = DateTime.now().toIso8601String().split('T').first;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = listen('attendance', _load);
  }

  @override
  void dispose() {
    if (_channel != null) client.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // RBAC parity with web: venue managers and athletes only see their
      // own attendance record, not everyone's.
      final uid = client.auth.currentUser?.id;
      final me = uid == null
          ? null
          : await client.from('profiles').select('role').eq('id', uid).maybeSingle();
      final myRole = '${me?['role'] ?? 'Athlete'}';
      final ownOnly = myRole == 'VenueManager' || myRole == 'Athlete';

      final data = ownOnly && uid != null
          ? await client
              .from('profiles')
              .select('id, full_name, role, attendance(id, date, status, leave_reason)')
              .inFilter('role', ['Athlete', 'Coach', 'HR', 'Finance', 'VenueManager'])
              .eq('id', uid)
              .order('full_name')
          : await client
              .from('profiles')
              .select('id, full_name, role, attendance(id, date, status, leave_reason)')
              .inFilter('role', ['Athlete', 'Coach', 'HR', 'Finance', 'VenueManager'])
              .order('full_name');
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

  DbRow? _recordFor(DbRow r) {
    final att = (r['attendance'] as List?) ?? const [];
    for (final a in att) {
      if ('${(a as Map)['date']}'.split('T').first == _date) return a as DbRow;
    }
    return null;
  }

  ({int present, int total, int pct}) get _summary {
    var present = 0, total = 0;
    for (final r in _rows) {
      final s = _recordFor(r)?['status'];
      if (s != null) {
        total += 1;
        if (s == 'Present' || s == 'Late') present += 1;
      }
    }
    // Rate over the whole roster, not just those marked so far —
    // 1 Present out of 16 people reads as ~6%, not 100%.
    final pct = _rows.isEmpty ? 0 : (present * 100 / _rows.length).round();
    return (present: present, total: total, pct: pct);
  }

  Future<void> _mark(DbRow r, String status, {String? leaveReason}) async {
    setState(() => _saving = true);
    try {
      final existing = _recordFor(r);
      final payload = <String, dynamic>{'status': status};
      if (status == 'Leave') {
        payload['leave_reason'] =
            leaveReason ?? existing?['leave_reason'];
      }
      if (existing != null) {
        await client.from('attendance').update(payload).eq('id', existing['id']);
      } else {
        await client.from('attendance').insert({'profile_id': r['id'], 'date': _date, ...payload});
      }
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Leave requires a reason dialog — web Attendance.tsx parity.
  Future<void> _onMark(DbRow r, String status) async {
    if (status != 'Leave') {
      await _mark(r, status);
      return;
    }
    final existing = _recordFor(r);
    final ctrl = TextEditingController(text: '${existing?['leave_reason'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave reason'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason'),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) {
                showSnack(ctx, 'Enter a reason to mark leave.', error: true);
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Mark Leave'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _mark(r, 'Leave', leaveReason: ctrl.text.trim());
  }

  bool get _viewOnly => _date.compareTo(DateTime.now().toIso8601String().split('T').first) < 0;

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title and date picker are separate rows — the date field never
          // squeezes/overflows the header on narrow screens.
          const PageHead('Attendance & Leave',
              sub: 'View any date. Marking is allowed for today onward.'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Date',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Brand.primary)),
              const SizedBox(width: 10),
              Expanded(
                // Full-width date field with a normal height: the old 48px
                // box + isDense combo truncated the "View date" label and
                // the picked date (tester round 3 #9).
                child: DateField(
                  label: 'View date',
                  value: _date,
                  onChanged: (v) => setState(() => _date = v ?? _date),
                  // Viewing any past date is allowed; the mark buttons are
                  // disabled for past days below.
                  firstDate: DateTime(2000),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            const gap = 12.0;
            final w = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: w,
                  child: StatCard(label: 'MARKED', value: '${s.total}', sub: 'of ${_rows.length} people', variant: 0),
                ),
                SizedBox(
                  width: w,
                  child: StatCard(
                      label: 'PRESENT + LATE',
                      value: '${s.present}',
                      sub: '${s.pct}% of ${_rows.length} people',
                      variant: 2),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          Card(
            child: _loading
                ? const LoadingState()
                : _rows.isEmpty
                    ? const EmptyState('No athletes to mark.')
                    : Column(
                        children: [
                          for (final r in _rows) _rowTile(r),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _rowTile(DbRow r) {
    final rec = _recordFor(r);
    final status = rec?['status']?.toString();
    final reason = rec?['leave_reason']?.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r['full_name'] ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('${r['role'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: subT(context))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (status != null)
                Tooltip(
                  message: reason ?? '',
                  triggerMode: TooltipTriggerMode.longPress,
                  child: BadgeChip(status, color: statusColor(status)),
                )
              else
                Text('not marked', style: TextStyle(fontSize: 12, color: faintT(context))),
            ],
          ),
          const SizedBox(height: 8),
          // Status buttons stretch evenly across the row — no wrapping,
          // no vertical stretching, fixed compact height. Past dates are
          // view-only (buttons disabled).
          Row(
            children: [
              for (var i = 0; i < _statuses.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: status == _statuses[i] ? Brand.primary : Colors.transparent,
                        foregroundColor: status == _statuses[i] ? Colors.white : Brand.primary,
                        side: BorderSide(
                            color: status == _statuses[i]
                                ? Brand.primary
                                : Brand.primary.withValues(alpha: 0.5)),
                      ),
                      onPressed: (_saving || _viewOnly) ? null : () => _onMark(r, _statuses[i]),
                      child: Text(_statuses[i], style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 18),
        ],
      ),
    );
  }
}
