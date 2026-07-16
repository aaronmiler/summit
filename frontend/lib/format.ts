import type { SetLog } from '~/types'

// mm:ss (or Ns under a minute) for a single set's hold/duration.
export function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  return `${mins}:${secs.toString().padStart(2, '0')}`
}

// One-line summary of a logged set, tuned to whatever fields it carries. Shared
// by the live session and the history detail.
export function describeSet(set: SetLog): string {
  const parts: string[] = []
  if (set.reps != null) {
    parts.push(set.weight != null ? `${set.reps} × ${set.weight} lb` : `${set.reps} reps`)
  } else if (set.weight != null) {
    parts.push(`${set.weight} lb`)
  }
  if (set.durationSeconds != null) parts.push(formatDuration(set.durationSeconds))
  if (set.rpe != null) parts.push(`@${set.rpe}`)
  if (set.notes) parts.push(set.notes)
  return parts.join('  ') || '—'
}

export function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}

export function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString([], { month: 'short', day: 'numeric' })
}

export function formatDateTime(iso: string): string {
  return `${formatDate(iso)} · ${formatTime(iso)}`
}

// Elapsed time between start and finish, e.g. "48 min" / "1h 12m"; null if unfinished.
export function workoutDuration(startedAt: string, finishedAt: string | null): string | null {
  if (!finishedAt) return null
  const mins = Math.round((new Date(finishedAt).getTime() - new Date(startedAt).getTime()) / 60000)
  if (mins < 60) return `${mins} min`
  return `${Math.floor(mins / 60)}h ${mins % 60}m`
}
