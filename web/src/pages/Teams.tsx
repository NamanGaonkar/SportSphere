import { useEffect, useState, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import { PageHead, EmptyState } from '../components/ui'

type Team = {
  id: string
  name: string
  sport: string
  coach_id: string | null
  coaches: { profile: { full_name: string } | null } | null
  athletes: { count: number }[] | null
}

const empty = { name: '', sport: '', coach_id: '' }

export default function Teams() {
  const [rows, setRows] = useState<Team[]>([])
  const [coaches, setCoaches] = useState<{ id: string; profile: { full_name: string } | null }[]>([])
  const [q, setQ] = useState('')
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState({ ...empty })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    const [tm, co] = await Promise.all([
      supabase.from('teams').select('*, coaches(*, profile:profiles(full_name)), athletes(count)').order('name'),
      supabase.from('coaches').select('id, profile:profiles(full_name)').order('id'),
    ])
    setRows((tm.data as unknown as Team[]) ?? [])
    setCoaches((co.data as unknown as { id: string; profile: { full_name: string } | null }[]) ?? [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const filtered = useMemo(() => rows.filter((r) => r.name.toLowerCase().includes(q.toLowerCase())), [rows, q])

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const payload = {
      name: form.name,
      sport: form.sport,
      coach_id: form.coach_id || null,
    }
    const { error } = editing
      ? await supabase.from('teams').update(payload).eq('id', editing)
      : await supabase.from('teams').insert(payload)
    if (error) { setError(error.message); return }
    setShowForm(false)
    setEditing(null)
    setForm({ ...empty })
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this team? Athletes will be unlinked.')) return
    await supabase.from('teams').delete().eq('id', id)
    load()
  }

  function openEdit(t: Team) {
    setEditing(t.id)
    setForm({ name: t.name, sport: t.sport, coach_id: t.coach_id ?? '' })
    setShowForm(true)
  }

  return (
    <div>
      <PageHead
        title="Teams"
        sub="Squads by sport, with coach assignment and roster size."
        action={<button className="btn" onClick={() => { setEditing(null); setForm({ ...empty }); setShowForm(true) }}>+ Add Team</button>}
      />

      <div className="toolbar">
        <input placeholder="Search teams…" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>

      <div className="card">
        {loading ? (
          <div className="muted">Loading…</div>
        ) : filtered.length === 0 ? (
          <EmptyState text="No teams found." />
        ) : (
          <table className="data-table">
            <thead>
              <tr><th>Name</th><th>Sport</th><th>Coach</th><th>Roster</th><th></th></tr>
            </thead>
            <tbody>
              {filtered.map((t) => (
                <tr key={t.id}>
                  <td>{t.name}</td>
                  <td>{t.sport}</td>
                  <td>{t.coaches?.profile?.full_name ?? '—'}</td>
                  <td>{t.athletes?.[0]?.count ?? 0} athletes</td>
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
            <h2>{editing ? 'Edit Team' : 'Add Team'}</h2>
            <form onSubmit={save}>
              <div className="form-grid">
                <div className="form-row">
                  <label>Name</label>
                  <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
                </div>
                <div className="form-row">
                  <label>Sport</label>
                  <input value={form.sport} onChange={(e) => setForm({ ...form, sport: e.target.value })} required />
                </div>
                <div className="form-row">
                  <label>Coach</label>
                  <select value={form.coach_id} onChange={(e) => setForm({ ...form, coach_id: e.target.value })}>
                    <option value="">— none —</option>
                    {coaches.map((c) => (
                      <option key={c.id} value={c.id}>{c.profile?.full_name ?? 'Coach'}</option>
                    ))}
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
