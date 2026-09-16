import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live cache of the sports list — one shared realtime channel, mirroring
/// web/src/lib/hooks.ts. The list is NEVER hardcoded: both apps read the
/// same `sports` table and update live when an admin edits it on the web.
class SportsCache extends ChangeNotifier {
  static final SportsCache instance = SportsCache._();
  SportsCache._() {
    _load();
    Supabase.instance.client
        .channel('public:sports')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sports',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  List<Map<String, dynamic>> rows = [];
  final Map<String, String> _names = {};

  /// Force-start the fetch immediately (cold-start pre-warm). The lazy
  /// singleton otherwise loads too late: the dashboard would compute
  /// "Teams by Sport" before any sport names exist and show "No sport".
  static void warm() => instance;

  /// Awaited by pages that need valid names on first paint.
  Future<void> get ready async {
    final f = _loading;
    if (f != null) await f;
  }
  Future<void>? _loading;

  Future<void> _load() async {
    final f = _doLoad();
    _loading = f;
    await f;
  }

  Future<void> _doLoad() async {
    try {
      final data = await Supabase.instance.client
          .from('sports')
          .select('id, name, icon')
          .order('name');
      rows = (data as List).cast<Map<String, dynamic>>();
      _names
        ..clear()
        ..addEntries(rows.map((r) => MapEntry(r['id'] as String, r['name'] as String)));
      notifyListeners();
    } catch (_) {
      // offline — keep last known list
    }
  }

  String name(String? id) => id == null ? '' : (_names[id] ?? '');
}

/// Subscribe to INSERT/UPDATE/DELETE on [table] so the UI reloads when the
/// web app (or the phone itself) changes data. Returns the channel; the
/// caller should remove it in dispose().
RealtimeChannel listen(String table, void Function() reload) {
  return Supabase.instance.client
      .channel('public:$table-${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => reload(),
      )
      .subscribe();
}
