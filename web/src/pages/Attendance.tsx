import { useEffect, useState, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import { PageHead, Badge, statusColor, EmptyState } from '../components/ui'

type AthleteRow = {
  id: string
  profile_id: string
  profile: {
    full_name: string
    attendance: { id: string; date: string; status: string; leave_reason: string | null }[]
  } | null
}

const STATUSES = ['Present', 'Absent', 'Late', 'Leave'] as const

export default function Attendance() {
  const [rows, setRows] = useState<AthleteRow[]>([])
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10))
  const [saving, setSaving] = useState(false)
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    const { data } = await supabase
      .from('athletes')
      .select('id, profile_id, profile:profiles(full_name, attendance(id, date, status, leave_reason))')
      .order('created_at')
    setRows((data as unknown as AthleteRow[]) ?? [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const statusFor = (r: AthleteRow) => {
    const rec = (r.profile?.attendance ?? []).find((a) => a.date === date)
    return rec?.status ?? null
  }

  const summary = useMemo(() => {
    let present = 0, total = 0
    for (const r of rows) {
      const s = statusFor(r)
      if (s) { total += 1; if (s === 'Present' || s === 'Late') present += 1 }
    }
    return { present, total, pct: total ? Math.round((present / total) * 100) : 0 }
  }, [rows, date])

  async function mark(r: AthleteRow, status: string) {
    setSaving(true)
    const existing = (r.profile?.attendance ?? []).find((a) => a.date === date)
    if (existing) {
      await supabase.from('attendance').update({ status }).eq('id', existing.id)
    } else {
      await supabase.from('attendance').insert({ profile_id: r.profile_id, date, status })
    }
    await load()
    setSaving(false)
  }

  return (
    <div>
      <PageHead
        title="Attendance & Leave"
        sub="Mark daily attendance for athletes; coaches and admins only."
        action={
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        }
      />

      <div className="cards">
        <div className="card stat-card">
          <div className="stat-label">Marked</div>
          <div className="stat-value">{summary.total}</div>
          <div className="stat-sub">of {rows.length} athletes</div>
        </div>
        <div className="card stat-card">
          <div className="stat-label">Present + Late</div>
          <div className="stat-value">{summary.present}</div>
          <div className="stat-sub">{summary.pct}% attendance</div>
        </div>
      </div>

      <div className="card">
        {loading ? (
          <div className="muted">Loading…</div>
        ) : rows.length === 0 ? (
          <EmptyState text="No athletes to mark." />
        ) : (
          <table className="data-table">
            <thead>
              <tr><th>Athlete</th><th>Status</th><th>Mark</th></tr>
            </thead>
            <tbody>
              {rows.map((r) => {
                const s = statusFor(r)
                return (
                  <tr key={r.id}>
                    <td>{r.profile?.full_name ?? '—'}</td>
                    <td>{s ? <Badge color={statusColor(s)}>{s}</Badge> : <span className="muted">not marked</span>}</td>
                    <td>
                      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                        {STATUSES.map((st) => (
                          <button
                            key={st}
                            disabled={saving}
                            className={`btn small ${s === st ? '' : 'secondary'}`}
                            onClick={() => mark(r, st)}
                          >
                            {st}
                          </button>
                        ))}
                      </div>
                      <div style={{ width: '100%' }} />
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
