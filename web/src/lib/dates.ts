/**
 * Shared date-window algorithm for dashboard/report charts.
 * ONE source of truth for both web and mobile so the graphs always show the
 * same days, in the same order, with the same labels.
 *
 * The window is ALWAYS the last N calendar days ending TODAY (rolling).
 * Every day gets a bucket even if there is no attendance data (0%), so the
 * x-axis never shifts shape when data is sparse.
 */

export type DayPoint = { key: string; label: string; present: number; total: number; pct: number }

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
 */
export function attendanceWindow(
  rows: { date: string; status: string }[],
  days: 7 | 30,
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
    return {
      key: k,
      label: shortDayLabel(k),
      present: b.present,
      total: b.total,
      pct: b.total === 0 ? 0 : Math.round((b.present / b.total) * 100),
    }
  })
}
