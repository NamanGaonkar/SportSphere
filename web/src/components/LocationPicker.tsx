import { useEffect, useMemo, useState } from 'react'
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

/** Smoothly flies the map when the pin moves via search results. */
function FlyTo({ target }: { target: [number, number] | null }) {
  const map = useMap()
  useEffect(() => {
    if (target) map.flyTo(target, 16, { duration: 0.6 })
  }, [target, map])
  return null
}

type GeoResult = { display_name: string; lat: string; lon: string }

export type LocationPickerResult = { location: string; lat: number | null; lng: number | null }

/**
 * Map + geocode location picker used in the Venue form (web).
 * - Click the map to drop the pin; Nominatim reverse-geocodes the address.
 * - Search box finds addresses/places and flies the pin there.
 * (Note: browsers do not allow setting User-Agent on fetch — the browser
 * sends its own, which satisfies Nominatim's policy on the web.)
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

  const center = useMemo<[number, number]>(() => pos ?? DEFAULT_CENTER, [pos])

  async function reverseGeocode(lat: number, lng: number) {
    setBusy(true)
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}`,
        { headers: { Accept: 'application/json' } },
      )
      const j = (await res.json()) as { display_name?: string }
      setLabel(j.display_name ?? '')
      onPick({ location: j.display_name ?? `${lat.toFixed(6)}, ${lng.toFixed(6)}`, lat, lng })
    } catch {
      // Nominatim can rate-limit; coordinates are still valid data.
      setLabel('')
      onPick({ location: `${lat.toFixed(6)}, ${lng.toFixed(6)}`, lat, lng })
    } finally {
      setBusy(false)
    }
  }

  function pick(lat: number, lng: number) {
    const p: [number, number] = [lat, lng]
    setPos(p)
    void reverseGeocode(lat, lng)
  }

  async function search() {
    const q = query.trim()
    if (!q) return
    setSearching(true)
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&q=${encodeURIComponent(q)}`,
        { headers: { Accept: 'application/json' } },
      )
      setResults((await res.json()) as GeoResult[])
    } catch {
      setResults([])
    } finally {
      setSearching(false)
    }
  }

  function applyResult(r: GeoResult) {
    const p: [number, number] = [Number(r.lat), Number(r.lon)]
    setResults([])
    setQuery('')
    setPos(p)
    setLabel(r.display_name)
    onPick({ location: r.display_name, lat: p[0], lng: p[1] })
  }

  return (
    <Box>
      {/* Address search — was missing; mirrors the mobile picker */}
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
              void search()
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
                <ListItemButton key={i} onClick={() => applyResult(r)}>
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
                : 'Tap the map or search to set the venue location'}
        </Typography>
        {pos && (
          <Button
            size="small"
            color="inherit"
            onClick={() => {
              setPos(null)
              setLabel('')
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
