import { useMemo, useState } from 'react'
import { MapContainer, TileLayer, Marker, useMapEvents } from 'react-leaflet'
import L from 'leaflet'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import Typography from '@mui/material/Typography'
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

export type LocationPickerResult = { location: string; lat: number | null; lng: number | null }

/**
 * Map + reverse-geocode location picker used in the Venue form (web).
 * Tap anywhere to drop the pin; the human-readable address is filled via
 * Nominatim (OSM's free reverse-geocoding service).
 */
export default function LocationPicker({
  initial,
  onPick,
}: {
  /** "lat,lng" string when editing a venue that already has coordinates. */
  initial?: { lat: number | null; lng: number | null }
  onPick: (r: LocationPickerResult) => void
}) {
  const [pos, setPos] = useState<[number, number] | null>(
    initial?.lat != null && initial?.lng != null ? [initial.lat, initial.lng] : null,
  )
  const [label, setLabel] = useState('')
  const [busy, setBusy] = useState(false)

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

  return (
    <Box>
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
                : 'Tap the map to set the venue location'}
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
