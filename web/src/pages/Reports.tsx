import { useEffect, useState, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import { useSports, useRealtimeTable } from '../lib/hooks'
import { PageHead, Section, EmptyState, LoadingState } from '../components/ui'
import Box from '@mui/material/Box'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import {
  PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer,
  CartesianGrid, Legend,
} from 'recharts'
import { palette } from '../theme'

const CHART_COLORS = [palette.primary, palette.success, palette.warning, palette.error, palette.info, palette.textMuted]

type SportCount = { sports: { name: string } | null }
type AttRow = { date: string; status: string }
type AwardRow = { id: string; title: string; date: string | null; level: string | null; athletes: { profile: { full_name: string } | null } | null }

export default function Reports() {
  const [sportData, setSportData] = useState<{ name: string; value: number }[]>([])
  const [teamsSportData, setTeamsSportData] = useState<{ name: string; value: number }[]>([])
  const [attData, setAttData] = useState<{ day: string; present: number }[]>([])
  const [awards, setAwards] = useState<AwardRow[]>([])
  const [loading, setLoading] = useState(true)
  const { byId } = useSports()

  const load = useCallback(async () => {
    setLoading(true)
    const [ajs, tms, att, aw] = await Promise.all([
      supabase.from('athlete_sports').select('sports(name)'),
      supabase.from('teams').select('sport_id'),
      supabase.from('attendance').select('date, status').gte('date', new Date(Date.now() - 30 * 86400000).toISOString().slice(0, 10)),
      supabase.from('awards').select('*, athletes(profile:profiles(full_name))').order('date', { ascending: false }).limit(8),
    ])
    // Athletes by sport: one entry per athlete-sport tag (multi-sport aware).
    const m = new Map<string, number>()
    for (const s of ((ajs.data ?? []) as unknown as SportCount[])) {
      const key = s.sports?.name ?? 'Unassigned'
      m.set(key, (m.get(key) ?? 0) + 1)
    }
    setSportData([...m.entries()].map(([name, value]) => ({ name, value })))

    const tm = new Map<string, number>()
    for (const t of (tms.data as { sport_id: string | null }[]) ?? []) {
      const key = byId(t.sport_id) || 'No sport'
      tm.set(key, (tm.get(key) ?? 0) + 1)
    }
    setTeamsSportData([...tm.entries()].map(([name, value]) => ({ name, value })))

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
  }, [])

  useEffect(() => { load() }, [load])
  useRealtimeTable('athlete_sports', load)
  useRealtimeTable('teams', load)
  useRealtimeTable('attendance', load)
  useRealtimeTable('awards', load)

  const tooltipStyle = {
    background: palette.surface,
    border: `1px solid ${palette.border}`,
    borderRadius: 10,
    fontFamily: 'Lato, sans-serif',
  }

  if (loading) return <LoadingState />

  return (
    <Box>
      <PageHead title="Reports" sub="Organization analytics - rosters, attendance and achievements." />

      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: '1fr 1fr' }, gap: 2 }}>
        <Section title="Athletes by Sport">
          {sportData.length === 0 ? (
            <EmptyState text="No athlete data yet." />
          ) : (
            <ResponsiveContainer width="100%" height={280}>
              <PieChart>
                <Pie data={sportData} dataKey="value" nameKey="name" innerRadius={60} outerRadius={100} paddingAngle={3}>
                  {sportData.map((_, i) => <Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />)}
                </Pie>
                <Tooltip contentStyle={tooltipStyle} />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          )}
        </Section>

        <Section title="Teams by Sport">
          {teamsSportData.length === 0 ? (
            <EmptyState text="No team data yet." />
          ) : (
            <ResponsiveContainer width="100%" height={280}>
              <PieChart>
                <Pie data={teamsSportData} dataKey="value" nameKey="name" innerRadius={60} outerRadius={100} paddingAngle={3}>
                  {teamsSportData.map((_, i) => <Cell key={i} fill={CHART_COLORS[(i + 2) % CHART_COLORS.length]} />)}
                </Pie>
                <Tooltip contentStyle={tooltipStyle} />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          )}
        </Section>

        <Section title="Attendance Rate - Last 30 Days (%)">
          {attData.length === 0 ? (
            <EmptyState text="No attendance data yet." />
          ) : (
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={attData}>
                <CartesianGrid strokeDasharray="3 3" stroke={palette.border} />
                <XAxis dataKey="day" stroke={palette.textMuted} fontSize={11} tickLine={false} />
                <YAxis stroke={palette.textMuted} fontSize={11} domain={[0, 100]} tickLine={false} />
                <Tooltip contentStyle={tooltipStyle} labelStyle={{ color: palette.black, fontWeight: 700 }} />
                <Bar dataKey="present" fill={palette.primary} radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </Section>
      </Box>

      {/* Full width below the charts: an odd number of items in the grid above
          would leave an empty hole next to the awards table otherwise. */}
      <Section title="Recent Awards & Achievements">
        {awards.length === 0 ? (
          <EmptyState text="No awards recorded yet." />
        ) : (
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Athlete</TableCell>
                <TableCell>Award</TableCell>
                <TableCell>Level</TableCell>
                <TableCell>Date</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {awards.map((a) => (
                <TableRow key={a.id} hover>
                  <TableCell>{a.athletes?.profile?.full_name ?? '-'}</TableCell>
                  <TableCell>{a.title}</TableCell>
                  <TableCell>{a.level ?? '-'}</TableCell>
                  <TableCell sx={{ color: 'text.secondary' }}>
                    {a.date ? new Date(a.date + 'T00:00:00').toLocaleDateString() : '-'}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </Section>
    </Box>
  )
}
