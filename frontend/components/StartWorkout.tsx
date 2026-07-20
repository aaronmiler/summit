import { useRoutines, useStartWorkout } from '~/api/queries'
import type { Routine } from '~/types'

// No active workout: pick a routine to start one. Routines are grouped into their
// programs so Today stays scannable when there are lots of options; ungrouped
// routines fall under "Other". Before any program exists, it's a flat grid (no
// headings). Starting primes the current-workout cache, so Today flips straight
// to the logging session.
export default function StartWorkout() {
  const { data: routines, isLoading } = useRoutines()
  const start = useStartWorkout()

  const { groups, grouped } = groupByProgram(routines ?? [])

  return (
    <section>
      <h1 className="page-heading text-green mb-2">Today</h1>
      <p className="text-muted mb-6">Pick a routine to start logging.</p>

      {isLoading ? (
        <p className="text-muted">Loading…</p>
      ) : routines?.length ? (
        groups.map((group) => (
          <div key={group.name} className="program-group">
            {grouped && <h2 className="program-group__title">{group.name}</h2>}
            <div className="card-grid">
              {group.routines.map((routine) => (
                <button
                  key={routine.id}
                  className="card card--interactive library-card start-card"
                  disabled={start.isPending}
                  onClick={() => start.mutate(routine.id)}
                >
                  <h2 className="card-title text-green">{routine.name}</h2>
                  {routine.notes && <p className="card-body">{routine.notes}</p>}
                </button>
              ))}
            </div>
          </div>
        ))
      ) : (
        <p className="text-muted">No routines yet — build one in the Library.</p>
      )}
    </section>
  )
}

// Bucket routines by program (alphabetical), ungrouped under "Other" last.
// `grouped` is false when nothing is assigned yet, so Today renders a flat grid
// with no section headings until programs are actually in use.
function groupByProgram(routines: Routine[]): {
  groups: { name: string; routines: Routine[] }[]
  grouped: boolean
} {
  const named = new Map<string, Routine[]>()
  const other: Routine[] = []
  for (const routine of routines) {
    if (routine.program) {
      const list = named.get(routine.program.name) ?? []
      list.push(routine)
      named.set(routine.program.name, list)
    } else {
      other.push(routine)
    }
  }

  const groups = [...named.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([name, groupRoutines]) => ({ name, routines: groupRoutines }))
  if (other.length) groups.push({ name: 'Other', routines: other })

  return { groups, grouped: named.size > 0 }
}
