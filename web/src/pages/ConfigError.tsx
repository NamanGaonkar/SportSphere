import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import Paper from '@mui/material/Paper'
import Button from '@mui/material/Button'
import RefreshIcon from '@mui/icons-material/Refresh'
import { envConfigured } from '../lib/supabase'

/** Shown instead of a blank white screen when Supabase env vars are missing. */
export default function ConfigError() {
  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'grid',
        placeItems: 'center',
        bgcolor: '#0A0A0A',
        p: 2,
      }}
    >
      <Paper sx={{ maxWidth: 480, p: 4, borderRadius: 3 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
          <Box component="img" src="/logo.png" alt="SportSphere" sx={{ width: 44, height: 44, objectFit: 'contain' }} />
          <Typography sx={{ fontWeight: 700, fontSize: 18 }}>SportSphere</Typography>
        </Box>
        <Typography sx={{ fontWeight: 700, mb: 1 }}>Configuration problem</Typography>
        <Typography sx={{ fontSize: 14, color: 'text.secondary', mb: 3 }}>
          The web app was built without Supabase credentials. Add{' '}
          <code style={{ fontWeight: 700 }}>VITE_SUPABASE_URL</code> and{' '}
          <code style={{ fontWeight: 700 }}>VITE_SUPABASE_ANON_KEY</code> to the deployment
          environment (Vercel: Project Settings &gt; Environment Variables), then redeploy.
        </Typography>
        <Button variant="contained" startIcon={<RefreshIcon />} onClick={() => window.location.reload()}>
          Retry
        </Button>
      </Paper>
    </Box>
  )
}

// Re-export so App.tsx can check config without importing env details.
export { envConfigured }
