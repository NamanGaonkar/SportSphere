import { useEffect, useState, useCallback } from 'react'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import MenuItem from '@mui/material/MenuItem'
import Dialog from '@mui/material/Dialog'
import DialogTitle from '@mui/material/DialogTitle'
import DialogContent from '@mui/material/DialogContent'
import DialogActions from '@mui/material/DialogActions'
import Alert from '@mui/material/Alert'
import IconButton from '@mui/material/IconButton'
import Typography from '@mui/material/Typography'
import AddIcon from '@mui/icons-material/Add'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import DeleteOutlinedIcon from '@mui/icons-material/DeleteOutlined'
import { supabase } from '../lib/supabase'
import { PageHead, Badge, statusColor, EmptyState, LoadingState } from '../components/ui'

type Venue = {
  id: string
  name: string
  location: string | null
  capacity: number | null
  status: string
  venue_bookings: { count: number }[] | null
}

const empty = { name: '', location: '', capacity: '', status: 'Active' }

export default function Venues() {
  const [rows, setRows] = useState<Venue[]>([])
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState({ ...empty })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    const { data } = await supabase
      .from('venues')
      .select('*, venue_bookings(count)')
      .order('name')
    setRows((data as unknown as Venue[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const payload = {
      name: form.name,
      location: form.location || null,
      capacity: form.capacity ? Number(form.capacity) : null,
      status: form.status,
    }
    const { error } = editing
      ? await supabase.from('venues').update(payload).eq('id', editing)
      : await supabase.from('venues').insert(payload)
    if (error) { setError(error.message); return }
    setShowForm(false)
    setEditing(null)
    setForm({ ...empty })
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this venue?')) return
    await supabase.from('venues').delete().eq('id', id)
    load()
  }

  function openEdit(v: Venue) {
    setEditing(v.id)
    setForm({ name: v.name, location: v.location ?? '', capacity: v.capacity?.toString() ?? '', status: v.status })
    setShowForm(true)
  }

  return (
    <Box>
      <PageHead
        title="Venues"
        sub="Grounds, arenas and facilities."
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => { setEditing(null); setForm({ ...empty }); setShowForm(true) }}>
            Add Venue
          </Button>
        }
      />

      {loading ? (
        <LoadingState />
      ) : rows.length === 0 ? (
        <Paper><EmptyState text="No venues yet." /></Paper>
      ) : (
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, 1fr)', md: 'repeat(3, 1fr)' },
            gap: 2,
          }}
        >
          {rows.map((v) => (
            <Paper key={v.id} sx={{ p: 2.5 }}>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 1 }}>
                <Typography variant="h6">{v.name}</Typography>
                <Badge color={statusColor(v.status)}>{v.status}</Badge>
              </Box>
              <Typography variant="body2" sx={{ color: 'text.secondary', mt: 0.5 }}>{v.location ?? '-'}</Typography>
              <Typography variant="body2" sx={{ mt: 1 }}>
                Capacity: {v.capacity?.toLocaleString() ?? '-'} - Bookings: {v.venue_bookings?.[0]?.count ?? 0}
              </Typography>
              <Box sx={{ mt: 2, display: 'flex', gap: 1, justifyContent: 'flex-end' }}>
                <IconButton size="small" onClick={() => openEdit(v)} aria-label="Edit">
                  <EditOutlinedIcon fontSize="small" />
                </IconButton>
                <IconButton size="small" color="error" onClick={() => remove(v.id)} aria-label="Delete">
                  <DeleteOutlinedIcon fontSize="small" />
                </IconButton>
              </Box>
            </Paper>
          ))}
        </Box>
      )}

      <Dialog open={showForm} onClose={() => setShowForm(false)} maxWidth="sm" fullWidth>
        <form onSubmit={save}>
          <DialogTitle>{editing ? 'Edit Venue' : 'Add Venue'}</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, pt: 0.5 }}>
              <TextField label="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required fullWidth />
              <TextField label="Location" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} fullWidth />
              <TextField type="number" label="Capacity" value={form.capacity} onChange={(e) => setForm({ ...form, capacity: e.target.value })} fullWidth />
              <TextField select label="Status" value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })} fullWidth>
                {['Active', 'Maintenance', 'Closed'].map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
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
