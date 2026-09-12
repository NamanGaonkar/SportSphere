import { useEffect, useState, useMemo, useCallback } from 'react'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import TablePagination from '@mui/material/TablePagination'
import { supabase } from '../lib/supabase'
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

const STATUSES = ['Present', 'Absent', 'Late', 'Leave'] as const

export default function Attendance() {
  const [rows, setRows] = useState<AthleteRow[]>([])
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10))
  const [saving, setSaving] = useState(false)
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    const { data } = await supabase
      .from('athletes')
      .select('id, profile_id, profile:profiles(full_name, attendance(id, date, status, leave_reason))')
      .order('created_at')
    setRows((data as unknown as AthleteRow[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

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
    // eslint-disable-next-line react-hooks/exhaustive-deps
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
    <Box>
      <PageHead
        title="Attendance & Leave"
        sub="Mark daily attendance for athletes."
        action={
          <TextField
            type="date"
            size="small"
            label="Date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            slotProps={{ inputLabel: { shrink: true } }}
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
        <StatCard label="Marked" value={summary.total} sub={`of ${rows.length} athletes`} />
        <StatCard label="Present + Late" value={summary.present} sub={`${summary.pct}% attendance`} />
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
                          <TableCell>
                            {s ? <Badge color={statusColor(s)}>{s}</Badge> : <Box component="span" sx={{ color: 'text.secondary' }}>not marked</Box>}
                          </TableCell>
                          <TableCell>
                            <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap' }}>
                              {STATUSES.map((st) => (
                                <Button
                                  key={st}
                                  size="small"
                                  disabled={saving}
                                  variant={s === st ? 'contained' : 'outlined'}
                                  onClick={() => mark(r, st)}
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
    </Box>
  )
}
