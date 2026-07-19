import { useState } from 'react'
import { formatDuration } from '~/lib/format'
import Adjuster from './Adjuster'

// A small modal for setting the between-sets rest, using the same jog-wheel
// encoder as timed sets so the interaction language matches. Edits a local draft;
// Save commits it, Cancel/backdrop discards. Clamped to a sane floor on save.
export default function RestEditor({
  seconds,
  min,
  onSave,
  onClose,
}: {
  seconds: number
  min: number
  onSave: (seconds: number) => void
  onClose: () => void
}) {
  const [draft, setDraft] = useState(seconds)

  return (
    <div className="modal-backdrop is-visible" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2 className="modal-title text-green">Rest between sets</h2>
        <div className="modal-body">
          <div className="hold-timer">
            <Adjuster value={draft} onChange={setDraft} />
            <div className="hold-box">
              <span className="hold-box__big tabular">{formatDuration(draft)}</span>
              <span className="caption text-muted">rest</span>
            </div>
          </div>
        </div>
        <div className="modal-actions">
          <button className="btn btn--ghost" type="button" onClick={onClose}>
            Cancel
          </button>
          <button
            className="btn btn--primary"
            type="button"
            onClick={() => {
              onSave(Math.max(min, draft))
              onClose()
            }}
          >
            Save
          </button>
        </div>
      </div>
    </div>
  )
}
