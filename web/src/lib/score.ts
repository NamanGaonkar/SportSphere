// Sport-aware scoring — one source of truth for how each sport's score is
// captured and displayed. The database composes the canonical score_display
// string (supabase/migrate_sport_integrity.sql); these helpers keep the UIs
// consistent with it. Mirrored in mobile/lib/lib/scoring.dart.

export type SportScoreKind = 'goal' | 'cricket' | 'sets' | 'games' | 'race'

export type ScoreFields = {
  score_a: number | null
  score_b: number | null
  wickets_a: number | null
  wickets_b: number | null
  sets_a: number | null
  sets_b: number | null
}

const EMPTY: ScoreFields = {
  score_a: null, score_b: null, wickets_a: null, wickets_b: null, sets_a: null, sets_b: null,
}

export function isScoreEmpty(s: Partial<ScoreFields> | null | undefined): boolean {
  if (!s) return true
  return (
    s.score_a == null && s.score_b == null &&
    s.wickets_a == null && s.wickets_b == null &&
    s.sets_a == null && s.sets_b == null
  )
}

export function scoreKind(sportName: string | null | undefined): SportScoreKind {
  if (!sportName) return 'goal'
  if (/cricket/i.test(sportName)) return 'cricket'
  if (/volleyball/i.test(sportName)) return 'sets'
  if (/badminton|table\s*tennis/i.test(sportName)) return 'games'
  if (/athletics|track|swimming|cycling|triathlon|marathon|cross\s*country/i.test(sportName)) return 'race'
  return 'goal'
}

export function kindLabel(kind: SportScoreKind): string {
  switch (kind) {
    case 'cricket': return 'runs / wickets'
    case 'sets': return 'sets (points)'
    case 'games': return 'games (points)'
    case 'race': return 'time / position'
    default: return 'goals / points'
  }
}

// Which fields the Edit dialog shows for each sport.
export type ScoreFieldDef = {
  key: keyof ScoreFields
  label: string
  type: 'number' | 'text'
}

export function scoreFieldsFor(kind: SportScoreKind): ScoreFieldDef[] {
  switch (kind) {
    case 'cricket':
      return [
        { key: 'score_a', label: 'Team A runs', type: 'number' },
        { key: 'wickets_a', label: 'Team A wickets', type: 'number' },
        { key: 'score_b', label: 'Team B runs', type: 'number' },
        { key: 'wickets_b', label: 'Team B wickets', type: 'number' },
      ]
    case 'sets':
      return [
        { key: 'sets_a', label: 'Team A sets won', type: 'number' },
        { key: 'sets_b', label: 'Team B sets won', type: 'number' },
        { key: 'score_a', label: 'Team A total points', type: 'number' },
        { key: 'score_b', label: 'Team B total points', type: 'number' },
      ]
    case 'games':
      return [
        { key: 'sets_a', label: 'Team A games won', type: 'number' },
        { key: 'sets_b', label: 'Team B games won', type: 'number' },
        { key: 'score_a', label: 'Team A total points', type: 'number' },
        { key: 'score_b', label: 'Team B total points', type: 'number' },
      ]
    case 'race':
      return [
        { key: 'score_a', label: 'Team A time / position', type: 'text' },
        { key: 'score_b', label: 'Team B time / position', type: 'text' },
      ]
    default:
      return [
        { key: 'score_a', label: 'Team A score', type: 'number' },
        { key: 'score_b', label: 'Team B score', type: 'number' },
      ]
  }
}

// Compact display for tables/cards. Scheduled/empty matches show '-' —
// never a fake 0 : 0. Completed matches should prefer the DB's
// score_display; this is the fallback when that column is unavailable.
export function formatScore(kind: SportScoreKind, s: Partial<ScoreFields> | null | undefined): string {
  if (isScoreEmpty(s)) return '-'
  const v = { ...EMPTY, ...(s ?? {}) }
  switch (kind) {
    case 'cricket':
      return `${v.score_a ?? 0}/${v.wickets_a ?? 0} vs ${v.score_b ?? 0}/${v.wickets_b ?? 0} (runs/wkts)`
    case 'sets':
      return `${v.sets_a ?? 0} : ${v.sets_b ?? 0} (sets)`
    case 'games':
      return `${v.sets_a ?? 0} : ${v.sets_b ?? 0} (games)`
    case 'race':
      return `${v.score_a ?? '-'} vs ${v.score_b ?? '-'}`
    default:
      return `${v.score_a ?? 0} : ${v.score_b ?? 0}`
  }
}
