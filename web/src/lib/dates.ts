/**
 * Shared date-window algorithm for dashboard/report charts.
 * ONE source of truth for both web and mobile so the graphs always show the
 * same days, in the same order, with the same labels.
 *
 * The window is ALWAYS the last N calendar days ending TODAY (rolling).
 * Every day gets a bucket even if there is no attendance data (0%), so the
 * x-axis never shifts shape when data is sparse.
 */

export type DayPoint = { key: string; label: string; present: number; total: number; pct: number; marked?: boolean }

/** yyyy-mm-dd in LOCAL time (what `date` columns contain). */
export function localDateKey(d: Date): string {
  const y = d.getFullYear()
  const m = `${d.getMonth() + 1}`.padStart(2, '0')
  const day = `${d.getDate()}`.padStart(2, '0')
  return `${y}-${m}-${day}`
}

/** "16 Sep" style short label — same format on web and mobile. */
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
export function shortDayLabel(key: string): string {
  const [, m, d] = key.split('-')
  return `${Number(d)} ${MONTHS[Number(m) - 1]}`
}

/**
 * Build the rolling N-day window and fold attendance rows into it.
 * rows: { date: 'yyyy-mm-dd', status: string } (extra fields fine).
 * roster: total people expected to attend (profiles in attendance roles).
 * When provided, pct = present / roster — so marking one person can never
 * read as 100%; the rate only fills up as more of the roster is marked.
 */
export function attendanceWindow(
  rows: { date: string; status: string }[],
  days: 7 | 30,
  roster?: number,
): DayPoint[] {
  const today = new Date()
  const buckets = new Map<string, { present: number; total: number }>()
  const keys: string[] = []
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() - i)
    const k = localDateKey(d)
    keys.push(k)
    buckets.set(k, { present: 0, total: 0 })
  }
  for (const r of rows) {
    const k = (r.date ?? '').slice(0, 10)
    const b = buckets.get(k)
    if (!b) continue
    b.total += 1
    if (r.status === 'Present' || r.status === 'Late') b.present += 1
  }
  return keys.map((k) => {
    const b = buckets.get(k)!
    // With a roster denominator the rate is honest: 1 Present out of 16
    // people reads as ~6%, not 100%. Days with no marks at all are still
    // flagged unmarked so charts can render them as gaps.
    const denom = roster && roster > 0 ? roster : b.total
    const pct = denom === 0 ? 0 : Math.round((b.present / denom) * 100)
    return {
      key: k,
      label: shortDayLabel(k),
      present: b.present,
      total: b.total,
      pct,
      marked: b.total > 0,
    }
  })
}
