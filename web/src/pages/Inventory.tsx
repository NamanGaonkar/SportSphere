import { useEffect, useState, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import { PageHead, Badge, EmptyState } from '../components/ui'

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

  async function load() {
    setLoading(true)
    const { data } = await supabase.from('inventory_items').select('*').order('name')
    setRows((data as Item[]) ?? [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

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
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this item?')) return
    await supabase.from('inventory_items').delete().eq('id', id)
    load()
  }

  return (
    <div>
      <PageHead title="Inventory & Equipment" sub="Kit and equipment stock levels." />

      <div className="grid-2">
        <div className="card">
          <h2>Add item</h2>
          <form onSubmit={add}>
            <div className="form-grid">
              <div className="form-row">
                <label>Name</label>
                <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
              </div>
              <div className="form-row">
                <label>Category</label>
                <input value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} placeholder="Equipment / Kits / Training" />
              </div>
              <div className="form-row">
                <label>Quantity</label>
                <input type="number" min={0} value={form.quantity} onChange={(e) => setForm({ ...form, quantity: e.target.value })} />
              </div>
            </div>
            {error && <div className="error-text">{error}</div>}
            <button className="btn">Add item</button>
          </form>
        </div>

        <div className="card">
          <h2 style={{ color: lowStock.length ? 'var(--warn)' : undefined }}>Low stock ({lowStock.length})</h2>
          {lowStock.length === 0 ? (
            <div className="muted" style={{ fontSize: 13 }}>All items sufficiently stocked (≥10).</div>
          ) : (
            lowStock.map((i) => (
              <div key={i.id} style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0', fontSize: 13.5 }}>
                <span>{i.name}</span><Badge color="amber">{i.quantity} left</Badge>
              </div>
            ))
          )}
        </div>
      </div>

      <div className="card" style={{ marginTop: 16 }}>
        {loading ? (
          <div className="muted">Loading…</div>
        ) : rows.length === 0 ? (
          <EmptyState text="No inventory items yet." />
        ) : (
          <table className="data-table">
            <thead>
              <tr><th>Item</th><th>Category</th><th>Quantity</th><th>Condition</th><th></th></tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td>{r.name}</td>
                  <td className="muted">{r.category ?? '—'}</td>
                  <td>{r.quantity ?? 0}</td>
                  <td>{r.condition ?? '—'}</td>
                  <td style={{ textAlign: 'right' }}>
                    <button className="btn danger small" onClick={() => remove(r.id)}>Delete</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
