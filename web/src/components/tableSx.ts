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
  '& td': { fontSize: 13.5 },
  '& tbody tr:hover': { bgcolor: 'rgba(255,106,19,0.04)' },
} as const

export default dataTableSx
