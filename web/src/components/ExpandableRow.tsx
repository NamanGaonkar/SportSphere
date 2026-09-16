import { useState, type ReactNode } from 'react'
import Box from '@mui/material/Box'
import Collapse from '@mui/material/Collapse'
import TableCell from '@mui/material/TableCell'
import TableRow from '@mui/material/TableRow'
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown'
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp'
import Typography from '@mui/material/Typography'
import Divider from '@mui/material/Divider'

export type KV = { k: string; v: ReactNode }

/** A table row that expands to a full detail view of the record. Tap/click
    anywhere on the row (or the chevron) to toggle. Keeps the exact MUI look. */
export default function ExpandableRow({
  children,
  detail,
  chips,
}: {
  children: ReactNode
  detail: KV[]
  chips?: { label: string; color: 'primary' | 'success' | 'warning' | 'error' | 'info' | 'default' }[]
}) {
  const [open, setOpen] = useState(false)
  return (
    <>
      <TableRow hover onClick={() => setOpen((o) => !o)} sx={{ cursor: 'pointer' }}>
        <TableCell padding="checkbox" sx={{ width: 40 }}>
          {open ? (
            <KeyboardArrowUpIcon fontSize="small" sx={{ color: 'primary.main', cursor: 'pointer' }} onClick={(e) => { e.stopPropagation(); setOpen(false) }} />
          ) : (
            <KeyboardArrowDownIcon fontSize="small" sx={{ color: 'text.secondary', cursor: 'pointer' }} onClick={(e) => { e.stopPropagation(); setOpen(true) }} />
          )}
        </TableCell>
        {children}
      </TableRow>
      <TableRow>
        <TableCell style={{ padding: 0, border: open ? undefined : 'none' }} colSpan={99}>
          <Collapse in={open} unmountOnExit>
            <Box sx={(t) => ({ py: 2, px: 3, bgcolor: t.palette.mode === 'light' ? 'rgba(255,106,19,0.03)' : 'rgba(255,106,19,0.06)' })}>
              {chips && chips.length > 0 && (
                <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', mb: 1.5 }}>
                  {chips.map((c) => (
                    <Box
                      key={c.label}
                      sx={(t) => ({
                        px: 1.25,
                        py: 0.4,
                        borderRadius: 99,
                        fontSize: 12,
                        fontWeight: 700,
                        color: c.color === 'primary' ? t.palette.primary.main : undefined,
                        bgcolor:
                          c.color === 'primary'
                            ? 'rgba(255,106,19,0.12)'
                            : c.color === 'success'
                              ? 'rgba(46,125,50,0.12)'
                              : c.color === 'warning'
                                ? 'rgba(178,106,0,0.12)'
                                : c.color === 'error'
                                  ? 'rgba(198,40,40,0.12)'
                                  : c.color === 'info'
                                    ? 'rgba(21,101,192,0.12)'
                                    : 'rgba(0,0,0,0.06)',
                      })}
                    >
                      {c.label}
                    </Box>
                  ))}
                </Box>
              )}
              <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, gap: 0.5 }}>
                {detail.map((d) => (
                  <Box key={d.k} sx={{ display: 'flex', gap: 1, alignItems: 'baseline' }}>
                    <Typography sx={{ fontSize: 12.5, color: 'text.secondary', minWidth: 140 }}>{d.k}</Typography>
                    <Typography sx={{ fontSize: 13.5, fontWeight: 600, flex: 1 }}>{d.v}</Typography>
                  </Box>
                ))}
              </Box>
              <Divider sx={{ mt: 1.5 }} />
            </Box>
          </Collapse>
        </TableCell>
      </TableRow>
    </>
  )
}
