import type { ReactNode } from 'react'
import type { SxProps, Theme } from '@mui/material/styles'
import Box from '@mui/material/Box'
import Chip from '@mui/material/Chip'
import Paper from '@mui/material/Paper'
import Typography from '@mui/material/Typography'
import Divider from '@mui/material/Divider'
import CircularProgress from '@mui/material/CircularProgress'
import InboxIcon from '@mui/icons-material/Inbox'

export type BadgeColor = 'success' | 'info' | 'warning' | 'error' | 'default'

export function PageHead({ title, sub, action }: { title: string; sub?: string; action?: ReactNode }) {
  return (
    <Box sx={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 2, flexWrap: 'wrap', mb: 3 }}>
      <Box>
        <Typography variant="h5">{title}</Typography>
        {sub && (
          <Typography variant="body2" sx={{ color: 'text.secondary', mt: 0.5 }}>
            {sub}
          </Typography>
        )}
      </Box>
      {action}
    </Box>
  )
}

// Dashboard stat card — same label / value / sub contract as the mobile app.
// ~55% orange tint background so the cards pop (brand parity with mobile).
export function StatCard({ label, value, sub, onClick }: { label: string; value: ReactNode; sub?: string; onClick?: () => void }) {
  return (
    <Paper
      elevation={0}
      onClick={onClick}
      sx={{
        p: 2.5,
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        bgcolor: '#FFF1E7',
        border: '1px solid rgba(255,106,19,0.25)',
        borderRadius: 3,
        // Clickable cards act as quick links into their module.
        ...(onClick
          ? { cursor: 'pointer', transition: 'transform .12s, box-shadow .12s',
              '&:hover': { transform: 'translateY(-2px)', boxShadow: '0 8px 22px rgba(255,106,19,0.18)', borderColor: 'rgba(255,106,19,0.5)' } }
          : {}),
      }}
    >
      <Typography
        sx={{
          fontSize: 11.5,
          fontWeight: 700,
          textTransform: 'uppercase',
          letterSpacing: 1,
          color: '#B25A1F',
        }}
      >
        {label}
      </Typography>
      <Typography
        sx={{
          fontSize: { xs: 26, md: 34 },
          fontWeight: 700,
          lineHeight: 1.2,
          mt: 0.5,
          color: '#1A1A1A',
          overflowWrap: 'anywhere',
          wordBreak: 'break-word',
        }}
      >
        {value}
      </Typography>
      {sub && (
        <Typography variant="caption" sx={{ color: 'text.secondary', mt: 'auto' }}>
          {sub}
        </Typography>
      )}
    </Paper>
  )
}

export function Section({ title, action, children, sx }: { title: string; action?: ReactNode; children: ReactNode; sx?: SxProps<Theme> }) {
  return (
    <Paper sx={[{ p: 2.5, mb: 2 }, ...(Array.isArray(sx) ? sx : [sx])] as SxProps<Theme>}>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 1.5, gap: 1 }}>
        <Typography variant="h6">{title}</Typography>
        {action}
      </Box>
      <Divider sx={{ mb: 2 }} />
      {children}
    </Paper>
  )
}

export function Badge({ color, children }: { color: BadgeColor; children: ReactNode }) {
  return <Chip size="small" color={color} label={children} variant={color === 'default' ? 'outlined' : 'filled'} />
}

export function EmptyState({ text }: { text: string }) {
  return (
    <Box sx={{ textAlign: 'center', py: 6, color: 'text.secondary' }}>
      <InboxIcon sx={{ fontSize: 40, mb: 1, opacity: 0.5 }} />
      <Typography variant="body2">{text}</Typography>
    </Box>
  )
}

export function LoadingState() {
  return (
    <Box sx={{ display: 'grid', placeItems: 'center', py: 8 }}>
      <CircularProgress color="primary" />
    </Box>
  )
}

export function statusColor(status: string): BadgeColor {
  switch (status) {
    case 'Present':
    case 'Completed':
    case 'Active':
    case 'Done':
      return 'success'
    case 'Live':
    case 'Scheduled':
      return 'info'
    case 'Late':
    case 'Maintenance':
    case 'In Progress':
      return 'warning'
    case 'Absent':
    case 'Cancelled':
    case 'Not cleared':
      return 'error'
    default:
      return 'default'
  }
}
