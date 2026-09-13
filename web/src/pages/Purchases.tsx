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
import Chip from '@mui/material/Chip'
import AddIcon from '@mui/icons-material/Add'
import DeleteOutlinedIcon from '@mui/icons-material/DeleteOutlined'
import SearchIcon from '@mui/icons-material/Search'
import InputAdornment from '@mui/material/InputAdornment'
import { supabase } from '../lib/supabase'
import { useRealtimeTable } from '../lib/hooks'
import { PageHead, Badge, statusColor, EmptyState, LoadingState, StatCard } from '../components/ui'
import dataTableSx from '../components/tableSx'

type Vendor = { id: string; name: string; contact: string | null; category: string | null }
type PO = {
  id: string
  status: string
  total: number | null
  created_at: string
  vendors: { name: string } | null
}
type LineItem = {
  id: string
  po_id: string
  description: string
  quantity: number
  unit_cost: number | null
  inventory_items: { name: string } | null
  purchase_orders: { status: string; vendors: { name: string } | null } | null
}

const STATUSES = ['Draft', 'Ordered', 'Received', 'Cancelled']

/**
 * Vendors & Purchases — a connected system: purchase orders carry real line
 * items linked to inventory; marking an order "Received" auto-stocks the
 * items and books the expense (DB trigger), and vendors own their orders.
 */
