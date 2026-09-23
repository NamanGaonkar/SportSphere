import { useEffect, useState, useMemo, useCallback } from 'react'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import MenuItem from '@mui/material/MenuItem'
import Chip from '@mui/material/Chip'
import Typography from '@mui/material/Typography'
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
import AddPhotoAlternateOutlinedIcon from '@mui/icons-material/AddPhotoAlternateOutlined'
import UploadFileIcon from '@mui/icons-material/UploadFile'
import { supabase } from '../lib/supabase'
import { useRealtimeTable } from '../lib/hooks'
import { useRole } from '../lib/permissions'
import { SportSelect, SportFilter } from '../components/SportSelect'
import { PageHead, EmptyState, LoadingState } from '../components/ui'
import dataTableSx from '../components/tableSx'

/** Image upload bound to the `documents` bucket — a real file picker,
 *  not a text field. value/onChange carry the public URL. */
function LogoField({ value, onChange }: { value: string; onChange: (url: string) => void }) {
  const [busy, setBusy] = useState(false)
  async function pick(file: File | null) {
    if (!file) return
    setBusy(true)
    try {
      const path = `team_logos/${Date.now()}_${file.name.replace(/\s+/g, '_')}`
      const { error } = await supabase.storage.from('documents').upload(path, file, { upsert: true })
      if (error) throw error
      const { data } = supabase.storage.from('documents').getPublicUrl(path)
      onChange(data.publicUrl)
    } finally {
      setBusy(false)
    }
  }
  return (
    <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
      {value ? (
        <Avatar src={value} sx={{ width: 56, height: 56, bgcolor: 'rgba(255,106,19,0.15)' }} variant="rounded" />
      ) : (
        <Avatar sx={{ width: 56, height: 56, bgcolor: 'rgba(255,106,19,0.15)' }} variant="rounded">
          <AddPhotoAlternateOutlinedIcon />
        </Avatar>
      )}
      <Box>
        <Button variant="outlined" component="label" size="small" disabled={busy} startIcon={<UploadFileIcon />} sx={{ textTransform: 'none' }}>
          {busy ? 'Uploading…' : value ? 'Replace logo' : 'Upload logo (PNG/JPG)'}
          <input type="file" hidden accept="image/png,image/jpeg,image/webp" onChange={(e) => pick(e.target.files?.[0] ?? null)} />
        </Button>
        {value && (
          <Button size="small" color="inherit" sx={{ display: 'block', textTransform: 'none' }} onClick={() => onChange('')}>
            Remove
          </Button>
        )}
      </Box>
    </Box>
  )
}

type Team = {
  id: string
  name: string
  sport_id: string | null
  coach_id: string | null
  logo_url: string | null
  sports: { name: string } | null
  coaches: { profile: { full_name: string } | null } | null
  athletes: { count: number }[] | null
  athlete_profiles?: { profile: { full_name: string } | null }[] | null
}

type TeamForm = { name: string; sport_id: string; coach_id: string; logo_url: string; athleteList?: { id: string; name: string }[] }
const empty: TeamForm = { name: '', sport_id: '', coach_id: '', logo_url: '' }

export default function Teams() {
  const [rows, setRows] = useState<Team[]>([])
  const [coaches, setCoaches] = useState<{ id: string; profile: { full_name: string } | null }[]>([])
  const [q, setQ] = useState('')
  const [filterS, setFilterS] = useState('')
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState<TeamForm>({ ...empty })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  // Venue managers are read-only on teams (tester round 2: no edit/delete).
  const role = useRole()
  const canEdit = role !== 'VenueManager' && role !== 'Athlete'

  const load = useCallback(async () => {
    const [tm, co] = await Promise.all([
      supabase.from('teams').select('*, sports(name), coaches(*, profile:profiles(full_name)), athletes(count), athlete_profiles:athletes(profile:profiles(full_name))').order('name'),
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
      logo_url: form.logo_url || null,
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
    setForm({
      name: t.name,
      sport_id: t.sport_id ?? '',
      coach_id: t.coach_id ?? '',
      logo_url: t.logo_url ?? '',
      // Roster read-only inside the edit dialog (tester: see who is in the team).
      athleteList: (t.athlete_profiles ?? []).map((p) => ({
        id: p.profile?.full_name ?? '?',
        name: p.profile?.full_name ?? '-',
      })),
    })
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
                    {canEdit && <TableCell align="right" sx={{ width: 96 }}>Actions</TableCell>}
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filtered
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((t) => (
                      <TableRow key={t.id} hover>
                        <TableCell>
                          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.25 }}>
                            {/* Team badge with fallback to the initial. */}
                            <Avatar
                              src={t.logo_url ?? undefined}
                              variant="rounded"
                              sx={{ width: 30, height: 30, fontSize: 13, bgcolor: 'rgba(255,106,19,0.18)', color: '#B25A1F', fontWeight: 700, borderRadius: 1 }}
                            >
                              {t.name.slice(0, 1).toUpperCase()}
                            </Avatar>
                            {t.name}
                          </Box>
                        </TableCell>
                        <TableCell>{t.sports?.name ?? '-'}</TableCell>
                        <TableCell>{t.coaches?.profile?.full_name ?? '-'}</TableCell>
                        <TableCell>
                          {t.athletes?.[0]?.count
                            ? `${t.athletes[0].count} athletes`
                            : 'No athletes'}
                        </TableCell>
                        {canEdit && (
                          <TableCell align="right" sx={{ whiteSpace: 'nowrap', width: 96, pr: 2 }}>
                            <IconButton size="small" onClick={() => openEdit(t)} aria-label="Edit">
                              <EditOutlinedIcon fontSize="small" />
                            </IconButton>
                            <IconButton size="small" color="error" onClick={() => remove(t.id)} aria-label="Delete">
                              <DeleteOutlinedIcon fontSize="small" />
                            </IconButton>
                          </TableCell>
                        )}
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
              <Box sx={{ gridColumn: '1 / -1' }}>
                {/* Real image upload — replaces the old plain text field. */}
                <LogoField value={form.logo_url} onChange={(url) => setForm({ ...form, logo_url: url })} />
              </Box>
            </Box>
            {editing && (form.athleteList?.length ?? 0) > 0 && (
              <Box sx={{ mt: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>Squad</Typography>
                <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.75 }}>
                  {(form.athleteList as { id: string; name: string }[]).map((a) => (
                    <Chip key={a.id} size="small" label={a.name} />
                  ))
                  }
                </Box>
              </Box>
            )}
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
