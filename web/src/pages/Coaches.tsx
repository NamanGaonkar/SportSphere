import { useEffect, useState, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import { PageHead, Badge, statusColor, EmptyState } from '../components/ui'

type Coach = {
  id: string
  specialization: string | null
  profile: { id: string; full_name: string; contact_info: string | null } | null
  teams: { id: string; name: string }[] | null
}

const empty = { full_name: '', specialization: '' }

export default function Coaches() {
  const [rows, setRows] = useState<Coach[]>([])
  const [q, setQ] = useState('')
  const [editing, setEditing] = useState<string | null>(null)
  const [editProfileId, setEditProfileId] = useState<string | null>(null)
  const [form, setForm] = useState({ ...empty })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    const { data } = await supabase
      .from('coaches')
      .select('*, profile:profiles(id, full_name, contact_info), teams(id, name)')
      .order('created_at')
    setRows((data as unknown as Coach[]) ?? [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const filtered = useMemo(
    () => rows.filter((r) => (r.profile?.full_name ?? '').toLowerCase().includes(q.toLowerCase())),
    [rows, q],
  )

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (editing && editProfileId) {
      await supabase.from('profiles').update({ full_name: form.full_name }).eq('id', editProfileId)
      const { error } = await supabase
        .from('coaches')
        .update({ specialization: form.specialization || null })
        .eq('id', editing)
      if (error) { setError(error.message); return }
    } else {
      const { data: profile, error: pErr } = await supabase
        .from('profiles')
        .insert({ full_name: form.full_name, role: 'Coach' })
        .select('id')
        .single()
      if (pErr || !profile) { setError(pErr?.message ?? 'Could not create profile'); return }
      const { error } = await supabase.from('coaches').insert({
        profile_id: profile.id,
        specialization: form.specialization || null,
      })
      if (error) { setError(error.message); return }
    }

    setShowForm(false)
    setEditing(null)
    setEditProfileId(null)
    setForm({ ...empty })
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this coach?')) return
    await supabase.from('coaches').delete().eq('id', id)
    load()
  }

  function openEdit(r: Coach) {
    setEditing(r.id)
    setEditProfileId(r.profile?.id ?? null)
    setForm({ full_name: r.profile?.full_name ?? '', specialization: r.specialization ?? '' })
    setShowForm(true)
  }

  return (
    <div>
      <PageHead
        title="Coaches"
        sub="Coaching staff and their specializations."
        action={<button className="btn" onClick={() => { setEditing(null); setEditProfileId(null); setForm({ ...empty }); setShowForm(true) }}>+ Add Coach</button>}
      />

      <div className="toolbar">
        <input placeholder="Search by name…" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>

      <div className="card">
        {loading ? (
          <div className="muted">Loading…</div>
        ) : filtered.length === 0 ? (
          <EmptyState text="No coaches found." />
        ) : (
          <table className="data-table">
            <thead>
              <tr><th>Name</th><th>Specialization</th><th>Teams</th><th></th></tr>
            </thead>
            <tbody>
              {filtered.map((r) => (
                <tr key={r.id}>
                  <td>{r.profile?.full_name ?? '—'}</td>
                  <td>{r.specialization ?? '—'}</td>
                  <td className="muted">{(r.teams ?? []).map((t) => t.name).join(', ') || '—'}</td>
                  <td style={{ textAlign: 'right' }}>
                    <button className="btn secondary small" onClick={() => openEdit(r)}>Edit</button>{' '}
                    <button className="btn danger small" onClick={() => remove(r.id)}>Delete</button>
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
            <h2>{editing ? 'Edit Coach' : 'Add Coach'}</h2>
            <form onSubmit={save}>
              <div className="form-grid">
                <div className="form-row">
                  <label>Full name</label>
                  <input value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} required />
                </div>
                <div className="form-row">
                  <label>Specialization</label>
                  <input value={form.specialization} onChange={(e) => setForm({ ...form, specialization: e.target.value })} placeholder="Football" />
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
