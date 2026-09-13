import { useState } from 'react'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
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
import { useSports } from '../lib/hooks'
import { PageHead, EmptyState, LoadingState } from '../components/ui'
import dataTableSx from '../components/tableSx'

export default function Sports() {
  const { sports, byId } = useSports()
  const [editing, setEditing] = useState<string | null>(null)
  const [name, setName] = useState('')
  const [icon, setIcon] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setSaving(true)
    const payload = { name: name.trim(), icon: icon.trim() || null }
    const { error } = editing
      ? await supabase.from('sports').update(payload).eq('id', editing)
      : await supabase.from('sports').insert(payload)
    setSaving(false)
    if (error) { setError(error.message); return }
    setShowForm(false)
    setEditing(null)
    setName('')
    setIcon('')
  }

  async function remove(id: string) {
    if (!confirm('Delete this sport? Teams, tournaments and training sessions linked to it will simply show no sport.')) return
    const { error } = await supabase.from('sports').delete().eq('id', id)
    if (error) alert(error.message)
  }

  function openEdit(id: string) {
    setEditing(id)
    setName(byId(id))
    setIcon(sports.find((s) => s.id === id)?.icon ?? '')
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
            onClick={() => { setEditing(null); setName(''); setIcon(''); setShowForm(true) }}
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
                  <TableCell>Icon</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {sports.map((s) => (
                  <TableRow key={s.id} hover>
                    <TableCell>{s.name}</TableCell>
                    <TableCell sx={{ color: 'text.secondary' }}>{s.icon ?? '-'}</TableCell>
                    <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                      <IconButton size="small" onClick={() => openEdit(s.id)} aria-label="Edit">
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
              <TextField label="Name" value={name} onChange={(e) => setName(e.target.value)} required fullWidth />
              <TextField label="Icon (emoji, optional)" value={icon} onChange={(e) => setIcon(e.target.value)} fullWidth />
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
