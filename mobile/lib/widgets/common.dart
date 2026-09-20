import 'dart:math' show atan2, pi, sqrt;

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

/// yyyy-mm-dd in LOCAL time (what the `date` columns contain).
String localDateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// "16 Sep" short label — same format as web (lib/dates.ts).
String shortDayLabel(String key) {
  final parts = key.split('-');
  return '${int.parse(parts[2])} ${months[int.parse(parts[1]) - 1]}';
}

class DayPoint {
  final String key; // yyyy-mm-dd
  final String label; // "16 Sep"
  final int present;
  final int total;
  final int pct;
  /// False = nobody was marked that day. Charts render these days as gaps,
  /// never as 0% or 100% (so one Present mark can't distort the rate).
  final bool marked;
  const DayPoint(this.key, this.label, this.present, this.total, this.pct, {this.marked = true});
}

/// Rolling N-day window ending today. Every day gets a bucket even when
/// empty, so the x-axis is always the same shape. Identical algorithm to
/// web/src/lib/dates.ts — the graphs on phone and web always agree.
/// [roster] = total people expected to attend; when given, pct is computed
/// against the roster (1 Present out of 16 people reads as ~6%, not 100%).
List<DayPoint> attendanceWindow(List<({String date, String status})> rows, int days, {int? roster}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final buckets = <String, List<int>>{}; // key -> [present, total]
  final keys = <String>[];
  for (var i = days - 1; i >= 0; i--) {
    final k = localDateKey(today.subtract(Duration(days: i)));
    keys.add(k);
    buckets[k] = [0, 0];
  }
  for (final r in rows) {
    final k = r.date.split('T').first;
    final b = buckets[k];
    if (b == null) continue;
    b[1] += 1;
    if (r.status == 'Present' || r.status == 'Late') b[0] += 1;
  }
  return [
    for (final k in keys)
      DayPoint(
        k,
        shortDayLabel(k),
        buckets[k]![0],
        buckets[k]![1],
        (roster != null && roster > 0
                ? buckets[k]![0] * 100 / roster
                : buckets[k]![1] == 0
                    ? 0.0
                    : buckets[k]![0] * 100 / buckets[k]![1])
            .round(),
        marked: buckets[k]![1] > 0,
      ),
  ];
}

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              ),
              // Action button (e.g. Add) sits beside the title and always
              // stays fully visible, never squeezed off-screen.
              ?action,
            ],
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(sub!, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            ),
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
    // 55% orange tint — makes the stat cards pop on both apps (brand pop).
    const tint = Color(0xFFFFF1E7); // ~55% toward white from Brand.primary
    return Card(
      color: tint,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Brand.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0xFFB25A1F))),
            const SizedBox(height: 6),
            // FittedText keeps long values (e.g. "Rs 12,34,567") inside the
            // card: the font shrinks to fit one line instead of overflowing.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700, height: 1.15, color: Color(0xFF1A1A1A))),
            ),
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

/// Compact money for stat cards: 1.2 Cr / 4.5 L / 12.3 K (web inrCompact parity).
String inrCompact(num? n) {
  if (n == null) return '-';
  final v = n.toDouble();
  final abs = v.abs();
  String two(double x) => x.toStringAsFixed(x >= 10 ? 0 : 2);
  if (abs >= 10000000) return '${v < 0 ? '-' : ''}Rs ${two(v.abs() / 10000000)} Cr';
  if (abs >= 100000) return '${v < 0 ? '-' : ''}Rs ${two(v.abs() / 100000)} L';
  if (abs >= 1000) return '${v < 0 ? '-' : ''}Rs ${(v.abs() / 1000).toStringAsFixed(abs >= 10000 ? 0 : 1)} K';
  return '${v < 0 ? '-' : ''}Rs ${v.round()}';
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
    // Center: empty states must never hug one side of a card.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.black.withValues(alpha: 0.3)),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black45)),
          ],
        ),
      ),
    );
  }
}

