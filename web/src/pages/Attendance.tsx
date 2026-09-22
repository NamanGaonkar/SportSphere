import { useEffect, useState, useMemo, useCallback } from 'react'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import Dialog from '@mui/material/Dialog'
import DialogTitle from '@mui/material/DialogTitle'
import DialogContent from '@mui/material/DialogContent'
import DialogActions from '@mui/material/DialogActions'
import Tooltip from '@mui/material/Tooltip'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import TablePagination from '@mui/material/TablePagination'
import { supabase } from '../lib/supabase'
import { useRealtimeTable } from '../lib/hooks'
import { useSession } from '../App'
import { PageHead, Badge, statusColor, EmptyState, LoadingState, StatCard } from '../components/ui'
import dataTableSx from '../components/tableSx'

type AthleteRow = {
  id: string
  profile_id: string
  profile: {
    full_name: string
    attendance: { id: string; date: string; status: string; leave_reason: string | null }[]
  } | null
}

/**
 * People with attendance (athletes + coaches + staff via profiles).
 * Venue managers and athletes only ever see their OWN record (tester:
 * "As venue manager I should not be able to view attendance of everyone").
 */
async function loadAttendanceRows(viewerId: string, viewerRole: string) {
  const ownOnly = viewerRole === 'VenueManager' || viewerRole === 'Athlete'
  let query = supabase
    .from('profiles')
    .select('id, full_name, role, attendance(id, date, status, leave_reason)')
    .in('role', ['Athlete', 'Coach', 'HR', 'Finance', 'VenueManager'])
    .order('full_name')
  if (ownOnly) query = query.eq('id', viewerId)
  const { data } = await query
  return ((data ?? []) as unknown as {
    id: string
    full_name: string
    role: string
    attendance: { id: string; date: string; status: string; leave_reason: string | null }[]
  }[])
    .filter((p) => ownOnly || p.role === 'Athlete' || p.attendance.length > 0)
    .map((p) => ({
      id: p.id,
      profile_id: p.id,
      role: p.role,
      profile: { full_name: p.full_name, attendance: p.attendance },
    }))
}

const STATUSES = ['Present', 'Absent', 'Late', 'Leave'] as const

