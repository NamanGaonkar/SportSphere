import { useEffect, useState, useMemo, useCallback } from 'react'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import MenuItem from '@mui/material/MenuItem'
import Chip from '@mui/material/Chip'
import Typography from '@mui/material/Typography'
import Avatar from '@mui/material/Avatar'
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
import { useSportNameMap } from '../components/SportSelect'
import { PageHead, EmptyState, LoadingState } from '../components/ui'
import dataTableSx from '../components/tableSx'

type Coach = {
  id: string
  specialization: string | null
  sport_id: string | null
  certification: string | null
  experience_years: number | null
  profile: { id: string; full_name: string; contact_info: string | null; avatar_url: string | null } | null
  teams: { id: string; name: string }[] | null
}

const empty = { full_name: '', specialization: '', sport_id: '', certification: '', experience_years: '' }

function coachPayload(f: typeof empty) {
  return {
    specialization: f.specialization || null,
    sport_id: f.sport_id || null,
    certification: f.certification || null,
    experience_years: f.experience_years === '' ? null : Number(f.experience_years),
  }
}

export default function Coaches() {
  const sportName = useSportNameMap()
  const [rows, setRows] = useState<Coach[]>([])
  const [q, setQ] = useState('')
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)
  const [editing, setEditing] = useState<string | null>(null)
  const [editProfileId, setEditProfileId] = useState<string | null>(null)
  const [form, setForm] = useState({ ...empty })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    const { data } = await supabase
      .from('coaches')
      .select('*, profile:profiles(id, full_name, contact_info, avatar_url), teams(id, name)')
      .order('created_at')
    setRows((data as unknown as Coach[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  const filtered = useMemo(
    () => rows.filter((r) => (r.profile?.full_name ?? '').toLowerCase().includes(q.toLowerCase())),
    [rows, q],
  )

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (editing && editProfileId) {
      const { error: pErr } = await supabase
        .from('profiles')
        .update({ full_name: form.full_name })
        .eq('id', editProfileId)
      if (pErr) { setError(pErr.message); return }
      const { error } = await supabase
        .from('coaches')
        .update(coachPayload(form))
        .eq('id', editing)
      if (error) { setError(error.message); return }
    } else {
      const { data: profile, error: pErr } = await supabase
        .from('profiles')
        .insert({ full_name: form.full_name, role: 'Coach' })
        .select('id')
        .single()
      if (pErr || !profile) { setError(pErr?.message ?? 'Could not create profile'); return }
      const { error } = await supabase.from('coaches').insert({
        profile_id: profile.id,
        ...coachPayload(form),
      })
      if (error) { setError(error.message); return }
    }

    setShowForm(false)
    setEditing(null)
    setEditProfileId(null)
    setForm({ ...empty })
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this coach?')) return
    await supabase.from('coaches').delete().eq('id', id)
    load()
  }

  function openEdit(r: Coach) {
    setEditing(r.id)
    setEditProfileId(r.profile?.id ?? null)
    setForm({
      full_name: r.profile?.full_name ?? '',
      specialization: r.specialization ?? '',
      sport_id: r.sport_id ?? '',
      certification: r.certification ?? '',
      experience_years: r.experience_years?.toString() ?? '',
    })
    setShowForm(true)
  }

  return (
    <Box>
      <PageHead
        title="Coaches"
        sub="Coaching staff and their specializations."
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => { setEditing(null); setEditProfileId(null); setForm({ ...empty }); setShowForm(true) }}>
            Add Coach
          </Button>
        }
      />

      <TextField
        size="small"
        placeholder="Search by name"
        value={q}
        onChange={(e) => { setQ(e.target.value); setPage(0) }}
        sx={{ mb: 2, width: 280 }}
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

      <Paper>
        {loading ? (
          <LoadingState />
        ) : filtered.length === 0 ? (
          <EmptyState text="No coaches found." />
        ) : (
          <>
            <TableContainer sx={dataTableSx}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Name</TableCell>
                    <TableCell>Specialization</TableCell>
                    <TableCell>Sport</TableCell>
                    <TableCell>Experience</TableCell>
                    <TableCell>Teams</TableCell>
                    <TableCell align="right">Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filtered
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((r) => (
                      <TableRow key={r.id} hover>
                        <TableCell>
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.25 }}>
                            <Avatar
                              src={r.profile?.avatar_url ?? undefined}
                              sx={{ width: 30, height: 30, fontSize: 13, bgcolor: 'rgba(255,106,19,0.18)', color: '#B25A1F', fontWeight: 700 }}
                            >
                              {(r.profile?.full_name ?? '?').slice(0, 1).toUpperCase()}
                            </Avatar>
                            {r.profile?.full_name ?? '-'}
                          </Box>
                        </TableCell>
                        <TableCell>{r.specialization ?? '-'}</TableCell>
                        <TableCell>{r.sport_id ? (sportName.get(r.sport_id) ?? '-') : '-'}</TableCell>
                        <TableCell>{r.experience_years != null ? `${r.experience_years} yrs` : '-'}</TableCell>
                        <TableCell>
                          {(r.teams ?? []).length === 0 ? (
                            <Typography variant="body2" sx={{ color: 'text.disabled' }}>-</Typography>
                          ) : (
                            // Chip per team assignment — scannable, not a comma blob.
                            <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap' }}>
                              {r.teams!.map((t) => (
                                <Chip key={t.id} size="small" label={t.name} variant="outlined" sx={{ borderColor: 'rgba(255,106,19,0.4)', color: '#B25A1F', fontSize: 12 }} />
                              ))}
                            </Box>
                          )}
                        </TableCell>
                        <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                          <IconButton size="small" onClick={() => openEdit(r)} aria-label="Edit">
                            <EditOutlinedIcon fontSize="small" />
                          </IconButton>
                          <IconButton size="small" color="error" onClick={() => remove(r.id)} aria-label="Delete">
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
          <DialogTitle>{editing ? 'Edit Coach' : 'Add Coach'}</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, pt: 0.5 }}>
              <TextField label="Full name" value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} required fullWidth />
              <TextField label="Specialization" value={form.specialization} onChange={(e) => setForm({ ...form, specialization: e.target.value })} fullWidth />
              <TextField select label="Sport" value={form.sport_id} onChange={(e) => setForm({ ...form, sport_id: e.target.value })} fullWidth>
                <MenuItem value="">None</MenuItem>
                {[...sportName.entries()].map(([id, name]) => <MenuItem key={id} value={id}>{name}</MenuItem>)}
              </TextField>
              <TextField label="Certification" value={form.certification} onChange={(e) => setForm({ ...form, certification: e.target.value })} fullWidth />
              <TextField type="number" label="Experience (years)" value={form.experience_years} onChange={(e) => setForm({ ...form, experience_years: e.target.value })} fullWidth />
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
