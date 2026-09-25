import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show Brand;
import '../widgets/common.dart';
import 'crud_page.dart' show DbRow;

final client = Supabase.instance.client;

// OpenStreetMap tiles — free, no API key, no billing account required.
const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

// Default map center: Bengaluru, India.
const _defaultCenter = LatLng(12.9716, 77.5946);

/// Reverse-geocode lat/lng into a human-readable address via Nominatim.
/// Falls back to raw coordinates when the lookup fails or is rate-limited.
Future<String> _reverseGeocode(double lat, double lng) async {
  try {
    final res = await http.get(
      Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng'),
      // Nominatim REJECTS requests without an identifying User-Agent (403).
      // Browsers send one automatically — Dart's http client doesn't —
      // which is why search + address lookup silently failed on phones
      // (falling back to raw coordinates) while the web app worked.
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'SportSphere/1.0 (sportsphere mobile app)',
      },
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final name = j['display_name'];
      if (name is String && name.isNotEmpty) return name;
    }
  } catch (_) {}
  return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
}

/// Forward-geocode a typed place name to lat/lng via Nominatim (OSM's
/// free geocoding service). Returns null when nothing matches.
Future<List<Map<String, dynamic>>> _searchPlaces(String query) async {
  try {
    final res = await http.get(
      Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&q=${Uri.encodeComponent(query)}'),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'SportSphere/1.0 (sportsphere mobile app)',
      },
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
  } catch (_) {}
  return const [];
}

