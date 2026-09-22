// Shared table styling used by all MUI data tables (pass to `sx`).
const dataTableSx = {
  '& th': {
    fontWeight: 700,
    fontSize: 11.5,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
    color: 'text.secondary',
    bgcolor: 'rgba(13,13,13,0.03)',
    whiteSpace: 'nowrap',
  },
  // Cell text wraps naturally at word boundaries instead of stretching
  // columns with mid-word breaks ("Maintenance" split across lines etc.).
  '& td': {
    fontSize: 13.5,
    overflowWrap: 'break-word',
    wordBreak: 'normal',
    whiteSpace: 'normal',
    verticalAlign: 'top',
  },
  '& tbody tr:hover': { bgcolor: 'rgba(255,106,19,0.04)' },
} as const

export default dataTableSx
