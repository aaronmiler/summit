import { Link } from 'react-router-dom'
import { useRoutines } from '~/api/queries'
import ProgramManager from './ProgramManager'

// Library landing: browse the shared routines. Each card opens the routine's
// slots; a link drops into the full exercise list. Read-only for now — editing
// and the LLM builder come later.
export default function Library() {
  const { data: routines, isLoading } = useRoutines()

  return (
    <section>
      <div className="library-header mb-6">
        <h1 className="page-heading text-green">Library</h1>
        <div className="library-header__actions">
          <Link to="/library/exercises" className="text-accent">
            Browse all exercises →
          </Link>
          <Link to="/library/routines/new" className="btn btn--primary btn--compact">
            + New routine
          </Link>
        </div>
      </div>

      <div className="library-section mb-6">
        <h2 className="program-group__title">Programs</h2>
        <ProgramManager />
      </div>

      {isLoading ? (
        <p className="text-muted">Loading…</p>
      ) : routines?.length ? (
        <div className="card-grid">
          {routines.map((routine) => (
            <Link
              key={routine.id}
              to={`/library/routines/${routine.id}`}
              className="card card--interactive library-card"
            >
              <h2 className="card-title text-green">{routine.name}</h2>
              {routine.notes && <p className="card-body">{routine.notes}</p>}
              {(routine.program || routine.preferredFrequency || routine.tags.length > 0) && (
                <div className="badge-row">
                  {routine.program && (
                    <span className="badge badge--accent">{routine.program.name}</span>
                  )}
                  {routine.preferredFrequency && (
                    <span className="badge badge--neutral">{routine.preferredFrequency}</span>
                  )}
                  {routine.tags.map((tag) => (
                    <span key={tag} className="badge badge--neutral">
                      {tag}
                    </span>
                  ))}
                </div>
              )}
            </Link>
          ))}
        </div>
      ) : (
        <p className="text-muted">No routines yet.</p>
      )}
    </section>
  )
}
