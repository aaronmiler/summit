import { Link } from 'react-router-dom'
import { useWorkoutHistory } from '~/api/queries'
import { formatDate, workoutDuration } from '~/lib/format'

// The History tab: the picked user's finished workouts, newest first. Tap a row
// for its logged sets. Read-only (the Log is immutable).
export default function History() {
  const { data: workouts, isLoading } = useWorkoutHistory()

  if (isLoading) return <p className="text-muted">Loading…</p>

  return (
    <section>
      <div className="library-header mb-6">
        <h1 className="page-heading text-green">History</h1>
        <Link to="/settings/health-import" className="text-accent">
          Connect Apple Health →
        </Link>
      </div>

      {workouts?.length ? (
        <ol className="history-list">
          {workouts.map((workout) => {
            const duration = workoutDuration(workout.startedAt, workout.finishedAt)
            return (
              <li key={workout.id}>
                <Link to={`/history/${workout.id}`} className="history-row">
                  <span className="history-date">{formatDate(workout.startedAt)}</span>
                  <span className="history-name">{workout.routine?.name ?? 'Off-script'}</span>
                  <span className="history-meta caption text-muted">
                    {workout.setCount} set{workout.setCount === 1 ? '' : 's'}
                    {duration && ` · ${duration}`}
                  </span>
                </Link>
              </li>
            )
          })}
        </ol>
      ) : (
        <p className="text-muted">No finished workouts yet.</p>
      )}
    </section>
  )
}
