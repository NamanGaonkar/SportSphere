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
import { useRealtimeTable, useSports } from '../lib/hooks'
import { SportFilter } from '../components/SportSelect'
import { PageHead, Badge, statusColor, EmptyState, LoadingState } from '../components/ui'
import dataTableSx from '../components/tableSx'

type Match = {
  id: string
  status: string
  score_a: number | null
  score_b: number | null
  result: string | null
  scheduled_at: string | null
  tournament_id: string | null
  venue_id: string | null
  match_type: string | null
  round_note: string | null
  team_a: { id: string; name: string; sport_id: string | null } | null
  team_b: { id: string; name: string } | null
  tournaments: { name: string } | null
  venues: { name: string } | null
}

type Team = { id: string; name: string; sport_id: string | null }
type Tournament = { id: string; name: string; sport_id: string | null }
type Venue = { id: string; name: string }

export default function Matches() {
  const [rows, setRows] = useState<Match[]>([])
  const [teams, setTeams] = useState<Team[]>([])
  const [tournaments, setTournaments] = useState<Tournament[]>([])
  const [venues, setVenues] = useState<Venue[]>([])
  const [filterT, setFilterT] = useState('')
  const [filterS, setFilterS] = useState('')
  const { byId } = useSports()
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState({
    tournament_id: '', team_a_id: '', team_b_id: '', scheduled_at: '',
    venue_id: '', match_type: 'League Match', round_note: '', status: 'Scheduled',
  })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    const [m, t, tr, vn] = await Promise.all([
      supabase
        .from('matches')
        .select('*, team_a:teams!matches_team_a_id_fkey(id, name, sport_id), team_b:teams!matches_team_b_id_fkey(id, name), tournaments(name, sport_id), venues(name)')
        .order('scheduled_at', { ascending: false }),
      supabase.from('teams').select('id, name, sport_id').order('name'),
      supabase.from('tournaments').select('id, name, sport_id').order('name'),
      supabase.from('venues').select('id, name').order('name'),
    ])
    setRows((m.data as unknown as Match[]) ?? [])
    setTeams((t.data as Team[]) ?? [])
    setTournaments((tr.data as Tournament[]) ?? [])
    setVenues((vn.data as Venue[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])
  useRealtimeTable('matches', load)

  const filtered = useMemo(
    () =>
      rows.filter(
        (r) =>
          (!filterT || r.tournament_id === filterT) &&
          (!filterS || r.team_a?.sport_id === filterS),
      ),
    [rows, filterT, filterS],
  )

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    if (form.team_a_id && form.team_a_id === form.team_b_id) {
      setError('Team A and Team B must be different teams.')
      return
    }
    const payload = {
      tournament_id: form.tournament_id || null,
      team_a_id: form.team_a_id || null,
      team_b_id: form.team_b_id || null,
      scheduled_at: form.scheduled_at ? new Date(form.scheduled_at).toISOString() : null,
      venue_id: form.venue_id || null,
      match_type: form.match_type || null,
      round_note: form.round_note || null,
      status: form.status,
    }
    const { error } = editing
      ? await supabase.from('matches').update(payload).eq('id', editing)
      : await supabase.from('matches').insert(payload)
    if (error) { setError(error.message); return }
    setShowForm(false)
    setEditing(null)
    setForm({ tournament_id: '', team_a_id: '', team_b_id: '', scheduled_at: '', venue_id: '', match_type: 'League Match', round_note: '', status: 'Scheduled' })
    load()
  }

  async function updateScore(m: Match, side: 'a' | 'b', value: string) {
    const patch = side === 'a' ? { score_a: Number(value) } : { score_b: Number(value) }
    await supabase.from('matches').update(patch).eq('id', m.id)
    load()
  }

  async function setStatus(m: Match, status: string) {
    const patch: Record<string, unknown> = { status }
    if (status === 'Completed') {
      patch.result = `${m.team_a?.name ?? 'A'} ${m.score_a ?? 0} - ${m.score_b ?? 0} ${m.team_b?.name ?? 'B'}`
    }
    await supabase.from('matches').update(patch).eq('id', m.id)
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this match?')) return
    await supabase.from('matches').delete().eq('id', id)
    load()
  }

  function openEdit(m?: Match) {
    if (m) {
      setEditing(m.id)
      setForm({
        tournament_id: m.tournament_id ?? '',
        team_a_id: m.team_a?.id ?? '',
        team_b_id: m.team_b?.id ?? '',
        scheduled_at: m.scheduled_at ? m.scheduled_at.slice(0, 16) : '',
        venue_id: m.venue_id ?? '',
        match_type: m.match_type ?? 'League Match',
        round_note: m.round_note ?? '',
        status: m.status === 'Live' ? 'Scheduled' : m.status,
      })
    } else {
      setEditing(null)
      setForm({ tournament_id: '', team_a_id: '', team_b_id: '', scheduled_at: '', venue_id: '', match_type: 'League Match', round_note: '', status: 'Scheduled' })
    }
    setShowForm(true)
  }

  // Picking a tournament narrows team options to that tournament's sport
  // (tester round 2 #9); picking a sport filter narrows them too.
  const formSportId =
    (tournaments.find((t) => t.id === form.tournament_id)?.sport_id) || ''
  const eligibleTeams = useMemo(
    () => teams.filter((t) => !formSportId || t.sport_id === formSportId),
    [teams, formSportId],
  )

  const fmt = (iso: string | null) =>
    iso ? new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }) : '-'

  return (
    <Box>
      <PageHead
        title="Fixtures & Results"
        sub="Schedule matches, record scores per sport, log results."
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => openEdit()}>
            Add Match
          </Button>
        }
      />

      <Box sx={{ display: 'flex', gap: 2, mb: 2, flexWrap: 'wrap' }}>
        <TextField
          select
          size="small"
          value={filterT}
          onChange={(e) => { setFilterT(e.target.value); setPage(0) }}
          sx={{ width: 280 }}
          label="Tournament"
        >
          <MenuItem value="">All tournaments</MenuItem>
          {tournaments.map((t) => <MenuItem key={t.id} value={t.id}>{t.name}</MenuItem>)}
        </TextField>
        <SportFilter value={filterS} onChange={(v) => { setFilterS(v); setPage(0) }} />
      </Box>

      <Paper>
        {loading ? (
          <LoadingState />
        ) : filtered.length === 0 ? (
          <EmptyState text="No matches found." />
        ) : (
          <>
            <TableContainer sx={dataTableSx}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Match</TableCell>
                    <TableCell>Sport</TableCell>
                    <TableCell>Type</TableCell>
                    <TableCell>Tournament</TableCell>
                    <TableCell>Venue</TableCell>
                    <TableCell>When</TableCell>
                    <TableCell>Score</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell align="right">Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filtered
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((m) => (
                      <TableRow key={m.id} hover>
                        <TableCell>{m.team_a?.name ?? 'TBD'} vs {m.team_b?.name ?? 'TBD'}</TableCell>
                        <TableCell>{byId(m.team_a?.sport_id) || '-'}</TableCell>
                        <TableCell>{m.match_type ?? 'League Match'}{m.round_note ? ` - ${m.round_note}` : ''}</TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>{m.tournaments?.name ?? '-'}</TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>{m.venues?.name ?? '-'}</TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>{fmt(m.scheduled_at)}</TableCell>
                        <TableCell>
                          <Box sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.5 }}>
                            <TextField
                              type="number" size="small" sx={{ width: 64 }}
                              defaultValue={m.score_a ?? 0}
                              onBlur={(e) => Number(e.target.value) !== (m.score_a ?? 0) && updateScore(m, 'a', e.target.value)}
                            />
                            <Box component="span">:</Box>
                            <TextField
                              type="number" size="small" sx={{ width: 64 }}
                              defaultValue={m.score_b ?? 0}
                              onBlur={(e) => Number(e.target.value) !== (m.score_b ?? 0) && updateScore(m, 'b', e.target.value)}
                            />
                          </Box>
                        </TableCell>
                        <TableCell>
                          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 0.5 }}>
                            <Badge color={statusColor(m.status)}>{m.status}</Badge>
                            <TextField
                              select size="small" defaultValue={m.status} sx={{ minWidth: 128 }}
                              onChange={(e) => setStatus(m, e.target.value)}
                            >
                              {/* No Live option: scores are final results entered
                                  after play, not a live tracker (tester request). */}
                              {['Scheduled', 'Completed', 'Cancelled'].map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
                            </TextField>
                          </Box>
                        </TableCell>
                        <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                          <IconButton size="small" onClick={() => openEdit(m)} aria-label="Edit">
                            <EditOutlinedIcon fontSize="small" />
                          </IconButton>
                          <IconButton size="small" color="error" onClick={() => remove(m.id)} aria-label="Delete">
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
          <DialogTitle>{editing ? 'Edit Match' : 'Add Match'}</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, pt: 0.5 }}>
              <TextField select label="Tournament" value={form.tournament_id} onChange={(e) => setForm({ ...form, tournament_id: e.target.value, team_a_id: '', team_b_id: '' })} fullWidth>
                <MenuItem value="">None (friendly / practice)</MenuItem>
                {tournaments.map((t) => <MenuItem key={t.id} value={t.id}>{t.name}</MenuItem>)}
              </TextField>
              <TextField select label="Match type" value={form.match_type} onChange={(e) => setForm({ ...form, match_type: e.target.value })} fullWidth>
                {['League Match', 'Tournament Match', 'Quarter Final', 'Semi Final', 'Final', 'Friendly', 'Practice Match'].map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
              </TextField>
              <TextField
                select
                label="Team A"
                value={form.team_a_id}
                onChange={(e) => setForm({ ...form, team_a_id: e.target.value })}
                fullWidth
                // Only teams eligible for the tournament's sport are offered.
              >
                <MenuItem value="">None</MenuItem>
                {eligibleTeams.filter((t) => t.id !== form.team_b_id).map((t) => <MenuItem key={t.id} value={t.id}>{t.name}</MenuItem>)}
              </TextField>
              <TextField
                select
                label="Team B"
                value={form.team_b_id}
                onChange={(e) => setForm({ ...form, team_b_id: e.target.value })}
                fullWidth
              >
                <MenuItem value="">None</MenuItem>
                {eligibleTeams.filter((t) => t.id !== form.team_a_id).map((t) => <MenuItem key={t.id} value={t.id}>{t.name}</MenuItem>)}
              </TextField>
              <TextField select label="Venue" value={form.venue_id} onChange={(e) => setForm({ ...form, venue_id: e.target.value })} fullWidth>
                <MenuItem value="">None</MenuItem>
                {venues.map((v) => <MenuItem key={v.id} value={v.id}>{v.name}</MenuItem>)}
              </TextField>
              <TextField label="Round note (e.g. Leg 2)" value={form.round_note} onChange={(e) => setForm({ ...form, round_note: e.target.value })} fullWidth />
              <TextField
                type="datetime-local" label="Scheduled at" value={form.scheduled_at}
                onChange={(e) => setForm({ ...form, scheduled_at: e.target.value })}
                slotProps={{
                  inputLabel: { shrink: true },
                  // New fixtures cannot be scheduled in the past.
                  htmlInput: { min: editing ? undefined : new Date().toISOString().slice(0, 16) },
                }}
                fullWidth sx={{ gridColumn: '1 / -1' }}
              />
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
