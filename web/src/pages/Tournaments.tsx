import { useEffect, useState, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import { PageHead, Badge, EmptyState } from '../components/ui'

type Tournament = {
  id: string
  name: string
  level: string
  start_date: string | null
  end_date: string | null
  venues: { name: string } | null
  matches: { count: number }[] | null
}

const empty = { name: '', level: 'School', start_date: '', end_date: '', venue_id: '' }

const levelColor = (l: string) =>
  l === 'National' ? 'red' : l === 'State' ? 'amber' : l === 'District' ? 'blue' : 'green'

export default function Tournaments() {
  const [rows, setRows] = useState<Tournament[]>([])
  const [venues, setVenues] = useState<{ id: string; name: string }[]>([])
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState({ ...empty })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    const [tr, vn] = await Promise.all([
      supabase.from('tournaments').select('*, venues(name), matches(count)').order('start_date', { ascending: false }),
      supabase.from('venues').select('id, name').order('name'),
    ])
    setRows((tr.data as unknown as Tournament[]) ?? [])
    setVenues((vn.data as { id: string; name: string }[]) ?? [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const filtered = useMemo(
    () => [...rows].sort((a, b) => a.name.localeCompare(b.name)),
    [rows],
  )

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const payload = {
      name: form.name,
      level: form.level,
      start_date: form.start_date || null,
      end_date: form.end_date || null,
      venue_id: form.venue_id || null,
    }
    const { error } = editing
      ? await supabase.from('tournaments').update(payload).eq('id', editing)
      : await supabase.from('tournaments').insert(payload)
    if (error) { setError(error.message); return }
    setShowForm(false)
    setEditing(null)
    setForm({ ...empty })
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this tournament and its matches?')) return
    await supabase.from('tournaments').delete().eq('id', id)
    load()
  }

  function openEdit(t: Tournament) {
    setEditing(t.id)
    setForm({
      name: t.name,
      level: t.level,
      start_date: t.start_date ?? '',
      end_date: t.end_date ?? '',
      venue_id: '',
    })
    setShowForm(true)
  }

  const fmt = (d: string | null) => (d ? new Date(d + 'T00:00:00').toLocaleDateString() : '—')

  return (
    <div>
      <PageHead
        title="Tournaments"
        sub="Competitions across School / District / State / National levels."
        action={<button className="btn" onClick={() => { setEditing(null); setForm({ ...empty }); setShowForm(true) }}>+ Add Tournament</button>}
      />

      <div className="card">
        {loading ? (
          <div className="muted">Loading…</div>
        ) : filtered.length === 0 ? (
          <EmptyState text="No tournaments yet." />
        ) : (
          <table className="data-table">
            <thead>
              <tr><th>Name</th><th>Level</th><th>Dates</th><th>Venue</th><th>Matches</th><th></th></tr>
            </thead>
            <tbody>
              {filtered.map((t) => (
                <tr key={t.id}>
                  <td>{t.name}</td>
                  <td><Badge color={levelColor(t.level)}>{t.level}</Badge></td>
                  <td className="muted">{fmt(t.start_date)} → {fmt(t.end_date)}</td>
                  <td>{t.venues?.name ?? '—'}</td>
                  <td>{t.matches?.[0]?.count ?? 0}</td>
                  <td style={{ textAlign: 'right' }}>
                    <button className="btn secondary small" onClick={() => openEdit(t)}>Edit</button>{' '}
                    <button className="btn danger small" onClick={() => remove(t.id)}>Delete</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {showForm && (
        <div className="modal-backdrop" onClick={() => setShowForm(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>{editing ? 'Edit Tournament' : 'Add Tournament'}</h2>
            <form onSubmit={save}>
              <div className="form-grid">
                <div className="form-row">
                  <label>Name</label>
                  <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
                </div>
                <div className="form-row">
                  <label>Level</label>
                  <select value={form.level} onChange={(e) => setForm({ ...form, level: e.target.value })}>
                    {['School', 'District', 'State', 'National'].map((l) => <option key={l}>{l}</option>)}
                  </select>
                </div>
                <div className="form-row">
                  <label>Start date</label>
                  <input type="date" value={form.start_date} onChange={(e) => setForm({ ...form, start_date: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>End date</label>
                  <input type="date" value={form.end_date} onChange={(e) => setForm({ ...form, end_date: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Venue</label>
                  <select value={form.venue_id} onChange={(e) => setForm({ ...form, venue_id: e.target.value })}>
                    <option value="">— none —</option>
                    {venues.map((v) => <option key={v.id} value={v.id}>{v.name}</option>)}
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
