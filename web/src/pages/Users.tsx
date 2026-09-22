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
import Avatar from '@mui/material/Avatar'
import Tooltip from '@mui/material/Tooltip'
import IconButton from '@mui/material/IconButton'
import SearchIcon from '@mui/icons-material/Search'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import InputAdornment from '@mui/material/InputAdornment'
import { supabase } from '../lib/supabase'
import { useRealtimeTable } from '../lib/hooks'
import {
  Button, Dialog, DialogTitle, DialogContent, DialogActions, MenuItem as MUIMenuItem,
} from '@mui/material'
import AddIcon from '@mui/icons-material/Add'
import { PageHead, EmptyState, LoadingState } from '../components/ui'
import dataTableSx from '../components/tableSx'

type UserRow = {
  id: string
  full_name: string
  role: string
  contact_info: string | null
  phone: string | null
  avatar_url: string | null
  created_at: string
  email?: string | null
}

const ROLES = ['Admin', 'Coach', 'Athlete', 'HR', 'Finance', 'VenueManager']

const roleColor = (r: string) =>
  r === 'Admin' ? 'error' : r === 'Coach' ? 'info' : r === 'HR' ? 'warning' : r === 'Finance' ? 'success' : 'default'

const initials = (name: string) =>
  name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]?.toUpperCase() ?? '').join('') || '?'

/** Admin-only user management — dense modern table: avatar + identity, role,
 *  inline-editable phone, joined. No under-full stretched columns. */
