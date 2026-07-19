import { useEffect, useRef, useState } from 'react'
import { formatDuration } from '~/lib/format'
import type { Cue } from '~/lib/cue'
import { useWakeLock } from '~/lib/wakeLock'

const LINGER_MS = 1500 // brief "rested" hold; its absence signals rest is over.
const FADE_MS = 500 // opacity transition; keep in sync with .rest-footer's CSS.

// The between-sets rest timer: a fixed bottom footer that auto-starts when a set
// is logged (`startedAt` flips to a fresh timestamp). A CSS-animated bar depletes
// left-to-right over `duration` (purely visual); the JS tick is what actually
// detects the finish, so it buzzes once, holds "rested" for a few seconds, then
// fades out — even if the animation is throttled. Never blocks: × dismisses it,
// and logging the next set restarts it. Rest length is set via the header button.
export default function RestTimer({
  startedAt,
  duration,
  onDismiss,
  cue,
}: {
  startedAt: number | null
  duration: number
  onDismiss: () => void
  cue: Cue
}) {
  const wakeLock = useWakeLock()
  const [now, setNow] = useState(() => Date.now())
  const [done, setDone] = useState(false)
  const [fading, setFading] = useState(false)
  const doneRef = useRef(false)

  // One run per rest (keyed by startedAt) or length change (duration): tick the
  // readout, and at the finish buzz once, let the screen sleep, then linger+fade.
  useEffect(() => {
    if (startedAt == null) return
    doneRef.current = false
    setDone(false)
    setFading(false)
    setNow(Date.now())
    wakeLock.acquire()
    const timeouts: number[] = []
    const tick = window.setInterval(() => {
      const t = Date.now()
      setNow(t)
      if (!doneRef.current && t - startedAt >= duration * 1000) {
        doneRef.current = true
        setDone(true)
        cue.done()
        wakeLock.release()
        timeouts.push(
          window.setTimeout(() => setFading(true), LINGER_MS),
          window.setTimeout(onDismiss, LINGER_MS + FADE_MS),
        )
      }
    }, 250)
    return () => {
      clearInterval(tick)
      timeouts.forEach(clearTimeout)
      wakeLock.release()
    }
  }, [startedAt, duration, cue, onDismiss, wakeLock])

  if (startedAt == null) return null

  const remaining = Math.max(0, Math.ceil(duration - (now - startedAt) / 1000))

  return (
    <div
      className={`rest-footer${done ? ' rest-footer--done' : ''}${fading ? ' rest-footer--fading' : ''}`}
      role="status"
      aria-live="polite"
    >
      <div
        key={`${startedAt}-${duration}`}
        className="rest-footer__bar"
        style={{ animationDuration: `${duration}s` }}
      />
      <div className="rest-footer__row">
        <span className="rest-footer__label">{done ? 'Rested 💪' : 'Rest'}</span>
        {!done && <span className="rest-footer__time tabular">{formatDuration(remaining)}</span>}
        <button className="rest-footer__skip" type="button" onClick={onDismiss} aria-label="dismiss rest timer">
          ×
        </button>
      </div>
    </div>
  )
}
