import { useEffect, useRef, useState, type ReactNode } from 'react'
import Box from '@mui/material/Box'

/**
 * Circular-reveal section transition (the same feel as the mobile app).
 * The new page grows out of a circle anchored at the point the user last
 * pressed — tapping a sidebar item makes the section pour out of the menu,
 * tapping a dashboard card makes it grow out of that card.
 *
 * Implementation notes:
 * - One document-level pointerdown listener records the last tap position.
 * - `locationKey` changes -> the inner Box remounts (via key) and plays the
 *   clip-path circle animation from that recorded point.
 * - The very first mount plays no animation (no weird flash after login).
 */
export default function PageTransition({ locationKey, children }: { locationKey: string; children: ReactNode }) {
  const origin = useRef({ x: 0, y: 0 })
  const first = useRef(true)
  const [plays, setPlays] = useState(0)

  useEffect(() => {
    const onDown = (e: PointerEvent) => {
      origin.current = { x: e.clientX, y: e.clientY }
    }
    document.addEventListener('pointerdown', onDown)
    return () => document.removeEventListener('pointerdown', onDown)
  }, [])

  useEffect(() => {
    if (first.current) {
      first.current = false
      return
    }
    setPlays((p) => p + 1)
  }, [locationKey])

  const { x, y } = origin.current

  return (
    <Box
      key={locationKey}
      sx={{
        '@keyframes circleIn': {
          from: {
            clipPath: `circle(0px at ${x}px ${y}px)`,
            opacity: 0.35,
          },
          to: {
            clipPath: `circle(142% at ${x}px ${y}px)`,
            opacity: 1,
          },
        },
        animation: plays > 0 ? 'circleIn 380ms cubic-bezier(0.4, 0, 0.2, 1)' : 'none',
      }}
    >
      {children}
    </Box>
  )
}