export default function Attendance() {
  const [rows, setRows] = useState<AthleteRow[]>([])
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10))
  const [saving, setSaving] = useState(false)
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)
  const [loading, setLoading] = useState(true)
  const [leaveFor, setLeaveFor] = useState<{ row: AthleteRow; reason: string } | null>(null)
  const session = useSession()
  const viewerId = session?.user.id ?? ''
  const viewerRole = session?.profile?.role ?? ''

  const load = useCallback(async () => {
    if (!viewerId) return
    setLoading(true)
    setRows((await loadAttendanceRows(viewerId, viewerRole)) as unknown as AthleteRow[])
    setLoading(false)
  }, [viewerId, viewerRole])

  useEffect(() => { load() }, [load])
  useRealtimeTable('attendance', load)

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
    // Rate is over the whole roster (all listed people), not just those
    // marked so far — 1 Present out of 16 people reads as ~6%, not 100%.
    return { present, total, pct: rows.length ? Math.round((present / rows.length) * 100) : 0 }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rows, date])

  async function mark(r: AthleteRow, status: string, leaveReason?: string) {
    // Marking is only allowed for today onward - past dates are view-only.
    if (date < new Date().toISOString().slice(0, 10)) return
    setSaving(true)
    const existing = (r.profile?.attendance ?? []).find((a) => a.date === date)
    const payload: Record<string, unknown> = { status }
    if (status === 'Leave') payload.leave_reason = leaveReason ?? existing?.leave_reason ?? null
    if (existing) {
      await supabase.from('attendance').update(payload).eq('id', existing.id)
    } else {
      await supabase.from('attendance').insert({ profile_id: r.profile_id, date, ...payload })
    }
    await load()
    setSaving(false)
  }

  function onMark(r: AthleteRow, status: string) {
    if (status === 'Leave') setLeaveFor({ row: r, reason: '' })
    else void mark(r, status)
  }

  return (
    <Box>
      <PageHead
        title="Attendance & Leave"
        sub={viewerRole === 'VenueManager' || viewerRole === 'Athlete' ? 'Your own attendance record.' : 'Mark daily attendance for athletes.'}
        action={
          <TextField
            type="date"
            size="small"
            label="Date"
            value={date}
            slotProps={{
              inputLabel: { shrink: true },
              formHelperText: { sx: { mx: 0.5 } },
            }}
            onChange={(e) => setDate(e.target.value)}
            helperText="View any date - marking is only allowed for today onward"
          />
        }
      />

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, 1fr)' },
          gap: 2,
          mb: 2,
        }}
      >
        <StatCard label="Marked" value={summary.total} sub={`of ${rows.length} athletes`} variant={0} />
        <StatCard label="Present + Late" value={summary.present} sub={`${summary.pct}% of ${rows.length} people`} variant={2} />
      </Box>

      <Paper>
        {loading ? (
          <LoadingState />
        ) : rows.length === 0 ? (
          <EmptyState text="No athletes to mark." />
        ) : (
          <>
            <TableContainer sx={dataTableSx}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Athlete</TableCell>
                    <TableCell>Role</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell>Mark</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {rows
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((r) => {
                      const s = statusFor(r)
                      return (
                        <TableRow key={r.id} hover>
                          <TableCell>{r.profile?.full_name ?? '-'}</TableCell>
                          <TableCell sx={{ color: 'text.secondary', fontSize: 12 }}>{(r as unknown as { role?: string }).role ?? ''}</TableCell>
                          <TableCell>
                            {s ? (
                              <Tooltip title={(r.profile?.attendance ?? []).find((a) => a.date === date)?.leave_reason ?? ''} disableHoverListener={!((r.profile?.attendance ?? []).find((a) => a.date === date)?.leave_reason)}>
                                <Box component="span"><Badge color={statusColor(s)}>{s}</Badge></Box>
                              </Tooltip>
                            ) : (
                              <Box component="span" sx={{ color: 'text.secondary' }}>not marked</Box>
                            )}
                          </TableCell>
                          <TableCell>
                            <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap' }}>
                              {STATUSES.map((st) => (
                                <Button
                                  key={st}
                                  size="small"
                                  disabled={saving || date < new Date().toISOString().slice(0, 10)}
                                  variant={s === st ? 'contained' : 'outlined'}
                                  onClick={() => onMark(r, st)}
                                  sx={{ minWidth: 72 }}
                                >
                                  {st}
                                </Button>
                              ))}
                            </Box>
                          </TableCell>
                        </TableRow>
                      )
                    })}
                </TableBody>
              </Table>
            </TableContainer>
            <TablePagination
              component="div"
              count={rows.length}
              page={page}
              onPageChange={(_, p) => setPage(p)}
              rowsPerPage={rowsPerPage}
              onRowsPerPageChange={(e) => { setRowsPerPage(Number(e.target.value)); setPage(0) }}
              rowsPerPageOptions={[10, 25, 50]}
            />
          </>
        )}
      </Paper>

      <Dialog open={leaveFor !== null} onClose={() => setLeaveFor(null)} maxWidth="xs" fullWidth>
        <DialogTitle>Leave reason</DialogTitle>
        <DialogContent dividers>
          <TextField
            label="Reason"
            value={leaveFor?.reason ?? ''}
            onChange={(e) => setLeaveFor((v) => (v ? { ...v, reason: e.target.value } : v))}
            fullWidth
            autoFocus
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setLeaveFor(null)} color="inherit">Cancel</Button>
          <Button
            variant="contained"
            onClick={async () => {
              if (leaveFor) await mark(leaveFor.row, 'Leave', leaveFor.reason)
              setLeaveFor(null)
            }}
          >
            Mark Leave
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  )
}
