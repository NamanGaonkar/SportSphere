import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { StatCard, Section, Badge, statusColor, EmptyState } from '../components/ui'
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
} from 'recharts'

type Counts = { athletes: number; coaches: number; teams: number; tournaments: number }
type MatchRow = {
  id: string
  status: string
  score_a: number | null
  score_b: number | null
  scheduled_at: string | null
  team_a: { name: string } | null
  team_b: { name: string } | null
  tournaments: { name: string } | null
}

export default function Dashboard() {
  const [counts, setCounts] = useState<Counts>({ athletes: 0, coaches: 0, teams: 0, tournaments: 0 })
  const [matches, setMatches] = useState<MatchRow[]>([])
  const [attendance, setAttendance] = useState<{ day: string; present: number }[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function load() {
      const [ath, coa, tea, tou, mat, att] = await Promise.all([
        supabase.from('athletes').select('id', { count: 'exact', head: true }),
        supabase.from('coaches').select('id', { count: 'exact', head: true }),
        supabase.from('teams').select('id', { count: 'exact', head: true }),
        supabase.from('tournaments').select('id', { count: 'exact', head: true }),
        supabase
          .from('matches')
          .select('*, team_a:teams!matches_team_a_id_fkey(name), team_b:teams!matches_team_b_id_fkey(name), tournaments(name)')
          .order('scheduled_at', { ascending: false })
          .limit(6),
        supabase.from('attendance').select('date, status').gte('date', new Date(Date.now() - 7 * 86400000).toISOString().slice(0, 10)),
      ])

      setCounts({
        athletes: ath.count ?? 0,
        coaches: coa.count ?? 0,
        teams: tea.count ?? 0,
        tournaments: tou.count ?? 0,
      })
      setMatches((mat.data as MatchRow[]) ?? [])
      const attRows = (att.data ?? []) as { date: string; status: string }[]
      const byDay = new Map<string, { present: number; total: number }>()
      for (const r of attRows) {
        const e = byDay.get(r.date) ?? { present: 0, total: 0 }
        e.total += 1
        if (r.status === 'Present' || r.status === 'Late') e.present += 1
        byDay.set(r.date, e)
      }
      setAttendance(
        [...byDay.entries()]
          .sort((a, b) => a[0].localeCompare(b[0]))
          .map(([date, e]) => ({
            day: new Date(date + 'T00:00:00').toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
            present: e.total ? Math.round((e.present / e.total) * 100) : 0,
          })),
      )
      setLoading(false)
    }
    load()
  }, [])

  const fmt = (iso: string | null) =>
    iso ? new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }) : '—'

  return (
    <div>
      <div className="page-head">
        <div>
          <h1>Dashboard</h1>
          <p>Organization overview — people, competitions and operations at a glance.</p>
        </div>
      </div>

      {loading ? (
        <div className="muted">Loading…</div>
      ) : (
        <>
          <div className="cards">
            <StatCard label="Athletes" value={counts.athletes} sub="Active roster" />
            <StatCard label="Coaches" value={counts.coaches} sub="Across all sports" />
            <StatCard label="Teams" value={counts.teams} sub="Registered squads" />
            <StatCard label="Tournaments" value={counts.tournaments} sub="All levels" />
          </div>

          <div className="grid-2">
            <Section title="Live & Recent Matches">
              {matches.length === 0 ? (
                <EmptyState text="No matches yet." />
              ) : (
                <table className="data-table">
                  <thead>
                    <tr><th>Match</th><th>Tournament</th><th>Score</th><th>Status</th></tr>
                  </thead>
                  <tbody>
                    {matches.map((m) => (
                      <tr key={m.id}>
                        <td>{m.team_a?.name ?? 'TBD'} vs {m.team_b?.name ?? 'TBD'}</td>
                        <td className="muted">{m.tournaments?.name ?? '—'}</td>
                        <td>{m.score_a ?? 0} – {m.score_b ?? 0}</td>
                        <td><Badge color={statusColor(m.status)}>{m.status}</Badge></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </Section>

            <Section title="Attendance — Last 7 Days (%)">
              {attendance.length === 0 ? (
                <EmptyState text="No attendance recorded yet." />
              ) : (
                <ResponsiveContainer width="100%" height={240}>
                  <BarChart data={attendance}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#2a3550" />
                    <XAxis dataKey="day" stroke="#93a0b8" fontSize={12} />
                    <YAxis stroke="#93a0b8" fontSize={12} domain={[0, 100]} />
                    <Tooltip
                      contentStyle={{ background: '#1e2740', border: '1px solid #2a3550', borderRadius: 8 }}
                      labelStyle={{ color: '#e8ecf4' }}
                    />
                    <Bar dataKey="present" fill="#4f7cff" radius={[6, 6, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </Section>
          </div>
        </>
      )}
    </div>
    )
}
