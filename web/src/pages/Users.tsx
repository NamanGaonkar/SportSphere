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
import TextField from '@mui/material/TextField'
import MenuItem from '@mui/material/MenuItem'
import Chip from '@mui/material/Chip'
import SearchIcon from '@mui/icons-material/Search'
import InputAdornment from '@mui/material/InputAdornment'
import { supabase } from '../lib/supabase'
import { useRealtimeTable } from '../lib/hooks'
import { PageHead, EmptyState, LoadingState } from '../components/ui'
import dataTableSx from '../components/tableSx'

type UserRow = {
  id: string
  full_name: string
  role: string
  contact_info: string | null
  created_at: string
  athletes: { id: string }[] | null
  coaches: { id: string }[] | null
  staff: { id: string }[] | null
}

const ROLES = ['Admin', 'Coach', 'Athlete', 'HR', 'Finance', 'VenueManager']

const roleColor = (r: string) =>
  r === 'Admin' ? 'error' : r === 'Coach' ? 'info' : r === 'HR' ? 'warning' : r === 'Finance' ? 'success' : 'default'

/** Admin-only user management: rename, change role, edit contact for everyone. */
export default function Users() {
  const [rows, setRows] = useState<UserRow[]>([])
  const [q, setQ] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)

  const load = useCallback(async () => {
    setLoading(true)
    const { data, error } = await supabase
      .from('profiles')
      .select('id, full_name, role, contact_info, created_at, athletes(id), coaches(id), staff(id)')
      .order('created_at', { ascending: false })
    if (error) setError(error.message)
    setRows((data as unknown as UserRow[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])
  useRealtimeTable('profiles', load)

  const filtered = rows.filter((r) =>
    !q || [r.full_name, r.role, r.contact_info].some((v) => (v ?? '').toLowerCase().includes(q.toLowerCase())),
  )

  async function setRole(r: UserRow, role: string) {
    setError('')
    if (r.role === 'Admin' && role !== 'Admin') {
      setError('Cannot demote the fixed admin account here - promote another admin first by SQL.')
      return
    }
    const { error } = await supabase.rpc('admin_set_role', { p_user: r.id, p_role: role })
    if (error) setError(error.message)
    else load()
  }

  async function rename(r: UserRow, name: string) {
    if (!name.trim() || name === r.full_name) return
    const { error } = await supabase.rpc('admin_rename_user', { p_user: r.id, p_name: name.trim() })
    if (error) setError(error.message)
  }

  async function setContact(r: UserRow, contact: string) {
    if (contact === (r.contact_info ?? '')) return
    const { error } = await supabase.rpc('admin_set_contact', { p_user: r.id, p_contact: contact || null })
    if (error) setError(error.message)
  }

  return (
    <Box>
      <PageHead title="User Management" sub="Manage every account: names, roles and contacts. Changes apply on web and mobile instantly." />

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>{error}</Alert>}

      <TextField
        size="small"
        placeholder="Search users"
        value={q}
        onChange={(e) => { setQ(e.target.value); setPage(0) }}
        sx={{ mb: 2, width: 280 }}
        slotProps={{ input: { startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment> } }}
      />

      <Paper>
        {loading ? (
          <LoadingState />
        ) : filtered.length === 0 ? (
          <EmptyState text="No users found." />
        ) : (
          <>
            <TableContainer sx={dataTableSx}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Name</TableCell>
                    <TableCell>Contact</TableCell>
                    <TableCell>Linked record</TableCell>
                    <TableCell>Role</TableCell>
                    <TableCell>Joined</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filtered
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((r) => (
                      <TableRow key={r.id} hover>
                        {/* Compact inline editors: no under-full standard
                            TextFields stretching into empty space. */}
                        <TableCell sx={{ width: 220 }}>
                          <TextField
                            defaultValue={r.full_name}
                            onBlur={(e) => rename(r, e.target.value)}
                            variant="standard"
                            fullWidth
                            slotProps={{ input: { disableUnderline: false } }}
                            sx={{ '& input': { fontWeight: 600, py: 0.5 } }}
                          />
                        </TableCell>
                        <TableCell sx={{ width: 200 }}>
                          <TextField
                            defaultValue={r.contact_info ?? ''}
                            onBlur={(e) => setContact(r, e.target.value)}
                            variant="standard"
                            placeholder="-"
                            fullWidth
                            sx={{ '& input': { py: 0.5 } }}
                          />
                        </TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>
                          {r.athletes?.length ? 'Athlete record' : r.coaches?.length ? 'Coach record' : r.staff?.length ? 'Staff record' : '-'}
                        </TableCell>
                        <TableCell sx={{ width: 210 }}>
                          <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 0.75 }}>
                            <Chip size="small" color={roleColor(r.role) as 'error'} label={r.role} />
                            <TextField
                              select
                              size="small"
                              value={r.role}
                              onChange={(e) => setRole(r, e.target.value)}
                              fullWidth
                              disabled={r.role === 'Admin'}
                            >
                              {ROLES.map((x) => <MenuItem key={x} value={x}>{x}</MenuItem>)}
                            </TextField>
                          </Box>
                        </TableCell>
                        <TableCell sx={{ color: 'text.secondary', whiteSpace: 'nowrap' }}>{new Date(r.created_at).toLocaleDateString()}</TableCell>
                      </TableRow>
                    ))}
                </TableBody>
              </Table>
            </TableContainer>
            <TablePagination
              component="div"
              count={filtered.length}
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
