import type { ReactNode } from 'react'
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
export function StatCard({ label, value, sub }: { label: string; value: ReactNode; sub?: string }) {
  return (
    <Paper sx={{ p: 2.5, height: '100%', display: 'flex', flexDirection: 'column' }}>
      <Typography
        sx={{
          fontSize: 11.5,
          fontWeight: 700,
          textTransform: 'uppercase',
          letterSpacing: 1,
          color: 'text.secondary',
        }}
      >
        {label}
      </Typography>
      <Typography sx={{ fontSize: 34, fontWeight: 700, lineHeight: 1.2, mt: 0.5 }}>{value}</Typography>
      {sub && (
        <Typography variant="caption" sx={{ color: 'text.secondary', mt: 'auto' }}>
          {sub}
        </Typography>
      )}
    </Paper>
  )
}

export function Section({ title, action, children }: { title: string; action?: ReactNode; children: ReactNode }) {
  return (
    <Paper sx={{ p: 2.5, mb: 2 }}>
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
