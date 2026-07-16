import { Link } from 'react-router-dom'
import { useExercises } from '~/api/queries'
import type { Exercise } from '~/types'

// The full movement library, grouped by muscle group. Read-only browse; the API
// already returns them ordered by (muscle_group, name), so grouping is a simple
// fold. modality shows as a badge — it's what will drive the logging widget.
export default function Exercises() {
  const { data: exercises, isLoading } = useExercises()

  if (isLoading) return <p className="text-muted">Loading…</p>

  const groups = groupByMuscle(exercises ?? [])

  return (
    <section>
      <Link to="/library" className="text-accent body-small">
        ← Library
      </Link>
      <h1 className="page-heading text-green mt-4 mb-6">Exercises</h1>

      {groups.map(([muscleGroup, items]) => (
        <div key={muscleGroup} className="mb-6">
          <h2 className="subsection-title">{muscleGroup}</h2>
          <ul className="exercise-list">
            {items.map((exercise) => (
              <li key={exercise.id} className="exercise-row">
                <span className="exercise-name">{exercise.name}</span>
                <span className="badge badge--neutral">{exercise.modality}</span>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </section>
  )
}

// Fold the (already sorted) list into [muscleGroup, exercises] pairs, insertion
// order preserved. Null muscle groups collect under "Other".
function groupByMuscle(exercises: Exercise[]): [string, Exercise[]][] {
  const groups = new Map<string, Exercise[]>()
  for (const exercise of exercises) {
    const key = exercise.muscleGroup ?? 'Other'
    const bucket = groups.get(key) ?? []
    bucket.push(exercise)
    groups.set(key, bucket)
  }
  return [...groups.entries()]
}