export default function Users() {
  const [rows, setRows] = useState<UserRow[]>([])
  const [q, setQ] = useState('')
  const [error, setError] = useState('')
  const [okMsg, setOkMsg] = useState('')
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)
  // New-account dialog (tester round 2 #7: admin could not add staff/HR).
  const [showAdd, setShowAdd] = useState(false)
  const [addForm, setAddForm] = useState({
    email: '', password: '', full_name: '', role: 'HR', department: '', designation: '',
  })
  // Inline rename dialog (keeps the table cell clean — name is not a form).
  const [renaming, setRenaming] = useState<UserRow | null>(null)
  const [renameValue, setRenameValue] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    const [prof, emails] = await Promise.all([
      supabase
        .from('profiles')
        .select('id, full_name, role, contact_info, phone, avatar_url, created_at')
        .order('created_at', { ascending: false }),
      // Auth emails live outside profiles; admin-only RPC surfaces them.
      supabase.rpc('admin_list_emails'),
    ])
    if (prof.error) setError(prof.error.message)
    const emailMap = new Map<string, string>(
      ((emails.data as { user_id: string; email: string }[]) ?? []).map((e) => [e.user_id, e.email]),
    )
    setRows(
      ((prof.data as unknown as UserRow[]) ?? []).map((r) => ({ ...r, email: emailMap.get(r.id) ?? null })),
    )
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])
  useRealtimeTable('profiles', load)

  const filtered = rows.filter((r) =>
    !q || [r.full_name, r.role, r.phone, r.email].some((v) => (v ?? '').toLowerCase().includes(q.toLowerCase())),
  )

  async function setRole(r: UserRow, role: string) {
    setError('')
    if (r.role === 'Admin') {
      setError('The primary Admin account is protected and cannot be changed.')
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

  async function setPhone(r: UserRow, phone: string) {
    if (phone === (r.phone ?? '')) return
    const { error } = await supabase.rpc('admin_set_phone', { p_user: r.id, p_phone: phone })
    if (error) setError(error.message)
  }

  async function createAccount(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setOkMsg('')
    const { data, error } = await supabase.rpc('admin_create_user', {
      p_email: addForm.email.trim(),
      p_password: addForm.password,
      p_name: addForm.full_name.trim(),
      p_role: addForm.role,
      p_department: addForm.department || null,
      p_designation: addForm.designation || null,
    })
    if (error) { setError(error.message); return }
    setOkMsg(`Account created for ${addForm.email} - they can sign in immediately.`)
    setShowAdd(false)
    setAddForm({ email: '', password: '', full_name: '', role: 'HR', department: '', designation: '' })
    load()
  }

  return (
    <Box>
      <PageHead
        title="User Management"
        sub="Every account at a glance - role, contact and join date, editable in place."
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => setShowAdd(true)}>
            Add staff / user
          </Button>
        }
      />

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>{error}</Alert>}
      {okMsg && <Alert severity="success" sx={{ mb: 2 }} onClose={() => setOkMsg('')}>{okMsg}</Alert>}

      <TextField
        size="small"
        placeholder="Search name, role, email or phone"
        value={q}
        onChange={(e) => { setQ(e.target.value); setPage(0) }}
        sx={{ mb: 2, width: 320 }}
        slotProps={{ input: { startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment> } }}
      />

      <Paper>
        {loading ? (
          <LoadingState />
        ) : filtered.length === 0 ? (
          <EmptyState text="No users found." />
        ) : (
          <>
            <TableContainer sx={{ ...dataTableSx, '& .MuiTableCell-root': { py: 1 } }}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Member</TableCell>
                    <TableCell sx={{ width: 150 }}>Role</TableCell>
                    <TableCell sx={{ width: 170 }}>Phone</TableCell>
                    <TableCell sx={{ width: 110 }}>Joined</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filtered
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((r) => (
                      <TableRow key={r.id} hover>
                        <TableCell>
                          {/* Identity block: avatar + name + email stacked —
                              dense, no half-empty stretched columns. */}
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.25, minWidth: 220 }}>
                            <Avatar
                              src={r.avatar_url ?? undefined}
                              sx={{ width: 34, height: 34, fontSize: 13, fontWeight: 700, bgcolor: 'secondary.main' }}
                            >
                              {initials(r.full_name)}
                            </Avatar>
                            <Box sx={{ minWidth: 0 }}>
                              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                                <Box sx={{ fontWeight: 600, fontSize: 13.5, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                  {r.full_name}
                                </Box>
                                <Tooltip title="Rename">
                                  <IconButton
                                    size="small"
                                    sx={{ p: 0.25, opacity: 0.45, '&:hover': { opacity: 1 } }}
                                    onClick={() => { setRenaming(r); setRenameValue(r.full_name) }}
                                    aria-label="Rename"
                                  >
                                    <EditOutlinedIcon sx={{ fontSize: 14 }} />
                                  </IconButton>
                                </Tooltip>
                              </Box>
                              <Box sx={{ fontSize: 12, color: 'text.secondary', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                {r.email ?? '-'}
                              </Box>
                            </Box>
                          </Box>
                        </TableCell>
                        <TableCell>
                          <RoleSelect role={r.role} onChange={(v) => setRole(r, v)} />
                        </TableCell>
                        <TableCell>
                          {/* Editable in place: blur saves via admin RPC.
                              Blank = never entered (clear on the server). */}
                          <TextField
                            defaultValue={r.phone ?? ''}
                            onBlur={(e) => setPhone(r, e.target.value.trim())}
                            onKeyDown={(e) => e.key === 'Enter' && (e.target as HTMLInputElement).blur()}
                            variant="standard"
                            placeholder="Add phone"
                            size="small"
                            sx={{ '& input': { py: 0.25, fontSize: 13 } }}
                          />
                        </TableCell>
                        <TableCell sx={{ color: 'text.secondary', whiteSpace: 'nowrap', fontSize: 12.5 }}>
                          {new Date(r.created_at).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: '2-digit' })}
                        </TableCell>
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

      {/* Rename dialog */}
      <Dialog open={!!renaming} onClose={() => setRenaming(null)} maxWidth="xs" fullWidth>
        <DialogTitle>Rename user</DialogTitle>
        <DialogContent>
          <TextField
            autoFocus fullWidth margin="dense"
            label="Full name" value={renameValue}
            onChange={(e) => setRenameValue(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && renaming) { rename(renaming, renameValue); setRenaming(null) }
            }}
          />
        </DialogContent>
        <DialogActions>
          <Button color="inherit" onClick={() => setRenaming(null)}>Cancel</Button>
          <Button
            variant="contained"
            onClick={() => { if (renaming) { rename(renaming, renameValue); setRenaming(null) } }}
          >
            Save
          </Button>
        </DialogActions>
      </Dialog>

      {/* Create account */}
      <Dialog open={showAdd} onClose={() => setShowAdd(false)} maxWidth="sm" fullWidth>
        <form onSubmit={createAccount}>
          <DialogTitle>Create account</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, pt: 0.5 }}>
              <TextField label="Email" type="email" value={addForm.email} onChange={(e) => setAddForm({ ...addForm, email: e.target.value })} required fullWidth />
              <TextField label="Password (min 6 chars)" type="password" value={addForm.password} onChange={(e) => setAddForm({ ...addForm, password: e.target.value })} required fullWidth slotProps={{ htmlInput: { minLength: 6 } }} />
              <TextField label="Full name" value={addForm.full_name} onChange={(e) => setAddForm({ ...addForm, full_name: e.target.value })} required fullWidth />
              <TextField select label="Role" value={addForm.role} onChange={(e) => setAddForm({ ...addForm, role: e.target.value })} fullWidth>
                {['HR', 'Finance', 'VenueManager', 'Coach', 'Athlete'].map((x) => <MUIMenuItem key={x} value={x}>{x}</MUIMenuItem>)}
              </TextField>
              {(addForm.role === 'HR' || addForm.role === 'Finance' || addForm.role === 'VenueManager') && (
                <>
                  <TextField label="Department" value={addForm.department} onChange={(e) => setAddForm({ ...addForm, department: e.target.value })} fullWidth />
                  <TextField label="Designation" value={addForm.designation} onChange={(e) => setAddForm({ ...addForm, designation: e.target.value })} fullWidth />
                </>
              )}
            </Box>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setShowAdd(false)} color="inherit">Cancel</Button>
            <Button type="submit" variant="contained">Create</Button>
          </DialogActions>
        </form>
      </Dialog>
    </Box>
  )
}

/** Compact role selector: chip look + dropdown, fixed 150px — no stretching. */
function RoleSelect({ role, onChange }: { role: string; onChange: (v: string) => void }) {
  if (role === 'Admin') return <Chip size="small" color="error" label="Admin" />
  return (
    <TextField
      select
      size="small"
      value={role}
      onChange={(e) => onChange(e.target.value)}
      sx={{ width: '100%', '& .MuiInputBase-root': { fontSize: 13 } }}
    >
      {ROLES.filter((x) => x !== 'Admin').map((x) => <MenuItem key={x} value={x}>{x}</MenuItem>)}
    </TextField>
  )
}
