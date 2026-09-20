import { useEffect, useMemo, useRef, useState } from 'react'
import { MapContainer, TileLayer, Marker, useMap, useMapEvents } from 'react-leaflet'
import L from 'leaflet'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
import Paper from '@mui/material/Paper'
import List from '@mui/material/List'
import ListItemButton from '@mui/material/ListItemButton'
import ListItemText from '@mui/material/ListItemText'
import CircularProgress from '@mui/material/CircularProgress'
import Typography from '@mui/material/Typography'
import SearchIcon from '@mui/icons-material/Search'
import 'leaflet/dist/leaflet.css'

// OpenStreetMap tiles — free, no API key, no billing account required.
const TILE_URL = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
const TILE_ATTR =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'

// Default center: Bengaluru, India.
const DEFAULT_CENTER: [number, number] = [12.9716, 77.5946]

// Geocoding stack: Photon (Komoot) first — it is built for browser apps,
// CORS-native and does not throttle web origins the way Nominatim's usage
// policy does (Nominatim 403s browser traffic after a burst, which made
// the search silently return nothing). Nominatim stays as fallback.
const GEO_HEADERS = { Accept: 'application/json' }

type GeoResult = { display_name: string; lat: string; lon: string }

type PhotonFeature = {
  geometry: { coordinates: [number, number] } // [lon, lat]
  properties: {
    name?: string
    street?: string
    housenumber?: string
    postcode?: string
    city?: string
    county?: string
    state?: string
    country?: string
  }
}

function photonLabel(p: PhotonFeature['properties']): string {
  return [p.name, p.street, p.city, p.state, p.country]
    .filter((x): x is string => !!x && x.length > 0)
    .join(', ')
}

/** Photon search → GeoJSON; returns empty list when nothing matches. */
async function photonSearch(q: string): Promise<GeoResult[]> {
  const res = await fetch(`https://photon.komoot.io/api/?limit=5&q=${encodeURIComponent(q)}`, {
    headers: GEO_HEADERS,
  })
  const j = (await res.json()) as { features?: PhotonFeature[] }
  return (j.features ?? []).map((f) => ({
    display_name: photonLabel(f.properties),
    lat: String(f.geometry.coordinates[1]),
    lon: String(f.geometry.coordinates[0]),
  }))
}

/** Nominatim search fallback (same API the mobile app uses). */
async function nominatimSearch(q: string): Promise<GeoResult[]> {
  const res = await fetch(
    `https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&q=${encodeURIComponent(q)}`,
    { headers: GEO_HEADERS },
  )
  return (await res.json()) as GeoResult[]
}

/** Reverse geocode: Photon first, Nominatim fallback, coordinates last. */
async function reverseLookup(lat: number, lng: number): Promise<string> {
  try {
    const res = await fetch(`https://photon.komoot.io/reverse?lat=${lat}&lon=${lng}`, {
      headers: GEO_HEADERS,
    })
    const j = (await res.json()) as { features?: PhotonFeature[] }
    const label = j.features?.[0] ? photonLabel(j.features[0].properties) : ''
    if (label) return label
  } catch {
    /* fall through */
  }
  try {
    const res = await fetch(
      `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}`,
      { headers: GEO_HEADERS },
    )
    const j = (await res.json()) as { display_name?: string }
    if (j.display_name) return j.display_name
  } catch {
    /* fall through */
  }
  return `${lat.toFixed(6)}, ${lng.toFixed(6)}`
}

// Small orange dot marker so the pin matches the brand palette.
const pin = L.divIcon({
  className: 'sportsphere-map-pin',
  html: '<span style="display:block;width:18px;height:18px;border-radius:50%;background:#FF6A13;border:3px solid #0D0D0D;box-shadow:0 0 0 2px rgba(255,106,19,.45)"></span>',
  iconSize: [18, 18],
  iconAnchor: [9, 9],
})

function ClickCapture({ onPick }: { onPick: (lat: number, lng: number) => void }) {
  useMapEvents({
    click(e) {
      onPick(e.latlng.lat, e.latlng.lng)
    },
  })
  return null
}

/** Smoothly flies the map whenever the pin target changes. */
function FlyTo({ target }: { target: [number, number] | null }) {
  const map = useMap()
  useEffect(() => {
    if (target) map.flyTo(target, 16, { duration: 0.6 })
  }, [target, map])
  return null
}

export type LocationPickerResult = { location: string; lat: number | null; lng: number | null }

/**
 * Map + geocode location picker used in the Venue form (web).
 * Mirrors the mobile picker's behavior:
 * - Type to search: results appear automatically (debounced) while typing.
 * - Tap a result: the pin flies there AND the full address is resolved via
 *   reverse geocoding (same lookup the phone runs after choosing a result).
 * - Click the map: pin drops, address reverse-geocodes.
 */
