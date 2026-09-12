import type { ReactNode } from 'react'

export function StatCard({ label, value, sub }: { label: string; value: ReactNode; sub?: string }) {
  return (
    <div className="card stat-card">
      <div className="stat-label">{label}</div>
      <div className="stat-value">{value}</div>
      {sub && <div className="stat-sub">{sub}</div>}
    </div>
  )
}

export function Section({ title, action, children }: { title: string; action?: ReactNode; children: ReactNode }) {
  return (
    <div className="card" style={{ marginBottom: 16 }}>
      <div className="page-head" style={{ marginBottom: 10 }}>
        <h2>{title}</h2>
        {action}
      </div>
      {children}
    </div>
  )
}

export function Badge({ color, children }: { color: 'green' | 'blue' | 'amber' | 'red' | 'gray'; children: ReactNode }) {
  return <span className={`badge ${color}`}>{children}</span>
}

export function PageHead({ title, sub, action }: { title: string; sub?: string; action?: ReactNode }) {
  return (
    <div className="page-head">
      <div>
        <h1>{title}</h1>
        {sub && <p>{sub}</p>}
      </div>
      {action}
    </div>
  )
}

export function EmptyState({ text }: { text: string }) {
  return <div className="empty-state">{text}</div>
}

export function statusColor(status: string): 'green' | 'blue' | 'amber' | 'red' | 'gray' {
  switch (status) {
    case 'Present':
    case 'Completed':
    case 'Active':
      return 'green'
    case 'Live':
    case 'Scheduled':
      return 'blue'
    case 'Late':
    case 'Maintenance':
      return 'amber'
    case 'Absent':
    case 'Cancelled':
      return 'red'
    default:
      return 'gray'
  }
}
