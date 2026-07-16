import { Link, useParams } from 'react-router-dom'
import { useRoutine } from '~/api/queries'
import type { RoutineExercise } from '~/types'

// One routine's ordered slots. A slot is an exercise XOR a progression; the
// progression case shows the phase ladder inline (current phase is per-user and
// derived from the Log, so it isn't highlighted here — that's a logging concern).
export default function RoutineDetail() {
  const { id } = useParams()
  const { data: routine, isLoading, isError } = useRoutine(id)

  if (isLoading) return <p className="text-muted">Loading…</p>
  if (isError || !routine) return <p className="text-muted">Routine not found.</p>

  return (
    <section>
      <Link to="/library" className="text-accent body-small">
        ← Library
      </Link>
      <h1 className="page-heading text-green mt-4">{routine.name}</h1>
      {routine.notes && <p className="body-text text-muted mb-4">{routine.notes}</p>}
      {(routine.preferredFrequency || routine.tags.length > 0) && (
        <div className="badge-row mb-6">
          {routine.preferredFrequency && (
            <span className="badge badge--accent">{routine.preferredFrequency}</span>
          )}
          {routine.tags.map((tag) => (
            <span key={tag} className="badge badge--neutral">
              {tag}
            </span>
          ))}
        </div>
      )}

      <ol className="slot-list">
        {routine.routineExercises.map((slot) => (
          <Slot key={slot.id} slot={slot} />
        ))}
      </ol>
    </section>
  )
}

function Slot({ slot }: { slot: RoutineExercise }) {
  const { exercise, progression } = slot

  return (
    <li className="card card--surface slot">
      <div className="slot-head">
        <span className="slot-name text-green">
          {exercise ? exercise.name : progression?.name}
          {progression && <span className="badge badge--neutral slot-tag">progression</span>}
          {exercise && (
            <span className="badge badge--neutral slot-tag">{exercise.modality}</span>
          )}
        </span>
        {slot.target && <span className="slot-target">{slot.target}</span>}
      </div>

      <div className="slot-meta caption text-muted">
        {slot.restSeconds != null && <span>{formatRest(slot.restSeconds)} rest</span>}
        {exercise?.muscleGroup && <span>{exercise.muscleGroup}</span>}
      </div>

      {slot.notes && <p className="body-small text-muted slot-note">{slot.notes}</p>}
      {slot.progressionNote && (
        <p className="body-small text-muted slot-note">{slot.progressionNote}</p>
      )}

      {progression && (
        <ol className="phase-list">
          {progression.phases.map((phase) => (
            <li key={phase.position} className="phase">
              <span className="phase-name">{phase.exerciseName}</span>
              {phase.target && <span className="phase-target caption text-muted">{phase.target}</span>}
              {phase.graduationCriteria && (
                <span className="phase-grad caption text-driftwood">
                  → {phase.graduationCriteria}
                </span>
              )}
            </li>
          ))}
        </ol>
      )}
    </li>
  )
}

// "120" -> "2:00", "90" -> "1:30", "60" -> "60s".
function formatRest(seconds: number): string {
  if (seconds < 60) return `${seconds}s`
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  return `${mins}:${secs.toString().padStart(2, '0')}`
}
