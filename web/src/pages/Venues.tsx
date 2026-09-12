import { useEffect, useState, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import { PageHead, Badge, statusColor, EmptyState } from '../components/ui'

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

  async function load() {
    setLoading(true)
    const { data } = await supabase
      .from('venues')
      .select('*, venue_bookings(count)')
      .order('name')
    setRows((data as unknown as Venue[]) ?? [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const filtered = useMemo(() => rows, [rows])

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
    <div>
      <PageHead
        title="Venues"
        sub="Grounds, arenas and facilities."
        action={<button className="btn" onClick={() => { setEditing(null); setForm({ ...empty }); setShowForm(true) }}>+ Add Venue</button>}
      />

      <div className="cards">
        {rows.map((v) => (
          <div className="card" key={v.id}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h3 style={{ margin: 0 }}>{v.name}</h3>
              <Badge color={statusColor(v.status)}>{v.status}</Badge>
            </div>
            <div className="muted" style={{ fontSize: 13, marginTop: 6 }}>{v.location ?? '—'}</div>
            <div style={{ fontSize: 13, marginTop: 8 }}>Capacity: {v.capacity?.toLocaleString() ?? '—'}</div>
            <div style={{ marginTop: 12, display: 'flex', gap: 8 }}>
              <button className="btn secondary small" onClick={() => openEdit(v)}>Edit</button>
              <button className="btn danger small" onClick={() => remove(v.id)}>Delete</button>
            </div>
          </div>
        ))}
      </div>

      {rows.length === 0 && !loading && <EmptyState text="No venues yet." />}

      {showForm && (
        <div className="modal-backdrop" onClick={() => setShowForm(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>{editing ? 'Edit Venue' : 'Add Venue'}</h2>
            <form onSubmit={save}>
              <div className="form-grid">
                <div className="form-row">
                  <label>Name</label>
                  <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
                </div>
                <div className="form-row">
                  <label>Location</label>
                  <input value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Capacity</label>
                  <input type="number" min={0} value={form.capacity} onChange={(e) => setForm({ ...form, capacity: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Status</label>
                  <select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
                    {['Active', 'Maintenance', 'Closed'].map((s) => <option key={s}>{s}</option>)}
                  </select>
                </div>
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