export default function LocationPicker({
  initial,
  onPick,
}: {
  /** lat/lng when editing a venue that already has coordinates. */
  initial?: { lat: number | null; lng: number | null }
  onPick: (r: LocationPickerResult) => void
}) {
  const [pos, setPos] = useState<[number, number] | null>(
    initial?.lat != null && initial?.lng != null ? [initial.lat, initial.lng] : null,
  )
  const [label, setLabel] = useState('')
  const [busy, setBusy] = useState(false)
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<GeoResult[]>([])
  const [searching, setSearching] = useState(false)
  const reqId = useRef(0)

  const center = useMemo<[number, number]>(() => pos ?? DEFAULT_CENTER, [pos])

  async function reverseGeocode(lat: number, lng: number) {
    setBusy(true)
    const location = await reverseLookup(lat, lng)
    setLabel(location)
    onPick({ location, lat, lng })
    setBusy(false)
  }

  function pick(lat: number, lng: number) {
    const p: [number, number] = [lat, lng]
    setResults([])
    setPos(p)
    void reverseGeocode(lat, lng)
  }

  async function search(q: string) {
    const term = q.trim()
    if (!term) {
      setResults([])
      return
    }
    const id = ++reqId.current
    setSearching(true)
    try {
      // Photon first; Nominatim only if Photon returns nothing (it may be
      // rate-limiting this browser — that was the "no results" bug).
      let found = await photonSearch(term)
      if (found.length === 0) found = await nominatimSearch(term)
      if (id !== reqId.current) return // a newer keystroke superseded this one
      setResults(found)
    } catch {
      if (id === reqId.current) setResults([])
    } finally {
      if (id === reqId.current) setSearching(false)
    }
  }

  // Debounced auto-search while typing (phone parity) — 500ms after the
  // last keystroke, so results appear without pressing Enter.
  useEffect(() => {
    const t = setTimeout(() => void search(query), 500)
    return () => clearTimeout(t)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query])

  async function applyResult(r: GeoResult) {
    const p: [number, number] = [Number(r.lat), Number(r.lon)]
    setQuery(r.display_name)
    setResults([])
    setPos(p)
    // Resolve the address through the same reverse-geocode path the phone
    // uses after picking a result — keeps label + pin in sync everywhere.
    await reverseGeocode(p[0], p[1])
  }

  return (
    <Box>
      {/* Address search — auto-suggests while typing, same as the phone */}
      <Box sx={{ position: 'relative', mb: 1 }}>
        <TextField
          size="small"
          fullWidth
          placeholder="Search address or place"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault()
              void search(query)
            }
          }}
          slotProps={{
            input: {
              startAdornment: <SearchIcon fontSize="small" sx={{ mr: 1, color: 'text.secondary' }} />,
              endAdornment: searching ? <CircularProgress size={18} sx={{ mr: 1 }} /> : null,
            },
          }}
        />
        {results.length > 0 && (
          <Paper
            elevation={3}
            sx={{
              position: 'absolute',
              zIndex: 1300,
              left: 0,
              right: 0,
              mt: 0.5,
              maxHeight: 220,
              overflow: 'auto',
            }}
          >
            <List dense disablePadding>
              {results.map((r, i) => (
                <ListItemButton key={i} onClick={() => void applyResult(r)}>
                  <ListItemText
                    primary={r.display_name}
                    slotProps={{ primary: { sx: { fontSize: 12.5 } } }}
                  />
                </ListItemButton>
              ))}
            </List>
          </Paper>
        )}
      </Box>
      <Box
        sx={{
          height: 260,
          borderRadius: 2,
          overflow: 'hidden',
          border: '1px solid',
          borderColor: 'divider',
          '& .leaflet-container': { height: '100%', width: '100%', background: '#e8e6e1' },
        }}
      >
        <MapContainer center={center} zoom={pos ? 16 : 11} scrollWheelZoom style={{ height: '100%', width: '100%' }}>
          <TileLayer url={TILE_URL} attribution={TILE_ATTR} />
          <ClickCapture onPick={pick} />
          <FlyTo target={pos} />
          {pos && <Marker position={pos} icon={pin} />}
        </MapContainer>
      </Box>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mt: 1 }}>
        <Typography variant="caption" sx={{ flex: 1, color: 'text.secondary' }}>
          {busy
            ? 'Looking up address...'
            : label
              ? label
              : pos
                ? `${pos[0].toFixed(6)}, ${pos[1].toFixed(6)}`
                : 'Search or tap the map to set the venue location'}
        </Typography>
        {pos && (
          <Button
            size="small"
            color="inherit"
            onClick={() => {
              setPos(null)
              setLabel('')
              setQuery('')
              onPick({ location: '', lat: null, lng: null })
            }}
          >
            Clear
          </Button>
        )}
      </Box>
    </Box>
  )
}
