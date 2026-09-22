import { useEffect, useState, useMemo, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useSports, useRealtimeTable } from '../lib/hooks'
import { attendanceWindow } from '../lib/dates'
import { StatCard, Section, Badge, statusColor, EmptyState, LoadingState } from '../components/ui'
import Box from '@mui/material/Box'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import Tooltip from '@mui/material/Tooltip'
import Typography from '@mui/material/Typography'
import LinearProgress from '@mui/material/LinearProgress'
import {
  BarChart, Bar, XAxis, YAxis, Tooltip as RTooltip, ResponsiveContainer, CartesianGrid,
} from 'recharts'
import { palette } from '../theme'

type Counts = { athletes: number; coaches: number; teams: number; tournaments: number }
type MatchRow = {
  id: string
  status: string
  score_a: number | null
  score_b: number | null
  score_display: string | null
  scheduled_at: string | null
  team_a: { name: string } | null
  team_b: { name: string } | null
  tournaments: { name: string } | null
}
type PayrollRow = {
  id: string
  month: string
  net: number | null
  staff: { profile: { full_name: string } | null } | null
  coach: { profile: { full_name: string } | null } | null
}
type AwardRow = {
  id: string
  title: string
  date: string | null
  level: string | null
  athletes: { profile: { full_name: string } | null } | null
}
type EquipRow = { id: string; name: string; quantity: number | null; min_stock: number | null; condition: string | null }
type MedRow = { id: string; athlete_id: string; type: string; cleared: boolean; date: string; athletes: { profile: { full_name: string } | null } | null }

