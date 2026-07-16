import { Link } from 'react-router-dom'
import { useIntegrationEvents } from '~/api/queries'
import { formatDateTime } from '~/lib/format'
import type { IntegrationEvent } from '~/types'

// Sync activity: the integration audit log, newest first. Every inbound push
// (and later, outbound LLM call) shows here — so when a session doesn't appear,
// one glance says whether the push even arrived and what it carried.
export default function Integrations() {
  const { data: events, isLoading, isError } = useIntegrationEvents()

  return (
    <section>
      <div className="library-header mb-6">
        <h1 className="page-heading text-green">Sync activity</h1>
        <Link to="/settings/health-import" className="text-accent">
          Connect Apple Health →
        </Link>
      </div>

      {isLoading ? (
        <p className="text-muted">Loading…</p>
      ) : isError ? (
        <p className="text-muted">Couldn't load events.</p>
      ) : events?.length ? (
        <ol className="event-list">
          {events.map((event) => (
            <EventRow key={event.id} event={event} />
          ))}
        </ol>
      ) : (
        <p className="text-muted">No integration activity yet.</p>
      )}
    </section>
  )
}

function EventRow({ event }: { event: IntegrationEvent }) {
  const ok = event.status === 'ok'
  return (
    <li className="event-row">
      <span className={`event-dot event-dot--${ok ? 'ok' : 'bad'}`} aria-hidden />
      <div className="event-main">
        <div className="event-head">
          <span className="event-kind">{event.kind}</span>
          {!ok && <span className="badge badge--neutral event-status">{event.status}</span>}
        </div>
        {event.summary && <span className="body-small">{event.summary}</span>}
        {event.error && <span className="body-small event-error">{event.error}</span>}
      </div>
      <div className="event-meta caption text-muted">
        <span>{formatDateTime(event.createdAt)}</span>
        {event.user && <span>{event.user}</span>}
      </div>
    </li>
  )
}
