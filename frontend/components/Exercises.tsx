import { useState } from 'react'
import { Link } from 'react-router-dom'
import {
  useExercises,
  useCreateExercise,
  useUpdateExercise,
  useDeleteExercise,
} from '~/api/queries'
import { MODALITIES, type Exercise, type ExerciseInput, type Modality } from '~/types'

// The movement library, grouped by muscle group — now editable. The API returns
// them ordered by (muscle_group, name), so grouping is a simple fold. Tapping a
// row opens the editor; "+ New exercise" opens a blank one. modality is
// load-bearing (it drives the logging widget), so it's a required dropdown.
export default function Exercises() {
  const { data: exercises, isLoading } = useExercises()
  // null = closed; { exercise: undefined } = new; { exercise } = editing that row.
  const [editing, setEditing] = useState<{ exercise?: Exercise } | null>(null)

  if (isLoading) return <p className="text-muted">Loading…</p>

  const list = exercises ?? []
  const groups = groupByMuscle(list)
  const muscleGroups = [...new Set(list.map((e) => e.muscleGroup).filter(Boolean))] as string[]

  return (
    <section>
      <Link to="/library" className="text-accent body-small">
        ← Library
      </Link>
      <div className="detail-header mt-4 mb-6">
        <h1 className="page-heading text-green">Exercises</h1>
        <button className="btn btn--primary btn--compact" onClick={() => setEditing({})}>
          + New exercise
        </button>
      </div>

      {groups.map(([muscleGroup, items]) => (
        <div key={muscleGroup} className="mb-6">
          <h2 className="subsection-title">{muscleGroup}</h2>
          <ul className="exercise-list">
            {items.map((exercise) => (
              <li key={exercise.id} className="exercise-row">
                <button className="exercise-edit" onClick={() => setEditing({ exercise })}>
                  <span className="exercise-name">{exercise.name}</span>
                  <span className="badge badge--neutral">{exercise.modality}</span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      ))}
      {list.length === 0 && <p className="text-muted">No exercises yet.</p>}

      {editing && (
        <ExerciseForm
          exercise={editing.exercise}
          muscleGroups={muscleGroups}
          onClose={() => setEditing(null)}
        />
      )}
    </section>
  )
}

// The create/edit modal. Delete lives here (edit mode only); the server guards
// it with a 422 when the movement is referenced, which we surface inline.
function ExerciseForm({
  exercise,
  muscleGroups,
  onClose,
}: {
  exercise?: Exercise
  muscleGroups: string[]
  onClose: () => void
}) {
  const create = useCreateExercise()
  const update = useUpdateExercise(exercise?.id ?? 0)
  const del = useDeleteExercise()
  const saving = create.isPending || update.isPending

  const [name, setName] = useState(exercise?.name ?? '')
  const [modality, setModality] = useState<Modality>(exercise?.modality ?? 'barbell')
  const [muscleGroup, setMuscleGroup] = useState(exercise?.muscleGroup ?? '')
  const [error, setError] = useState<string | null>(null)

  function handleSave() {
    setError(null)
    const input: ExerciseInput = {
      name: name.trim(),
      modality,
      muscleGroup: muscleGroup.trim() || null,
    }
    const opts = {
      onSuccess: onClose,
      onError: (e: unknown) => setError(errorMessage(e) ?? 'Could not save.'),
    }
    if (exercise) update.mutate(input, opts)
    else create.mutate(input, opts)
  }

  function handleDelete() {
    if (!exercise) return
    if (!window.confirm(`Delete "${exercise.name}"?`)) return
    setError(null)
    del.mutate(exercise.id, {
      onSuccess: onClose,
      onError: (e: unknown) => setError(errorMessage(e) ?? 'Could not delete.'),
    })
  }

  return (
    <div className="modal-backdrop is-visible" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2 className="modal-title text-green">{exercise ? 'Edit exercise' : 'New exercise'}</h2>

        <div className="form-group">
          <label className="form-label" htmlFor="exercise-name">Name</label>
          <input
            id="exercise-name"
            className="form-input"
            autoFocus
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Barbell Row"
          />
        </div>

        <div className="form-row">
          <div className="form-group">
            <label className="form-label" htmlFor="exercise-modality">Modality</label>
            <select
              id="exercise-modality"
              className="form-input"
              value={modality}
              onChange={(e) => setModality(e.target.value as Modality)}
            >
              {MODALITIES.map((m) => (
                <option key={m} value={m}>{m}</option>
              ))}
            </select>
          </div>
          <div className="form-group">
            <label className="form-label" htmlFor="exercise-muscle">Muscle group</label>
            <input
              id="exercise-muscle"
              className="form-input"
              list="muscle-groups"
              value={muscleGroup}
              onChange={(e) => setMuscleGroup(e.target.value)}
              placeholder="Back"
            />
            <datalist id="muscle-groups">
              {muscleGroups.map((g) => (
                <option key={g} value={g} />
              ))}
            </datalist>
          </div>
        </div>

        {error && <p className="body-small text-danger mb-4">{error}</p>}

        <div className="modal-actions">
          {exercise && (
            <button
              className="btn btn--ghost text-danger exercise-form__delete"
              disabled={del.isPending}
              onClick={handleDelete}
            >
              Delete
            </button>
          )}
          <button className="btn btn--ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn--primary" disabled={name.trim() === '' || saving} onClick={handleSave}>
            {saving ? 'Saving…' : 'Save'}
          </button>
        </div>
      </div>
    </div>
  )
}

// The client throws an Error whose `body` is the parsed JSON; our 422s carry
// `{ error }` (guard) or `{ errors: [...] }` (validation). Pull a message from
// either shape.
function errorMessage(e: unknown): string | null {
  const body = (e as { body?: { error?: string; errors?: string[] } })?.body
  if (!body) return null
  if (body.error) return body.error
  if (body.errors?.length) return body.errors.join(', ')
  return null
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
