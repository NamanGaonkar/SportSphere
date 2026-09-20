import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Box from '@mui/material/Box'
import Paper from '@mui/material/Paper'
import Tabs from '@mui/material/Tabs'
import Tab from '@mui/material/Tab'
import TextField from '@mui/material/TextField'
import MenuItem from '@mui/material/MenuItem'
import InputAdornment from '@mui/material/InputAdornment'
import IconButton from '@mui/material/IconButton'
import Button from '@mui/material/Button'
import Typography from '@mui/material/Typography'
import Alert from '@mui/material/Alert'
import Visibility from '@mui/icons-material/Visibility'
import VisibilityOff from '@mui/icons-material/VisibilityOff'
import { supabase } from '../lib/supabase'

// Roles available at public signup. Admin is NOT selectable — the single
// admin account is provisioned out-of-band (supabase/branding.sql).
const SIGNUP_ROLES = ['Athlete', 'Coach', 'HR', 'Finance', 'VenueManager']

export default function Login() {
  const [mode, setMode] = useState(0)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [fullName, setFullName] = useState('')
  const [role, setRole] = useState('Athlete')
  const [showPw, setShowPw] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [busy, setBusy] = useState(false)
  const navigate = useNavigate()

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setNotice('')
    setBusy(true)

    if (mode === 1) {
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { full_name: fullName, role } },
      })
      setBusy(false)
      if (error) {
        setError(error.message)
        return
      }
      setNotice('Account created. If email confirmation is required, check your inbox; otherwise you are signed in.')
      navigate('/')
      return
    }

    const { error } = await supabase.auth.signInWithPassword({ email, password })
    setBusy(false)
    if (error) {
      setError(error.message)
      return
    }
    navigate('/')
  }

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', flexDirection: { xs: 'column', md: 'row' }, position: 'relative' }}>
      {/* Background image at ~55% opacity under everything */}
      <Box
        sx={{
          position: 'absolute',
          inset: 0,
          backgroundImage: 'url(/background.jpg)',
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          opacity: 0.55,
        }}
      />
      {/* Dark veil so text stays readable over the photo —
          uniform #0D0D0D hardening (80/60/40) keeps white and orange text
          sharply legible without washing out. */}
      <Box
        sx={{
          position: 'absolute',
          inset: 0,
          background:
            'linear-gradient(90deg, rgba(13,13,13,0.80) 0%, rgba(13,13,13,0.60) 45%, rgba(13,13,13,0.40) 100%)',
        }}
      />

      {/* Brand panel — vertically centered flex column that visually
          balances the floating sign-in card on the right. */}
      <Box
        sx={{
          position: 'relative',
          zIndex: 1,
          flex: { md: '0 0 52%' },
          color: 'common.white',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          alignItems: 'flex-start',
          maxWidth: { md: 640 },
          pl: { xs: 4, lg: 10 },
          pr: { xs: 4, md: 2 },
          py: { xs: 6, md: 6 },
        }}
      >
        {/* Logo lockup: 64px icon above the wordmark */}
        <Box
          component="img"
          src="/logo.png"
          alt="SportSphere"
          sx={{
            width: 64,
            height: 64,
            objectFit: 'contain',
            filter: 'drop-shadow(0 4px 12px rgba(0,0,0,0.6))',
          }}
        />
        <Typography sx={{ mt: 2, fontSize: 26, fontWeight: 800, letterSpacing: 2, lineHeight: 1 }}>
          SPORT<span style={{ color: '#FF6A13' }}>SPHERE</span>
        </Typography>
        {/* Eyebrow badge */}
        <Typography
          sx={{
            mt: 1,
            color: '#FF6A13',
            fontSize: 12,
            fontWeight: 700,
            letterSpacing: '0.2em',
            textTransform: 'uppercase',
          }}
        >
          Elevate every game
        </Typography>
        {/* Headline — extra-bold, tight leading */}
        <Typography
          sx={{
            mt: 6,
            mb: 4,
            fontSize: { xs: 34, lg: 48 },
            fontWeight: 800,
            lineHeight: 1.15,
            color: '#FFFFFF',
            maxWidth: 560,
            textShadow: '0 2px 8px rgba(0,0,0,0.35)',
          }}
        >
          Sports organization management, in one place.
        </Typography>
        <Typography
          sx={{
            color: '#E2E8F0',
            fontSize: { xs: 15, lg: 18 },
            lineHeight: 1.65,
            fontWeight: 400,
            maxWidth: 480,
            textShadow: '0 1px 4px rgba(0,0,0,0.5)',
          }}
        >
          Manage athletes, coaches, teams, tournaments, venues and operations from a single
          platform built for clubs, academies and school sports bodies.
        </Typography>
      </Box>

      {/* Form panel */}
      <Box sx={{ position: 'relative', zIndex: 1, flex: 1, display: 'grid', placeItems: 'center', p: 3 }}>
        <Paper sx={{ width: '100%', maxWidth: 400, p: 4, bgcolor: 'rgba(255,255,255,0.96)', backdropFilter: 'blur(6px)' }}>
          <Tabs value={mode} onChange={(_, v) => { setMode(v); setError(''); setNotice('') }} sx={{ mb: 3 }}>
            <Tab label="Sign in" />
            <Tab label="Sign up" />
          </Tabs>

          <form onSubmit={submit}>
            {mode === 1 && (
              <>
                <TextField
                  label="Full name"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  fullWidth
                  required
                  margin="normal"
                />
                <TextField
                  select
                  label="Role"
                  value={role}
                  onChange={(e) => setRole(e.target.value)}
                  fullWidth
                  margin="normal"
                  helperText="Determines what you can access after signing in."
                >
                  {SIGNUP_ROLES.map((r) => (
                    <MenuItem key={r} value={r}>{r}</MenuItem>
                  ))}
                </TextField>
              </>
            )}
            <TextField
              type="email"
              label="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              fullWidth
              required
              margin="normal"
            />
            <TextField
              type={showPw ? 'text' : 'password'}
              label="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              fullWidth
              required
              margin="normal"
              slotProps={{
                input: {
                  endAdornment: (
                    <InputAdornment position="end">
                      <IconButton onClick={() => setShowPw(!showPw)} edge="end" aria-label="Toggle password visibility">
                        {showPw ? <VisibilityOff /> : <Visibility />}
                      </IconButton>
                    </InputAdornment>
                  ),
                },
              }}
            />

            {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
            {notice && <Alert severity="success" sx={{ mt: 2 }}>{notice}</Alert>}

            <Button type="submit" variant="contained" fullWidth size="large" disabled={busy} sx={{ mt: 3 }}>
              {busy ? 'Please wait' : mode === 1 ? 'Create account' : 'Sign in'}
            </Button>
          </form>
        </Paper>
      </Box>
    </Box>
  )
}
