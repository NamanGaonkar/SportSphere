/** Full rupee formatting for tables (1,23,456 style, en-IN). */
export function inr(n: number | null | undefined): string {
  if (n == null || Number.isNaN(Number(n))) return '-'
  return `Rs ${Math.round(Number(n)).toLocaleString('en-IN')}`
}

/** Compact rupee formatting for stat cards: 1.2 Cr / 4.5 L / 12.3 K so the
    card value never overflows its box. */
export function inrCompact(n: number | null | undefined): string {
  const v = Number(n ?? 0)
  if (!Number.isFinite(v)) return '-'
  const abs = Math.abs(v)
  if (abs >= 1_00_00_000) return `Rs ${(v / 1_00_00_000).toFixed(abs >= 10_00_00_000 ? 0 : 2)} Cr`
  if (abs >= 1_00_000) return `Rs ${(v / 1_00_000).toFixed(abs >= 10_00_000 ? 0 : 2)} L`
  if (abs >= 1_000) return `Rs ${(v / 1_000).toFixed(abs >= 10_000 ? 0 : 1)} K`
  return `Rs ${Math.round(v)}`
}
