
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/sports.dart';
import '../widgets/common.dart';

/// Mobile mirror of web/src/components/CrudPage.tsx — same tables, same
/// fields, same columns, same payloads. One generic engine + per-module defs.

typedef DbRow = Map<String, dynamic>;

enum FType { text, number, date, datetime, textarea, select, checkbox }

class SourceDef {
  final String table;
  final String select;
  final String labelPath;
  final String? valueKey;
  const SourceDef(this.table, this.select, this.labelPath, {this.valueKey});
}

class FieldDef {
  final String key;
  final String label;
  final FType type;
  final List<String>? options;
  final SourceDef? source;
  final bool required;
  final bool fullWidth;
  const FieldDef(
    this.key,
    this.label, {
    this.type = FType.text,
    this.options,
    this.source,
    this.required = false,
    this.fullWidth = false,
  });
}

class ColumnDef {
  final String key;
  final String label;
  final Widget Function(DbRow row)? render;
  const ColumnDef(this.key, this.label, {this.render});
}

// ---- shared sources (same tables as web modules.tsx) ----
const sportSource = SourceDef('sports', 'id, name', 'name');
const teamSource = SourceDef('teams', 'id, name', 'name');
const venueSource = SourceDef('venues', 'id, name', 'name');
const coachSource = SourceDef('coaches', 'id, profile:profiles(full_name)', 'profile.full_name');
const athleteSource = SourceDef('athletes', 'id, profile:profiles(full_name)', 'profile.full_name');

final client = Supabase.instance.client;

String _resolveLabel(String labelPath, DbRow r) {
  dynamic o = r;
  for (final k in labelPath.split('.')) {
    if (o is Map<String, dynamic>) o = o[k];
  }
  return o?.toString() ?? '-';
}

// ---- module definitions (1:1 with web/src/pages/modules.tsx) ----

