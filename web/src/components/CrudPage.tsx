import { useEffect, useState, useMemo } from 'react'
import type { ReactNode } from 'react'
import { supabase } from '../lib/supabase'
import { PageHead, EmptyState } from './ui'

export type FieldDef = {
  key: string
  label: string
  type?: 'text' | 'number' | 'date' | 'datetime-local' | 'textarea' | 'select' | 'checkbox'
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
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState<Record<string, unknown>>({})
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    const { data } = await supabase.from(table).select('*').order(orderBy, { ascending: false })
    setRows(((data ?? []) as unknown) as Record<string, unknown>[])
    setLoading(false)
  }

  async function loadSources() {
    const next: Record<string, Option[]> = {}
    for (const f of fields) {
      if (!f.source) continue
      const s = f.source
      const { data } = await supabase.from(s.table).select(s.select)
      next[f.key] = (((data ?? []) as unknown) as Record<string, unknown>[]).map((r) => ({
        value: String(r[s.valueKey ?? 'id']),
        label: String(
          s.labelPath.split('.').reduce<unknown>((o, k) => (o as Record<string, unknown>)?.[k], r) ?? '—',
        ),
      }))
    }
    setSources(next)
  }

  useEffect(() => {
    load()
    loadSources()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

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
      init[f.key] = f.type === 'checkbox' ? false : f.type === 'number' ? '' : ''
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
      return opt?.label ?? '—'
    }
    if (f.type === 'datetime-local' && v) {
      return new Date(String(v)).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
    }
    if (f.type === 'date' && v) {
      return new Date(String(v) + 'T00:00:00').toLocaleDateString()
    }
    if (v === null || v === undefined || v === '') return '—'
    return String(v)
  }

  return (
    <div>
      <PageHead
        title={title}
        sub={sub}
        action={<button className="btn" onClick={openAdd}>+ Add</button>}
      />

      {searchKeys.length > 0 && (
        <div className="toolbar">
          <input placeholder="Search…" value={q} onChange={(e) => setQ(e.target.value)} />
        </div>
      )}

      <div className="card">
        {loading ? (
          <div className="muted">Loading…</div>
        ) : filtered.length === 0 ? (
          <EmptyState text="Nothing here yet — use + Add to create the first record." />
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table className="data-table">
              <thead>
                <tr>
                  {columns.map((c) => <th key={c.key}>{c.label}</th>)}
                  <th style={{ textAlign: 'right' }}></th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((row) => (
                  <tr key={String(row.id)}>
                    {columns.map((c) => (
                      <td key={c.key}>
                        {c.render ? c.render(row) : displayValue(fields.find((f) => f.key === c.key) ?? { key: c.key, label: c.label }, row)}
                      </td>
                    ))}
                    <td style={{ textAlign: 'right' }}>
                      <button className="btn secondary small" onClick={() => openEdit(row)}>Edit</button>{' '}
                      <button className="btn danger small" onClick={() => remove(String(row.id))}>Delete</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {showForm && (
        <div className="modal-backdrop" onClick={() => setShowForm(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>{editing ? 'Edit' : 'Add'} — {title}</h2>
            <form onSubmit={save}>
              <div className="form-grid">
                {fields.map((f) => (
                  <div className="form-row" key={f.key} style={f.fullWidth ? { gridColumn: '1 / -1' } : undefined}>
                    <label>{f.label}</label>
                    {f.type === 'textarea' ? (
                      <textarea
                        value={String(form[f.key] ?? '')}
                        onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                        rows={2}
                      />
                    ) : f.type === 'select' ? (
                      <select
                        value={String(form[f.key] ?? '')}
                        onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                      >
                        <option value="">— none —</option>
                        {(f.options ?? []).map((o) => <option key={o}>{o}</option>)}
                        {(sources[f.key] ?? []).map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
                      </select>
                    ) : f.type === 'checkbox' ? (
                      <input
                        type="checkbox"
                        checked={Boolean(form[f.key])}
                        onChange={(e) => setForm({ ...form, [f.key]: e.target.checked })}
                        style={{ width: 18, height: 18 }}
                      />
                    ) : (
                      <input
                        type={f.type ?? 'text'}
                        value={String(form[f.key] ?? '')}
                        onChange={(e) => setForm({ ...form, [f.key]: e.target.value })}
                        required={f.required}
                      />
                    )}
                  </div>
                ))}
              </div>
              {error && <div className="error-text">{error}</div>}
              <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
                <button type="button" className="btn secondary" onClick={() => setShowForm(false)}>Cancel</button>
                <button className="btn">{editing ? 'Save' : 'Add'}</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