/// Titled content card used by dashboard/reports/profile sections.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool centerChild;
  const SectionCard({super.key, required this.title, required this.child, this.centerChild = false});

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
            centerChild ? Center(child: child) : child,
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
/// Every row has a leading chevron cell — tapping the row expands a full
/// detail panel below it (web ExpandableRow parity), so no column is ever
/// cut off on a phone screen.
class PagedTable<T> extends StatefulWidget {
  final List<T> items;
  final List<DataColumn> columns;
  final DataRow Function(T item) rowBuilder;

  /// Full detail lines shown when the row is expanded. Key = label.
  final List<MapEntry<String, String>> Function(T item)? detailBuilder;

  /// Optional colored chips shown at the top of the expanded panel.
  final List<(String, Color)> Function(T item)? chipsBuilder;

  final String emptyText;
  const PagedTable({
    super.key,
    required this.items,
    required this.columns,
    required this.rowBuilder,
    this.detailBuilder,
    this.chipsBuilder,
    this.emptyText = 'No records yet.',
  });

  @override
  State<PagedTable<T>> createState() => _PagedTableState<T>();
}

class _PagedTableState<T> extends State<PagedTable<T>> {
  int _page = 0;
  int _perPage = 10;
  int? _expandedIdx; // one expanded row at a time

  void _toggle(int idx) {
    setState(() => _expandedIdx = _expandedIdx == idx ? null : idx);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    if (total == 0) return EmptyState(widget.emptyText);
    final maxPage = (total - 1) ~/ _perPage;
    if (_page > maxPage) _page = maxPage;
    final slice = widget.items.skip(_page * _perPage).take(_perPage).toList();

    final hasDetail = widget.detailBuilder != null;
    const chevronW = 34.0;
    const colGap = 8.0; // breathing room inside each cell

    return LayoutBuilder(builder: (context, box) {
      final viewport = box.maxWidth;
      final n = widget.columns.length;

      // Column sizing: first (name/title) column gets double weight,
      // Actions column has a hard minimum so the edit/delete icons always
      // fit. Leftover width is distributed by weight; if the minimums
      // already exceed the viewport the table scrolls horizontally.
      final minW = List<double>.generate(n, (i) {
        if (i == n - 1) return 118.0; // actions: 3 compact icon buttons
        if (i == 0) return 120.0; // name/title column
        return 78.0;
      });
      // Columns after the first share width equally (weight 1.0) except the
      // actions column which keeps its fixed minimum — prevents a Wrap of
      // chips in a middle column from squeezing other columns to a sliver.
      final weights = List<double>.generate(
          n, (i) => (i == 0 || i == n - 1) ? 1.0 : 1.6);
      final sumW = weights.fold<double>(0, (s, w) => s + w);
      final minTotal =
          (hasDetail ? chevronW : 0) + minW.fold<double>(0, (s, w) => s + w);

      final widths = List<double>.filled(n, 0);
      double tableW;
      if (viewport >= minTotal) {
        // Fit the viewport: base = minimum, extra spread by weight.
        final extra = viewport - minTotal;
        tableW = viewport;
        for (var i = 0; i < n; i++) {
          widths[i] = minW[i] + extra * weights[i] / sumW;
        }
      } else {
        // Scroll horizontally at minimum sizes (+50% on the name column).
        tableW = minTotal + (hasDetail ? 0 : 0);
        for (var i = 0; i < n; i++) {
          widths[i] = minW[i] + (i == 0 ? 60.0 : 0);
          tableW += (i == 0 ? 60.0 : 0);
        }
      }

      Widget headerCell(int i) => Container(
            width: widths[i],
            padding: EdgeInsets.symmetric(horizontal: colGap, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xFFE4E4DC), width: 0.8)),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle(
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                      letterSpacing: 0.3),
                  child: widget.columns[i].label,
                ),
              ),
            ),
          );

      Widget dataCell(int i, Widget child) => Container(
            width: widths[i],
            padding: EdgeInsets.symmetric(horizontal: colGap, vertical: 8),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Color(0xFFEDEDE5), width: 0.8)),
            ),
            child: child,
          );

      // ---- Header row ----
      final header = Container(
        color: const Color(0xFFF5F5F0),
        child: Row(
          children: [
            if (hasDetail)
              const SizedBox(width: chevronW),
            for (var i = 0; i < n; i++) headerCell(i),
          ],
        ),
      );

      // ---- Data rows: each row is [row, its own detail panel] so the
      // panel opens DIRECTLY UNDER the tapped row, not pooled at the
      // bottom. Fixed column widths keep everything aligned.
      final rowWidgets = <Widget>[];
      for (var i = 0; i < slice.length; i++) {
        final item = slice[i];
        final idx = _page * _perPage + i;
        final open = hasDetail && _expandedIdx == idx;
        final base = widget.rowBuilder(item);

        rowWidgets.add(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: open ? const Color(0xFFFFF4EC) : Colors.transparent,
                child: InkWell(
                  onTap: hasDetail ? () => _toggle(idx) : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 50),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasDetail)
                          SizedBox(
                            width: chevronW,
                            child: Icon(
                              open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 20,
                              color: Brand.primary,
                            ),
                          ),
                        for (var c = 0; c < n && c < base.cells.length; c++)
                          dataCell(c, base.cells[c].child),
                      ],
                    ),
                  ),
                ),
              ),
              if (open)
                _DetailPanel(
                  detail: widget.detailBuilder!(item),
                  chips: widget.chipsBuilder?.call(item) ?? const [],
                ),
              Container(height: 1, color: const Color(0xFFEDEDE5)),
            ],
          ),
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableW,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [header, ...rowWidgets],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // "1–10 of 26" then ONE rows-per-page selector — the value
                // lives only inside the dropdown trigger, never duplicated
                // beside it (no "Rows: 10 10" rendering).
                Text(
                    '${_page * _perPage + 1}-${(_page + 1) * _perPage > total ? total : (_page + 1) * _perPage} of $total',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(width: 4),
                DropdownButton<int>(
                  value: _perPage,
                  underline: const SizedBox.shrink(),
                  items: const [10, 25, 50]
                      .map((n) => DropdownMenuItem(
                          value: n, child: Text('$n rows', style: TextStyle(fontSize: 12))))
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
                Text('${_page + 1}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
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
    });
  }
}

