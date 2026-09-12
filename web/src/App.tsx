import { useEffect, useMemo, useState, createContext, useContext } from 'react'
import { Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom'
import type { User } from '@supabase/supabase-js'
import Box from '@mui/material/Box'
import Drawer from '@mui/material/Drawer'
import List from '@mui/material/List'
import ListItemButton from '@mui/material/ListItemButton'
import ListItemIcon from '@mui/material/ListItemIcon'
import ListItemText from '@mui/material/ListItemText'
import Typography from '@mui/material/Typography'
import Divider from '@mui/material/Divider'
import Button from '@mui/material/Button'
import LinearProgress from '@mui/material/LinearProgress'
import SportsScoreIcon from '@mui/icons-material/SportsScore'
import LogoutIcon from '@mui/icons-material/Logout'
import {
  Dashboard as DashboardIcon, BarChart as ReportsIcon,
  Groups as AthletesIcon, Sports as CoachesIcon, Shield as TeamsIcon,
  Badge as StaffIcon, EmojiEvents as TournamentsIcon,
  SportsScore as MatchesIcon, Stadium as VenuesIcon,
  FactCheck as AttendanceIcon, Inventory2 as InventoryIcon,
  CleaningServices as HousekeepingIcon, ShoppingCart as PurchasesIcon,
  Payments as ExpensesIcon, FitnessCenter as TrainingIcon,
  School as ActivitiesIcon, Event as EventsIcon,
  DirectionsBus as TransportIcon, Hotel as AccommodationIcon,
  Speed as PerformanceIcon, MedicalServices as MedicalIcon,
} from '@mui/icons-material'
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

// Navigation order is shared with the mobile app shell (same sections, same order).
const NAV_SECTIONS: {
  section: string
  items: { to: string; label: string; icon: typeof DashboardIcon; roles?: string[] }[]
}[] = [
  {
    section: 'Overview',
    items: [
      { to: '/', label: 'Dashboard', icon: DashboardIcon },
      { to: '/reports', label: 'Reports', icon: ReportsIcon },
    ],
  },
  {
    section: 'People',
    items: [
      { to: '/athletes', label: 'Athletes', icon: AthletesIcon },
      { to: '/coaches', label: 'Coaches', icon: CoachesIcon },
      { to: '/teams', label: 'Teams', icon: TeamsIcon },
      { to: '/staff', label: 'Staff & HR', icon: StaffIcon },
    ],
  },
  {
    section: 'Competitions',
    items: [
      { to: '/tournaments', label: 'Tournaments', icon: TournamentsIcon },
      { to: '/matches', label: 'Fixtures & Results', icon: MatchesIcon },
      { to: '/venues', label: 'Venues', icon: VenuesIcon },
    ],
  },
  {
    section: 'Operations',
    items: [
      { to: '/attendance', label: 'Attendance & Leave', icon: AttendanceIcon },
      { to: '/inventory', label: 'Inventory', icon: InventoryIcon },
      { to: '/housekeeping', label: 'Housekeeping', icon: HousekeepingIcon },
      { to: '/purchases', label: 'Vendors & Purchases', icon: PurchasesIcon },
      { to: '/expenses', label: 'Finance & Expenses', icon: ExpensesIcon, roles: ['Admin', 'Finance', 'HR'] },
    ],
  },
  {
    section: 'Programs & Logistics',
    items: [
      { to: '/training', label: 'Training & Camps', icon: TrainingIcon },
      { to: '/activities', label: 'School Activities', icon: ActivitiesIcon },
      { to: '/events', label: 'Events', icon: EventsIcon },
      { to: '/transport', label: 'Transport', icon: TransportIcon },
      { to: '/accommodation', label: 'Accommodation', icon: AccommodationIcon },
    ],
  },
  {
    section: 'Athlete Care',
    items: [
      { to: '/performance', label: 'Performance', icon: PerformanceIcon },
      { to: '/medical', label: 'Medical', icon: MedicalIcon },
    ],
  },
]

export default function App() {
  const [session, setSession] = useState<Session>(null)
  const [loading, setLoading] = useState(true)
  const navigate = useNavigate()
  const location = useLocation()

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

  const visibleSections = useMemo(() => {
    const role = session?.profile?.role
    return NAV_SECTIONS.map((s) => ({
      ...s,
      items: s.items.filter((i) => !i.roles || (role && i.roles.includes(role))),
    }))
  }, [session])

  if (loading) {
    return (
      <Box sx={{ minHeight: '100vh', display: 'grid', placeItems: 'center', bgcolor: 'background.default' }}>
        <Box sx={{ width: 220, textAlign: 'center' }}>
          <SportsScoreIcon color="primary" sx={{ fontSize: 44, mb: 2 }} />
          <LinearProgress />
        </Box>
      </Box>
    )
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

  return (
    <SessionContext.Provider value={session}>
      <Box sx={{ display: 'flex', minHeight: '100vh' }}>
        <Drawer
          variant="permanent"
          sx={{
            width: 240,
            flexShrink: 0,
            '& .MuiDrawer-paper': {
              width: 240,
              boxSizing: 'border-box',
              bgcolor: 'common.black',
              color: 'common.white',
              borderRight: 'none',
            },
          }}
        >
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, px: 2.5, py: 2.5 }}>
            <Box
              sx={{
                width: 34,
                height: 34,
                borderRadius: 2,
                bgcolor: 'primary.main',
                display: 'grid',
                placeItems: 'center',
                flexShrink: 0,
              }}
            >
              <SportsScoreIcon sx={{ fontSize: 20, color: 'common.white' }} />
            </Box>
            <Typography sx={{ fontWeight: 700, fontSize: 17, letterSpacing: 0.2 }}>
              SportSphere
            </Typography>
          </Box>
          <Divider sx={{ borderColor: 'rgba(255,255,255,0.12)' }} />
          <Box sx={{ flex: 1, overflowY: 'auto' }}>
            {visibleSections.map((s) => (
              <List key={s.section} disablePadding>
                <Typography
                  sx={{
                    px: 2.5,
                    pt: 2,
                    pb: 0.5,
                    fontSize: 10.5,
                    fontWeight: 700,
                    letterSpacing: 1.2,
                    textTransform: 'uppercase',
                    color: 'rgba(255,255,255,0.45)',
                  }}
                >
                  {s.section}
                </Typography>
                {s.items.map((i) => {
                  const active = location.pathname === i.to
                  const Icon = i.icon
                  return (
                    <ListItemButton
                      key={i.to}
                      selected={active}
                      onClick={() => navigate(i.to)}
                      sx={{
                        mx: 1,
                        mb: 0.25,
                        borderRadius: 1.5,
                        py: 1,
                        color: 'rgba(255,255,255,0.72)',
                        '&.Mui-selected': {
                          bgcolor: 'primary.main',
                          color: 'common.white',
                          '&:hover': { bgcolor: 'secondary.main' },
                        },
                        '&:hover': { bgcolor: 'rgba(255,255,255,0.08)' },
                      }}
                    >
                      <ListItemIcon sx={{ minWidth: 36, color: 'inherit' }}>
                        <Icon fontSize="small" />
                      </ListItemIcon>
                      <ListItemText
                        primary={i.label}
                        slotProps={{
                          primary: {
                            sx: { fontSize: 13.5, fontWeight: active ? 700 : 400 },
                          },
                        }}
                      />
                    </ListItemButton>
                  )
                })}
              </List>
            ))}
          </Box>
          <Box sx={{ p: 2, borderTop: '1px solid rgba(255,255,255,0.12)' }}>
            <Typography sx={{ fontSize: 13, fontWeight: 600 }} noWrap>
              {session.profile?.full_name ?? session.user.email}
            </Typography>
            <Typography sx={{ fontSize: 11.5, color: 'rgba(255,255,255,0.5)', mb: 1 }}>{role}</Typography>
            <Button
              fullWidth
              size="small"
              startIcon={<LogoutIcon />}
              onClick={async () => {
                await supabase.auth.signOut()
                navigate('/login')
              }}
              sx={{
                color: 'rgba(255,255,255,0.72)',
                borderColor: 'rgba(255,255,255,0.25)',
                '&:hover': { borderColor: 'primary.main', color: 'primary.main' },
              }}
              variant="outlined"
            >
              Sign out
            </Button>
          </Box>
        </Drawer>

        <Box component="main" sx={{ flex: 1, p: { xs: 2, md: 3 }, maxWidth: 1440, minWidth: 0 }}>
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
        </Box>
      </Box>
    </SessionContext.Provider>
  )
}
