import { useState } from 'react'
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
import Alert from '@mui/material/Alert'
import IconButton from '@mui/material/IconButton'
import AddIcon from '@mui/icons-material/Add'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import DeleteOutlinedIcon from '@mui/icons-material/DeleteOutlined'
import { supabase } from '../lib/supabase'
import { useSports, useRealtimeTable } from '../lib/hooks'
import { PageHead, EmptyState, LoadingState, Badge } from '../components/ui'
import dataTableSx from '../components/tableSx'

type Sport = { id: string; name: string; icon: string | null; sport_type?: string | null; format?: string | null; indoor_outdoor?: string | null }

const empty = { name: '', icon: '', sport_type: 'Team', format: 'League', indoor_outdoor: 'Outdoor' }

export default function Sports() {
  const { sports, refresh } = useSports()
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState({ ...empty })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  useRealtimeTable('sports', refresh)

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setSaving(true)
    const payload = {
      name: form.name.trim(),
      icon: form.icon.trim() || null,
      sport_type: form.sport_type,
      format: form.format,
      indoor_outdoor: form.indoor_outdoor,
    }
    const { error } = editing
      ? await supabase.from('sports').update(payload).eq('id', editing)
      : await supabase.from('sports').insert(payload)
    setSaving(false)
    if (error) { setError(error.message); return }
    setShowForm(false)
    setEditing(null)
    setForm({ ...empty })
    refresh()
  }

  async function remove(id: string) {
    if (!confirm('Delete this sport? Teams, tournaments and training sessions linked to it will simply show no sport.')) return
    const { error } = await supabase.from('sports').delete().eq('id', id)
    if (error) alert(error.message)
    refresh()
  }

  function openEdit(s: Sport) {
    setEditing(s.id)
    setForm({
      name: s.name,
      icon: s.icon ?? '',
      sport_type: s.sport_type ?? 'Team',
      format: s.format ?? 'League',
      indoor_outdoor: s.indoor_outdoor ?? 'Outdoor',
    })
    setShowForm(true)
  }

  return (
    <Box>
      <PageHead
        title="Sports"
        sub="Single source of truth — both the web app and the mobile app read this list live."
        action={
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={() => { setEditing(null); setForm({ ...empty }); setShowForm(true) }}
          >
            Add Sport
          </Button>
        }
      />

      <Paper>
        {sports.length === 0 ? (
          <LoadingState />
        ) : (
          <TableContainer sx={dataTableSx}>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Name</TableCell>
                  <TableCell>Type</TableCell>
                  <TableCell>Format</TableCell>
                  <TableCell>Indoor / Outdoor</TableCell>
                  <TableCell>Icon</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {sports.map((s) => (
                  <TableRow key={s.id} hover>
                    <TableCell sx={{ fontWeight: 600 }}>{s.name}</TableCell>
                    <TableCell>{s.sport_type ?? '-'}</TableCell>
                    <TableCell>{s.format ?? '-'}</TableCell>
                    <TableCell>
                      <Badge color={s.indoor_outdoor === 'Indoor' ? 'info' : 'success'}>{s.indoor_outdoor ?? '-'}</Badge>
                    </TableCell>
                    <TableCell sx={{ color: 'text.secondary' }}>{s.icon ?? '-'}</TableCell>
                    <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                      <IconButton size="small" onClick={() => openEdit(s)} aria-label="Edit">
                        <EditOutlinedIcon fontSize="small" />
                      </IconButton>
                      <IconButton size="small" color="error" onClick={() => remove(s.id)} aria-label="Delete">
                        <DeleteOutlinedIcon fontSize="small" />
                      </IconButton>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        )}
        {sports.length === 0 && <EmptyState text="No sports yet." />}
      </Paper>

      <Dialog open={showForm} onClose={() => setShowForm(false)} maxWidth="xs" fullWidth>
        <form onSubmit={save}>
          <DialogTitle>{editing ? 'Edit Sport' : 'Add Sport'}</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gap: 2, pt: 0.5 }}>
              <TextField label="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required fullWidth />
              <TextField select label="Sport type" value={form.sport_type} onChange={(e) => setForm({ ...form, sport_type: e.target.value })} fullWidth>
                {['Team', 'Individual', 'Mixed'].map((o) => <MenuItem key={o} value={o}>{o}</MenuItem>)}
              </TextField>
              <TextField select label="Format" value={form.format} onChange={(e) => setForm({ ...form, format: e.target.value })} fullWidth>
                {['League', 'Knockout', 'League + Knockout', 'Timed', 'Points'].map((o) => <MenuItem key={o} value={o}>{o}</MenuItem>)}
              </TextField>
              <TextField select label="Indoor / Outdoor" value={form.indoor_outdoor} onChange={(e) => setForm({ ...form, indoor_outdoor: e.target.value })} fullWidth>
                {['Indoor', 'Outdoor'].map((o) => <MenuItem key={o} value={o}>{o}</MenuItem>)}
              </TextField>
              <TextField label="Icon (optional)" value={form.icon} onChange={(e) => setForm({ ...form, icon: e.target.value })} fullWidth />
            </Box>
            {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setShowForm(false)} color="inherit">Cancel</Button>
            <Button type="submit" variant="contained" disabled={saving}>{editing ? 'Save' : 'Add'}</Button>
          </DialogActions>
        </form>
      </Dialog>
    </Box>
  )
}
