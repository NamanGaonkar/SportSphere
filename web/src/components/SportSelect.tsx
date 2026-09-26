import { useState, useMemo, useEffect } from 'react'
import TextField from '@mui/material/TextField'
import MenuItem from '@mui/material/MenuItem'
import Box from '@mui/material/Box'
import { supabase } from '../lib/supabase'
import { useSports } from '../lib/hooks'

/** Team dropdown scoped to a sport: when a sport is selected (e.g. Cricket)
 *  only that sport's teams are offered — cross-sport assignment is blocked
 *  at the UI level on both web and mobile (the DB guard stays as backup). */
export function TeamSelectScoped({
  value,
  onChange,
  sportId,
  label = 'Team',
  allowEmpty = true,
  emptyLabel = 'None',
}: {
  value: string
  onChange: (v: string) => void
  sportId: string
  label?: string
  allowEmpty?: boolean
  emptyLabel?: string
}) {
  const [teams, setTeams] = useState<{ id: string; name: string; sport_id: string | null }[]>([])
  useEffect(() => {
    let alive = true
    supabase
      .from('teams')
      .select('id, name, sport_id')
      .order('name')
      .then(({ data }) => {
        if (alive) setTeams(((data ?? []) as { id: string; name: string; sport_id: string | null }[]))
      })
    return () => {
      alive = false
    }
  }, [])
  const scoped = useMemo(
    () => teams.filter((t) => !sportId || t.sport_id === sportId),
    [teams, sportId],
  )
  const valid = scoped.some((t) => t.id === value)
  return (
    <TextField
      select
      label={label}
      value={valid ? value : ''}
      onChange={(e) => onChange(e.target.value)}
      fullWidth
      helperText={sportId && scoped.length === 0 ? 'No teams in this sport yet' : undefined}
    >
      {allowEmpty && <MenuItem value="">{emptyLabel}</MenuItem>}
      {scoped.map((t) => (
        <MenuItem key={t.id} value={t.id}>{t.name}</MenuItem>
      ))}
    </TextField>
  )
}

/** Sport dropdown fed live from the sports table. Empty value = no sport. */
export function SportSelect({
  value,
  onChange,
  label = 'Sport',
  required = false,
  allowEmpty = true,
  emptyLabel = 'None',
}: {
  value: string
  onChange: (v: string) => void
  label?: string
  required?: boolean
  allowEmpty?: boolean
  emptyLabel?: string
}) {
  const { sports } = useSports()
  return (
    <TextField
      select
      label={label}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      required={required}
      fullWidth
      // Cap the menu height so the 21-sport list scrolls inside a bounded
      // dropdown instead of covering the whole dialog.
      slotProps={{
        select: {
          MenuProps: {
            slotProps: { paper: { sx: { maxHeight: 320 } } },
          },
        },
      }}
    >
      {allowEmpty && <MenuItem value="">{emptyLabel}</MenuItem>}
      {sports.map((s) => (
        <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>
      ))}
    </TextField>
  )
}

/** Compact filter dropdown: "All sports" + each sport. */
export function SportFilter({
  value,
  onChange,
  width = 220,
}: {
  value: string
  onChange: (v: string) => void
  width?: number
}) {
  const { sports } = useSports()
  return (
    <TextField
      select
      size="small"
      label="Sport"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      sx={{ mb: 2, width }}
      slotProps={{
        select: {
          MenuProps: {
            slotProps: { paper: { sx: { maxHeight: 320 } } },
          },
        },
      }}
    >
      <MenuItem value="">All sports</MenuItem>
      {sports.map((s) => (
        <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>
      ))}
    </TextField>
  )
}

/** Multi-select of sports used on the Athlete form (athlete_sports join). */
export function SportMultiSelect({
  value,
  onChange,
  label = 'Sports',
}: {
  value: string[]
  onChange: (v: string[]) => void
  label?: string
}) {
  const { sports } = useSports()
  const [open, setOpen] = useState(false)
  // Use a plain select with multiple=true via native rendering is clunky in MUI;
  // render checkboxes inside a select for the familiar multi-pick UX.
  return (
    <TextField
      select
      label={label}
      value={value}
      onChange={(e) => {
        const v = e.target.value
        onChange(typeof v === 'string' ? [] : v)
      }}
      fullWidth
      slotProps={{
        select: {
          multiple: true,
          open,
          onOpen: () => setOpen(true),
          onClose: () => setOpen(false),
          renderValue: (selected) => {
            const sel = (selected ?? []) as string[]
            if (!sel.length) return ''
            return sel
              .map((id) => sports.find((s) => s.id === id)?.name ?? '')
              .filter(Boolean)
              .join(', ')
          },
        },
      }}
    >
      {sports.map((s) => (
        <MenuItem key={s.id} value={s.id}>
          <Box component="span" sx={{ display: 'inline-flex', alignItems: 'center', gap: 1 }}>
            <input type="checkbox" checked={value.includes(s.id)} readOnly />
            {s.name}
          </Box>
        </MenuItem>
      ))}
    </TextField>
  )
}

/** Resolve a set of sport_ids for many rows in one query. */
export function useSportNameMap() {
  const { sports } = useSports()
  return useMemo(() => {
    const m = new Map<string, string>()
    for (const s of sports) m.set(s.id, s.name)
    return m
  }, [sports])
}
