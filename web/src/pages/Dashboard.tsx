import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { StatCard, Section, Badge, statusColor, EmptyState, LoadingState } from '../components/ui'
import Box from '@mui/material/Box'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
} from 'recharts'
import { palette } from '../theme'

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

// Dashboard metrics are shared with the mobile app (same stats, same order).
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

  if (loading) return <LoadingState />

  return (
    <Box>
      {/* Stat cards: equal width, equal 16px gaps on every breakpoint */}
      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: 'repeat(2, 1fr)', sm: 'repeat(2, 1fr)', md: 'repeat(4, 1fr)' },
          gap: 2,
          mb: 2,
        }}
      >
        <StatCard label="Athletes" value={counts.athletes} sub="Active roster" />
        <StatCard label="Coaches" value={counts.coaches} sub="Across all sports" />
        <StatCard label="Teams" value={counts.teams} sub="Registered squads" />
        <StatCard label="Tournaments" value={counts.tournaments} sub="All levels" />
      </Box>

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', md: '1fr 1fr' },
          gap: 2,
        }}
      >
        <Section title="Recent Matches">
          {matches.length === 0 ? (
            <EmptyState text="No matches scheduled yet." />
          ) : (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Match</TableCell>
                    <TableCell>Tournament</TableCell>
                    <TableCell>Score</TableCell>
                    <TableCell>Status</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {matches.map((m) => (
                    <TableRow key={m.id}>
                      <TableCell>{m.team_a?.name ?? 'TBD'} vs {m.team_b?.name ?? 'TBD'}</TableCell>
                      <TableCell sx={{ color: 'text.secondary' }}>{m.tournaments?.name ?? '-'}</TableCell>
                      <TableCell>{m.score_a ?? 0} : {m.score_b ?? 0}</TableCell>
                      <TableCell><Badge color={statusColor(m.status)}>{m.status}</Badge></TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </Section>

        <Section title="Attendance - Last 7 Days (%)">
          {attendance.length === 0 ? (
            <EmptyState text="No attendance recorded yet." />
          ) : (
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={attendance}>
                <CartesianGrid strokeDasharray="3 3" stroke={palette.border} />
                <XAxis dataKey="day" stroke={palette.textMuted} fontSize={12} tickLine={false} />
                <YAxis stroke={palette.textMuted} fontSize={12} domain={[0, 100]} tickLine={false} />
                <Tooltip
                  contentStyle={{
                    background: palette.surface,
                    border: `1px solid ${palette.border}`,
                    borderRadius: 10,
                    fontFamily: 'Lato, sans-serif',
                  }}
                  labelStyle={{ color: palette.black, fontWeight: 700 }}
                />
                <Bar dataKey="present" fill={palette.primary} radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </Section>
      </Box>
    </Box>
  )
}