export default function Purchases() {
  const [pos, setPos] = useState<PO[]>([])
  const [items, setItems] = useState<LineItem[]>([])
  const [vendors, setVendors] = useState<Vendor[]>([])
  const [inventory, setInventory] = useState<{ id: string; name: string; unit_cost: number | null }[]>([])
  const [tab, setTab] = useState(0)
  const [q, setQ] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)

  // PO dialog
  const [showPO, setShowPO] = useState(false)
  const [poVendor, setPoVendor] = useState('')
  const [poStatus, setPoStatus] = useState('Draft')
  const [lines, setLines] = useState<{ item_id: string; description: string; quantity: string; unit_cost: string }[]>([])

  // vendor dialog
  const [showVendor, setShowVendor] = useState(false)
  const [vForm, setVForm] = useState({ name: '', contact: '', category: '' })

  const load = useCallback(async () => {
    setLoading(true)
    const [po, li, ve, inv] = await Promise.all([
      supabase.from('purchase_orders').select('id, status, total, created_at, vendors(name)').order('created_at', { ascending: false }),
      supabase.from('purchase_order_items').select('*, inventory_items(name), purchase_orders(status, vendors(name))').order('created_at', { ascending: false }),
      supabase.from('vendors').select('*').order('name'),
      supabase.from('inventory_items').select('id, name, unit_cost').order('name'),
    ])
    setPos((po.data as unknown as PO[]) ?? [])
    setItems((li.data as unknown as LineItem[]) ?? [])
    setVendors((ve.data as Vendor[]) ?? [])
    setInventory((inv.data as { id: string; name: string; unit_cost: number | null }[]) ?? [])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])
  useRealtimeTable('purchase_orders', load)
  useRealtimeTable('purchase_order_items', load)
  useRealtimeTable('vendors', load)

  const filteredPOs = useMemo(() => {
    if (!q) return pos
    const ql = q.toLowerCase()
    return pos.filter((p) => (p.vendors?.name ?? '').toLowerCase().includes(ql) || p.status.toLowerCase().includes(ql))
  }, [pos, q])
  const filteredVendors = useMemo(() => {
    if (!q) return vendors
    const ql = q.toLowerCase()
    return vendors.filter((v) => [v.name, v.contact, v.category].some((s) => (s ?? '').toLowerCase().includes(ql)))
  }, [vendors, q])

  const poValue = (id: string) => items.filter((i) => i.po_id === id).reduce((s, i) => s + i.quantity * Number(i.unit_cost ?? 0), 0)
  const pendingValue = useMemo(
    () => pos.filter((p) => p.status === 'Ordered').reduce((s, p) => s + poValue(p.id), 0),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [pos, items],
  )
  const inr = (n: number) => `Rs ${Math.round(n).toLocaleString('en-IN')}`

  function openPO() {
    setPoVendor(''); setPoStatus('Draft'); setLines([]); setError('')
    setShowPO(true)
  }

  function addLine() {
    setLines((l) => [...l, { item_id: '', description: '', quantity: '1', unit_cost: '' }])
  }

  function applyItem(idx: number, itemId: string) {
    const inv = inventory.find((i) => i.id === itemId)
    setLines((l) => l.map((line, i) =>
      i === idx
        ? { ...line, item_id: itemId, description: inv?.name ?? line.description, unit_cost: inv && !line.unit_cost ? String(inv.unit_cost ?? '') : line.unit_cost }
        : line,
    ))
  }

  function lineTotal() {
    return lines.reduce((s, l) => s + (Number(l.quantity) || 0) * (Number(l.unit_cost) || 0), 0)
  }

  async function savePO(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    if (!poVendor) { setError('Pick a vendor.'); return }
    if (lines.length === 0) { setError('Add at least one line item.'); return }
    const total = lineTotal()
    const { data, error } = await supabase
      .from('purchase_orders')
      .insert({ vendor_id: poVendor, status: poStatus, total, items: lines.map((l) => ({ name: l.description, qty: Number(l.quantity), price: Number(l.unit_cost) })) })
      .select('id')
      .single()
    if (error) { setError(error.message); return }
    const rows = lines
      .filter((l) => l.description.trim())
      .map((l) => ({
        po_id: data.id,
        item_id: l.item_id || null,
        description: l.description.trim(),
        quantity: Number(l.quantity) || 1,
        unit_cost: Number(l.unit_cost) || 0,
      }))
    if (rows.length) {
      const { error: e2 } = await supabase.from('purchase_order_items').insert(rows)
      if (e2) { setError(e2.message); return }
    }
    setShowPO(false)
    load()
  }

  async function setPOStatus(po: PO, status: string) {
    const { error } = await supabase.from('purchase_orders').update({ status }).eq('id', po.id)
    if (error) setError(error.message)
    else load()
  }

  async function saveVendor(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const { error } = await supabase.from('vendors').insert({
      name: vForm.name, contact: vForm.contact || null, category: vForm.category || null,
    })
    if (error) { setError(error.message); return }
    setShowVendor(false)
    setVForm({ name: '', contact: '', category: '' })
    load()
  }

  async function removeVendor(v: Vendor) {
    if (!confirm(`Delete vendor "${v.name}"? Their orders stay but become unlinked.`)) return
    await supabase.from('vendors').delete().eq('id', v.id)
    load()
  }

  return (
    <Box>
      <PageHead
        title="Vendor & Purchase Management"
        sub="Purchase orders with linked line items; receiving an order auto-updates stock."
        action={
          <Box sx={{ display: 'flex', gap: 1 }}>
            <Button variant="outlined" startIcon={<AddIcon />} onClick={() => setShowVendor(true)}>Add Vendor</Button>
            <Button variant="contained" startIcon={<AddIcon />} onClick={openPO}>New Order</Button>
          </Box>
        }
      />

      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: 'repeat(3, 1fr)' }, gap: 2, mb: 2 }}>
        <StatCard label="Purchase orders" value={pos.length} sub={`${pos.filter((p) => p.status === 'Received').length} received`} />
        <StatCard label="Pending delivery" value={pos.filter((p) => p.status === 'Ordered').length} sub={`${inr(pendingValue)} on order`} />
        <StatCard label="Vendors" value={vendors.length} sub="Active supplier directory" />
      </Box>

      {error && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>{error}</Alert>}

      <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2 }}>
        <Tab label="Orders" />
        <Tab label="Line items" />
        <Tab label="Vendors" />
      </Tabs>

      <TextField
        size="small"
        placeholder="Search"
        value={q}
        onChange={(e) => { setQ(e.target.value); setPage(0) }}
        sx={{ mb: 2, width: 280 }}
        slotProps={{ input: { startAdornment: <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment> } }}
      />

      {tab === 0 && (
        <Paper>
          {loading ? (
            <LoadingState />
          ) : filteredPOs.length === 0 ? (
            <EmptyState text="No purchase orders yet." />
          ) : (
            <>
              <TableContainer sx={dataTableSx}>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Vendor</TableCell>
                      <TableCell>Items</TableCell>
                      <TableCell>Total</TableCell>
                      <TableCell>Status</TableCell>
                      <TableCell>Set status</TableCell>
                      <TableCell>Created</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {filteredPOs
                      .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                      .map((p) => (
                        <TableRow key={p.id} hover>
                          <TableCell sx={{ fontWeight: 600 }}>{p.vendors?.name ?? '-'}</TableCell>
                          <TableCell>
                            <Chip size="small" label={`${items.filter((i) => i.po_id === p.id).length} lines`} variant="outlined" />
                          </TableCell>
                          <TableCell sx={{ fontWeight: 700 }}>{inr(poValue(p.id) || Number(p.total ?? 0))}</TableCell>
                          <TableCell><Badge color={statusColor(p.status === 'Received' ? 'Completed' : p.status === 'Ordered' ? 'Live' : p.status)}>{p.status}</Badge></TableCell>
                          <TableCell>
                            <TextField select size="small" value={p.status} onChange={(e) => setPOStatus(p, e.target.value)} sx={{ minWidth: 130 }}>
                              {STATUSES.map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
                            </TextField>
                          </TableCell>
                          <TableCell sx={{ color: 'text.secondary' }}>{new Date(p.created_at).toLocaleDateString()}</TableCell>
                        </TableRow>
                      ))}
                  </TableBody>
                </Table>
              </TableContainer>
              <TablePagination
                component="div" count={filteredPOs.length} page={page}
                onPageChange={(_, p) => setPage(p)}
                rowsPerPage={rowsPerPage}
                onRowsPerPageChange={(e) => { setRowsPerPage(Number(e.target.value)); setPage(0) }}
                rowsPerPageOptions={[10, 25, 50]}
              />
            </>
          )}
        </Paper>
      )}

      {tab === 1 && (
        <Paper>
          {loading ? (
            <LoadingState />
          ) : items.length === 0 ? (
            <EmptyState text="No line items yet." />
          ) : (
            <>
              <TableContainer sx={dataTableSx}>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Description</TableCell>
                      <TableCell>Linked inventory item</TableCell>
                      <TableCell>Qty</TableCell>
                      <TableCell>Unit cost</TableCell>
                      <TableCell>Line total</TableCell>
                      <TableCell>Order</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {items.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage).map((i) => (
                      <TableRow key={i.id} hover>
                        <TableCell sx={{ fontWeight: 600 }}>{i.description}</TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>{i.inventory_items?.name ?? 'Unlinked'}</TableCell>
                        <TableCell>{i.quantity}</TableCell>
                        <TableCell>{inr(Number(i.unit_cost ?? 0))}</TableCell>
                        <TableCell sx={{ fontWeight: 700 }}>{inr(i.quantity * Number(i.unit_cost ?? 0))}</TableCell>
                        <TableCell>
                          {i.purchase_orders?.vendors?.name ?? '-'}
                          <Typography variant="caption" sx={{ display: 'block', color: 'text.secondary' }}>
                            {i.purchase_orders?.status ?? ''}
                          </Typography>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
              <TablePagination
                component="div" count={items.length} page={page}
                onPageChange={(_, p) => setPage(p)}
                rowsPerPage={rowsPerPage}
                onRowsPerPageChange={(e) => { setRowsPerPage(Number(e.target.value)); setPage(0) }
                }
                rowsPerPageOptions={[10, 25, 50]}
              />
            </>
          )}
        </Paper>
      )}

      {tab === 2 && (
        <Paper>
          {loading ? (
            <LoadingState />
          ) : filteredVendors.length === 0 ? (
            <EmptyState text="No vendors yet." />
          ) : (
            <>
              <TableContainer sx={dataTableSx}>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Vendor</TableCell>
                      <TableCell>Contact</TableCell>
                      <TableCell>Category</TableCell>
                      <TableCell>Orders</TableCell>
                      <TableCell align="right">Actions</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {filteredVendors.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage).map((v) => (
                      <TableRow key={v.id} hover>
                        <TableCell sx={{ fontWeight: 600 }}>{v.name}</TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>{v.contact ?? '-'}</TableCell>
                        <TableCell><Chip size="small" label={v.category ?? 'General'} variant="outlined" /></TableCell>
                        <TableCell>{pos.filter((p) => p.vendors?.name === v.name).length}</TableCell>
                        <TableCell align="right">
                          <IconButton size="small" color="error" onClick={() => removeVendor(v)} aria-label="Delete">
                            <DeleteOutlinedIcon fontSize="small" />
                          </IconButton>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
              <TablePagination
                component="div" count={filteredVendors.length} page={page}
                onPageChange={(_, p) => setPage(p)}
                rowsPerPage={rowsPerPage}
                onRowsPerPageChange={(e) => { setRowsPerPage(Number(e.target.value)); setPage(0) }}
                rowsPerPageOptions={[10, 25, 50]}
              />
            </>
          )}
        </Paper>
      )}

      {/* New PO dialog */}
      <Dialog open={showPO} onClose={() => setShowPO(false)} maxWidth="md" fullWidth>
        <form onSubmit={savePO}>
          <DialogTitle>New purchase order</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 2, pt: 0.5, mb: 2 }}>
              <TextField select label="Vendor" value={poVendor} onChange={(e) => setPoVendor(e.target.value)} fullWidth>
                <MenuItem value="">Select vendor</MenuItem>
                {vendors.map((v) => <MenuItem key={v.id} value={v.id}>{v.name}</MenuItem>)}
              </TextField>
              <TextField select label="Status" value={poStatus} onChange={(e) => setPoStatus(e.target.value)} fullWidth>
                {STATUSES.map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
              </TextField>
            </Box>

            <Typography variant="subtitle2" sx={{ mb: 1 }}>Line items</Typography>
            {lines.map((l, idx) => (
              <Box key={idx} sx={{ display: 'grid', gridTemplateColumns: '2fr 1fr 1fr auto', gap: 1, mb: 1, alignItems: 'center' }}>
                <TextField
                  select size="small" label="Inventory item"
                  value={l.item_id}
                  onChange={(e) => applyItem(idx, e.target.value)}
                  fullWidth
                >
                  <MenuItem value="">Custom (no stock link)</MenuItem>
                  {inventory.map((i) => <MenuItem key={i.id} value={i.id}>{i.name}</MenuItem>)}
                </TextField>
                <TextField size="small" type="number" label="Qty" value={l.quantity} onChange={(e) => setLines((ls) => ls.map((x, i2) => i2 === idx ? { ...x, quantity: e.target.value } : x))} />
                <TextField size="small" type="number" label="Unit cost" value={l.unit_cost} onChange={(e) => setLines((ls) => ls.map((x, i2) => i2 === idx ? { ...x, unit_cost: e.target.value } : x))} />
                <IconButton size="small" color="error" onClick={() => setLines((ls) => ls.filter((_, i2) => i2 !== idx))} aria-label="Remove line">
                  <DeleteOutlinedIcon fontSize="small" />
                </IconButton>
              </Box>
            ))}
            <Button size="small" startIcon={<AddIcon />} onClick={addLine}>Add line item</Button>

            <Typography sx={{ mt: 2, fontWeight: 700 }}>Order total: {inr(lineTotal())}</Typography>
            <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
              Marking the order "Received" auto-adds the linked items to stock and books the expense.
            </Typography>
            {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setShowPO(false)} color="inherit">Cancel</Button>
            <Button type="submit" variant="contained">Create order</Button>
          </DialogActions>
        </form>
      </Dialog>

      {/* Add vendor */}
      <Dialog open={showVendor} onClose={() => setShowVendor(false)} maxWidth="xs" fullWidth>
        <form onSubmit={saveVendor}>
          <DialogTitle>Add vendor</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gap: 2, pt: 0.5 }}>
              <TextField label="Name" value={vForm.name} onChange={(e) => setVForm({ ...vForm, name: e.target.value })} required fullWidth />
              <TextField label="Contact" value={vForm.contact} onChange={(e) => setVForm({ ...vForm, contact: e.target.value })} fullWidth />
              <TextField label="Category" value={vForm.category} onChange={(e) => setVForm({ ...vForm, category: e.target.value })} fullWidth />
            </Box>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setShowVendor(false)} color="inherit">Cancel</Button>
            <Button type="submit" variant="contained">Add</Button>
          </DialogActions>
        </form>
      </Dialog>
    </Box>
  )
}
