import { Link, useParams } from 'react-router-dom'
import { useWorkoutDetail } from '~/api/queries'
import { describeSet, formatDateTime, formatPace, workoutDuration } from '~/lib/format'
import type { WorkoutHealth } from '~/types'

// One past workout: its logged sets grouped by exercise. Grouping is off the Log
// (each set carries its own exercise), so it's correct even if the routine has
// since changed. Read-only.
export default function WorkoutDetail() {
  const { id } = useParams()
  const { data: workout, isLoading, isError } = useWorkoutDetail(id)

  if (isLoading) return <p className="text-muted">Loading…</p>
  if (isError || !workout) return <p className="text-muted">Workout not found.</p>

  const duration = workoutDuration(workout.startedAt, workout.finishedAt)

  return (
    <section>
      <Link to="/history" className="text-accent body-small">
        ← History
      </Link>
      <h1 className="page-heading text-green mt-4">
        {workout.routine?.name ?? workout.health?.activity ?? 'Off-script'}
      </h1>
      <p className="caption text-muted mb-6">
        {formatDateTime(workout.startedAt)}
        {duration && ` · ${duration}`}
      </p>

      {workout.health ? (
        <HealthStats health={workout.health} />
      ) : (
        workout.notes && <p className="body-text text-muted mb-4">{workout.notes}</p>
      )}

      {workout.exercises.length === 0 ? (
        <p className="text-muted">No sets were logged.</p>
      ) : (
        <ol className="slot-list">
          {workout.exercises.map((group) => (
            <li key={group.exercise.id} className="card card--surface slot">
              <div className="slot-head">
                <span className="slot-name text-green">
                  {group.exercise.name}
                  <span className="badge badge--neutral slot-tag">{group.exercise.modality}</span>
                </span>
              </div>
              <ol className="logged-sets">
                {group.sets.map((set) => (
                  <li key={set.id} className="logged-set">
                    <span className="logged-set__n caption text-muted">#{set.setNumber}</span>
                    <span className="logged-set__val">{describeSet(set)}</span>
                  </li>
                ))}
              </ol>
            </li>
          ))}
        </ol>
      )}
    </section>
  )
}

// Apple Health stats for an import-materialized workout: only the fields the
// export actually carried (older/indoor pushes omit distance, HR, etc.).
function HealthStats({ health }: { health: WorkoutHealth }) {
  const pace = formatPace(health.distance, health.durationSeconds, health.distanceUnits)
  const hr =
    health.avgHr != null
      ? `${health.avgHr}${health.maxHr != null ? ` / ${health.maxHr}` : ''} bpm`
      : null

  const stats = [
    health.distance != null && `${health.distance} ${health.distanceUnits ?? 'mi'}`,
    pace,
    health.elevation != null && `${health.elevation} ${health.elevationUnits ?? 'ft'} ↑`,
    hr,
    health.calories != null && `${health.calories} cal`,
    health.totalCalories != null && `${health.totalCalories} cal out`,
  ].filter(Boolean) as string[]

  if (stats.length === 0) return null

  return (
    <div className="badge-row mb-6">
      {stats.map((s) => (
        <span key={s} className="badge badge--neutral">
          {s}
        </span>
      ))}
    </div>
  )
}
