import { useEffect, useState } from 'react'
import { useSession } from '../App'

/** Current user's role (empty string before the session hydrates). */
export function useRole(): string {
  const session = useSession()
  return session?.profile?.role ?? ''
}

/** Admin-only: every destructive/management action. */
export function useIsAdmin(): boolean {
  return useRole() === 'Admin'
}

/**
 * Role-gated editing. TRUE (full edit) for Admin/HR/Finance/VenueManager;
 * Coaches keep edit rights only on tables listed in coachEditable.
 * Everyone else (athletes, venue managers on roster tables, ...) gets
 * read-only views — no edit/delete buttons at all.
 */
export function useCanEdit(coachEditable = true): boolean {
  const role = useRole()
  if (role === 'Admin' || role === 'HR' || role === 'Finance' || role === 'VenueManager') return true
  if (role === 'Coach' && coachEditable) return true
  return false
}

/** Athletes get zero management rights anywhere. */
export function useCanEditNoAthlete(coachEditable = true): boolean {
  const can = useCanEdit(coachEditable)
  const role = useRole()
  if (role === 'Athlete') return false
  return can
}
