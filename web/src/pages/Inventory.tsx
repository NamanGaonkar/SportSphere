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
import Tabs from '@mui/material/Tabs'
import Tab from '@mui/material/Tab'
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
import LinearProgress from '@mui/material/LinearProgress'
import InputAdornment from '@mui/material/InputAdornment'
import AddIcon from '@mui/icons-material/Add'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import DeleteOutlinedIcon from '@mui/icons-material/DeleteOutlined'
import SearchIcon from '@mui/icons-material/Search'
import SwapVertIcon from '@mui/icons-material/SwapVert'
import { supabase } from '../lib/supabase'
import { useRealtimeTable } from '../lib/hooks'
import { PageHead, Badge, statusColor, EmptyState, LoadingState, StatCard } from '../components/ui'
import ExpandableRow from '../components/ExpandableRow'
import { inr, inrCompact } from '../lib/format'
import dataTableSx from '../components/tableSx'

type Item = {
  id: string
  name: string
  category: string | null
  quantity: number | null
  condition: string | null
  location: string | null
  unit: string | null
  min_stock: number | null
  unit_cost: number | null
  assigned_team_id: string | null
  teams: { name: string } | null
}
type Tx = {
  id: string
  tx_type: string
  quantity: number
  note: string | null
  created_at: string
  inventory_items: { name: string } | null
  profiles: { full_name: string } | null
}

const CONDITIONS = ['New', 'Good', 'Worn', 'Damaged', 'Under maintenance']

