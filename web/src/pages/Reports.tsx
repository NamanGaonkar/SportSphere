import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { PageHead, Section } from '../components/ui'
import {
  PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer,
  CartesianGrid, Legend,
} from 'recharts'

const COLORS = ['#4f7cff', '#22c55e', '#f59e0b', '#ef4444', '#a78bfa', '#06b6d4']

type SportCount = { sport: string | null; count: number }
type AttRow = { date: string; status: string }
type AwardRow = { id: string; title: string; date: string | null; level: string | null; athletes: { profile: { full_name: string } | null } | null }

export default function Reports() {
  const [sportData, setSportData] = useState<{ name: string; value: number }[]>([])
  const [attData, setAttData] = useState<{ day: string; present: number }[]>([])
  const [awards, setAwards] = useState<AwardRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function load() {
      const [ath, att, aw] = await Promise.all([
        supabase.from('athletes').select('sport'),
        supabase.from('attendance').select('date, status').gte('date', new Date(Date.now() - 30 * 86400000).toISOString().slice(0, 10)),
        supabase.from('awards').select('*, athletes(profile:profiles(full_name))').order('date', { ascending: false }).limit(8),
      ])
      const sports = (ath.data as SportCount[]) ?? []
      const m = new Map<string, number>()
      for (const s of sports) {
        const key = s.sport ?? 'Unassigned'
        m.set(key, (m.get(key) ?? 0) + 1)
      }
      setSportData([...m.entries()].map(([name, value]) => ({ name, value })))

      const rows = (att.data as AttRow[]) ?? []
      const byDay = new Map<string, { present: number; total: number }>()
      for (const r of rows) {
        const e = byDay.get(r.date) ?? { present: 0, total: 0 }
        e.total += 1
        if (r.status === 'Present' || r.status === 'Late') e.present += 1
        byDay.set(r.date, e)
      }
      setAttData(
        [...byDay.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([date, e]) => ({
          day: new Date(date + 'T00:00:00').toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
          present: e.total ? Math.round((e.present / e.total) * 100) : 0,
        })),
      )
      setAwards((aw.data as unknown as AwardRow[]) ?? [])
      setLoading(false)
    }
    load()
  }, [])

  return (
    <div>
      <PageHead title="Reports" sub="Organization analytics — rosters, attendance and achievements." />

      {loading ? (
        <div className="muted">Loading…</div>
      ) : (
        <>
          <div className="grid-2">
            <Section title="Athletes by Sport">
              {sportData.length === 0 ? (
                <div className="empty-state">No athlete data.</div>
              ) : (
                <ResponsiveContainer width="100%" height={280}>
                  <PieChart>
                    <Pie data={sportData} dataKey="value" nameKey="name" innerRadius={60} outerRadius={100} paddingAngle={3}>
                      {sportData.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                    </Pie>
                    <Tooltip contentStyle={{ background: '#1e2740', border: '1px solid #2a3550', borderRadius: 8 }} />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </Section>

            <Section title="Attendance Rate — Last 30 Days (%)">
              {attData.length === 0 ? (
                <div className="empty-state">No attendance data.</div>
              ) : (
                <ResponsiveContainer width="100%" height={280}>
                  <BarChart data={attData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#2a3550" />
                    <XAxis dataKey="day" stroke="#93a0b8" fontSize={11} />
                    <YAxis stroke="#93a0b8" fontSize={11} domain={[0, 100]} />
                    <Tooltip contentStyle={{ background: '#1e2740', border: '1px solid #2a3550', borderRadius: 8 }} />
                    <Bar dataKey="present" fill="#22c55e" radius={[6, 6, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              )}
            </Section>
          </div>

          <Section title="Recent Awards & Achievements">
            {awards.length === 0 ? (
              <div className="empty-state">No awards recorded.</div>
            ) : (
              <table className="data-table">
                <thead>
                  <tr><th>Athlete</th><th>Award</th><th>Level</th><th>Date</th></tr>
                </thead>
                <tbody>
                  {awards.map((a) => (
                    <tr key={a.id}>
                      <td>{a.athletes?.profile?.full_name ?? '—'}</td>
                      <td>{a.title}</td>
                      <td>{a.level ?? '—'}</td>
                      <td className="muted">{a.date ? new Date(a.date + 'T00:00:00').toLocaleDateString() : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </Section>
        </>
      )}
    </div>
  )
}
