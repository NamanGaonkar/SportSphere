import { useEffect, useState, useMemo, useCallback } from 'react'
import type { ReactNode } from 'react'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import MenuItem from '@mui/material/MenuItem'
import FormControlLabel from '@mui/material/FormControlLabel'
import Checkbox from '@mui/material/Checkbox'
import Dialog from '@mui/material/Dialog'
import DialogTitle from '@mui/material/DialogTitle'
import DialogContent from '@mui/material/DialogContent'
import DialogActions from '@mui/material/DialogActions'
import Table from '@mui/material/Table'
import TableBody from '@mui/material/TableBody'
import TableCell from '@mui/material/TableCell'
import TableContainer from '@mui/material/TableContainer'
import TableHead from '@mui/material/TableHead'
import TablePagination from '@mui/material/TablePagination'
import TableRow from '@mui/material/TableRow'
import Alert from '@mui/material/Alert'
import InputAdornment from '@mui/material/InputAdornment'
import IconButton from '@mui/material/IconButton'
import AddIcon from '@mui/icons-material/Add'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import DeleteOutlinedIcon from '@mui/icons-material/DeleteOutlined'
import SearchIcon from '@mui/icons-material/Search'
import { supabase } from '../lib/supabase'
import { useCanEdit } from '../lib/permissions'
import { PageHead, EmptyState, LoadingState } from './ui'
import ExpandableRow from './ExpandableRow'
import dataTableSx from './tableSx'
import FileField from './FileField'

export type FieldDef = {
  key: string
  label: string
  type?: 'text' | 'number' | 'date' | 'datetime-local' | 'time' | 'textarea' | 'select' | 'checkbox' | 'file'
  options?: string[]
  source?: { table: string; select: string; valueKey?: string; labelPath: string }
  required?: boolean
  fullWidth?: boolean
}

export type ColumnDef = {
  key: string
  label: string
  render?: (row: Record<string, unknown>) => ReactNode
}

type Option = { value: string; label: string }

function isoToLocalInput(iso: string | null, type?: string): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (isNaN(d.getTime())) return ''
  const pad = (n: number) => n.toString().padStart(2, '0')
  const date = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
  if (type === 'datetime-local') {
    return `${date}T${pad(d.getHours())}:${pad(d.getMinutes())}`
  }
  return date
}