/// Interactive map page shown as a full-screen route from the venue form.
/// Tap to drop the pin, "Set location" confirms; address is reverse-geocoded.
class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key, this.initialLat, this.initialLng});

  final double? initialLat;
  final double? initialLng;

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? _pos;
  String _label = '';
  bool _busy = false;
  late final MapController _mapController = MapController();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _pos = (widget.initialLat != null && widget.initialLng != null)
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : null;
  }

  Future<void> _pick(LatLng p) async {
    setState(() {
      _pos = p;
      _busy = true;
    });
    final address = await _reverseGeocode(p.latitude, p.longitude);
    if (mounted) {
      setState(() {
        _label = address;
        _busy = false;
      });
    }
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final results = await _searchPlaces(q);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _applyResult(Map<String, dynamic> r) {
    final lat = double.parse(r['lat'] as String);
    final lon = double.parse(r['lon'] as String);
    final p = LatLng(lat, lon);
    _mapController.move(p, 16);
    _results = [];
    _searchCtrl.clear();
    _pick(p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin venue location'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pos ?? _defaultCenter,
              initialZoom: _pos != null ? 16 : 11,
              onTap: (_, p) => _pick(p),
            ),
            children: [
              TileLayer(urlTemplate: _tileUrl, userAgentPackageName: 'com.sportsphere.app'),
              MarkerLayer(
                markers: [
                  if (_pos != null)
                    Marker(
                      point: _pos!,
                      width: 26,
                      height: 26,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF6A13),
                          border: Border.all(color: const Color(0xFF0D0D0D), width: 3),
                          boxShadow: [BoxShadow(color: const Color(0x73FF6A13), blurRadius: 8, spreadRadius: 2)],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Address search bar (top) — jumps the pin to the best match.
          Positioned(
            left: 12, right: 12, top: 12,
            child: Column(children: [
              TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Search address or place',
                  prefixIcon: const Icon(Icons.search, size: 22),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(icon: const Icon(Icons.search, size: 22), onPressed: _search),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (_results.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    children: [
                      for (final r in _results)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, size: 20),
                          title: Text('${r['display_name'] ?? ''}',
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5)),
                          onTap: () => _applyResult(r),
                        ),
                    ],
                  ),
                ),
            ]),
          ),
          Positioned(
            left: 12, right: 12, bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: _busy
                      ? const Row(children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Looking up address...'),
                        ])
                      : Text(
                          _label.isEmpty
                              ? (_pos == null ? 'Tap the map to drop the pin' : '${_pos!.latitude.toStringAsFixed(6)}, ${_pos!.longitude.toStringAsFixed(6)}')
                              : _label,
                          style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                        ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                      onPressed: (_pos == null || _busy)
                          ? null
                          : () => Navigator.pop(context, {
                                'location': _label.isEmpty ? '${_pos!.latitude.toStringAsFixed(6)}, ${_pos!.longitude.toStringAsFixed(6)}' : _label,
                                'lat': _pos!.latitude,
                                'lng': _pos!.longitude,
                              }),
                      child: const Text('Set location'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VenuesAdminPage extends StatefulWidget {
  const VenuesAdminPage({super.key});

  @override
  State<VenuesAdminPage> createState() => _VenuesAdminPageState();
}

class _VenuesAdminPageState extends State<VenuesAdminPage> {
  List<DbRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await client.from('venues').select('*, venue_bookings(count)').order('name');
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
          PageHead('Venues',
              sub: 'Grounds, arenas and facilities.',
              action: FilledButton.icon(
                onPressed: () => _showForm(null),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Venue'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              )),
          if (_loading)
            const Card(child: LoadingState())
          else if (_rows.isEmpty)
            const Card(child: EmptyState('No venues yet.'))
          else
            LayoutBuilder(builder: (context, constraints) {
              const gap = 16.0;
              final cols = constraints.maxWidth >= 640 ? 3 : (constraints.maxWidth >= 420 ? 2 : 1);
              final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final v in _rows)
                    SizedBox(
                      width: w,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text('${v['name'] ?? '-'}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                                ),
                                BadgeChip('${v['status'] ?? '-'}',
                                    color: statusColor('${v['status'] ?? ''}')),
                              ]),
                              const SizedBox(height: 6),
                              // Address in a padded highlight box so it
                              // stands out (web parity).
                              if ('${v['location'] ?? ''}'.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Brand.primary.withValues(alpha: 0.07),
                                    border: Border.all(color: Brand.primary.withValues(alpha: 0.22)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.place_outlined, size: 15, color: Brand.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${v['location']}',
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12.5,
                                              height: 1.35,
                                              color: Theme.of(context).colorScheme.onSurface
                                                  .withValues(alpha: 0.75)),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Text('-', style: TextStyle(fontSize: 12.5, color: subT(context))),
                              const SizedBox(height: 8),
                              Text(
                                'Capacity: ${v['capacity'] ?? '-'} - Bookings: ${((v['venue_bookings'] as List?) ?? const []).isNotEmpty ? (v['venue_bookings'] as List)[0]['count'] : 0}',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              const SizedBox(height: 6),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit_outlined, size: 19),
                                  onPressed: () => _showForm(v),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFC62828)),
                                  onPressed: () => _remove(v),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showForm(DbRow? editing) async {
    final nameCtrl = TextEditingController(text: '${editing?['name'] ?? ''}');
    final locCtrl = TextEditingController(text: '${editing?['location'] ?? ''}');
    final capCtrl = TextEditingController(text: '${editing?['capacity'] ?? ''}');
    String status = editing != null ? '${editing['status']}' : 'Active';
    double? lat = (editing?['lat'] as num?)?.toDouble();
    double? lng = (editing?['lng'] as num?)?.toDouble();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: Text(editing == null ? 'Add Venue' : 'Edit Venue'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location')),
            const SizedBox(height: 12),
            TextField(
              controller: capCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: numberInput,
              decoration: const InputDecoration(labelText: 'Capacity'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final s in ['Active', 'Maintenance', 'Closed']) DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) => setM(() => status = v ?? 'Active'),
            ),
            const SizedBox(height: 12),
            // Map launcher: opens the full-screen OSM picker, comes back
            // with address + coordinates which fill the Location field.
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.map_outlined, size: 20),
              // Coordinates stay in the DB — the visible label is the
              // human-readable address, same as the web app.
              label: Text((lat != null && lng != null) ? 'Change pinned location' : 'Pin on map'),
              onPressed: () async {
                final r = await Navigator.push<Map<String, dynamic>>(
                  ctx,
                  MaterialPageRoute(builder: (_) => MapPickerPage(initialLat: lat, initialLng: lng)),
                );
                if (r != null) {
                  setM(() {
                    lat = r['lat'] as double;
                    lng = r['lng'] as double;
                    locCtrl.text = r['location'] as String;
                  });
                }
              },
            ),
            if (lat != null && lng != null)
              Row(children: [
                Expanded(
                  child: Text(
                    locCtrl.text.trim().isNotEmpty
                        ? locCtrl.text.trim()
                        : '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                TextButton(
                  onPressed: () => setM(() {
                    lat = null;
                    lng = null;
                    locCtrl.clear();
                  }),
                  child: const Text('Clear pin'),
                ),
              ]),
          ]),
          // Cancel and Save are the SAME style pairing and height — the old
          // text-only Cancel read as a footnote next to the filled button.
          actions: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: Text(editing == null ? 'Add' : 'Save'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final payload = {
        'name': nameCtrl.text.trim(),
        'location': locCtrl.text.trim().isEmpty ? null : locCtrl.text.trim(),
        'capacity': capCtrl.text.isEmpty ? null : num.tryParse(capCtrl.text),
        'status': status,
        'lat': lat,
        'lng': lng,
      };
      if (editing != null) {
        await client.from('venues').update(payload).eq('id', editing['id']);
      } else {
        await client.from('venues').insert(payload);
      }
      _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _remove(DbRow v) async {
    if (!await confirmDelete(context, 'venue')) return;
    await client.from('venues').delete().eq('id', v['id']);
    _load();
  }
}
