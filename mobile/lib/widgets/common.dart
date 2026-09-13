import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show Brand;

/// Mirrors web/src/components/ui.tsx statusColor().
Color statusColor(String s) {
  switch (s) {
    case 'Present':
    case 'Completed':
    case 'Active':
    case 'Done':
      return const Color(0xFF2E7D32);
    case 'Live':
    case 'Scheduled':
      return const Color(0xFF1565C0);
    case 'Late':
    case 'Maintenance':
    case 'In Progress':
      return const Color(0xFFB26A00);
    case 'Absent':
    case 'Cancelled':
    case 'Not cleared':
      return const Color(0xFFC62828);
    default:
      return const Color(0xFF757575);
  }
}

Color levelColor(String l) {
  switch (l) {
    case 'National':
      return const Color(0xFFC62828);
    case 'State':
      return const Color(0xFFB26A00);
    case 'District':
      return const Color(0xFF1565C0);
    default:
      return const Color(0xFF2E7D32);
  }
}

String inr(num? n) {
  if (n == null) return '-';
  final neg = n < 0;
  final digits = n.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    b.write(digits[i]);
    final rem = digits.length - 1 - i;
    if (rem > 0 && rem % 3 == 0) b.write(',');
  }
  return '${neg ? '-' : ''}Rs ${b.toString()}';
}

const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final d = DateTime.tryParse(iso.length == 10 ? '${iso}T00:00:00' : iso);
  if (d == null) return '-';
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String fmtDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '-';
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]}, $hh:$mm';
}

class PageHead extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? action;
  const PageHead(this.title, {super.key, this.sub, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(sub!, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                  ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Same label / value / sub contract as web StatCard.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const StatCard({super.key, required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15)),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(sub!, style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
              ),
          ],
        ),
      ),
    );
  }
}

class BadgeChip extends StatelessWidget {
  final String text;
  final Color color;
  const BadgeChip(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.ellipsis),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: Colors.black.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black45)),
        ],
      ),
    );
  }
}

/// Titled content card used by dashboard/reports/profile sections.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const SectionCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.black54)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: Colors.black38),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Web-style paginated DataTable: horizontal-scrollable table + a
/// "rows per page / x-y of n / arrows" footer, like MUI TablePagination.
class PagedTable<T> extends StatefulWidget {
  final List<T> items;
  final List<DataColumn> columns;
  final DataRow Function(T item) rowBuilder;
  final String emptyText;
  const PagedTable({
    super.key,
    required this.items,
    required this.columns,
    required this.rowBuilder,
    this.emptyText = 'No records yet.',
  });

  @override
  State<PagedTable<T>> createState() => _PagedTableState<T>();
}

class _PagedTableState<T> extends State<PagedTable<T>> {
  int _page = 0;
  int _perPage = 10;

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    if (total == 0) return EmptyState(widget.emptyText);
    final maxPage = (total - 1) ~/ _perPage;
    if (_page > maxPage) _page = maxPage;
    final slice = widget.items.skip(_page * _perPage).take(_perPage).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 22,
            headingRowHeight: 44,
            dataRowMinHeight: 46,
            dataRowMaxHeight: 64,
            headingTextStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: 0.3),
            headingRowColor: const WidgetStatePropertyAll(Color(0xFFF5F5F0)),
            columns: widget.columns,
            rows: [for (final item in slice) widget.rowBuilder(item)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${_page * _perPage + 1}-${(_page + 1) * _perPage > total ? total : (_page + 1) * _perPage} of $total',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(width: 12),
              Text('Rows: $_perPage', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              DropdownButton<int>(
                value: _perPage,
                underline: const SizedBox.shrink(),
                items: const [10, 25, 50]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n', style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (v) => setState(() {
                  _perPage = v ?? 10;
                  _page = 0;
                }),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${_page + 1}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _page < maxPage ? () => setState(() => _page++) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontal percentage bars — used for "Teams by sport" and Reports.
class HBars extends StatelessWidget {
  final List<MapEntry<String, num>> entries;
  final Color color;
  const HBars(this.entries, {super.key, this.color = Brand.primary});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const EmptyState('No data yet.');
    final max = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 118,
                  child: Text(e.key,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(height: 16, color: const Color(0xFFF0F0EA)),
                        FractionallySizedBox(
                          widthFactor: max == 0 ? 0 : e.value / max,
                          child: Container(height: 16, color: color),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 30,
                  child: Text('${e.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Vertical daily bars for the attendance chart (0-100%).
class VBars extends StatelessWidget {
  final List<MapEntry<String, num>> entries;
  const VBars(this.entries, {super.key});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const EmptyState('No attendance recorded yet.');
    return SizedBox(
      height: 150,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${e.value}%',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Container(
                      width: 26,
                      height: 100 * e.value / 100 + 4,
                      decoration: BoxDecoration(
                        color: Brand.primary,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(e.key, style: const TextStyle(fontSize: 10.5, color: Colors.black45)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Web-style confirmed delete.
Future<bool> confirmDelete(BuildContext context, String what) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete'),
      content: Text('Delete this $what? This cannot be undone.'),
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
  return res ?? false;
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFC62828) : Brand.black,
    ),
  );
}

/// Date field that opens the material date picker (web `type=date` parity).
class DateField extends StatelessWidget {
  final String label;
  final String? value; // yyyy-mm-dd
  final ValueChanged<String?> onChanged;
  const DateField({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: value == null || value!.isEmpty ? '' : fmtDate(value)),
      decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20)),
      onTap: () async {
        final initial = DateTime.tryParse(value != null && value!.length == 10 ? '$value T00:00:00'.replaceAll(' ', '') : '') ??
            DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          final m = picked.month.toString().padLeft(2, '0');
          final d = picked.day.toString().padLeft(2, '0');
          onChanged('${picked.year}-$m-$d');
        }
      },
    );
  }
}

/// Datetime field: date picker followed by time picker (web `datetime-local`).
class DateTimeField extends StatelessWidget {
  final String label;
  final String? value; // ISO string
  final ValueChanged<String?> onChanged;
  const DateTimeField({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final initial = DateTime.tryParse(value ?? '')?.toLocal();
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: initial == null ? '' : fmtDateTime(initial.toIso8601String())),
      decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.event_outlined, size: 20)),
      onTap: () async {
        final day = await showDatePicker(
          context: context,
          initialDate: initial ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (day == null) return;
        if (!context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: initial != null ? TimeOfDay.fromDateTime(initial) : TimeOfDay.now(),
        );
        if (time == null) return;
        final dt = DateTime(day.year, day.month, day.day, time.hour, time.minute);
        onChanged(dt.toUtc().toIso8601String());
      },
    );
  }
}

/// Number-only formatter for money/quantity fields.
final numberInput = [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))];
