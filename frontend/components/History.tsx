import { Link } from 'react-router-dom'
import { useWorkoutHistory } from '~/api/queries'
import { formatDate, formatTime, workoutDuration } from '~/lib/format'
import type { SessionSummary, WorkoutSummary } from '~/types'

// The History tab: the picked user's finished workouts, grouped into training
// sessions, newest first. A session with a single workout renders as a plain
// row; a multi-event day (warmup + lift + watch strength) renders as a card with
// its workouts nested. Each row taps through to its own logged sets. Read-only.
export default function History() {
  const { data: sessions, isLoading } = useWorkoutHistory()

  if (isLoading) return <p className="text-muted">Loading…</p>

  return (
    <section>
      <div className="library-header mb-6">
        <h1 className="page-heading text-green">History</h1>
        <div className="header-links">
          <Link to="/settings/integrations" className="text-accent">
            Sync activity →
          </Link>
          <Link to="/settings/health-import" className="text-accent">
            Connect Apple Health →
          </Link>
        </div>
      </div>

      {sessions?.length ? (
        <ol className="history-list">
          {sessions.map((session) => (
            <li key={session.id}>
              {session.workouts.length === 1 ? (
                <WorkoutRow workout={session.workouts[0]} />
              ) : (
                <SessionCard session={session} />
              )}
            </li>
          ))}
        </ol>
      ) : (
        <p className="text-muted">No finished workouts yet.</p>
      )}
    </section>
  )
}

// A multi-event session: a derived header (name, rolled-up meta) over its
// workouts. `lead` on the nested rows shows the time so their sequence reads.
function SessionCard({ session }: { session: SessionSummary }) {
  return (
    <div className="session-card">
      <div className="session-header">
        <span className="history-date">{formatDate(session.startedAt)}</span>
        <span className="history-name">{session.name}</span>
        <span className="history-meta caption text-muted">
          {sessionMeta(session)}
        </span>
      </div>
      <ol className="session-workouts">
        {session.workouts.map((workout) => (
          <li key={workout.id}>
            <WorkoutRow workout={workout} lead={formatTime(workout.startedAt)} />
          </li>
        ))}
      </ol>
    </div>
  )
}

// One workout row. Standalone it leads with the date; nested in a session it
// leads with the time (passed as `lead`).
function WorkoutRow({ workout, lead }: { workout: WorkoutSummary; lead?: string }) {
  const duration = workoutDuration(workout.startedAt, workout.finishedAt)
  const name = workout.routine?.name ?? workout.activity ?? 'Off-script'
  const meta = [
    workout.setCount > 0 && `${workout.setCount} set${workout.setCount === 1 ? '' : 's'}`,
    workout.calories != null && `${workout.calories} cal`,
    duration,
  ]
    .filter(Boolean)
    .join(' · ')
  return (
    <Link to={`/history/${workout.id}`} className="history-row">
      <span className="history-date">{lead ?? formatDate(workout.startedAt)}</span>
      <span className="history-name">{name}</span>
      <span className="history-meta caption text-muted">{meta}</span>
    </Link>
  )
}

function sessionMeta(session: SessionSummary): string {
  const duration = workoutDuration(session.startedAt, session.finishedAt)
  return [
    session.setCount > 0 && `${session.setCount} set${session.setCount === 1 ? '' : 's'}`,
    session.calories != null && `${session.calories} cal`,
    duration,
  ]
    .filter(Boolean)
    .join(' · ')
}
