import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useHealthImportSetup } from '~/api/queries'

// "Connect Apple Health": the values to paste into the Health Auto Export app so
// it pushes your workouts to Summit. HAE strips header values on export, so the
// auth header is always added by hand — the URL + settings can come from a file.
export default function HealthImportSetup() {
  const { data: setup, isLoading, isError } = useHealthImportSetup()

  if (isLoading) return <p className="text-muted">Loading…</p>
  if (isError || !setup) return <p className="text-muted">Couldn't load setup.</p>

  return (
    <section className="setup">
      <Link to="/history" className="text-accent body-small">
        ← History
      </Link>
      <h1 className="page-heading text-green mt-4 mb-2">Connect Apple Health</h1>
      <p className="text-muted mb-6">
        Summit imports your Apple Fitness workouts through the{' '}
        <strong>Health Auto Export</strong> app. Set up one REST API automation:
      </p>

      <ol className="setup-steps">
        <li>
          In Health Auto Export, add an <strong>Automation</strong> → type <strong>REST API</strong>.
        </li>
        <li>
          Paste this as the <strong>URL</strong>:
          <CopyRow value={setup.url} />
        </li>
        <li>
          Add a <strong>header</strong> — Health Auto Export can't carry this in a file, so add it
          here by hand:
          <CopyRow label="Key" value={setup.headerKey} />
          <CopyRow label="Value" value={setup.headerValue} />
        </li>
        <li>
          Set <strong>Export Data Type</strong> = Workouts, <strong>Format</strong> = JSON,{' '}
          <strong>Export Version</strong> = v2, then save. It syncs every few minutes and backfills
          the last 7 days (re-sends are de-duplicated).
        </li>
      </ol>

      <div className="setup-file">
        <p className="body-small text-muted mb-2">
          Prefer importing a file? This pre-fills the URL and settings — you'll still add the header
          above after importing.
        </p>
        <button className="btn btn--secondary" onClick={() => downloadConfig(setup.url)}>
          Download config file
        </button>
      </div>
    </section>
  )
}

function CopyRow({ label, value }: { label?: string; value: string }) {
  const [copied, setCopied] = useState(false)

  async function copy() {
    await navigator.clipboard.writeText(value)
    setCopied(true)
    setTimeout(() => setCopied(false), 1500)
  }

  return (
    <div className="copy-row">
      {label && <span className="copy-row__label caption text-muted">{label}</span>}
      <code className="copy-row__value">{value}</code>
      <button className="btn btn--ghost btn--compact" onClick={copy}>
        {copied ? 'Copied' : 'Copy'}
      </button>
    </div>
  )
}

// Build a Health Auto Export automation config with the URL + workout settings
// filled in, and download it. Headers stay empty (HAE never imports them).
function downloadConfig(url: string) {
  const config = {
    configSchemaVersion: '1.0',
    name: 'Summit Workouts',
    exportDestination: 'restApi',
    urlString: url,
    headers: [],
    exportDataType: 'workouts',
    exportFormat: 'JSON',
    exportVersion: 'ExportVersion.v2',
    exportPeriod: 'Previous 7 Days',
    exportFileLength: 'day',
    includeWorkouts: true,
    includeWorkoutMetadata: true,
    includeRoutes: true,
    includeHealthMetrics: false,
    aggregateData: true,
    syncCadenceInterval: 'minutes',
    syncCadenceNumber: 5,
    requestTimeout: 60,
    metrics: [],
    workoutTypes: [],
  }

  const blob = new Blob([JSON.stringify(config, null, 2)], { type: 'application/json' })
  const href = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = href
  a.download = 'summit-health-import.json'
  a.click()
  URL.revokeObjectURL(href)
}
