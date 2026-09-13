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
import AddIcon from '@mui/icons-material/Add'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import DeleteOutlinedIcon from '@mui/icons-material/DeleteOutlined'
import { supabase } from '../lib/supabase'
import { useRealtimeTable } from '../lib/hooks'
import { SportSelect, SportFilter } from '../components/SportSelect'
import { PageHead, Badge, EmptyState, LoadingState } from '../components/ui'
import dataTableSx from '../components/tableSx'

type Tournament = {
  id: string
  name: string
  level: string
  start_date: string | null
  end_date: string | null
  sport_id: string | null
  sports: { name: string } | null
  venues: { name: string } | null
  matches: { count: number }[] | null
}

const empty = { name: '', level: 'School', sport_id: '', start_date: '', end_date: '', venue_id: '' }

const levelColor = (l: string) =>
  l === 'National' ? 'error' : l === 'State' ? 'warning' : l === 'District' ? 'info' : 'success'

export default function Tournaments() {
  const [rows, setRows] = useState<Tournament[]>([])
  const [venues, setVenues] = useState<{ id: string; name: string }[]>([])
  const [filterS, setFilterS] = useState('')
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState({ ...empty })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    const [tr, vn] = await Promise.all([
      supabase.from('tournaments').select('*, sports(name), venues(name), matches(count)').order('start_date', { ascending: false }),
      supabase.from('venues').select('id, name').order('name'),
    ])
    setRows((tr.data as unknown as Tournament[]) ?? [])
    setVenues((vn.data as { id: string; name: string }[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])
  useRealtimeTable('tournaments', load)

  const sorted = useMemo(
    () =>
      [...rows]
        .filter((r) => !filterS || r.sport_id === filterS)
        .sort((a, b) => a.name.localeCompare(b.name)),
    [rows, filterS],
  )

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const payload = {
      name: form.name,
      level: form.level,
      sport_id: form.sport_id || null,
      start_date: form.start_date || null,
      end_date: form.end_date || null,
      venue_id: form.venue_id || null,
    }
    const { error } = editing
      ? await supabase.from('tournaments').update(payload).eq('id', editing)
      : await supabase.from('tournaments').insert(payload)
    if (error) { setError(error.message); return }
    setShowForm(false)
    setEditing(null)
    setForm({ ...empty })
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this tournament and its matches?')) return
    await supabase.from('tournaments').delete().eq('id', id)
    load()
  }

  function openEdit(t: Tournament) {
    setEditing(t.id)
    setForm({
      name: t.name,
      level: t.level,
      sport_id: t.sport_id ?? '',
      start_date: t.start_date ?? '',
      end_date: t.end_date ?? '',
      venue_id: '',
    })
    setShowForm(true)
  }

  const fmt = (d: string | null) => (d ? new Date(d + 'T00:00:00').toLocaleDateString() : '-')

  return (
    <Box>
      <PageHead
        title="Tournaments"
        sub="Competitions across School, District, State and National levels."
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => { setEditing(null); setForm({ ...empty }); setShowForm(true) }}>
            Add Tournament
          </Button>
        }
      />

      <SportFilter value={filterS} onChange={(v) => { setFilterS(v); setPage(0) }} />

      <Paper>
        {loading ? (
          <LoadingState />
        ) : sorted.length === 0 ? (
          <EmptyState text="No tournaments yet." />
        ) : (
          <>
            <TableContainer sx={dataTableSx}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Name</TableCell>
                    <TableCell>Sport</TableCell>
                    <TableCell>Level</TableCell>
                    <TableCell>Dates</TableCell>
                    <TableCell>Venue</TableCell>
                    <TableCell>Matches</TableCell>
                    <TableCell align="right">Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {sorted
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((t) => (
                      <TableRow key={t.id} hover>
                        <TableCell>{t.name}</TableCell>
                        <TableCell>{t.sports?.name ?? '-'}</TableCell>
                        <TableCell><Badge color={levelColor(t.level)}>{t.level}</Badge></TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>{fmt(t.start_date)} to {fmt(t.end_date)}</TableCell>
                        <TableCell>{t.venues?.name ?? '-'}</TableCell>
                        <TableCell>{t.matches?.[0]?.count ?? 0}</TableCell>
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
              count={sorted.length}
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
          <DialogTitle>{editing ? 'Edit Tournament' : 'Add Tournament'}</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, pt: 0.5 }}>
              <TextField label="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required fullWidth />
              <TextField select label="Level" value={form.level} onChange={(e) => setForm({ ...form, level: e.target.value })} fullWidth>
                {['School', 'District', 'State', 'National'].map((l) => <MenuItem key={l} value={l}>{l}</MenuItem>)}
              </TextField>
              <SportSelect value={form.sport_id} onChange={(v) => setForm({ ...form, sport_id: v })} emptyLabel="No sport" />
              <TextField type="date" label="Start date" value={form.start_date} onChange={(e) => setForm({ ...form, start_date: e.target.value })} slotProps={{ inputLabel: { shrink: true } }} fullWidth />
              <TextField type="date" label="End date" value={form.end_date} onChange={(e) => setForm({ ...form, end_date: e.target.value })} slotProps={{ inputLabel: { shrink: true } }} fullWidth />
              <TextField select label="Venue" value={form.venue_id} onChange={(e) => setForm({ ...form, venue_id: e.target.value })} fullWidth>
                <MenuItem value="">None</MenuItem>
                {venues.map((v) => <MenuItem key={v.id} value={v.id}>{v.name}</MenuItem>)}
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