/// The expanded panel under a table row: chips + label/value grid.
class _DetailPanel extends StatelessWidget {
  final List<MapEntry<String, String>> detail;
  final List<(String, Color)> chips;
  const _DetailPanel({required this.detail, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF4EC),
        border: Border(left: BorderSide(color: Brand.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final (label, color) in chips) BadgeChip(label, color: color)],
              ),
            ),
          for (final e in detail)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(e.key,
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                  Expanded(
                    child: Text(e.value.isEmpty ? '-' : e.value,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Donut pie — web Reports.tsx parity (recharts PieChart with innerRadius).
/// Colors match the web CHART_COLORS order.
const pieColors = [
  Color(0xFFFF6A13), // primary orange
  Color(0xFF2E7D32), // success
  Color(0xFFB26A00), // warning
  Color(0xFFC62828), // error
  Color(0xFF1565C0), // info
  Color(0xFF757575), // muted
];

class DonutPie extends StatefulWidget {
  final List<MapEntry<String, num>> entries;
  const DonutPie(this.entries, {super.key});

  @override
  State<DonutPie> createState() => _DonutPieState();
}

class _DonutPieState extends State<DonutPie> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    if (entries.isEmpty) return const EmptyState('No data yet.');
    final total = entries.fold<num>(0, (s, e) => s + e.value);
    // The donut + legend group sizes to its content; the parent card must
    // center it (SectionCard centerChild) or it hugs the left edge.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 160,
          width: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: GestureDetector(
                  // Tap a slice to inspect it (angle -> segment lookup).
                  onTapUp: (d) {
                    const c = Offset(80, 80);
                    final dx = d.localPosition.dx - c.dx;
                    final dy = d.localPosition.dy - c.dy;
                    final dist = sqrt(dx * dx + dy * dy);
                    if (dist < 160 * 0.62 / 2 || dist > 80) {
                      setState(() => _selected = null);
                      return;
                    }
                    var deg = atan2(dy, dx) * 180 / pi + 90; // 0 = top
                    if (deg < 0) deg += 360;
                    var acc = 0.0;
                    for (var i = 0; i < entries.length; i++) {
                      final sweep = entries[i].value / (total == 0 ? 1 : total) * 360;
                      if (deg >= acc && deg < acc + sweep) {
                        setState(() => _selected = _selected == i ? null : i);
                        return;
                      }
                      acc += sweep;
                    }
                    setState(() => _selected = null);
                  },
                  child: CustomPaint(
                    painter: _DonutPainter(
                      segments: [
                        for (var i = 0; i < entries.length; i++)
                          MapEntry(entries[i].value / (total == 0 ? 1 : total), pieColors[i % pieColors.length]),
                      ],
                      selectedIndex: _selected,
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selected == null ? total.toString() : entries[_selected!].value.toString(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  if (_selected != null)
                    Text(
                      entries[_selected!].key,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < entries.length; i++)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _selected = _selected == i ? null : i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: pieColors[i % pieColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text('${entries[i].key} (${entries[i].value})',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: _selected == i ? Brand.primary : Colors.black87,
                              fontWeight: _selected == i ? FontWeight.w700 : FontWeight.w400)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<double, Color>> segments;
  final int? selectedIndex;
  const _DonutPainter({required this.segments, this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final inner = radius * 0.62;
    final paint = Paint()..style = PaintingStyle.stroke;
    var start = -1.5708; // top
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final sweep = seg.key * 6.28318;
      final sel = selectedIndex == i;
      paint.color = seg.value;
      paint.strokeWidth = radius - inner + (sel ? 6 : 0);
      canvas.drawArc(Rect.fromCircle(center: center, radius: (radius + inner) / 2 - (sel ? 3 : 0)), start, sweep == 0 ? 0.0001 : sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.selectedIndex != selectedIndex;
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

/// Vertical daily bars for the attendance chart (0-100% scale).
/// A real chart, not floating sticks: y-gridlines with 0/50/100 labels,
/// bars sized to fill the card width (30-day charts no longer need the
/// cramped sideways scroll), dashed gaps for unmarked days, and a tap
/// tooltip on every bar showing the exact day / rate / marks.
class VBars extends StatelessWidget {
  final List<DayPoint> points;
  final double barWidth; // preferred bar width when space allows
  final double height;
  /// Show a % label above every bar (sparse charts like the 7-day view).
  final bool showValueLabels;
  /// Label every Nth day on the x-axis (0 = all). Dense charts use 3.
  final int labelEvery;
  const VBars(this.points,
      {super.key,
      this.barWidth = 22,
      this.height = 170,
      this.showValueLabels = true,
      this.labelEvery = 0});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const EmptyState('No attendance recorded yet.');
    const yGutter = 34.0; // left labels: 100 / 50 / 0
    const xLabelH = 38.0; // bottom band for the angled day labels
    final valueSlot = showValueLabels ? 18.0 : 2.0; // space reserved above bars
    final plotH = (height - xLabelH - valueSlot).clamp(60.0, 260.0);
    final barArea = plotH - 2; // hairpin so a 100% bar never overflows
    final n = points.length;

    // Tick cadence anchored to the NEWEST day (index n-1 = today) so the
    // right-most column always carries its date, plus the oldest column.
    // (Labeling from the oldest side was dropping today's label entirely.)
    bool hasTick(int i) =>
        labelEvery <= 0 || i == n - 1 || i == 0 || (n - 1 - i) % labelEvery == 0;

    return LayoutBuilder(builder: (context, box) {
      // Fill the card width; only scroll when slots get inhumanly small.
      final slot = (box.maxWidth - yGutter - 4) / n;
      final scroll = slot < 10;
      final usedSlot = scroll ? 12.0 : slot;
      final bar = (usedSlot * 0.62).clamp(3.0, barWidth);

      // Deterministic slot layout (fixed widths, left-aligned): bars and
      // labels use the SAME construction, so ticks sit exactly under their
      // bars — spaceEvenly drift was making labels wander off their bars.
      Widget slots(Widget Function(int i) child) => Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [for (var i = 0; i < n; i++) SizedBox(width: usedSlot, child: child(i))],
          );

      final plot = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: yGutter,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                Text('100', style: _axisStyle),
                Text('50', style: _axisStyle),
                Text('0', style: _axisStyle),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Gridlines: 100% / 50% / baseline.
                Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(height: 1, color: const Color(0xFFE4E4DC))),
                Positioned(
                    left: 0,
                    right: 0,
                    top: plotH / 2,
                    child: Container(height: 1, color: const Color(0xFFE4E4DC))),
                Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(height: 1, color: const Color(0xFFC9C9C0))),
                Positioned.fill(
                  child: slots(
                    (i) => _BarSlot(
                      p: points[i],
                      slot: usedSlot,
                      bar: bar,
                      plotH: plotH,
                      barArea: barArea,
                      valueSlot: valueSlot,
                      showValue: showValueLabels,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      // Angled day labels (web's -40° treatment): end-anchored at the tick
      // and swinging down-left, so full "16 Sep" labels stay readable even
      // on a 30-bar dense axis.
      final labels = Padding(
        padding: const EdgeInsets.only(left: yGutter + 4),
        child: SizedBox(
          height: xLabelH,
          child: slots(
            (i) => hasTick(i)
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Transform.rotate(
                        angle: -0.62, // ~ -35°
                        alignment: Alignment.topRight,
                        child: Text(points[i].label, style: _axisStyle),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );

      return SizedBox(
        height: height,
        child: scroll
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [plot, labels],
                ),
              )
            : Column(children: [Expanded(child: plot), labels]),
      );
    });
  }
}

const _axisStyle = TextStyle(
    fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black54);

/// One day's column inside the plot: value label, bar (or dash gap), all
/// inside a tap tooltip with the exact numbers for that day.
class _BarSlot extends StatelessWidget {
  final DayPoint p;
  final double slot;
  final double bar;
  final double plotH;
  final double barArea;
  final double valueSlot;
  final bool showValue;
  const _BarSlot({
    required this.p,
    required this.slot,
    required this.bar,
    required this.plotH,
    required this.barArea,
    required this.valueSlot,
    required this.showValue,
  });

  @override
  Widget build(BuildContext context) {
    final tip = p.marked
        ? '${p.label} - ${p.pct}% (${p.present} of ${p.total} marked)'
        : '${p.label} - no marks recorded';
    final Widget column = SizedBox(
      width: slot,
      height: plotH,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: valueSlot,
            child: showValue && p.marked
                ? Text('${p.pct}',
                    style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54))
                : null,
          ),
          if (!p.marked)
            // Unmarked day: a small dash, never a bar (never 0%, never 100%).
            Container(width: bar, height: 2, color: Colors.black12)
          else
            Container(
              width: bar,
              // True percentage scale against the fixed plot area.
              height: (p.pct / 100 * barArea).clamp(2.0, barArea),
              decoration: BoxDecoration(
                color: p.pct == 0
                    ? Brand.primary.withValues(alpha: 0.30) // marked, all absent
                    : Brand.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
        ],
      ),
    );
    return Tooltip(message: tip, triggerMode: TooltipTriggerMode.tap, child: column);
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
/// [firstDate] defaults to today — past dates cannot be picked anywhere
/// unless a caller explicitly allows them (e.g. DOB).
class DateField extends StatelessWidget {
  final String label;
  final String? value; // yyyy-mm-dd
  final ValueChanged<String?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: value == null || value!.isEmpty ? '' : fmtDate(value)),
      decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20)),
      onTap: () async {
        final now = DateTime.now();
        final first = firstDate ?? DateTime(now.year, now.month, now.day);
        final initialRaw = DateTime.tryParse(value != null && value!.length == 10 ? '$value T00:00:00'.replaceAll(' ', '') : '');
        var initial = initialRaw;
        if (initial == null || initial.isBefore(first)) initial = first;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: lastDate ?? DateTime(2100),
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
        final now = DateTime.now();
        final day = await showDatePicker(
          context: context,
          initialDate: initial ?? now,
          firstDate: DateTime(now.year, now.month, now.day),
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
