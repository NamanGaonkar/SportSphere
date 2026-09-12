import { useEffect, useState, useCallback } from 'react'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import TablePagination from '@mui/material/TablePagination'
import Alert from '@mui/material/Alert'
import { supabase } from '../lib/supabase'
import { PageHead, EmptyState, LoadingState } from '../components/ui'
import dataTableSx from '../components/tableSx'

type Staff = {
  id: string
  department: string | null
  designation: string | null
  profile: { full_name: string } | null
  payroll: { month: string; gross: number; deductions: number; net: number }[]
}

export default function Staff() {
  const [rows, setRows] = useState<Staff[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)

  const load = useCallback(async () => {
    setLoading(true)
    const { data, error } = await supabase
      .from('staff')
      .select('*, profile:profiles(full_name), payroll(month, gross, deductions, net)')
      .order('created_at')
    if (error) setError(error.message)
    setRows((data as unknown as Staff[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  return (
    <Box>
      <PageHead title="Staff & HR" sub="Staff directory and payroll summary." />
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Paper>
        {loading ? (
          <LoadingState />
        ) : rows.length === 0 ? (
          <EmptyState text="No staff records yet." />
        ) : (
          <>
            <TableContainer sx={dataTableSx}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Name</TableCell>
                    <TableCell>Department</TableCell>
                    <TableCell>Designation</TableCell>
                    <TableCell>Latest Payroll (net)</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {rows
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((s) => {
                      const latest = s.payroll?.[s.payroll.length - 1]
                      return (
                        <TableRow key={s.id} hover>
                          <TableCell>{s.profile?.full_name ?? '-'}</TableCell>
                          <TableCell>{s.department ?? '-'}</TableCell>
                          <TableCell>{s.designation ?? '-'}</TableCell>
                          <TableCell>
                            {latest ? `Rs ${Number(latest.net).toLocaleString('en-IN')} (${latest.month?.slice(0, 7)})` : '-'}
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