// Dashboard metrics are shared with the mobile app (same stats, same order,
// same sections — parity is intentional and enforced on both sides).
export default function Dashboard() {
  const navigate = useNavigate()
  const [counts, setCounts] = useState<Counts>({ athletes: 0, coaches: 0, teams: 0, tournaments: 0 })
  const [matches, setMatches] = useState<MatchRow[]>([])
  const [attendance, setAttendance] = useState<{ day: string; present: number | null }[]>([])
  const [teamSports, setTeamSports] = useState<{ id: string; sport_id: string | null }[]>([])
  const [payroll, setPayroll] = useState<PayrollRow[]>([])
  const [awards, setAwards] = useState<AwardRow[]>([])
  const [equip, setEquip] = useState<EquipRow[]>([])
  const [med, setMed] = useState<MedRow[]>([])
  const [lowStockCount, setLowStockCount] = useState(0)
  const [pendingPO, setPendingPO] = useState(0)
  const [notCleared, setNotCleared] = useState(0)
  const [loading, setLoading] = useState(true)
  const { byId } = useSports()

  const load = useCallback(async () => {
    {
      const [ath, coa, tea, tou, mat, att, roster, tsp, pay, aw, eq, po, medq] = await Promise.all([
        supabase.from('athletes').select('id', { count: 'exact', head: true }),
        supabase.from('coaches').select('id', { count: 'exact', head: true }),
        supabase.from('teams').select('id', { count: 'exact', head: true }),
        supabase.from('tournaments').select('id', { count: 'exact', head: true }),
        supabase
          .from('matches')
          .select('*, score_display, team_a:teams!matches_team_a_id_fkey(name), team_b:teams!matches_team_b_id_fkey(name), tournaments(name)')
          .order('scheduled_at', { ascending: false }),
        supabase.from('attendance').select('date, status').gte('date', new Date(Date.now() - 7 * 86400000).toISOString().slice(0, 10)),
        // Roster = everyone attendance applies to (athletes + coaches + staff roles).
        supabase.from('profiles').select('id', { count: 'exact', head: true }).in('role', ['Athlete', 'Coach', 'HR', 'Finance', 'VenueManager']),
        supabase.from('teams').select('id, sport_id'),
        supabase.from('payroll').select('id, month, net, staff_id, coach_id, staff:staff_id(profile:profiles(full_name)), coach:coach_id(profile:profiles(full_name))').order('month', { ascending: false }).limit(6),
        supabase.from('awards').select('id, title, date, level, athletes(profile:profiles(full_name))').order('date', { ascending: false }).limit(6),
        supabase.from('inventory_items').select('id, name, quantity, min_stock, condition'),
        supabase.from('purchase_orders').select('id, status'),
        supabase.from('medical_records').select('id, athlete_id, type, cleared, date, athletes(profile:profiles(full_name))').order('date', { ascending: false }).limit(8),
      ])

      setCounts({
        athletes: ath.count ?? 0,
        coaches: coa.count ?? 0,
        teams: tea.count ?? 0,
        tournaments: tou.count ?? 0,
      })
      setMatches((mat.data as MatchRow[]) ?? [])
      setTeamSports((tsp.data as { id: string; sport_id: string | null }[]) ?? [])
      setPayroll((pay.data as unknown as PayrollRow[]) ?? [])
      setAwards((aw.data as unknown as AwardRow[]) ?? [])
      const eqRows = (eq.data as EquipRow[]) ?? []
      setEquip(eqRows)
      setLowStockCount(eqRows.filter((r) => (r.quantity ?? 0) <= (r.min_stock ?? 0)).length)
      setPendingPO(((po.data as { status: string }[]) ?? []).filter((r) => r.status === 'Ordered').length)
      const medRows = (medq.data as unknown as MedRow[]) ?? []
      setMed(medRows)
      // "not cleared" = any record not cleared; approximated by unique athletes here
      setNotCleared(new Set(medRows.filter((r) => !r.cleared).map((r) => r.athlete_id)).size)
      const attRows = (att.data ?? []) as { date: string; status: string }[]
      setAttendance(
        // Rate is computed against the full roster: 1 Present out of 16
        // people reads as ~6%, not 100%. Unmarked days render as gaps.
        attendanceWindow(attRows, 7, roster.count ?? 0).map((p) => ({ day: p.label, present: p.marked === false ? (null as unknown as number) : p.pct })),
      )
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  // Live sync with the mobile app: any change to these tables re-runs load().
  useRealtimeTable('teams', load)
  useRealtimeTable('tournaments', load)
  useRealtimeTable('matches', load)
  useRealtimeTable('attendance', load)
  useRealtimeTable('inventory_items', load)
  useRealtimeTable('purchase_orders', load)
  useRealtimeTable('medical_records', load)
  useRealtimeTable('payroll', load)
  useRealtimeTable('awards', load)

  const teamsBySport = useMemo(() => {
    const m = new Map<string, number>()
    for (const t of teamSports) {
      const key = byId(t.sport_id) || 'No sport'
      m.set(key, (m.get(key) ?? 0) + 1)
    }
    return [...m.entries()].map(([name, teams]) => ({ name, teams })).sort((a, b) => b.teams - a.teams)
  }, [teamSports, byId])

  if (loading) return <LoadingState />

  const inr = (n: number | null | undefined) => `Rs ${Number(n ?? 0).toLocaleString('en-IN')}`

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
        {/* Stat cards double as quick links into their modules. */}
        <StatCard label="Athletes" value={counts.athletes} sub="Active roster" variant={0} onClick={() => navigate('/athletes')} />
        <StatCard label="Coaches" value={counts.coaches} sub="Across all sports" variant={1} onClick={() => navigate('/coaches')} />
        <StatCard label="Teams" value={counts.teams} sub="Registered squads" variant={2} onClick={() => navigate('/teams')} />
        <StatCard label="Tournaments" value={counts.tournaments} sub="All levels" variant={3} onClick={() => navigate('/tournaments')} />
      </Box>

      {/* Ops strip: inventory / procurement / medical at a glance */}
      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', sm: 'repeat(3, 1fr)' },
          gap: 2,
          mb: 2,
        }}
      >
        <StatCard
          label="Equipment alerts"
          value={lowStockCount}
          sub={lowStockCount > 0 ? 'Items at or below min stock' : 'All stock levels healthy'}
          variant={4}
          onClick={() => navigate('/inventory')}
        />
        <StatCard label="POs awaiting delivery" value={pendingPO} sub="Marked Ordered" variant={5} onClick={() => navigate('/purchases')} />
        <StatCard label="Athletes not cleared" value={notCleared} sub="From latest medical records" variant={1} onClick={() => navigate('/medical')} />
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
                      <TableCell>
                        {(m.score_a == null && m.score_b == null) || m.status === 'Scheduled'
                          ? <Typography sx={{ color: 'text.disabled' }}>-</Typography>
                          : <Box component="span" sx={{ fontWeight: 600, whiteSpace: 'nowrap' }}>{m.score_display || `${m.score_a ?? 0} : ${m.score_b ?? 0}`}</Box>}
                      </TableCell>
                      <TableCell><Badge color={statusColor(m.status)}>{m.status}</Badge></TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </Section>

        <Section title="Teams by Sport">
          {teamsBySport.length === 0 ? (
            <EmptyState text="No teams yet." />
          ) : (
            /* Hand-rolled bar list: label + track + value in one flex row.
               The label and the bar live in the SAME element, so axis naming
               and hover can never drift out of alignment (Recharts' vertical
               band axis kept misaligning ticks vs cursor). */
            <Box sx={{ display: 'flex', flexDirection: 'column' }}>
              {teamsBySport.map((s) => {
                const max = Math.max(...teamsBySport.map((x) => x.teams), 1)
                const pct = Math.max((s.teams / max) * 100, 6) // min 6% so a lone team is still visible
                return (
                  <Tooltip
                    key={s.name}
                    title={`${s.teams} team${s.teams === 1 ? '' : 's'} - ${s.name}`}
                    arrow
                    placement="top"
                  >
                    <Box
                      sx={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 1.5,
                        py: 1,
                        px: 1,
                        borderRadius: 1.5,
                        transition: 'background-color .15s',
                        '&:hover': { bgcolor: 'rgba(255,106,19,0.08)' },
                      }}
                    >
                      {/* Sport name — full text, one line, own fixed column */}
                      <Typography
                        sx={{
                          width: 190,
                          flexShrink: 0,
                          fontSize: 12.5,
                          fontWeight: 600,
                          color: palette.black,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {s.name}
                      </Typography>
                      {/* Bar track — fills the rest of the card width */}
                      <Box sx={{ flex: 1, height: 22, borderRadius: 1, bgcolor: 'rgba(13,13,13,0.05)', overflow: 'hidden' }}>
                        <Box
                          sx={{
                            width: `${pct}%`,
                            height: '100%',
                            borderRadius: 1,
                            background: 'linear-gradient(90deg, #FF6A13, #FF8A42)',
                          }}
                        />
                      </Box>
                      {/* Count, pinned right so values line up in a column */}
                      <Typography sx={{ width: 34, textAlign: 'right', fontSize: 13, fontWeight: 700, color: palette.black }}>
                        {s.teams}
                      </Typography>
                    </Box>
                  </Tooltip>
                )
              })}
            </Box>
          )}
        </Section>

        <Section title="Attendance - Last 7 Days (%)">
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={attendance} margin={{ left: -14, right: 8, top: 8, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke={palette.border} vertical={false} />
              <XAxis
                dataKey="day"
                stroke={palette.textMuted}
                fontSize={10.5}
                tickLine={false}
                interval={0}
                angle={-35}
                textAnchor="end"
                height={52}
                tickMargin={6}
              />
              <YAxis
                stroke={palette.textMuted}
                fontSize={11}
                domain={[0, 100]}
                ticks={[0, 25, 50, 75, 100]}
                tickLine={false}
                tickFormatter={(v: number) => `${v}%`}
              />
              <RTooltip
                contentStyle={{
                  background: palette.surface,
                  border: `1px solid ${palette.border}`,
                  borderRadius: 10,
                  fontFamily: 'Lato, sans-serif',
                }}
                labelStyle={{ color: palette.black, fontWeight: 700 }}
                formatter={(v) => [`${v}%`, 'Attendance']}
              />
              <Bar dataKey="present" fill={palette.primary} radius={[6, 6, 0, 0]} barSize={18} maxBarSize={22} />
            </BarChart>
          </ResponsiveContainer>
        </Section>

        <Section title="Latest Payroll">
          {payroll.length === 0 ? (
            <EmptyState text="No payroll recorded yet." />
          ) : (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Staff</TableCell>
                    <TableCell>Month</TableCell>
                    <TableCell align="right">Net Pay</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {payroll.map((p) => (
                    <TableRow key={p.id}>
                      <TableCell>{p.staff?.profile?.full_name ?? p.coach?.profile?.full_name ?? '-'}</TableCell>
                      <TableCell sx={{ color: 'text.secondary' }}>{p.month?.slice(0, 7)}</TableCell>
                      <TableCell align="right" sx={{ fontWeight: 700 }}>{inr(p.net)}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </Section>

        <Section title="Recent Awards & Achievements">
          {awards.length === 0 ? (
            <EmptyState text="No awards recorded yet." />
          ) : (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Athlete</TableCell>
                    <TableCell>Award</TableCell>
                    <TableCell>Level</TableCell>
                    <TableCell align="right">Date</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {awards.map((a) => (
                    <TableRow key={a.id}>
                      <TableCell>{a.athletes?.profile?.full_name ?? '-'}</TableCell>
                      <TableCell sx={{ fontWeight: 600 }}>{a.title}</TableCell>
                      <TableCell><Badge color={a.level === 'National' ? 'error' : a.level === 'State' ? 'warning' : a.level === 'District' ? 'info' : 'success'}>{a.level ?? '-'}</Badge></TableCell>
                      <TableCell align="right" sx={{ color: 'text.secondary' }}>
                        {a.date ? new Date(a.date + 'T00:00:00').toLocaleDateString() : '-'}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </Section>

        <Section title="Equipment Watchlist">
          {equip.length === 0 ? (
            <EmptyState text="No inventory items yet." />
          ) : (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Item</TableCell>
                    <TableCell>Stock</TableCell>
                    <TableCell>Level</TableCell>
                    <TableCell>Condition</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {[...equip]
                    .sort((a, b) => (a.quantity ?? 0) - (b.quantity ?? 0))
                    .slice(0, 6)
                    .map((r) => {
                      const min = r.min_stock ?? 0
                      const q = r.quantity ?? 0
                      const pct = min > 0 ? Math.min(100, Math.round((q / (min * 2)) * 100)) : 100
                      const low = q <= min
                      return (
                        <TableRow key={r.id}>
                          <TableCell>{r.name}</TableCell>
                          <TableCell>{q}</TableCell>
                          <TableCell sx={{ width: 140 }}>
                            <Tooltip title={low ? 'At or below minimum' : 'Healthy'}>
                              <LinearProgress
                                variant="determinate"
                                value={pct}
                                color={low ? 'warning' : 'success'}
                                sx={{ height: 6, borderRadius: 3 }}
                              />
                            </Tooltip>
                          </TableCell>
                          <TableCell sx={{ color: 'text.secondary' }}>{r.condition ?? '-'}</TableCell>
                        </TableRow>
                      )
                    })}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </Section>

        <Section title="Medical Watchlist" sx={{ gridColumn: { md: '1 / -1' } }}>
          {med.length === 0 ? (
            <EmptyState text="No medical records yet." />
          ) : (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Athlete</TableCell>
                    <TableCell>Type</TableCell>
                    <TableCell>Date</TableCell>
                    <TableCell>Clearance</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {med.slice(0, 8).map((r) => (
                    <TableRow key={r.id}>
                      <TableCell>{r.athletes?.profile?.full_name ?? '-'}</TableCell>
                      <TableCell>{r.type}</TableCell>
                      <TableCell sx={{ color: 'text.secondary' }}>
                        {r.date ? new Date(r.date + 'T00:00:00').toLocaleDateString() : '-'}
                      </TableCell>
                      <TableCell>
                        <Badge color={r.cleared ? 'success' : 'error'}>{r.cleared ? 'Cleared' : 'Not cleared'}</Badge>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </Section>
      </Box>

      <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 1 }}>
        Live data - all cards update in real time from both web and mobile.
      </Typography>
    </Box>
  )
}
