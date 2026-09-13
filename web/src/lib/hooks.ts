import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

export type Sport = { id: string; name: string; icon: string | null }

let cache: Sport[] | null = null
const listeners = new Set<(s: Sport[]) => void>()

// One shared subscription: every mounted SportFilter / SportSelect updates
// live when an admin edits the sports list on the web app.
supabase
  .channel('sports-realtime')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'sports' }, () => {
    cache = null
    void load()
  })
  .subscribe()

async function load(): Promise<Sport[]> {
  const { data } = await supabase.from('sports').select('id, name, icon').order('name')
  cache = (data as Sport[]) ?? []
  for (const fn of listeners) fn(cache)
  return cache
}

/** Live list of sports from the DB — single source of truth, never hardcoded. */
export function useSports(): { sports: Sport[]; byId: (id: string | null | undefined) => string } {
  const [sports, setSports] = useState<Sport[]>(cache ?? [])
  useEffect(() => {
    listeners.add(setSports)
    if (!cache) void load()
    else setSports(cache)
    return () => { listeners.delete(setSports) }
  }, [])
  const byId = (id: string | null | undefined) =>
    sports.find((s) => s.id === id)?.name ?? ''
  return { sports, byId }
}

/**
 * Live sync for any table in the supabase_realtime publication.
 * Pass a reload function; it is re-run whenever the table changes
 * (INSERT / UPDATE / DELETE from web OR mobile).
 */
export function useRealtimeTable(table: string, reload: () => void | Promise<void>, enabled = true) {
  useEffect(() => {
    if (!enabled) return
    const ch = supabase
      .channel(`${table}-changes-${Math.random().toString(36).slice(2, 8)}`)
      .on('postgres_changes', { event: '*', schema: 'public', table }, () => { void reload() })
      .subscribe()
    return () => { void supabase.removeChannel(ch) }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [table, enabled])
}
