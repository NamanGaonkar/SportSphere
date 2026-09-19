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
import Avatar from '@mui/material/Avatar'
import { supabase } from '../lib/supabase'
import { useRealtimeTable } from '../lib/hooks'
import { SportMultiSelect } from '../components/SportSelect'
import { PageHead, Badge, EmptyState, LoadingState } from '../components/ui'
import ExpandableRow from '../components/ExpandableRow'
import dataTableSx from '../components/tableSx'

type Athlete = {
  id: string
  dob: string | null
  medical_notes: string | null
  profile_id: string
  profile: { id: string; full_name: string; contact_info: string | null; avatar_url: string | null } | null
  teams: { name: string } | null
  athlete_sports: { sports: { name: string } | null }[] | null
}
type Team = { id: string; name: string }

const empty = { full_name: '', sportIds: [] as string[], dob: '', team_id: '', medical_notes: '' }

export default function Athletes() {
  const [rows, setRows] = useState<Athlete[]>([])
  const [teams, setTeams] = useState<Team[]>([])
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
    const [ath, tm] = await Promise.all([
      supabase
        .from('athletes')
        .select('*, profile:profiles(id, full_name, contact_info, avatar_url), teams(name), athlete_sports(sports(name))')
        .order('created_at'),
      supabase.from('teams').select('id, name').order('name'),
    ])
    setRows((ath.data as unknown as Athlete[]) ?? [])
    setTeams((tm.data as Team[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])
  useRealtimeTable('athletes', load)

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
        .from('athletes')
        .update({ dob: form.dob || null, team_id: form.team_id || null, medical_notes: form.medical_notes || null })
        .eq('id', editing)
      if (error) { setError(error.message); return }
      // Replace the sport tags wholesale (join-table sync).
      await supabase.from('athlete_sports').delete().eq('athlete_id', editing)
      if (form.sportIds.length) {
        await supabase.from('athlete_sports').insert(form.sportIds.map((sid) => ({ athlete_id: editing, sport_id: sid })))
      }
    } else {
      const { data: profile, error: pErr } = await supabase
        .from('profiles')
        .insert({ full_name: form.full_name, role: 'Athlete', contact_info: null })
        .select('id')
        .single()
      if (pErr || !profile) { setError(pErr?.message ?? 'Could not create profile'); return }
      const { data: athlete, error } = await supabase
        .from('athletes')
        .insert({ profile_id: profile.id, dob: form.dob || null, team_id: form.team_id || null, medical_notes: form.medical_notes || null })
        .select('id')
        .single()
      if (error) { setError(error.message); return }
      if (athlete && form.sportIds.length) {
        await supabase.from('athlete_sports').insert(form.sportIds.map((sid) => ({ athlete_id: athlete.id, sport_id: sid })))
      }
    }

    setShowForm(false)
    setEditing(null)
    setEditProfileId(null)
    setForm({ ...empty })
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this athlete?')) return
    await supabase.from('athletes').delete().eq('id', id)
    load()
  }

  function openEdit(r: Athlete) {
    setEditing(r.id)
    setEditProfileId(r.profile?.id ?? null)
    setForm({
      full_name: r.profile?.full_name ?? '',
      sportIds: [],
      dob: r.dob ?? '',
      team_id: '',
      medical_notes: r.medical_notes ?? '',
    })
    setShowForm(true)
    // sport ids come from a follow-up fetch (names are embedded in the list query)
    void supabase
      .from('athlete_sports')
      .select('sport_id')
      .eq('athlete_id', r.id)
      .then(({ data }) => {
        setForm((f) => ({ ...f, sportIds: ((data ?? []) as { sport_id: string }[]).map((d) => d.sport_id) }))
      })
  }

  const age = (dob: string | null) =>
    dob ? Math.floor((Date.now() - new Date(dob).getTime()) / (365.25 * 86400000)) : null

  const sportNames = (r: Athlete) =>
    (r.athlete_sports ?? []).map((x) => x.sports?.name).filter(Boolean).join(', ') || '-'

  return (
    <Box>
      <PageHead
        title="Athletes"
        sub="Roster management - profiles, sports, team and medical notes."
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => { setEditing(null); setEditProfileId(null); setForm({ ...empty }); setShowForm(true) }}>
            Add Athlete
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
          <EmptyState text="No athletes found." />
        ) : (
          <>
            <TableContainer sx={dataTableSx}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell padding="checkbox" sx={{ width: 40 }} />
                    <TableCell>Name</TableCell>
                    <TableCell>Sports</TableCell>
                    <TableCell>Team</TableCell>
                    <TableCell>Age</TableCell>
                    <TableCell>Medical</TableCell>
                    <TableCell align="right">Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filtered
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((r) => (
                      <ExpandableRow
                        key={r.id}
                        chips={[
                          { label: r.teams?.name ?? 'No team', color: 'primary' },
                          { label: r.medical_notes ? 'Medical notes' : 'Medically OK', color: r.medical_notes ? 'warning' : 'success' },
                        ]}
                        detail={[
                          { k: 'Full name', v: r.profile?.full_name ?? '-' },
                          { k: 'Sports', v: sportNames(r) },
                          { k: 'Team', v: r.teams?.name ?? '-' },
                          { k: 'Date of birth', v: r.dob ?? '-' },
                          { k: 'Age', v: age(r.dob) ?? '-' },
                          { k: 'Medical notes', v: r.medical_notes || '-' },
                        ]}
                      >
                        <TableCell onClick={(e) => e.stopPropagation()}>
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
                        <TableCell onClick={(e) => e.stopPropagation()}>{sportNames(r)}</TableCell>
                        <TableCell onClick={(e) => e.stopPropagation()}>{r.teams?.name ?? '-'}</TableCell>
                        <TableCell onClick={(e) => e.stopPropagation()}>{age(r.dob) ?? '-'}</TableCell>
                        <TableCell onClick={(e) => e.stopPropagation()}>
                          {r.medical_notes
                            ? <Badge color="warning">{r.medical_notes.length > 28 ? r.medical_notes.slice(0, 28) + '...' : r.medical_notes}</Badge>
                            : <Badge color="success">OK</Badge>}
                        </TableCell>
                        <TableCell align="right" sx={{ whiteSpace: 'nowrap' }} onClick={(e) => e.stopPropagation()}>
                          <IconButton size="small" onClick={() => openEdit(r)} aria-label="Edit">
                            <EditOutlinedIcon fontSize="small" />
                          </IconButton>
                          <IconButton size="small" color="error" onClick={() => remove(r.id)} aria-label="Delete">
                            <DeleteOutlinedIcon fontSize="small" />
                          </IconButton>
                        </TableCell>
                      </ExpandableRow>
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
          <DialogTitle>{editing ? 'Edit Athlete' : 'Add Athlete'}</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, pt: 0.5 }}>
              <TextField label="Full name" value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} required fullWidth />
              <SportMultiSelect value={form.sportIds} onChange={(v) => setForm({ ...form, sportIds: v })} />
              <TextField type="date" label="Date of birth" value={form.dob} onChange={(e) => setForm({ ...form, dob: e.target.value })} slotProps={{ inputLabel: { shrink: true } }} fullWidth />
              <TextField select label="Team" value={form.team_id} onChange={(e) => setForm({ ...form, team_id: e.target.value })} fullWidth>
                <MenuItem value="">None</MenuItem>
                {teams.map((t) => <MenuItem key={t.id} value={t.id}>{t.name}</MenuItem>)}
              </TextField>
              <Box sx={{ gridColumn: '1 / -1' }}>
                <TextField label="Medical notes" multiline minRows={2} value={form.medical_notes} onChange={(e) => setForm({ ...form, medical_notes: e.target.value })} fullWidth />
              </Box>
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
