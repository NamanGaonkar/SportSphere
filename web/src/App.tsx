import { useEffect, useMemo, useState, createContext, useContext } from 'react'
import { Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom'
import type { User } from '@supabase/supabase-js'
import Box from '@mui/material/Box'
import Drawer from '@mui/material/Drawer'
import List from '@mui/material/List'
import ListItemButton from '@mui/material/ListItemButton'
import ListItemIcon from '@mui/material/ListItemIcon'
import ListItemText from '@mui/material/ListItemText'
import Tooltip from '@mui/material/Tooltip'
import IconButton from '@mui/material/IconButton'
import Typography from '@mui/material/Typography'
import Divider from '@mui/material/Divider'
import Button from '@mui/material/Button'
import LinearProgress from '@mui/material/LinearProgress'
import LogoutIcon from '@mui/icons-material/Logout'
import ChevronLeftIcon from '@mui/icons-material/ChevronLeft'
import ChevronRightIcon from '@mui/icons-material/ChevronRight'
import PaymentsIcon from '@mui/icons-material/Payments'
import BuildIcon from '@mui/icons-material/Build'
import BookingIcon from '@mui/icons-material/EventAvailable'
import {
  Dashboard as DashboardIcon, BarChart as ReportsIcon,
  Groups as AthletesIcon, Sports as CoachesIcon, Shield as TeamsIcon,
  Badge as StaffIcon, EmojiEvents as TournamentsIcon,
  SportsScore as MatchesIcon, Stadium as VenuesIcon,
  SportsSoccer as SportIcon,
  FactCheck as AttendanceIcon, Inventory2 as InventoryIcon,
  CleaningServices as HousekeepingIcon, ShoppingCart as PurchasesIcon,
  Payments as ExpensesIcon, FitnessCenter as TrainingIcon,
  School as ActivitiesIcon, Event as EventsIcon,
  DirectionsBus as TransportIcon, Hotel as AccommodationIcon,
  Speed as PerformanceIcon, MedicalServices as MedicalIcon,
  ManageAccounts as ManageAccountsIcon,
  AccountCircle as AccountCircleIcon,
} from '@mui/icons-material'
import { supabase, envConfigured } from './lib/supabase'
import PageTransition from './components/PageTransition'
import ConfigError from './pages/ConfigError'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Athletes from './pages/Athletes'
import Coaches from './pages/Coaches'
import Teams from './pages/Teams'
import Tournaments from './pages/Tournaments'
import Matches from './pages/Matches'
import Venues from './pages/Venues'
import Sports from './pages/Sports'
import Attendance from './pages/Attendance'
import Staff from './pages/Staff'
import Inventory from './pages/Inventory'
import Reports from './pages/Reports'
import {
  Housekeeping, Training, Performance, Medical,
  EventsPage, Transport, Accommodation, Expenses, Activities,
  VenueMaintenance, PayrollPage, VenueBookings,
} from './pages/modules'
import Purchases from './pages/Purchases'
import Users from './pages/Users'
import Profile from './pages/Profile'

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
    section: 'My Account',
    items: [
      { to: '/profile', label: 'My Profile', icon: AccountCircleIcon },
      { to: '/users', label: 'User Management', icon: ManageAccountsIcon, roles: ['Admin'] },
    ],
  },
  {
    section: 'People',
    items: [
      { to: '/athletes', label: 'Athletes', icon: AthletesIcon, roles: ['Admin', 'Coach', 'HR'] },
      { to: '/coaches', label: 'Coaches', icon: CoachesIcon, roles: ['Admin', 'HR'] },
      { to: '/teams', label: 'Teams', icon: TeamsIcon },
      { to: '/staff', label: 'Staff & HR', icon: StaffIcon, roles: ['Admin', 'HR'] },
    ],
  },
  {
    section: 'Competitions',
    items: [
      { to: '/tournaments', label: 'Tournaments', icon: TournamentsIcon },
      { to: '/matches', label: 'Fixtures & Results', icon: MatchesIcon },
      { to: '/venues', label: 'Venues', icon: VenuesIcon },
      { to: '/sports', label: 'Sports', icon: SportIcon, roles: ['Admin'] },
    ],
  },
  {
    section: 'Operations',
    items: [
      { to: '/attendance', label: 'Attendance & Leave', icon: AttendanceIcon },
      { to: '/inventory', label: 'Inventory', icon: InventoryIcon },
      { to: '/housekeeping', label: 'Housekeeping', icon: HousekeepingIcon, roles: ['Admin', 'VenueManager'] },
      { to: '/maintenance', label: 'Venue Maintenance', icon: BuildIcon, roles: ['Admin', 'VenueManager'] },
      { to: '/bookings', label: 'Venue Booking', icon: BookingIcon },
      { to: '/purchases', label: 'Vendors & Purchases', icon: PurchasesIcon, roles: ['Admin', 'Finance', 'HR'] },
      { to: '/payroll', label: 'Payroll', icon: PaymentsIcon, roles: ['Admin', 'Finance', 'HR'] },
      { to: '/expenses', label: 'Finance & Expenses', icon: ExpensesIcon, roles: ['Admin', 'Finance', 'HR'] },
    ],
  },
  {
    section: 'Programs & Logistics',
    items: [
      { to: '/training', label: 'Training & Camps', icon: TrainingIcon, roles: ['Admin', 'Coach'] },
      { to: '/activities', label: 'School Activities', icon: ActivitiesIcon, roles: ['Admin', 'Coach'] },
      { to: '/events', label: 'Events', icon: EventsIcon },
      { to: '/transport', label: 'Transport', icon: TransportIcon, roles: ['Admin', 'VenueManager', 'Coach'] },
      { to: '/accommodation', label: 'Accommodation', icon: AccommodationIcon, roles: ['Admin', 'VenueManager', 'Coach'] },
    ],
  },
  {
    section: 'Athlete Care',
    // Visible to every staff role so the section shows in the sidebar for
    // all of them (athletes see their own data through My Profile).
    items: [
      { to: '/performance', label: 'Performance', icon: PerformanceIcon, roles: ['Admin', 'Coach', 'HR', 'Finance', 'VenueManager'] },
      { to: '/medical', label: 'Medical', icon: MedicalIcon, roles: ['Admin', 'Coach', 'HR', 'Finance', 'VenueManager'] },
    ],
  },
]

