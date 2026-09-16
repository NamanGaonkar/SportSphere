import { createClient, type SupabaseClient } from '@supabase/supabase-js'

// Config is read defensively: missing/whitespace-corrupted values must never
// crash the app at import time (that renders a blank white page). Instead the
// client is created lazily and a clear error screen is shown if env is bad.
const rawUrl = (import.meta.env.VITE_SUPABASE_URL as string | undefined) ?? ''
const rawKey = (import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined) ?? ''

// Strip stray whitespace/CR (guards against CRLF env corruption, like mobile).
export const SUPABASE_URL = rawUrl.trim().replace(/\r/g, '')
export const SUPABASE_ANON_KEY = rawKey.trim().replace(/\r/g, '')

export const envConfigured =
  SUPABASE_URL.startsWith('https://') && SUPABASE_URL.includes('.supabase.co') && SUPABASE_ANON_KEY.length > 20

let _client: SupabaseClient | null = null

/** Throws a descriptive error only when actually used with a bad config. */
export function getSupabase(): SupabaseClient {
  if (!envConfigured) {
    throw new Error(
      'Supabase is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY ' +
        '(local: root .env / Vercel: Project Settings > Environment Variables), then rebuild.',
    )
  }
  if (!_client) _client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
  return _client
}

// Back-compat: the rest of the app imports { supabase }. On a correctly
// configured deployment (local dev, Vercel with env vars) this is created
// immediately; on a misconfigured one, App routes to the config-error screen
// before anything touches the client.
export const supabase: SupabaseClient = new Proxy({} as SupabaseClient, {
  get(_t, prop) {
    return Reflect.get(getSupabase(), prop)
  },
})
