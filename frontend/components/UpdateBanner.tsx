import { useState } from 'react'
import { useVersionCheck } from '~/api/queries'

// Shown when the server is running a newer build than the one this tab loaded
// (a deploy landed mid-session). Refresh reloads into the new build; Later
// dismisses it for this session. Stays hidden in dev, where the version is the
// constant "dev" and never moves.
export default function UpdateBanner() {
  const { updateAvailable } = useVersionCheck()
  const [dismissed, setDismissed] = useState(false)

  if (!updateAvailable || dismissed) return null

  return (
    <div className="alert alert--info update-banner" role="status">
      <span>A new version of Summit is available.</span>
      <span className="update-banner__actions">
        <button className="btn btn--primary btn--compact" onClick={() => window.location.reload()}>
          Refresh
        </button>
        <button className="btn btn--ghost btn--compact" onClick={() => setDismissed(true)}>
          Later
        </button>
      </span>
    </div>
  )
}
