// Sport-aware scoring — mirror of web/src/lib/score.ts. The database
// composes the canonical score_display string; this keeps the app's
// capture fields and fallback rendering consistent with web.

class ScoreFields {
  final int? scoreA, scoreB, wicketsA, wicketsB, setsA, setsB;
  ScoreFields({this.scoreA, this.scoreB, this.wicketsA, this.wicketsB, this.setsA, this.setsB});

  Map<String, dynamic> toUpdate() => {
        'score_a': scoreA,
        'score_b': scoreB,
        'wickets_a': wicketsA,
        'wickets_b': wicketsB,
        'sets_a': setsA,
        'sets_b': setsB,
      };
}

class ScoreFieldDef {
  final String key;
  final String label;
  final bool numeric;
  const ScoreFieldDef(this.key, this.label, {this.numeric = true});
}

enum ScoreKind { goal, cricket, sets, games, race }

ScoreKind scoreKind(String? sportName) {
  final n = (sportName ?? '').toLowerCase();
  if (n.contains('cricket')) return ScoreKind.cricket;
  if (n.contains('volleyball')) return ScoreKind.sets;
  if (n.contains('badminton') || n.contains('table tennis')) return ScoreKind.games;
  if (n.contains('athletics') ||
      n.contains('track') ||
      n.contains('swimming') ||
      n.contains('cycling') ||
      n.contains('triathlon') ||
      n.contains('marathon') ||
      n.contains('cross country')) {
    return ScoreKind.race;
  }
  return ScoreKind.goal;
}

String kindLabel(ScoreKind k) {
  switch (k) {
    case ScoreKind.cricket:
      return 'runs / wickets';
    case ScoreKind.sets:
      return 'sets (points)';
    case ScoreKind.games:
      return 'games (points)';
    case ScoreKind.race:
      return 'time / position';
    case ScoreKind.goal:
      return 'goals / points';
  }
}

List<ScoreFieldDef> scoreFieldsFor(ScoreKind k) {
  switch (k) {
    case ScoreKind.cricket:
      return const [
        ScoreFieldDef('score_a', 'Team A runs'),
        ScoreFieldDef('wickets_a', 'Team A wickets'),
        ScoreFieldDef('score_b', 'Team B runs'),
        ScoreFieldDef('wickets_b', 'Team B wickets'),
      ];
    case ScoreKind.sets:
      return const [
        ScoreFieldDef('sets_a', 'Team A sets won'),
        ScoreFieldDef('sets_b', 'Team B sets won'),
        ScoreFieldDef('score_a', 'Team A total points'),
        ScoreFieldDef('score_b', 'Team B total points'),
      ];
    case ScoreKind.games:
      return const [
        ScoreFieldDef('sets_a', 'Team A games won'),
        ScoreFieldDef('sets_b', 'Team B games won'),
        ScoreFieldDef('score_a', 'Team A total points'),
        ScoreFieldDef('score_b', 'Team B total points'),
      ];
    case ScoreKind.race:
      return const [
        ScoreFieldDef('score_a', 'Team A time / position', numeric: false),
        ScoreFieldDef('score_b', 'Team B time / position', numeric: false),
      ];
    case ScoreKind.goal:
      return const [
        ScoreFieldDef('score_a', 'Team A score'),
        ScoreFieldDef('score_b', 'Team B score'),
      ];
  }
}

bool scoreIsEmpty(Map m) =>
    m['score_a'] == null &&
    m['score_b'] == null &&
    m['wickets_a'] == null &&
    m['wickets_b'] == null &&
    m['sets_a'] == null &&
    m['sets_b'] == null;

/// Fallback rendering when score_display is unavailable. Scheduled/empty
/// matches show '-' — never a fake 0 : 0.
String formatScore(ScoreKind k, Map m, {bool scheduled = false}) {
  if (scheduled || scoreIsEmpty(m)) return '-';
  switch (k) {
    case ScoreKind.cricket:
      return '${m['score_a'] ?? 0}/${m['wickets_a'] ?? 0} vs ${m['score_b'] ?? 0}/${m['wickets_b'] ?? 0} (runs/wkts)';
    case ScoreKind.sets:
      return '${m['sets_a'] ?? 0} : ${m['sets_b'] ?? 0} (sets)';
    case ScoreKind.games:
      return '${m['sets_a'] ?? 0} : ${m['sets_b'] ?? 0} (games)';
    case ScoreKind.race:
      return '${m['score_a'] ?? '-'} vs ${m['score_b'] ?? '-'}';
    case ScoreKind.goal:
      return '${m['score_a'] ?? 0} : ${m['score_b'] ?? 0}';
  }
}