export default function CrudPage({
  title,
  sub,
  table,
  orderBy = 'created_at',
  columns,
  fields,
  searchKeys = [],
}: {
  title: string
  sub: string
  table: string
  orderBy?: string
  columns: ColumnDef[]
  fields: FieldDef[]
  searchKeys?: string[]
}) {
  const [rows, setRows] = useState<Record<string, unknown>[]>([])
  const [sources, setSources] = useState<Record<string, Option[]>>({})
  const [q, setQ] = useState('')
  const [page, setPage] = useState(0)
  const [rowsPerPage, setRowsPerPage] = useState(10)
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState<Record<string, unknown>>({})
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const canEdit = useCanEdit()

  const load = useCallback(async () => {
    setLoading(true)
    const { data } = await supabase.from(table).select('*').order(orderBy, { ascending: false })
    setRows(((data ?? []) as unknown) as Record<string, unknown>[])
    setLoading(false)
  }, [table, orderBy])

  const loadSources = useCallback(async () => {
    const next: Record<string, Option[]> = {}
    for (const f of fields) {
      if (!f.source) continue
      const s = f.source
      const { data } = await supabase.from(s.table).select(s.select)
      next[f.key] = (((data ?? []) as unknown) as Record<string, unknown>[]).map((r) => ({
        value: String(r[s.valueKey ?? 'id']),
        label: String(
          s.labelPath.split('.').reduce<unknown>((o, k) => (o as Record<string, unknown>)?.[k], r) ?? '-',
        ),
      }))
    }
    setSources(next)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fields])

  useEffect(() => {
    load()
    loadSources()
  }, [load, loadSources])

  const filtered = useMemo(() => {
    if (!q || searchKeys.length === 0) return rows
    const ql = q.toLowerCase()
    return rows.filter((r) =>
      searchKeys.some((k) => String(r[k] ?? '').toLowerCase().includes(ql)),
    )
  }, [rows, q, searchKeys])

  function openAdd() {
    const init: Record<string, unknown> = {}
    for (const f of fields) {
      init[f.key] = f.type === 'checkbox' ? false : ''
    }
    setForm(init)
    setEditing(null)
    setShowForm(true)
  }

  function openEdit(row: Record<string, unknown>) {
    const init: Record<string, unknown> = {}
    for (const f of fields) {
      const v = row[f.key]
      if (f.type === 'datetime-local' || f.type === 'date') {
        init[f.key] = isoToLocalInput(v as string | null, f.type)
      } else if (f.type === 'time') {
        // Stored as a timestamp; edit shows just the clock time.
        init[f.key] = v ? new Date(String(v)).toTimeString().slice(0, 5) : ''
      } else if (f.type === 'checkbox') {
        init[f.key] = Boolean(v)
      } else if (f.type === 'textarea' && f.key === 'items') {
        init[f.key] = JSON.stringify(v ?? [], null, 0)
      } else {
        init[f.key] = v ?? ''
      }
    }
    setForm(init)
    setEditing(String(row.id))
    setShowForm(true)
  }

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const payload: Record<string, unknown> = {}
    for (const f of fields) {
      let v = form[f.key]
      if (f.type === 'number') v = v === '' || v === null ? null : Number(v)
      if (f.type === 'datetime-local' && v) v = new Date(String(v)).toISOString()
      if (f.type === 'time' && v) {
        // Time-only fields combine with the row's scheduled date (the DB
        // column is a timestamp); without a date they'd be unparseable.
        const day = String(form.scheduled_date || new Date().toISOString().slice(0, 10))
        v = new Date(`${day}T${v}`).toISOString()
      }
      if (f.type === 'checkbox') v = Boolean(v)
      if (f.type === 'select' && v === '') v = null
      if (f.key === 'items' && typeof v === 'string') {
        try { v = JSON.parse(v || '[]') } catch { setError('Items must be valid JSON'); return }
      }
      if (v === '') v = null
      payload[f.key] = v
    }
    const { error } = editing
      ? await supabase.from(table).update(payload).eq('id', editing)
      : await supabase.from(table).insert(payload)
    if (error) { setError(error.message); return }
    setShowForm(false)
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this record?')) return
    await supabase.from(table).delete().eq('id', id)
    load()
  }

  function displayValue(f: FieldDef, row: Record<string, unknown>): ReactNode {
    const v = row[f.key]
    if (f.type === 'checkbox') return v ? 'Yes' : 'No'
    if (f.type === 'select' && f.source) {
      const opt = (sources[f.key] ?? []).find((o) => o.value === String(v))
      return opt?.label ?? '-'
    }
    if (f.type === 'datetime-local' && v) {
      return new Date(String(v)).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
    }
    if (f.type === 'time' && v) {
      return new Date(String(v)).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })
    }
    if (f.type === 'date' && v) {
      return new Date(String(v) + 'T00:00:00').toLocaleDateString()
    }
    if (v === null || v === undefined || v === '') return '-'
    return String(v)
  }

  return (
    <Box>
      <PageHead
        title={title}
        sub={sub}
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={openAdd}>
            Add
          </Button>
        }
      />

      {searchKeys.length > 0 && (
        <TextField
          size="small"
          placeholder="Search"
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
      )}

      <Paper sx={{ mb: 2 }}>
        {loading ? (
          <LoadingState />
        ) : filtered.length === 0 ? (
          <EmptyState text="No records yet. Use the Add button to create the first one." />
        ) : (
          <>
            <TableContainer sx={dataTableSx}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell padding="checkbox" sx={{ width: 40 }} />
                    {columns.map((c) => <TableCell key={c.key}>{c.label}</TableCell>)}
                    {canEdit && <TableCell align="right" sx={{ width: 96 }}>Actions</TableCell>}
                  </TableRow>
                </TableHead>
                <TableBody>
                  {filtered
                    .slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage)
                    .map((row) => (
                      <ExpandableRow
                        key={String(row.id)}
                        detail={[
                          ...columns.map((c) => ({
                            k: c.label,
                            v: c.render ? c.render(row) : displayValue(fields.find((f) => f.key === c.key) ?? { key: c.key, label: c.label }, row),
                          })),
                          { k: 'Created', v: row.created_at ? new Date(String(row.created_at)).toLocaleString() : '-' },
                        ]}
                      >
                        {columns.map((c) => (
                          <TableCell key={c.key} onClick={(e) => e.stopPropagation()}>
                            {c.render ? c.render(row) : displayValue(fields.find((f) => f.key === c.key) ?? { key: c.key, label: c.label }, row)}
                          </TableCell>
                        ))}
                        <TableCell
                          align="right"
                          onClick={(e) => e.stopPropagation()}
                          sx={
                            canEdit
                              ? { whiteSpace: 'nowrap', width: 96, pr: 2 }
                              : { width: 96, pr: 2 }
                          }
                        >
                          {canEdit && (
                            <>
                              <IconButton size="small" onClick={() => openEdit(row)} aria-label="Edit">
                                <EditOutlinedIcon fontSize="small" />
                              </IconButton>
                              <IconButton size="small" color="error" onClick={() => remove(String(row.id))} aria-label="Delete">
                                <DeleteOutlinedIcon fontSize="small" />
                              </IconButton>
                            </>
                          )}
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
          <DialogTitle>{editing ? 'Edit' : 'Add'} - {title}</DialogTitle>
          <DialogContent dividers>
            <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2, pt: 0.5 }}>
              {fields.map((f) => (
                <Box key={f.key} sx={{ gridColumn: f.fullWidth ? '1 / -1' : undefined }}>
                  {f.type === 'checkbox' ? (
                    <FormControlLabel
                      control={
                        <Checkbox
                          checked={Boolean(form[f.key])}
                          onChange={(e) => setForm({ ...form, [f.key]: e.target.checked })}
                        />
                      }
                      label={f.label}
                    />
                  ) : f.type === 'file' ? (
                    <FileField
                      label={f.label}
                      value={String(form[f.key] ?? '')}
                      onChange={(url) => setForm({ ...form, [f.key]: url })}
                    />
                  ) : f.type === 'textarea' ? (
                    <TextField
                      label={f.label}
                      multiline
                      minRows={2}
                      value={String(form[f.key] ?? '')}
                      onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                      fullWidth
                      required={f.required}
                    />
                  ) : f.type === 'select' ? (
                    <TextField
                      select
                      label={f.label}
                      value={String(form[f.key] ?? '')}
                      onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                      fullWidth
                    >
                      <MenuItem value="">None</MenuItem>
                      {(f.options ?? []).map((o) => <MenuItem key={o} value={o}>{o}</MenuItem>)}
                      {(sources[f.key] ?? []).map((o) => <MenuItem key={o.value} value={o.value}>{o.label}</MenuItem>)}
                    </TextField>
                  ) : (
                    <TextField
                      type={f.type ?? 'text'}
                      label={f.label}
                      value={String(form[f.key] ?? '')}
                      onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                      fullWidth
                      required={f.required}
                      slotProps={f.type === 'date' || f.type === 'datetime-local' || f.type === 'time' ? { inputLabel: { shrink: true } } : undefined}
                    />
                  )}
                </Box>
              ))}
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
