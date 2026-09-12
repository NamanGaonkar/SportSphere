import { useEffect, useState, createContext, useContext } from 'react'
import { Routes, Route, NavLink, Navigate, useNavigate } from 'react-router-dom'
import type { User } from '@supabase/supabase-js'
import { supabase } from './lib/supabase'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Athletes from './pages/Athletes'
import Coaches from './pages/Coaches'
import Teams from './pages/Teams'
import Tournaments from './pages/Tournaments'
import Matches from './pages/Matches'
import Venues from './pages/Venues'
import Attendance from './pages/Attendance'
import Staff from './pages/Staff'
import Inventory from './pages/Inventory'
import Reports from './pages/Reports'
import {
  Purchases, Housekeeping, Training, Performance, Medical,
  EventsPage, Transport, Accommodation, Expenses, Activities,
} from './pages/modules'
import './App.css'

export type Profile = {
  id: string
  full_name: string
  role: 'Admin' | 'Coach' | 'Athlete' | 'HR' | 'Finance' | 'VenueManager'
  avatar_url: string | null
  contact_info: string | null
}

type Session = { user: User; profile: Profile } | null

const SessionContext = createContext<Session>(null)
export const useSession = () => useContext(SessionContext)

const NAV_SECTIONS: { section: string; items: { to: string; label: string; roles?: string[] }[] }[] = [
  {
    section: 'Overview',
    items: [
      { to: '/', label: 'Dashboard' },
      { to: '/reports', label: 'Reports' },
    ],
  },
  {
    section: 'People',
    items: [
      { to: '/athletes', label: 'Athletes' },
      { to: '/coaches', label: 'Coaches' },
      { to: '/teams', label: 'Teams' },
      { to: '/staff', label: 'Staff & HR' },
    ],
  },
  {
    section: 'Competitions',
    items: [
      { to: '/tournaments', label: 'Tournaments' },
      { to: '/matches', label: 'Fixtures & Results' },
      { to: '/venues', label: 'Venues' },
    ],
  },
  {
    section: 'Operations',
    items: [
      { to: '/attendance', label: 'Attendance & Leave' },
      { to: '/inventory', label: 'Inventory' },
      { to: '/housekeeping', label: 'Housekeeping' },
      { to: '/purchases', label: 'Vendors & Purchases' },
      { to: '/expenses', label: 'Finance & Expenses', roles: ['Admin', 'Finance', 'HR'] },
    ],
  },
  {
    section: 'Programs & Logistics',
    items: [
      { to: '/training', label: 'Training & Camps' },
      { to: '/activities', label: 'School Activities' },
      { to: '/events', label: 'Events' },
      { to: '/transport', label: 'Transport' },
      { to: '/accommodation', label: 'Accommodation' },
    ],
  },
  {
    section: 'Athlete Care',
    items: [
      { to: '/performance', label: 'Performance' },
      { to: '/medical', label: 'Medical' },
    ],
  },
]

export default function App() {
  const [session, setSession] = useState<Session>(null)
  const [loading, setLoading] = useState(true)
  const navigate = useNavigate()

  useEffect(() => {
    supabase.auth.getSession().then(async ({ data }) => {
      if (data.session) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', data.session.user.id)
          .single()
        setSession({ user: data.session.user, profile: profile as Profile })
      }
      setLoading(false)
    })

    const { data: sub } = supabase.auth.onAuthStateChange(async (_event, newSession) => {
      if (newSession) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', newSession.user.id)
          .single()
        setSession({ user: newSession.user, profile: profile as Profile })
      } else {
        setSession(null)
      }
    })

    return () => sub.subscription.unsubscribe()
  }, [])

  if (loading) {
    return <div className="auth-wrap"><div className="muted">Loading SportSphere…</div></div>
  }

  if (!session) {
    return (
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    )
  }

  const role = session.profile?.role ?? 'Athlete'
  const canSee = (roles?: string[]) => !roles || roles.includes(role)

  return (
    <SessionContext.Provider value={session}>
      <div className="app-shell">
        <aside className="sidebar">
          <div className="logo">Sport<span>Sphere</span></div>
          {NAV_SECTIONS.map((s) => (
            <div key={s.section}>
              <div className="section">{s.section}</div>
              {s.items.filter((i) => canSee(i.roles)).map((i) => (
                <NavLink key={i.to} to={i.to} end={i.to === '/'} className={({ isActive }) => (isActive ? 'active' : '')}>
                  {i.label}
                </NavLink>
              ))}
            </div>
          ))}
          <div className="foot">
            <div>{session.profile?.full_name ?? session.user.email}</div>
            <div style={{ opacity: 0.7 }}>{role}</div>
            <button
              onClick={async () => {
                await supabase.auth.signOut()
                navigate('/login')
              }}
            >
              Sign out
            </button>
          </div>
        </aside>
        <main className="main">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/reports" element={<Reports />} />
            <Route path="/athletes" element={<Athletes />} />
            <Route path="/coaches" element={<Coaches />} />
            <Route path="/teams" element={<Teams />} />
            <Route path="/staff" element={<Staff />} />
            <Route path="/tournaments" element={<Tournaments />} />
            <Route path="/matches" element={<Matches />} />
            <Route path="/venues" element={<Venues />} />
            <Route path="/attendance" element={<Attendance />} />
            <Route path="/inventory" element={<Inventory />} />
            <Route path="/housekeeping" element={<Housekeeping />} />
            <Route path="/purchases" element={<Purchases />} />
            <Route path="/expenses" element={<Expenses />} />
            <Route path="/training" element={<Training />} />
            <Route path="/activities" element={<Activities />} />
            <Route path="/events" element={<EventsPage />} />
            <Route path="/transport" element={<Transport />} />
            <Route path="/accommodation" element={<Accommodation />} />
            <Route path="/performance" element={<Performance />} />
            <Route path="/medical" element={<Medical />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>
      </div>
    </SessionContext.Provider>
  )
}
