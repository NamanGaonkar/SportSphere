import { useEffect, useState, useMemo, useCallback } from 'react'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import MenuItem from '@mui/material/MenuItem'
import Dialog from '@mui/material/Dialog'
import DialogTitle from '@mui/material/DialogTitle'
import DialogContent from '@mui/material/DialogContent'
import DialogActions from '@mui/material/DialogActions'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TableRow from '@mui/material/TableRow'
import TablePagination from '@mui/material/TablePagination'
import Alert from '@mui/material/Alert'
import IconButton from '@mui/material/IconButton'
import InputAdornment from '@mui/material/InputAdornment'
import AddIcon from '@mui/icons-material/Add'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import DeleteOutlinedIcon from '@mui/icons-material/DeleteOutlined'
import SearchIcon from '@mui/icons-material/Search'
import { supabase } from '../lib/supabase'
import { useRealtimeTable } from '../lib/hooks'
import { SportSelect, SportFilter } from '../components/SportSelect'
import { PageHead, EmptyState, LoadingState } from '../components/ui'
import dataTableSx from '../components/tableSx'

type Team = {
  id: string
  name: string
  sport_id: string | null
  coach_id: string | null
  sports: { name: string } | null
  coaches: { profile: { full_name: string } | null } | null
  athletes: { count: number }[] | null
}

const empty = { name: '', sport_id: '', coach_id: '' }

export default function Teams() {
  const [rows, setRows] = useState<Team[]>([])
  const [coaches, setCoaches] = useState<{ id: string; profile: { full_name: string } | null }[]>([])
  const [q, setQ] = useState('')
  const [filterS, setFilterS] = useState('')
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState({ ...empty })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    const [tm, co] = await Promise.all([
      supabase.from('teams').select('*, sports(name), coaches(*, profile:profiles(full_name)), athletes(count)').order('name'),
      supabase.from('coaches').select('id, profile:profiles(full_name)').order('id'),
    ])
    setRows((tm.data as unknown as Team[]) ?? [])
    setCoaches((co.data as unknown as { id: string; profile: { full_name: string } | null }[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])
  useRealtimeTable('teams', load)

  const filtered = useMemo(
    () =>
      rows.filter(
        (r) =>
          r.name.toLowerCase().includes(q.toLowerCase()) &&
          (!filterS || r.sport_id === filterS),
      ),
    [rows, q, filterS],
  )

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const payload = {
      name: form.name,
      sport_id: form.sport_id || null,
      coach_id: form.coach_id || null,
    }
    const { error } = editing
      ? await supabase.from('teams').update(payload).eq('id', editing)
      : await supabase.from('teams').insert(payload)
    if (error) { setError(error.message); return }
    setShowForm(false)
    setEditing(null)
    setForm({ ...empty })
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this team? Athletes will be unlinked.')) return
    await supabase.from('teams').delete().eq('id', id)
    load()
  }

  function openEdit(t: Team) {
    setEditing(t.id)
    setForm({ name: t.name, sport_id: t.sport_id ?? '', coach_id: t.coach_id ?? '' })
    setShowForm(true)
  }

  return (
    <Box>
      <PageHead
        title="Teams"
        sub="Squads by sport, with coach assignment and roster size."
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => { setEditing(null); setForm({ ...empty }); setShowForm(true) }}>
            Add Team
          </Button>
        }
      />

      <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap' }}>
        <TextField
          size="small"
          placeholder="Search teams"
          value={q}
          onChange={(e) => { setQ(e.target.value); setPage(0) }}
          sx={{ width: 280 }}
          slotProps={{
            input: {
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon fontSize="small" />
                </InputAdornment>
              ),
            },
          }}
        />
        <SportFilter value={filterS} onChange={(v) => { setFilterS(v); setPage(0) }} />
      </Box>

      <Paper>
        {loading ? (
          <LoadingState />
        ) : filtered.length === 0 ? (
          <EmptyState text="No teams found." />
        ) : (
          <>
            <TableContainer sx={dataTableSx}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Name</TableCell>
                    <TableCell>Sport</TableCell>
                    <TableCell>Coach</TableCell>
                    <TableCell>Roster</TableCell>
                    <TableCell align="right">Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filtered
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((t) => (
                      <TableRow key={t.id} hover>
                        <TableCell>{t.name}</TableCell>
                        <TableCell>{t.sports?.name ?? '-'}</TableCell>
                        <TableCell>{t.coaches?.profile?.full_name ?? '-'}</TableCell>
                        <TableCell>{t.athletes?.[0]?.count ?? 0} athletes</TableCell>
                        <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                          <IconButton size="small" onClick={() => openEdit(t)} aria-label="Edit">
                            <EditOutlinedIcon fontSize="small" />
                          </IconButton>
                          <IconButton size="small" color="error" onClick={() => remove(t.id)} aria-label="Delete">
                            <DeleteOutlinedIcon fontSize="small" />
                          </IconButton>
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

      <Dialog open={showForm} onClose={() => setShowForm(false)} maxWidth="sm" fullWidth>
        <form onSubmit={save}>
          <DialogTitle>{editing ? 'Edit Team' : 'Add Team'}</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, pt: 0.5 }}>
              <TextField label="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required fullWidth />
              <SportSelect
                value={form.sport_id}
                onChange={(v) => setForm({ ...form, sport_id: v })}
                emptyLabel="No sport"
              />
              <TextField select label="Coach" value={form.coach_id} onChange={(e) => setForm({ ...form, coach_id: e.target.value })} fullWidth>
                <MenuItem value="">None</MenuItem>
                {coaches.map((c) => (
                  <MenuItem key={c.id} value={c.id}>{c.profile?.full_name ?? 'Coach'}</MenuItem>
                ))}
              </TextField>
            </Box>
            {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setShowForm(false)} color="inherit">Cancel</Button>
            <Button type="submit" variant="contained">{editing ? 'Save' : 'Add'}</Button>
          </DialogActions>
        </form>
      </Dialog>
    </Box>
  )
}