/** Detailed equipment management: full item fields + a stock transaction log. */
export default function Inventory() {
  const [rows, setRows] = useState<Item[]>([])
  const [txs, setTxs] = useState<Tx[]>([])
  const [teams, setTeams] = useState<{ id: string; name: string }[]>([])
  const [tab, setTab] = useState(0)
  const [q, setQ] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)

  // add/edit item
  const [showForm, setShowForm] = useState(false)
  const [editing, setEditing] = useState<Item | null>(null)
  const [form, setForm] = useState({ name: '', category: '', quantity: '', condition: 'Good', location: '', unit: 'pcs', min_stock: '', unit_cost: '', assigned_team_id: '' })

  // stock movement
  const [moveFor, setMoveFor] = useState<Item | null>(null)
  const [moveType, setMoveType] = useState('IN')
  const [moveQty, setMoveQty] = useState('')
  const [moveNote, setMoveNote] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    const [items, tx, tm] = await Promise.all([
      supabase.from('inventory_items').select('*, teams(name)').order('name'),
      supabase.from('stock_transactions').select('*, inventory_items(name), profiles(full_name)').order('created_at', { ascending: false }).limit(100),
      supabase.from('teams').select('id, name').order('name'),
    ])
    setRows((items.data as unknown as Item[]) ?? [])
    setTxs((tx.data as unknown as Tx[]) ?? [])
    setTeams((tm.data as { id: string; name: string }[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])
  useRealtimeTable('inventory_items', load)
  useRealtimeTable('stock_transactions', load)

  const filtered = useMemo(() => {
    if (!q) return rows
    const ql = q.toLowerCase()
    return rows.filter((r) =>
      [r.name, r.category, r.location, r.teams?.name].some((v) => (v ?? '').toLowerCase().includes(ql)),
    )
  }, [rows, q])

  const lowStock = useMemo(() => rows.filter((r) => (r.quantity ?? 0) <= (r.min_stock ?? 0)), [rows])
  const totalValue = useMemo(() => rows.reduce((s, r) => s + (r.quantity ?? 0) * (r.unit_cost ?? 0), 0), [rows])
  // inr() imported from lib/format (shared)

  function openAdd() {
    setEditing(null)
    setForm({ name: '', category: '', quantity: '', condition: 'Good', location: '', unit: 'pcs', min_stock: '', unit_cost: '', assigned_team_id: '' })
    setShowForm(true)
  }

  function openEdit(r: Item) {
    setEditing(r)
    setForm({
      name: r.name,
      category: r.category ?? '',
      quantity: String(r.quantity ?? ''),
      condition: r.condition ?? 'Good',
      location: r.location ?? '',
      unit: r.unit ?? 'pcs',
      min_stock: String(r.min_stock ?? ''),
      unit_cost: String(r.unit_cost ?? ''),
      assigned_team_id: r.assigned_team_id ?? '',
    })
    setShowForm(true)
  }

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const payload = {
      name: form.name,
      category: form.category || null,
      quantity: form.quantity === '' ? 0 : Number(form.quantity),
      condition: form.condition,
      location: form.location || null,
      unit: form.unit || 'pcs',
      min_stock: form.min_stock === '' ? 0 : Number(form.min_stock),
      unit_cost: form.unit_cost === '' ? 0 : Number(form.unit_cost),
      assigned_team_id: form.assigned_team_id || null,
    }
    if (!editing && payload.quantity > 0) {
      // create, then log the opening stock as an IN transaction
      const { data, error } = await supabase.from('inventory_items').insert(payload).select('id').single()
      if (error) { setError(error.message); return }
      await supabase.rpc('stock_move', { p_item: data.id, p_type: 'IN', p_qty: payload.quantity, p_note: 'Opening stock' })
    } else {
      const { error } = editing
        ? await supabase.from('inventory_items').update(payload).eq('id', editing.id)
        : await supabase.from('inventory_items').insert(payload)
      if (error) { setError(error.message); return }
    }
    setShowForm(false)
    load()
  }

  async function remove(r: Item) {
    if (!confirm(`Delete "${r.name}"? Its transaction history is removed too.`)) return
    await supabase.from('inventory_items').delete().eq('id', r.id)
    load()
  }

  async function submitMove(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const qty = Number(moveQty)
    if (!moveFor || !qty || qty <= 0) { setError('Enter a valid quantity.'); return }
    const { error } = await supabase.rpc('stock_move', {
      p_item: moveFor.id, p_type: moveType, p_qty: qty, p_note: moveNote || null,
    })
    if (error) { setError(error.message); return }
    setMoveFor(null)
    setMoveQty(''); setMoveNote(''); setMoveType('IN')
    load()
  }

  return (
    <Box>
      <PageHead
        title="Inventory & Equipment"
        sub="Detailed equipment management: stock levels, locations, conditions and movements."
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={openAdd}>
            Add Item
          </Button>
        }
      />

      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: 'repeat(3, 1fr)' }, gap: 2, mb: 2 }}>
        <StatCard label="Items" value={rows.length} sub={`${rows.reduce((s, r) => s + (r.quantity ?? 0), 0)} units in stock`} variant={0} />
        <StatCard label="Low stock" value={lowStock.length} sub="At or below minimum level" variant={4} />
        <StatCard label="Estimated value" value={inrCompact(totalValue)} sub="Quantity x unit cost" variant={2} />
      </Box>

      {lowStock.length > 0 && tab === 0 && (
        <Paper sx={{ p: 2.5, mb: 2 }}>
          <Typography variant="h6" sx={{ color: 'warning.main', mb: 1 }}>
            Low stock ({lowStock.length})
          </Typography>
          {lowStock.map((i) => (
            <Box key={i.id} sx={{ display: 'flex', alignItems: 'center', gap: 2, py: 0.5 }}>
              <Typography variant="body2" sx={{ flex: 1 }}>{i.name}</Typography>
              <Box sx={{ width: 160 }}>
                <LinearProgress
                  variant="determinate"
                  value={Math.min(100, Math.round(((i.quantity ?? 0) / Math.max(1, (i.min_stock ?? 0) * 2)) * 100))}
                  color="warning"
                  sx={{ height: 6, borderRadius: 3 }}
                />
              </Box>
              <Badge color="warning">{i.quantity} left (min {i.min_stock ?? 0})</Badge>
            </Box>
          ))}
        </Paper>
      )}

      <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2 }}>
        <Tab label="Equipment" />
        <Tab label={`Stock movements (${txs.length})`} icon={<SwapVertIcon fontSize="small" />} iconPosition="start" />
      </Tabs>

      {tab === 0 && (
        <>
          <TextField
            size="small"
            placeholder="Search items"
            value={q}
            onChange={(e) => { setQ(e.target.value); setPage(0) }}
            sx={{ mb: 2, width: 280 }}
            slotProps={{ input: { startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment> } }}
          />
          <Paper>
            {loading ? (
              <LoadingState />
            ) : filtered.length === 0 ? (
              <EmptyState text="No inventory items yet." />
            ) : (
              <>
                <TableContainer sx={dataTableSx}>
                  <Table size="small">
                    <TableHead>
                    <TableRow>
                      <TableCell padding="checkbox" sx={{ width: 40 }} />
                      <TableCell>Item</TableCell>
                      <TableCell>Category</TableCell>
                      <TableCell>Stock</TableCell>
                      <TableCell>Level</TableCell>
                      <TableCell>Condition</TableCell>
                      <TableCell>Location</TableCell>
                      <TableCell>Assigned team</TableCell>
                      <TableCell align="right">Actions</TableCell>
                    </TableRow>
                    </TableHead>
                    <TableBody>
                      {filtered
                        .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                        .map((r) => {
                          const min = r.min_stock ?? 0
                          const qty = r.quantity ?? 0
                          const pct = min > 0 ? Math.min(100, Math.round((qty / (min * 2)) * 100)) : 100
                          const low = qty <= min
                          return (
                            <ExpandableRow
                              key={r.id}
                              chips={[
                                { label: low ? 'Low stock' : 'Healthy stock', color: low ? 'warning' : 'success' },
                                { label: `Stock value ${inr(qty * Number(r.unit_cost ?? 0))}`, color: 'primary' },
                              ]}
                              detail={[
                                { k: 'Item', v: r.name },
                                { k: 'Category', v: r.category ?? '-' },
                                { k: 'Stock', v: `${qty} ${r.unit ?? ''} (min ${min})` },
                                { k: 'Condition', v: r.condition ?? '-' },
                                { k: 'Location', v: r.location ?? '-' },
                                { k: 'Assigned team', v: r.teams?.name ?? '-' },
                                { k: 'Unit cost', v: inr(r.unit_cost ?? 0) },
                                { k: 'Total value', v: inr(qty * Number(r.unit_cost ?? 0)) },
                              ]}
                            >
                              <TableCell onClick={(e) => e.stopPropagation()}>
                                <Typography sx={{ fontWeight: 600, fontSize: 13.5 }}>{r.name}</Typography>
                                {r.unit && <Typography variant="caption" sx={{ color: 'text.secondary' }}>unit cost {inr(r.unit_cost ?? 0)}</Typography>}
                              </TableCell>
                              <TableCell onClick={(e) => e.stopPropagation()} sx={{ color: 'text.secondary' }}>{r.category ?? '-'}</TableCell>
                              <TableCell onClick={(e) => e.stopPropagation()} sx={{ fontWeight: 700, color: low ? 'warning.main' : undefined }}>{qty} {r.unit ?? ''}</TableCell>
                              <TableCell onClick={(e) => e.stopPropagation()} sx={{ width: 120 }}>
                                <LinearProgress variant="determinate" value={pct} color={low ? 'warning' : 'success'} sx={{ height: 6, borderRadius: 3 }} />
                              </TableCell>
                              <TableCell onClick={(e) => e.stopPropagation()}><Badge color={statusColor(r.condition === 'Good' || r.condition === 'New' ? 'Active' : r.condition === 'Worn' ? 'Late' : 'Maintenance')}>{r.condition ?? '-'}</Badge></TableCell>
                              <TableCell onClick={(e) => e.stopPropagation()} sx={{ color: 'text.secondary' }}>{r.location ?? '-'}</TableCell>
                              <TableCell onClick={(e) => e.stopPropagation()} sx={{ color: 'text.secondary' }}>{r.teams?.name ?? '-'}</TableCell>
                              <TableCell align="right" sx={{ whiteSpace: 'nowrap' }} onClick={(e) => e.stopPropagation()}>
                                <IconButton size="small" color="primary" onClick={() => { setMoveFor(r); setMoveType('IN'); setMoveQty(''); setMoveNote('') }} aria-label="Stock movement">
                                  <SwapVertIcon fontSize="small" />
                                </IconButton>
                                <IconButton size="small" onClick={() => openEdit(r)} aria-label="Edit">
                                  <EditOutlinedIcon fontSize="small" />
                                </IconButton>
                                <IconButton size="small" color="error" onClick={() => remove(r)} aria-label="Delete">
                                  <DeleteOutlinedIcon fontSize="small" />
                                </IconButton>
                              </TableCell>
                            </ExpandableRow>
                          )
                        })}
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
        </>
      )}

      {tab === 1 && (
        <Paper>
          {loading ? (
            <LoadingState />
          ) : txs.length === 0 ? (
            <EmptyState text="No stock movements yet." />
          ) : (
            <>
              <TableContainer sx={dataTableSx}>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Item</TableCell>
                      <TableCell>Type</TableCell>
                      <TableCell>Qty</TableCell>
                      <TableCell>Note</TableCell>
                      <TableCell>By</TableCell>
                      <TableCell>When</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {txs.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage).map((t) => (
                      <TableRow key={t.id} hover>
                        <TableCell>{t.inventory_items?.name ?? '-'}</TableCell>
                        <TableCell>
                          <Badge color={t.tx_type === 'IN' ? 'success' : t.tx_type === 'OUT' ? 'warning' : t.tx_type === 'MAINTENANCE' ? 'info' : 'default'}>{t.tx_type}</Badge>
                        </TableCell>
                        <TableCell sx={{ fontWeight: 700 }}>{t.quantity}</TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>{t.note ?? '-'}</TableCell>
                        <TableCell>{t.profiles?.full_name ?? '-'}</TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>{new Date(t.created_at).toLocaleString()}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
              <TablePagination
                component="div"
                count={txs.length}
                page={page}
                onPageChange={(_, p) => setPage(p)}
                rowsPerPage={rowsPerPage}
                onRowsPerPageChange={(e) => { setRowsPerPage(Number(e.target.value)); setPage(0) }}
                rowsPerPageOptions={[10, 25, 50]}
              />
            </>
          )}
        </Paper>
      )}

      {/* Add / edit item */}
      <Dialog open={showForm} onClose={() => setShowForm(false)} maxWidth="sm" fullWidth>
        <form onSubmit={save}>
          <DialogTitle>{editing ? `Edit - ${editing.name}` : 'Add Inventory Item'}</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, pt: 0.5 }}>
              <TextField label="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required fullWidth />
              <TextField label="Category" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} fullWidth />
              <TextField type="number" label="Quantity" value={form.quantity} onChange={(e) => setForm({ ...form, quantity: e.target.value })} fullWidth disabled={Boolean(editing)} helperText={editing ? 'Use stock movements to change quantity' : 'Opening stock is logged automatically'} />
              <TextField select label="Condition" value={form.condition} onChange={(e) => setForm({ ...form, condition: e.target.value })} fullWidth>
                {CONDITIONS.map((c) => <MenuItem key={c} value={c}>{c}</MenuItem>)}
              </TextField>
              <TextField label="Location" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} fullWidth />
              <TextField label="Unit" value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })} fullWidth />
              <TextField type="number" label="Minimum stock" value={form.min_stock} onChange={(e) => setForm({ ...form, min_stock: e.target.value })} fullWidth />
              <TextField type="number" label="Unit cost (INR)" value={form.unit_cost} onChange={(e) => setForm({ ...form, unit_cost: e.target.value })} fullWidth />
              <TextField select label="Assigned team" value={form.assigned_team_id} onChange={(e) => setForm({ ...form, assigned_team_id: e.target.value })} fullWidth>
                <MenuItem value="">None</MenuItem>
                {teams.map((t) => <MenuItem key={t.id} value={t.id}>{t.name}</MenuItem>)}
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

      {/* Stock movement */}
      <Dialog open={moveFor !== null} onClose={() => setMoveFor(null)} maxWidth="xs" fullWidth>
        <form onSubmit={submitMove}>
          <DialogTitle>Stock movement - {moveFor?.name}</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gap: 2, pt: 0.5 }}>
              <TextField select label="Type" value={moveType} onChange={(e) => setMoveType(e.target.value)} fullWidth>
                <MenuItem value="IN">IN - stock received</MenuItem>
                <MenuItem value="OUT">OUT - issued / consumed</MenuItem>
                <MenuItem value="MAINTENANCE">MAINTENANCE - sent for repair</MenuItem>
                <MenuItem value="ADJUST">ADJUST - set exact count</MenuItem>
              </TextField>
              <TextField type="number" label="Quantity" value={moveQty} onChange={(e) => setMoveQty(e.target.value)} required fullWidth />
              <TextField label="Note" value={moveNote} onChange={(e) => setMoveNote(e.target.value)} fullWidth />
              {moveFor && (
                <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                  Current stock: {moveFor.quantity} {moveFor.unit ?? ''}
                </Typography>
              )}
            </Box>
            {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setMoveFor(null)} color="inherit">Cancel</Button>
            <Button type="submit" variant="contained">Record movement</Button>
          </DialogActions>
        </form>
      </Dialog>
    </Box>
  )
}
