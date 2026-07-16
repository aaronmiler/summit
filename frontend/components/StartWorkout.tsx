import { useRoutines, useStartWorkout } from '~/api/queries'

// No active workout: pick a routine to start one. Starting primes the
// current-workout cache, so Today flips straight to the logging session.
export default function StartWorkout() {
  const { data: routines, isLoading } = useRoutines()
  const start = useStartWorkout()

  return (
    <section>
      <h1 className="page-heading text-green mb-2">Today</h1>
      <p className="text-muted mb-6">Pick a routine to start logging.</p>

      {isLoading ? (
        <p className="text-muted">Loading…</p>
      ) : routines?.length ? (
        <div className="card-grid">
          {routines.map((routine) => (
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
      ) : (
        <p className="text-muted">No routines yet — build one in the Library.</p>
      )}
    </section>
  )
}
