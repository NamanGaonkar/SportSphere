import { useEffect, useState, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import { PageHead, Badge, statusColor, EmptyState } from '../components/ui'

type Athlete = {
  id: string
  dob: string | null
  sport: string | null
  medical_notes: string | null
  profile_id: string
  profile: { id: string; full_name: string; contact_info: string | null } | null
  teams: { name: string } | null
}
type Team = { id: string; name: string }

const empty = { full_name: '', sport: '', dob: '', team_id: '', medical_notes: '' }

export default function Athletes() {
  const [rows, setRows] = useState<Athlete[]>([])
  const [teams, setTeams] = useState<Team[]>([])
  const [q, setQ] = useState('')
  const [editing, setEditing] = useState<string | null>(null)
  const [editProfileId, setEditProfileId] = useState<string | null>(null)
  const [form, setForm] = useState({ ...empty })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    const [ath, tm] = await Promise.all([
      supabase.from('athletes').select('*, profile:profiles(id, full_name, contact_info), teams(name)').order('created_at'),
      supabase.from('teams').select('id, name').order('name'),
    ])
    setRows((ath.data as unknown as Athlete[]) ?? [])
    setTeams((tm.data as Team[]) ?? [])
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
      const { error: pErr } = await supabase
        .from('profiles')
        .update({ full_name: form.full_name })
        .eq('id', editProfileId)
      if (pErr) { setError(pErr.message); return }
      const { error } = await supabase
        .from('athletes')
        .update({
          sport: form.sport || null,
          dob: form.dob || null,
          team_id: form.team_id || null,
          medical_notes: form.medical_notes || null,
        })
        .eq('id', editing)
      if (error) { setError(error.message); return }
    } else {
      // Roster-only profile (no login). Later, linking an auth user enables sign-in.
      const { data: profile, error: pErr } = await supabase
        .from('profiles')
        .insert({ full_name: form.full_name, role: 'Athlete', contact_info: null })
        .select('id')
        .single()
      if (pErr || !profile) { setError(pErr?.message ?? 'Could not create profile'); return }
      const { error } = await supabase.from('athletes').insert({
        profile_id: profile.id,
        sport: form.sport || null,
        dob: form.dob || null,
        team_id: form.team_id || null,
        medical_notes: form.medical_notes || null,
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
    if (!confirm('Delete this athlete?')) return
    await supabase.from('athletes').delete().eq('id', id)
    load()
  }

  function openEdit(r: Athlete) {
    setEditing(r.id)
    setEditProfileId(r.profile?.id ?? null)
    setForm({
      full_name: r.profile?.full_name ?? '',
      sport: r.sport ?? '',
      dob: r.dob ?? '',
      team_id: '',
      medical_notes: r.medical_notes ?? '',
    })
    setShowForm(true)
  }

  const age = (dob: string | null) =>
    dob ? Math.floor((Date.now() - new Date(dob).getTime()) / (365.25 * 86400000)) : null

  return (
    <div>
      <PageHead
        title="Athletes"
        sub="Roster management — profiles, sport, team and medical notes."
        action={<button className="btn" onClick={() => { setEditing(null); setEditProfileId(null); setForm({ ...empty }); setShowForm(true) }}>+ Add Athlete</button>}
      />

      <div className="toolbar">
        <input placeholder="Search by name…" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>

      <div className="card">
        {loading ? (
          <div className="muted">Loading…</div>
        ) : filtered.length === 0 ? (
          <EmptyState text="No athletes found." />
        ) : (
          <table className="data-table">
            <thead>
              <tr><th>Name</th><th>Sport</th><th>Team</th><th>Age</th><th>Medical</th><th></th></tr>
            </thead>
            <tbody>
              {filtered.map((r) => (
                <tr key={r.id}>
                  <td>{r.profile?.full_name ?? '—'}</td>
                  <td>{r.sport ?? '—'}</td>
                  <td>{r.teams?.name ?? '—'}</td>
                  <td>{age(r.dob) ?? '—'}</td>
                  <td>
                    {r.medical_notes
                      ? <Badge color={statusColor('Absent')}>⚠ {r.medical_notes.slice(0, 30)}</Badge>
                      : <Badge color="green">OK</Badge>}
                  </td>
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
            <h2>{editing ? 'Edit Athlete' : 'Add Athlete'}</h2>
            <form onSubmit={save}>
              <div className="form-grid">
                <div className="form-row">
                  <label>Full name</label>
                  <input value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} required />
                </div>
                <div className="form-row">
                  <label>Sport</label>
                  <input value={form.sport} onChange={(e) => setForm({ ...form, sport: e.target.value })} placeholder="Football" />
                </div>
                <div className="form-row">
                  <label>Date of birth</label>
                  <input type="date" value={form.dob} onChange={(e) => setForm({ ...form, dob: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Team</label>
                  <select value={form.team_id} onChange={(e) => setForm({ ...form, team_id: e.target.value })}>
                    <option value="">— none —</option>
                    {teams.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
                  </select>
                </div>
              </div>
              <div className="form-row">
                <label>Medical notes</label>
                <textarea value={form.medical_notes} onChange={(e) => setForm({ ...form, medical_notes: e.target.value })} rows={2} />
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