List<Widget Function()> modulePages() {
  Widget housekeeping() => CrudList(
        title: 'Housekeeping Management',
        sub: 'Cleaning and upkeep tasks across venues.',
        table: 'housekeeping_tasks',
        searchKeys: const ['area', 'task', 'assigned_to'],
        columns: [
          ColumnDef('area', 'Area'),
          ColumnDef('task', 'Task'),
          ColumnDef('assigned_to', 'Assigned'),
          ColumnDef('scheduled_date', 'Date', render: (r) => Text(fmtDate(r['scheduled_date']?.toString()))),
          ColumnDef('status', 'Status',
              render: (r) => BadgeChip((r['status'] ?? '-').toString(), color: statusColor(r['status']?.toString() ?? ''))),
        ],
        fields: const [
          FieldDef('area', 'Area', required: true),
          FieldDef('task', 'Task', required: true),
          FieldDef('assigned_to', 'Assigned to'),
          FieldDef('scheduled_date', 'Scheduled date', type: FType.date),
          FieldDef('status', 'Status', type: FType.select, options: ['Pending', 'In Progress', 'Done']),
        ],
      );

  Widget training() => CrudList(
        title: 'Training & Camps',
        sub: 'Training sessions and residential camps.',
        table: 'training_sessions',
        searchKeys: const ['title'],
        columns: [
          ColumnDef('title', 'Title'),
          ColumnDef('type', 'Type'),
          ColumnDef('sport_id', 'Sport', render: (r) => Text(SportsCache.instance.name(r['sport_id']?.toString()))),
          ColumnDef('coach_id', 'Coach', render: (r) => _srcText('coaches', r['coach_id'])),
          ColumnDef('start_time', 'When', render: (r) => Text(fmtDateTime(r['start_time']?.toString()))),
        ],
        fields: const [
          FieldDef('title', 'Title', required: true),
          FieldDef('type', 'Type', type: FType.select, options: ['Session', 'Camp']),
          FieldDef('sport_id', 'Sport', type: FType.select, source: sportSource),
          FieldDef('coach_id', 'Coach', type: FType.select, source: coachSource),
          FieldDef('team_id', 'Team', type: FType.select, source: teamSource),
          FieldDef('venue_id', 'Venue', type: FType.select, source: venueSource),
          FieldDef('start_time', 'Starts', type: FType.datetime),
          FieldDef('end_time', 'Ends', type: FType.datetime),
          FieldDef('notes', 'Notes', type: FType.textarea, fullWidth: true),
        ],
      );

  Widget performance() => CrudList(
        title: 'Athlete Performance',
        sub: 'Structured metric logging: sprints, jumps, endurance, gym and assessments.',
        table: 'performance_records',
        orderBy: 'date',
        searchKeys: const ['metric', 'value'],
        columns: [
          ColumnDef('athlete_id', 'Athlete', render: (r) => _srcText('athletes', r['athlete_id'])),
          ColumnDef('date', 'Date', render: (r) => Text(fmtDate(r['date']?.toString()))),
          ColumnDef('metric', 'Metric', render: (r) => Text('${r['metric'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600))),
          ColumnDef('value_num', 'Result', render: (r) => Text('${r['value_num'] ?? r['value'] ?? '-'} ${r['unit'] ?? ''}')),
          ColumnDef('session_type', 'Session', render: (r) => BadgeChip('${r['session_type'] ?? 'Test'}', color: statusColor('Scheduled'))),
          ColumnDef('coach_note', 'Coach note', render: (r) => Text('${r['coach_note'] ?? '-'}', overflow: TextOverflow.ellipsis)),
        ],
        fields: const [
          FieldDef('athlete_id', 'Athlete', type: FType.select, source: athleteSource, required: true),
          FieldDef('date', 'Date', type: FType.date),
          FieldDef('metric', 'Metric (e.g. 100m Sprint)', required: true),
          FieldDef('value', 'Result (display)', required: true),
          FieldDef('value_num', 'Numeric value', type: FType.number),
          FieldDef('unit', 'Unit (sec / cm / kg / reps)'),
          FieldDef('session_type', 'Session type', type: FType.select, options: ['Test', 'Assessment', 'Gym', 'Competition']),
          FieldDef('coach_note', 'Coach note', type: FType.textarea, fullWidth: true),
        ],
      );

  Widget medical() => CrudList(
        title: 'Athlete Medical',
        sub: 'Detailed logging: vitals, injuries, severity, treatment and follow-ups.',
        table: 'medical_records',
        orderBy: 'date',
        searchKeys: const ['details'],
        columns: [
          ColumnDef('athlete_id', 'Athlete', render: (r) => _srcText('athletes', r['athlete_id'])),
          ColumnDef('type', 'Type', render: (r) => BadgeChip('${r['type'] ?? '-'}',
              color: r['type'] == 'Injury' ? const Color(0xFFC62828) : r['type'] == 'Physio' ? const Color(0xFFB26A00) : const Color(0xFF1565C0))),
          ColumnDef('details', 'Details'),
          ColumnDef('severity', 'Severity', render: (r) {
            final s = '${r['severity'] ?? 'None'}';
            return s == 'None' ? const Text('-') : BadgeChip(s, color: s == 'Severe' ? const Color(0xFFC62828) : s == 'Moderate' ? const Color(0xFFB26A00) : const Color(0xFF1565C0));
          }),
          ColumnDef('cleared', 'Cleared', render: (r) => BadgeChip(
              r['cleared'] == true ? 'Cleared' : 'Not cleared',
              color: r['cleared'] == true ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
          ColumnDef('follow_up_date', 'Follow-up', render: (r) => Text(fmtDate(r['follow_up_date']?.toString()))),
          ColumnDef('date', 'Date', render: (r) => Text(fmtDate(r['date']?.toString()))),
        ],
        fields: const [
          FieldDef('athlete_id', 'Athlete', type: FType.select, source: athleteSource, required: true),
          FieldDef('date', 'Date', type: FType.date),
          FieldDef('type', 'Type', type: FType.select, options: ['Checkup', 'Injury', 'Physio', 'Clearance']),
          FieldDef('height_cm', 'Height (cm)', type: FType.number),
          FieldDef('weight_kg', 'Weight (kg)', type: FType.number),
          FieldDef('severity', 'Severity', type: FType.select, options: ['None', 'Mild', 'Moderate', 'Severe']),
          FieldDef('cleared', 'Cleared to play', type: FType.checkbox),
          FieldDef('treatment', 'Treatment', fullWidth: true),
          FieldDef('follow_up_date', 'Follow-up date', type: FType.date),
          FieldDef('details', 'Details', type: FType.textarea, required: true, fullWidth: true),
        ],
      );

  Widget eventsPage() => CrudList(
        title: 'Events Management',
        sub: 'Ceremonies, workshops and other events.',
        table: 'events',
        searchKeys: const ['title'],
        columns: [
          ColumnDef('title', 'Title'),
          ColumnDef('type', 'Type'),
          ColumnDef('date', 'Date', render: (r) => Text(fmtDate(r['date']?.toString()))),
          ColumnDef('venue_id', 'Venue', render: (r) => _srcText('venues', r['venue_id'])),
        ],
        fields: const [
          FieldDef('title', 'Title', required: true),
          FieldDef('type', 'Type', type: FType.select, options: ['General', 'Ceremony', 'Workshop', 'Other']),
          FieldDef('date', 'Date', type: FType.date),
          FieldDef('venue_id', 'Venue', type: FType.select, source: venueSource),
          FieldDef('description', 'Description', type: FType.textarea, fullWidth: true),
        ],
      );

  Widget transport() => CrudList(
        title: 'Transport',
        sub: 'Team travel - buses, vehicles, drivers.',
        table: 'transport',
        searchKeys: const ['purpose', 'vehicle', 'driver'],
        columns: [
          ColumnDef('purpose', 'Purpose'),
          ColumnDef('vehicle', 'Vehicle'),
          ColumnDef('driver', 'Driver'),
          ColumnDef('depart_at', 'Departure', render: (r) => Text(fmtDateTime(r['depart_at']?.toString()))),
          ColumnDef('status', 'Status',
              render: (r) => BadgeChip((r['status'] ?? '-').toString(), color: statusColor(r['status']?.toString() ?? ''))),
        ],
        fields: const [
          FieldDef('purpose', 'Purpose', required: true),
          FieldDef('vehicle', 'Vehicle'),
          FieldDef('driver', 'Driver'),
          FieldDef('team_id', 'Team', type: FType.select, source: teamSource),
          FieldDef('depart_at', 'Departure', type: FType.datetime),
          FieldDef('return_at', 'Return', type: FType.datetime),
          FieldDef('status', 'Status', type: FType.select, options: ['Planned', 'In Transit', 'Completed']),
        ],
      );

  Widget accommodation() => CrudList(
        title: 'Accommodation',
        sub: 'Hotel stays for teams during travel.',
        table: 'accommodation',
        searchKeys: const ['hotel', 'location'],
        columns: [
          ColumnDef('hotel', 'Hotel'),
          ColumnDef('location', 'Location'),
          ColumnDef('check_in', 'Check-in', render: (r) => Text(fmtDate(r['check_in']?.toString()))),
          ColumnDef('check_out', 'Check-out', render: (r) => Text(fmtDate(r['check_out']?.toString()))),
          ColumnDef('rooms', 'Rooms'),
          ColumnDef('status', 'Status',
              render: (r) => BadgeChip((r['status'] ?? '-').toString(), color: statusColor(r['status']?.toString() ?? ''))),
        ],
        fields: const [
          FieldDef('hotel', 'Hotel', required: true),
          FieldDef('location', 'Location'),
          FieldDef('team_id', 'Team', type: FType.select, source: teamSource),
          FieldDef('check_in', 'Check-in', type: FType.date),
          FieldDef('check_out', 'Check-out', type: FType.date),
          FieldDef('rooms', 'Rooms', type: FType.number),
          FieldDef('status', 'Status', type: FType.select, options: ['Booked', 'Checked-in', 'Completed']),
        ],
      );

  Widget expenses() => CrudList(
        title: 'Finance & Expenses',
        sub: 'Organization spending by category.',
        table: 'expenses',
        searchKeys: const ['category', 'description'],
        columns: [
          ColumnDef('category', 'Category'),
          ColumnDef('amount', 'Amount', render: (r) => Text(inr(_num(r['amount'])))),
          ColumnDef('date', 'Date', render: (r) => Text(fmtDate(r['date']?.toString()))),
          ColumnDef('description', 'Description'),
          ColumnDef('approved_by', 'Approved by'),
        ],
        fields: const [
          FieldDef('category', 'Category', type: FType.select,
              options: ['Equipment', 'Travel', 'Salaries', 'Venue', 'Other'], required: true),
          FieldDef('amount', 'Amount (INR)', type: FType.number, required: true),
          FieldDef('date', 'Date', type: FType.date),
          FieldDef('description', 'Description', type: FType.textarea, fullWidth: true),
          FieldDef('approved_by', 'Approved by'),
        ],
      );

  Widget activities() => CrudList(
        title: 'School Sports Activities',
        sub: 'School-level events and outreach programs.',
        table: 'school_activities',
        searchKeys: const ['title', 'school'],
        columns: [
          ColumnDef('title', 'Title'),
          ColumnDef('school', 'School'),
          ColumnDef('date', 'Date', render: (r) => Text(fmtDate(r['date']?.toString()))),
          ColumnDef('participants', 'Participants'),
        ],
        fields: const [
          FieldDef('title', 'Title', required: true),
          FieldDef('school', 'School'),
          FieldDef('date', 'Date', type: FType.date),
          FieldDef('participants', 'Participants', type: FType.number),
          FieldDef('description', 'Description', type: FType.textarea, fullWidth: true),
        ],
      );

  return [
    housekeeping,
    training,
    performance,
    medical,
    eventsPage,
    transport,
    accommodation,
    expenses,
    activities,
  ];
}

num? _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');

Widget _srcText(String table, dynamic id) {
  return FutureBuilder<String>(
    future: _labelFor(table, id?.toString()),
    builder: (context, snap) => Text(snap.data ?? '-'),
  );
}

final _labelCache = <String, Map<String, String>>{};

Future<String> _labelFor(String table, String? id) async {
  if (id == null || id.isEmpty) return '-';
  final cache = _labelCache.putIfAbsent(table, () => {});
  if (cache.containsKey(id)) return cache[id]!;
  List<dynamic> data;
  switch (table) {
    case 'coaches':
      data = await client.from('coaches').select('id, profile:profiles(full_name)');
      break;
    case 'athletes':
      data = await client.from('athletes').select('id, profile:profiles(full_name)');
      break;
    default:
      data = await client.from(table).select('id, name');
  }
  for (final r in data.cast<DbRow>()) {
    cache[r['id'].toString()] = _resolveLabel(table == 'coaches' || table == 'athletes' ? 'profile.full_name' : 'name', r);
  }
  return cache[id] ?? '-';
}

class CrudList extends StatefulWidget {
  final String title;
  final String sub;
  final String table;
  final String orderBy;
  final List<ColumnDef> columns;
  final List<FieldDef> fields;
  final List<String> searchKeys;
  const CrudList({
    super.key,
    required this.title,
    required this.sub,
    required this.table,
    required this.columns,
    required this.fields,
    this.orderBy = 'created_at',
    this.searchKeys = const [],
  });

  @override
  State<CrudList> createState() => _CrudListState();
}

class _CrudListState extends State<CrudList> {
  List<DbRow> _rows = [];
  final Map<String, List<({String value, String label})>> _sources = {};
  bool _loading = true;
  String _q = '';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSources();
    _channel = listen(widget.table, _load);
  }

  @override
  void dispose() {
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await client.from(widget.table).select('*').order(widget.orderBy, ascending: false);
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

  Future<void> _loadSources() async {
    for (final f in widget.fields) {
      if (f.source == null || _sources.containsKey(f.key)) continue;
      try {
        final data = await client.from(f.source!.table).select(f.source!.select);
        if (!mounted) return;
        setState(() {
          _sources[f.key] = (data as List).cast<DbRow>().map((r) {
            final value = r[f.source!.valueKey ?? 'id'].toString();
            final label = _resolveLabel(f.source!.labelPath, r);
            return (value: value, label: label);
          }).toList();
        });
      } catch (_) {}
    }
  }

  List<DbRow> get _filtered {
    if (_q.isEmpty || widget.searchKeys.isEmpty) return _rows;
    return _rows.where((r) {
      return widget.searchKeys.any((k) => '${r[k] ?? ''}'.toLowerCase().contains(_q.toLowerCase()));
    }).toList();
  }

  /// Full detail lines for the expanded row panel: every column resolved
  /// to a human value, plus created timestamp.
  List<MapEntry<String, String>> _detailFor(DbRow row) {
    final out = <MapEntry<String, String>>[];
    for (final c in widget.columns) {
      final matches = widget.fields.where((x) => x.key == c.key).toList();
      final f = matches.isEmpty ? FieldDef(c.key, c.label) : matches.first;
      final cell = c.render?.call(row) ?? Text(_display(f, row));
      final text = _cellText(cell);
      out.add(MapEntry(c.label, text));
    }
    out.add(MapEntry('Created', fmtDateTime(row['created_at']?.toString())));
    return out;
  }

  static String _cellText(Widget w) {
    if (w is Text) return w.data ?? w.textSpan?.toPlainText() ?? '-';
    if (w is RichText) return w.text.toPlainText();
    return '-';
  }

  String _display(FieldDef f, DbRow row) {
    final v = row[f.key];
    switch (f.type) {
      case FType.checkbox:
        return v == true ? 'Yes' : 'No';
      case FType.select:
        if (f.source != null) {
          final src = _sources[f.key] ?? const [];
          for (final o in src) {
            if (o.value == v.toString()) return o.label;
          }
          return '-';
        }
        return v?.toString() ?? '-';
      case FType.datetime:
        return fmtDateTime(v?.toString());
      case FType.date:
        return fmtDate(v?.toString());
      default:
        return (v == null || v == '') ? '-' : v.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHead(
            widget.title,
            sub: widget.sub,
            action: FilledButton.icon(
              onPressed: _openAdd,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ),
          if (widget.searchKeys.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
              ),
            ),
          Card(
            child: _loading
                ? const LoadingState()
                : PagedTable(
                    items: filtered,
                    emptyText: 'No records yet. Use the Add button to create the first one.',
                    detailBuilder: (row) => _detailFor(row),
                    columns: [
                      for (final c in widget.columns) DataColumn(label: Text(c.label)),
                      const DataColumn(label: Text('Actions')),
                    ],
                    rowBuilder: (row) => DataRow(cells: [
                      for (final c in widget.columns)
                        DataCell(
                          c.render?.call(row) ??
                              Text(_display(widget.fields.firstWhere(
                                (f) => f.key == c.key,
                                orElse: () => FieldDef(c.key, c.label),
                              ), row)),
                        ),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () => _openEdit(row),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFC62828)),
                          onPressed: () => _remove(row),
                        ),
                      ])),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAdd() => _showForm(null);

  Future<void> _openEdit(DbRow row) => _showForm(row);

  Future<void> _showForm(DbRow? editing) async {
    final form = <String, dynamic>{};
    for (final f in widget.fields) {
      final v = editing?[f.key];
      if (f.type == FType.checkbox) {
        form[f.key] = v == true;
      } else if (f.type == FType.datetime) {
        form[f.key] = v?.toString() ?? '';
      } else if (f.type == FType.date) {
        form[f.key] = (v?.toString() ?? '').split('T').first;
      } else {
        form[f.key] = v?.toString() ?? '';
      }
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          maxChildSize: 0.95,
          builder: (ctx, scrollCtrl) => _CrudForm(
            widget: widget,
            editing: editing,
            initial: form,
            sources: _sources,
            scrollCtrl: scrollCtrl,
          ),
        ),
      ),
    );
    _load();
  }

  Future<void> _remove(DbRow row) async {
    if (!await confirmDelete(context, 'record')) return;
    try {
      await client.from(widget.table).delete().eq('id', row['id']);
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }
}

class _CrudForm extends StatefulWidget {
  final CrudList widget;
  final DbRow? editing;
  final Map<String, dynamic> initial;
  final Map<String, List<({String value, String label})>> sources;
  final ScrollController scrollCtrl;
  const _CrudForm({
    required this.widget,
    required this.editing,
    required this.initial,
    required this.sources,
    required this.scrollCtrl,
  });

  @override
  State<_CrudForm> createState() => _CrudFormState();
}

class _CrudFormState extends State<_CrudForm> {
  late Map<String, dynamic> _form;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _form = {...widget.initial};
  }

  Future<void> _save() async {
    setState(() => _error = '');
    final payload = <String, dynamic>{};
    for (final f in widget.widget.fields) {
      dynamic v = _form[f.key];
      if (f.type == FType.number) {
        v = (v == null || v == '') ? null : num.tryParse(v.toString());
      }
      if (f.type == FType.datetime && v != null && v != '') {
        v = DateTime.tryParse(v.toString())?.toUtc().toIso8601String();
      }
      if (f.type == FType.checkbox) v = v == true;
      if (f.type == FType.select && v == '') v = null;
      if (v == '') v = null;
      payload[f.key] = v;
    }
    try {
      final editing = widget.editing;
      if (editing != null) {
        await client.from(widget.widget.table).update(payload).eq('id', editing['id']);
      } else {
        await client.from(widget.widget.table).insert(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.widget;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('${widget.editing != null ? 'Edit' : 'Add'} - ${w.title}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: widget.scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              for (final f in w.fields) ...[
                _field(f),
                const SizedBox(height: 14),
              ],
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error, style: const TextStyle(color: Color(0xFFC62828), fontSize: 13)),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.of(context).padding.bottom),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: Text(widget.editing != null ? 'Save' : 'Add'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(FieldDef f) {
    switch (f.type) {
      case FType.checkbox:
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label, style: const TextStyle(fontSize: 14)),
          value: _form[f.key] == true,
          onChanged: (v) => setState(() => _form[f.key] = v ?? false),
        );
      case FType.textarea:
        return TextFormField(
          initialValue: '${_form[f.key] ?? ''}',
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(labelText: f.label),
          onChanged: (v) => _form[f.key] = v,
        );
      case FType.select:
        final opts = <({String value, String label})>[
          const (value: '', label: 'None'),
          if (f.options != null)
            for (final o in f.options!) (value: o, label: o),
          ...(widget.sources[f.key] ?? const []),
        ];
        return DropdownButtonFormField<String>(
          initialValue: '${_form[f.key] ?? ''}',
          isExpanded: true,
          decoration: InputDecoration(labelText: f.label),
          items: [
            for (final o in opts)
              DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _form[f.key] = v ?? ''),
        );
      case FType.date:
        return DateField(
          label: f.label,
          value: '${_form[f.key] ?? ''}',
          onChanged: (v) => setState(() => _form[f.key] = v ?? ''),
        );
      case FType.datetime:
        return DateTimeField(
          label: f.label,
          value: '${_form[f.key] ?? ''}',
          onChanged: (v) => setState(() => _form[f.key] = v ?? ''),
        );
      case FType.number:
        return TextFormField(
          initialValue: '${_form[f.key] ?? ''}',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: numberInput,
          decoration: InputDecoration(labelText: f.label),
          onChanged: (v) => _form[f.key] = v,
        );
      case FType.text:
        return TextFormField(
          initialValue: '${_form[f.key] ?? ''}',
          decoration: InputDecoration(labelText: f.label),
          onChanged: (v) => _form[f.key] = v,
        );
    }
  }
}
