import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { PageHead, EmptyState } from '../components/ui'

type Staff = {
  id: string
  department: string | null
  designation: string | null
  profile: { full_name: string } | null
  payroll: { month: string; gross: number; deductions: number; net: number }[]
}

export default function Staff() {
  const [rows, setRows] = useState<Staff[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  async function load() {
    setLoading(true)
    const { data, error } = await supabase
      .from('staff')
      .select('*, profile:profiles(full_name), payroll(month, gross, deductions, net)')
      .order('created_at')
    if (error) setError(error.message)
    setRows((data as unknown as Staff[]) ?? [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  return (
    <div>
      <PageHead title="Staff & HR" sub="Staff directory and payroll summary." />
      {error && <div className="error-text">{error}</div>}
      <div className="card">
        {loading ? (
          <div className="muted">Loading…</div>
        ) : rows.length === 0 ? (
          <EmptyState text="No staff records yet." />
        ) : (
          <table className="data-table">
            <thead>
              <tr><th>Name</th><th>Department</th><th>Designation</th><th>Latest Payroll (net)</th></tr>
            </thead>
            <tbody>
              {rows.map((s) => {
                const latest = s.payroll?.[s.payroll.length - 1]
                return (
                  <tr key={s.id}>
                    <td>{s.profile?.full_name ?? '—'}</td>
                    <td>{s.department ?? '—'}</td>
                    <td>{s.designation ?? '—'}</td>
                    <td>{latest ? `₹${Number(latest.net).toLocaleString('en-IN')} (${latest.month?.slice(0, 7)})` : '—'}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
