import { useEffect, useState, useMemo } from 'react'
import { supabase } from '../lib/supabase'
import { PageHead, Badge, statusColor, EmptyState } from '../components/ui'

type Match = {
  id: string
  status: string
  score_a: number | null
  score_b: number | null
  result: string | null
  scheduled_at: string | null
  tournament_id: string | null
  team_a: { id: string; name: string } | null
  team_b: { id: string; name: string } | null
  tournaments: { name: string } | null
}

type Team = { id: string; name: string }
type Tournament = { id: string; name: string }

export default function Matches() {
  const [rows, setRows] = useState<Match[]>([])
  const [teams, setTeams] = useState<Team[]>([])
  const [tournaments, setTournaments] = useState<Tournament[]>([])
  const [filterT, setFilterT] = useState('')
  const [editing, setEditing] = useState<string | null>(null)
  const [form, setForm] = useState({
    tournament_id: '', team_a_id: '', team_b_id: '', scheduled_at: '', status: 'Scheduled',
  })
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    const [m, t, tr] = await Promise.all([
      supabase
        .from('matches')
        .select('*, team_a:teams!matches_team_a_id_fkey(id, name), team_b:teams!matches_team_b_id_fkey(id, name), tournaments(name)')
        .order('scheduled_at', { ascending: false }),
      supabase.from('teams').select('id, name').order('name'),
      supabase.from('tournaments').select('id, name').order('name'),
    ])
    setRows((m.data as unknown as Match[]) ?? [])
    setTeams((t.data as Team[]) ?? [])
    setTournaments((tr.data as Tournament[]) ?? [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const filtered = useMemo(
    () => (filterT ? rows.filter((r) => r.tournament_id === filterT) : rows),
    [rows, filterT],
  )

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    const payload = {
      tournament_id: form.tournament_id || null,
      team_a_id: form.team_a_id || null,
      team_b_id: form.team_b_id || null,
      scheduled_at: form.scheduled_at ? new Date(form.scheduled_at).toISOString() : null,
      status: form.status,
    }
    const { error } = editing
      ? await supabase.from('matches').update(payload).eq('id', editing)
      : await supabase.from('matches').insert(payload)
    if (error) { setError(error.message); return }
    setShowForm(false)
    setEditing(null)
    setForm({ tournament_id: '', team_a_id: '', team_b_id: '', scheduled_at: '', status: 'Scheduled' })
    load()
  }

  async function updateScore(m: Match, side: 'a' | 'b', value: string) {
    const patch = side === 'a' ? { score_a: Number(value) } : { score_b: Number(value) }
    await supabase.from('matches').update(patch).eq('id', m.id)
    load()
  }

  async function setStatus(m: Match, status: string) {
    const patch: Record<string, unknown> = { status }
    if (status === 'Completed') {
      patch.result = `${m.team_a?.name ?? 'A'} ${m.score_a ?? 0} - ${m.score_b ?? 0} ${m.team_b?.name ?? 'B'}`
    }
    await supabase.from('matches').update(patch).eq('id', m.id)
    load()
  }

  async function remove(id: string) {
    if (!confirm('Delete this match?')) return
    await supabase.from('matches').delete().eq('id', id)
    load()
  }

  function openEdit(m?: Match) {
    if (m) {
      setEditing(m.id)
      setForm({
        tournament_id: m.tournament_id ?? '',
        team_a_id: m.team_a?.id ?? '',
        team_b_id: m.team_b?.id ?? '',
        scheduled_at: m.scheduled_at ? m.scheduled_at.slice(0, 16) : '',
        status: m.status,
      })
    } else {
      setEditing(null)
      setForm({ tournament_id: '', team_a_id: '', team_b_id: '', scheduled_at: '', status: 'Scheduled' })
    }
    setShowForm(true)
  }

  const fmt = (iso: string | null) =>
    iso ? new Date(iso).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }) : '—'

  return (
    <div>
      <PageHead
        title="Fixtures & Results"
        sub="Schedule matches, update live scores, record results."
        action={<button className="btn" onClick={() => openEdit()}>+ Add Match</button>}
      />

      <div className="toolbar">
        <select value={filterT} onChange={(e) => setFilterT(e.target.value)}>
          <option value="">All tournaments</option>
          {tournaments.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
        </select>
      </div>

      <div className="card">
        {loading ? (
          <div className="muted">Loading…</div>
        ) : filtered.length === 0 ? (
          <EmptyState text="No matches found." />
        ) : (
          <table className="data-table">
            <thead>
              <tr><th>Match</th><th>Tournament</th><th>When</th><th>Score</th><th>Status</th><th></th></tr>
            </thead>
            <tbody>
              {filtered.map((m) => (
                <tr key={m.id}>
                  <td>{m.team_a?.name ?? 'TBD'} vs {m.team_b?.name ?? 'TBD'}</td>
                  <td className="muted">{m.tournaments?.name ?? '—'}</td>
                  <td className="muted">{fmt(m.scheduled_at)}</td>
                  <td>
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                      <input
                        type="number" min={0} style={{ width: 56, padding: '4px 6px' }}
                        defaultValue={m.score_a ?? 0}
                        onBlur={(e) => Number(e.target.value) !== (m.score_a ?? 0) && updateScore(m, 'a', e.target.value)}
                      />
                      :
                      <input
                        type="number" min={0} style={{ width: 56, padding: '4px 6px' }}
                        defaultValue={m.score_b ?? 0}
                        onBlur={(e) => Number(e.target.value) !== (m.score_b ?? 0) && updateScore(m, 'b', e.target.value)}
                      />
                    </span>
                  </td>
                  <td>
                    <select
                      defaultValue={m.status}
                      onChange={(e) => setStatus(m, e.target.value)}
                      style={{ padding: '4px 8px', fontSize: 12 }}
                    >
                      {['Scheduled', 'Live', 'Completed', 'Cancelled'].map((s) => <option key={s}>{s}</option>)}
                    </select>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <button className="btn secondary small" onClick={() => openEdit(m)}>Edit</button>{' '}
                    <button className="btn danger small" onClick={() => remove(m.id)}>Delete</button>
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
            <h2>{editing ? 'Edit Match' : 'Add Match'}</h2>
            <form onSubmit={save}>
              <div className="form-grid">
                <div className="form-row">
                  <label>Tournament</label>
                  <select value={form.tournament_id} onChange={(e) => setForm({ ...form, tournament_id: e.target.value })}>
                    <option value="">— none —</option>
                    {tournaments.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
                  </select>
                </div>
                <div className="form-row">
                  <label>Status</label>
                  <select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
                    {['Scheduled', 'Live', 'Completed', 'Cancelled'].map((s) => <option key={s}>{s}</option>)}
                  </select>
                </div>
                <div className="form-row">
                  <label>Team A</label>
                  <select value={form.team_a_id} onChange={(e) => setForm({ ...form, team_a_id: e.target.value })}>
                    <option value="">— none —</option>
                    {teams.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
                  </select>
                </div>
                <div className="form-row">
                  <label>Team B</label>
                  <select value={form.team_b_id} onChange={(e) => setForm({ ...form, team_b_id: e.target.value })}>
                    <option value="">— none —</option>
                    {teams.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
                  </select>
                </div>
                <div className="form-row">
                  <label>Scheduled at</label>
                  <input type="datetime-local" value={form.scheduled_at} onChange={(e) => setForm({ ...form, scheduled_at: e.target.value })} />
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