export default function App() {
  // Hard guard: never attempt auth/data on a misconfigured deployment.
  if (!envConfigured) {
    return (
      <Routes>
        <Route path="*" element={<ConfigError />} />
      </Routes>
    )
  }

  const [session, setSession] = useState<Session>(null)
  const [loading, setLoading] = useState(true)
  const [collapsed, setCollapsed] = useState(() => {
    try { return localStorage.getItem('sportsphere.nav.collapsed') === '1' } catch { return false }
  })
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
          <Box
            component="img"
            src="/logo.png"
            alt="SportSphere"
            sx={{ width: 96, height: 'auto', mb: 2 }}
          />
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
  const expandedWidth = 248
  const collapsedWidth = 76
  const drawerWidth = collapsed ? collapsedWidth : expandedWidth

  return (
    <SessionContext.Provider value={session}>
      <Box sx={{ display: 'flex', minHeight: '100vh', bgcolor: 'background.default' }}>
        <Drawer
          variant="permanent"
          sx={{
            width: drawerWidth,
            flexShrink: 0,
            transition: (t) => t.transitions.create('width', { duration: 220 }),
            // Floating rail: never touches any edge — inset from left/top/bottom.
            '& .MuiDrawer-paper': {
              position: 'fixed',
              top: 12,
              left: 12,
              bottom: 12,
              height: 'auto',
              width: drawerWidth,
              boxSizing: 'border-box',
              bgcolor: 'common.black',
              color: 'common.white',
              border: '1px solid rgba(255,255,255,0.08)',
              borderRadius: 2.5,
              boxShadow: '0 12px 40px rgba(13,13,13,0.35)',
              transition: (t) => t.transitions.create('width', { duration: 220 }),
              overflowX: 'hidden',
              display: 'flex',
              flexDirection: 'column',
            },
          }}
        >
          {/* Brand row + collapse toggle */}
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, px: collapsed ? 1.5 : 2.5, py: 2, flexShrink: 0 }}>
            <Box
              component="img"
              src="/logo.png"
              alt="SportSphere"
              sx={{ width: 30, height: 34, objectFit: 'contain', flexShrink: 0, mx: collapsed ? 'auto' : 0 }}
            />
            {!collapsed && (
              <Typography sx={{ fontWeight: 700, fontSize: 16, letterSpacing: 0.2, flex: 1 }} noWrap>
                SportSphere
              </Typography>
            )}
            <IconButton
              size="small"
              onClick={() => { setCollapsed(!collapsed); try { localStorage.setItem('sportsphere.nav.collapsed', collapsed ? '0' : '1') } catch { /* ignore */ } }}
              aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
              sx={{
                color: 'rgba(255,255,255,0.6)',
                display: collapsed ? 'none' : 'inline-flex',
                '&:hover': { color: 'primary.main' },
              }}
            >
              <ChevronLeftIcon fontSize="small" />
            </IconButton>
          </Box>
          {collapsed && (
            <Box sx={{ display: 'flex', justifyContent: 'center', pb: 1.5, flexShrink: 0 }}>
              <IconButton
                size="small"
                onClick={() => { setCollapsed(false); try { localStorage.setItem('sportsphere.nav.collapsed', '0') } catch { /* ignore */ } }}
                aria-label="Expand sidebar"
                sx={{ color: 'rgba(255,255,255,0.6)', '&:hover': { color: 'primary.main' } }}
              >
                <ChevronRightIcon fontSize="small" />
              </IconButton>
            </Box>
          )}
          <Divider sx={{ borderColor: 'rgba(255,255,255,0.12)', flexShrink: 0 }} />
          <Box
            sx={{
              flex: 1,
              overflowY: 'auto',
              overflowX: 'hidden',
              py: 0.5,
              // Normal scroll, invisible scrollbar
              scrollbarWidth: 'none',
              msOverflowStyle: 'none',
              '&::-webkit-scrollbar': { display: 'none' },
            }}
          >
            {visibleSections.map((s) => (
              <List key={s.section} disablePadding>
                {!collapsed && (
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
                )}
                {collapsed && <Box sx={{ height: 10 }} />}
                {s.items.map((i) => {
                  const active = location.pathname === i.to
                  const Icon = i.icon
                  const item = (
                    <ListItemButton
                      key={i.to}
                      selected={active}
                      onClick={() => navigate(i.to)}
                      sx={{
                        mx: 1,
                        mb: 0.25,
                        borderRadius: 1.5,
                        py: 1,
                        minHeight: 42,
                        px: collapsed ? 1.25 : 2,
                        justifyContent: collapsed ? 'center' : 'flex-start',
                        color: 'rgba(255,255,255,0.72)',
                        '&.Mui-selected': {
                          bgcolor: 'primary.main',
                          color: 'common.white',
                          '&:hover': { bgcolor: 'secondary.main' },
                        },
                        '&:hover': { bgcolor: 'rgba(255,255,255,0.08)' },
                      }}
                    >
                      <ListItemIcon sx={{ minWidth: 36, color: 'inherit', justifyContent: 'center' }}>
                        <Icon fontSize="small" />
                      </ListItemIcon>
                      {!collapsed && (
                        <ListItemText
                          primary={i.label}
                          slotProps={{
                            primary: {
                              sx: { fontSize: 13.5, fontWeight: active ? 700 : 400, whiteSpace: 'nowrap' },
                            },
                          }}
                        />
                      )}
                    </ListItemButton>
                  )
                  return collapsed ? (
                    <Tooltip key={i.to} title={i.label} placement="right">
                      {item}
                    </Tooltip>
                  ) : (
                    item
                  )
                })}
              </List>
            ))}
          </Box>
          <Box sx={{ p: collapsed ? 1 : 2, borderTop: '1px solid rgba(255,255,255,0.12)', textAlign: 'left', flexShrink: 0 }}>
            {!collapsed && (
              <>
                <Typography sx={{ fontSize: 13, fontWeight: 600 }} noWrap>
                  {session.profile?.full_name ?? session.user.email}
                </Typography>
                <Typography sx={{ fontSize: 11.5, color: 'rgba(255,255,255,0.5)', mb: 1 }}>{role}</Typography>
              </>
            )}
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
                borderRadius: 999,
                minWidth: collapsed ? 0 : undefined,
                px: collapsed ? 1 : undefined,
                '&:hover': { borderColor: 'primary.main', color: 'primary.main' },
              }}
              variant="outlined"
              aria-label="Sign out"
            >
              {!collapsed && 'Sign out'}
            </Button>
          </Box>
        </Drawer>

        {/* Main content: the Drawer already reserves the rail's width in the
            flex layout (the paper itself is position:fixed) — so no extra
            margin is needed beyond the page padding. */}
        <Box
          component="main"
          sx={{
            flex: 1,
            minWidth: 0,
            p: { xs: 2, md: 3 },
          }}
        >
          {/* Circular reveal: each section grows out of the point the user
              tapped (sidebar item, dashboard card, etc.). */}
          <PageTransition locationKey={location.pathname}>
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
            <Route path="/sports" element={<Sports />} />
            <Route path="/attendance" element={<Attendance />} />
            <Route path="/inventory" element={<Inventory />} />
            <Route path="/purchases" element={<Purchases />} />
            <Route path="/users" element={<Users />} />
            <Route path="/profile" element={<Profile />} />
            <Route path="/housekeeping" element={<Housekeeping />} />
            <Route path="/maintenance" element={<VenueMaintenance />} />
            <Route path="/bookings" element={<VenueBookings />} />
            <Route path="/payroll" element={<PayrollPage />} />
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
          </PageTransition>
        </Box>
      </Box>
    </SessionContext.Provider>
  )
}
