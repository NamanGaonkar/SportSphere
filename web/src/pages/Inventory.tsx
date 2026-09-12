import { useEffect, useState, useMemo, useCallback } from 'react'
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
import TablePagination from '@mui/material/TablePagination'
import Alert from '@mui/material/Alert'
import IconButton from '@mui/material/IconButton'
import Typography from '@mui/material/Typography'
import AddIcon from '@mui/icons-material/Add'
import DeleteOutlinedIcon from '@mui/icons-material/DeleteOutlined'
import { supabase } from '../lib/supabase'
import { PageHead, Badge, EmptyState, LoadingState } from '../components/ui'
import dataTableSx from '../components/tableSx'

type Item = {
  id: string
  name: string
  category: string | null
  quantity: number | null
  condition: string | null
}

export default function Inventory() {
  const [rows, setRows] = useState<Item[]>([])
  const [form, setForm] = useState({ name: '', category: '', quantity: '' })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [showForm, setShowForm] = useState(false)
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)

  const load = useCallback(async () => {
    setLoading(true)
    const { data } = await supabase.from('inventory_items').select('*').order('name')
    setRows((data as Item[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  const lowStock = useMemo(() => rows.filter((r) => (r.quantity ?? 0) < 10), [rows])

  async function add(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const { error } = await supabase.from('inventory_items').insert({
      name: form.name,
      category: form.category || null,
      quantity: form.quantity ? Number(form.quantity) : 0,
    })
    if (error) { setError(error.message); return }
    setForm({ name: '', category: '', quantity: '' })
    setShowForm(false)
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this item?')) return
    await supabase.from('inventory_items').delete().eq('id', id)
    load()
  }

  return (
    <Box>
      <PageHead
        title="Inventory & Equipment"
        sub="Kit and equipment stock levels."
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => setShowForm(true)}>
            Add Item
          </Button>
        }
      />

      {lowStock.length > 0 && (
        <Paper sx={{ p: 2.5, mb: 2 }}>
          <Typography variant="h6" sx={{ color: 'warning.main', mb: 1 }}>
            Low stock ({lowStock.length})
          </Typography>
          {lowStock.map((i) => (
            <Box key={i.id} sx={{ display: 'flex', justifyContent: 'space-between', py: 0.5 }}>
              <Typography variant="body2">{i.name}</Typography>
              <Badge color="warning">{i.quantity} left</Badge>
            </Box>
          ))}
        </Paper>
      )}

      <Paper>
        {loading ? (
          <LoadingState />
        ) : rows.length === 0 ? (
          <EmptyState text="No inventory items yet." />
        ) : (
          <>
            <TableContainer sx={dataTableSx}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Item</TableCell>
                    <TableCell>Category</TableCell>
                    <TableCell>Quantity</TableCell>
                    <TableCell>Condition</TableCell>
                    <TableCell align="right">Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {rows
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((r) => (
                      <TableRow key={r.id} hover>
                        <TableCell>{r.name}</TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>{r.category ?? '-'}</TableCell>
                        <TableCell>{r.quantity ?? 0}</TableCell>
                        <TableCell>{r.condition ?? '-'}</TableCell>
                        <TableCell align="right">
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
              count={rows.length}
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
        <form onSubmit={add}>
          <DialogTitle>Add Inventory Item</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, pt: 0.5 }}>
              <TextField label="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required fullWidth />
              <TextField label="Category" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} fullWidth />
              <TextField type="number" label="Quantity" value={form.quantity} onChange={(e) => setForm({ ...form, quantity: e.target.value })} fullWidth />
            </Box>
            {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setShowForm(false)} color="inherit">Cancel</Button>
            <Button type="submit" variant="contained">Add</Button>
          </DialogActions>
        </form>
      </Dialog>
    </Box>
  )
}
