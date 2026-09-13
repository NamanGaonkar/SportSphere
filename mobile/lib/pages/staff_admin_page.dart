import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

/// Staff & HR directory with latest payroll — web Staff.tsx parity.
class StaffAdminPage extends StatefulWidget {
  const StaffAdminPage({super.key});

  @override
  State<StaffAdminPage> createState() => _StaffAdminPageState();
}

class _StaffAdminPageState extends State<StaffAdminPage> {
  List<DbRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await client
          .from('staff')
          .select('*, profile:profiles(full_name), payroll(month, gross, deductions, net)')
          .order('created_at');
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PageHead('Staff & HR', sub: 'Staff directory and payroll summary.'),
          Card(
            child: _loading
                ? const LoadingState()
                : PagedTable(
                    items: _rows,
                    emptyText: 'No staff records yet.',
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Department')),
                      DataColumn(label: Text('Designation')),
                      DataColumn(label: Text('Latest Payroll (net)')),
                    ],
                    rowBuilder: (s) {
                      final payroll = (s['payroll'] as List?) ?? const [];
                      final latest = payroll.isNotEmpty ? payroll.last as Map : null;
                      return DataRow(cells: [
                        DataCell(Text('${((s['profile'] ?? {}) as Map)['full_name'] ?? '-'}')),
                        DataCell(Text('${s['department'] ?? '-'}')),
                        DataCell(Text('${s['designation'] ?? '-'}')),
                        DataCell(Text(latest == null
                            ? '-'
                            : '${inr(latest['net'] is num ? latest['net'] as num : null)} (${('${latest['month'] ?? ''}').split('T').first})')),
                      ]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
