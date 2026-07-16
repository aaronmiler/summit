import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type KeyboardEvent as ReactKeyboardEvent,
  type PointerEvent as ReactPointerEvent,
} from 'react'
import { formatDuration } from '~/lib/format'

// The two tunable knobs. Deploy-to-change is fine — they're not user settings.
const COUNT_IN_SECONDS = 5 // "get set" runway before the hold begins.
const STOP_SHAVE_SECONDS = 3 // reaction/reach-to-phone lag, trimmed off every stop.
const DEFAULT_TARGET = 20 // where the encoder sits with no prior hang to seed from.
const PX_PER_UNIT = 10 // horizontal drag distance (px) that changes the value by 1s.

const COUNT_IN_MS = COUNT_IN_SECONDS * 1000

// The full `timed` (hangboard) widget: a thumb-first hold timer that logs its
// own set. One consistent control stack — an adjuster bar, a big box, a
// full-width primary button — where only the box content and the button's job
// change per step:
//   idle    -> adjuster sets the target, box shows it, button = Start
//   running -> box shows the live timer (5s count-in, count DOWN to 0, then UP
//              into overtime); button = Stop; adjuster is frozen
//   done    -> adjuster edits the held result, box shows it, button = Log
// The target and the result are distinct values, so the seed and the output are
// never the same box. Screen stays awake for the whole run.
export default function HoldTimer({
  seedTarget,
  pending,
  onLog,
}: {
  seedTarget: number | null
  pending: boolean
  onLog: (seconds: number) => void
}) {
  const [target, setTarget] = useState(seedTarget && seedTarget > 0 ? seedTarget : DEFAULT_TARGET)
  const [result, setResult] = useState<number | null>(null) // set once a run ends.
  const [running, setRunning] = useState(false)
  const [now, setNow] = useState(0)
  const startedAt = useRef<number | null>(null)
  const targetMs = useRef(0)
  const lastElapsed = useRef(0)

  const wakeLock = useWakeLock()
  const cue = useCue()

  const start = useCallback(() => {
    if (!(target > 0)) return
    targetMs.current = target * 1000
    startedAt.current = Date.now()
    lastElapsed.current = 0
    setResult(null)
    setNow(Date.now())
    setRunning(true)
    wakeLock.acquire()
    cue.arm()
  }, [target, wakeLock, cue])

  const stop = useCallback(() => {
    const began = startedAt.current
    startedAt.current = null
    setRunning(false)
    wakeLock.release()
    // Only produce a result if the hold actually started (past the count-in);
    // a stop during the count-in is an abort.
    if (began != null) {
      const elapsed = Date.now() - began
      if (elapsed >= COUNT_IN_MS) {
        const held = (elapsed - COUNT_IN_MS) / 1000
        setResult(Math.max(0, Math.round(held) - STOP_SHAVE_SECONDS))
      }
    }
  }, [wakeLock])

  const log = useCallback(() => {
    if (result == null) return
    onLog(result)
    setResult(null) // ready for the next set; target stays for a repeat.
  }, [result, onLog])

  // Tick while running: advance the display and fire the cues at each second
  // boundary. Timestamp-based so it can't drift.
  useEffect(() => {
    if (!running) return
    const id = setInterval(() => {
      const began = startedAt.current
      if (began == null) return
      const t = Date.now()
      fireCues(cue, lastElapsed.current, t - began, targetMs.current)
      lastElapsed.current = t - began
      setNow(t)
    }, 100)
    return () => clearInterval(id)
  }, [running, cue])

  useEffect(() => () => wakeLock.release(), [wakeLock]) // release if we unmount mid-hold.

  // --- running ---
  if (running) {
    const elapsed = startedAt.current == null ? 0 : now - startedAt.current
    const inCountIn = elapsed < COUNT_IN_MS
    return (
      <div className="hold-timer">
        <Adjuster value={target} disabled />
        {inCountIn ? (
          <Box label="get set" big={String(Math.ceil((COUNT_IN_MS - elapsed) / 1000))} />
        ) : (
          <LiveBox holdSeconds={(elapsed - COUNT_IN_MS) / 1000} targetSeconds={targetMs.current / 1000} />
        )}
        <button className="btn btn--primary hold-timer__primary" type="button" onClick={stop}>
          {inCountIn ? 'Cancel' : 'Stop'}
        </button>
      </div>
    )
  }

  // --- done ---
  if (result != null) {
    return (
      <div className="hold-timer">
        <Adjuster value={result} onChange={setResult} />
        <Box big={formatDuration(result)} label="held" />
        <button className="btn btn--primary hold-timer__primary" type="button" disabled={pending} onClick={log}>
          Log set
        </button>
        <button className="btn btn--ghost hold-timer__redo" type="button" onClick={() => setResult(null)}>
          ↺ Redo
        </button>
      </div>
    )
  }

  // --- idle ---
  return (
    <div className="hold-timer">
      <Adjuster value={target} onChange={setTarget} />
      <Box big={formatDuration(target)} label="target" />
      <button
        className="btn btn--primary hold-timer__primary"
        type="button"
        disabled={!(target > 0)}
        onClick={start}
      >
        Start hold ▸
      </button>
    </div>
  )
}

// The adjuster bar: [−] encoder [+]. The encoder is a jog wheel — drag left/right
// for a *relative* delta (no anchor, effectively infinite), with scrolling ticks
// and a fixed center line. Steppers and arrow keys nudge by 1s; a spinbutton role
// keeps it accessible without pretending to have a fixed range.
function Adjuster({
  value,
  onChange,
  disabled,
}: {
  value: number
  onChange?: (n: number) => void
  disabled?: boolean
}) {
  const drag = useRef<{ x: number; from: number } | null>(null)
  const set = (n: number) => onChange?.(Math.max(0, n))

  const onPointerDown = (e: ReactPointerEvent) => {
    if (disabled || !onChange) return
    e.currentTarget.setPointerCapture?.(e.pointerId)
    drag.current = { x: e.clientX, from: value }
  }
  const onPointerMove = (e: ReactPointerEvent) => {
    if (!drag.current) return
    set(drag.current.from + Math.round((e.clientX - drag.current.x) / PX_PER_UNIT))
  }
  const endDrag = () => {
    drag.current = null
  }
  const onKeyDown = (e: ReactKeyboardEvent) => {
    if (e.key === 'ArrowRight' || e.key === 'ArrowUp') set(value + 1)
    else if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') set(value - 1)
    else return
    e.preventDefault()
  }

  return (
    <div className="adjuster">
      <button className="adjuster__step" type="button" disabled={disabled} onClick={() => set(value - 1)} aria-label="minus one second">
        −
      </button>
      <div
        className={`encoder ${disabled ? 'encoder--disabled' : ''}`}
        role="spinbutton"
        tabIndex={disabled ? -1 : 0}
        aria-valuenow={value}
        aria-label="seconds"
        aria-disabled={disabled || undefined}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        onKeyDown={onKeyDown}
        style={{ '--tick-offset': `${-value * PX_PER_UNIT}px` } as CSSProperties}
      >
        <div className="encoder__ticks" />
        <div className="encoder__cursor" />
      </div>
      <button className="adjuster__step" type="button" disabled={disabled} onClick={() => set(value + 1)} aria-label="plus one second">
        +
      </button>
    </div>
  )
}

// The big central box: a large number with a small caption under it.
function Box({ big, label, over }: { big: string; label: string; over?: boolean }) {
  return (
    <div className={`hold-box ${over ? 'hold-box--over' : ''}`}>
      <span className="hold-box__big tabular">{big}</span>
      <span className="caption text-muted">{label}</span>
    </div>
  )
}

// Live during the hold: "N left" down to the target, then "N over" counting up.
function LiveBox({ holdSeconds, targetSeconds }: { holdSeconds: number; targetSeconds: number }) {
  const remaining = targetSeconds - holdSeconds
  const over = remaining <= 0
  const value = over ? Math.floor(holdSeconds - targetSeconds) : Math.ceil(remaining)
  return <Box big={formatDuration(value)} label={over ? 'over' : 'left'} over={over} />
}

// Fire cues on second boundaries: a tick on each count-in second, GO when the
// hold starts, and a distinct beep when the target is reached (the down->up flip).
function fireCues(cue: Cue, prevMs: number, curMs: number, targetMs: number) {
  if (curMs < COUNT_IN_MS) {
    const prevSec = Math.ceil((COUNT_IN_MS - Math.max(prevMs, 0)) / 1000)
    const curSec = Math.ceil((COUNT_IN_MS - curMs) / 1000)
    if (curSec < prevSec && curSec >= 1) cue.tick()
  }
  if (prevMs < COUNT_IN_MS && curMs >= COUNT_IN_MS) cue.go()
  const prevHold = prevMs - COUNT_IN_MS
  const curHold = curMs - COUNT_IN_MS
  if (prevHold < targetMs && curHold >= targetMs) cue.target()
}

// --- Screen wake lock ------------------------------------------------------
// Feature-detected; a no-op where unsupported. Browsers drop the lock when the
// tab is hidden, so re-acquire on return-to-foreground while we're still active.
function useWakeLock() {
  const sentinel = useRef<WakeLockSentinel | null>(null)
  const active = useRef(false)

  const acquire = useCallback(async () => {
    active.current = true
    try {
      if ('wakeLock' in navigator) sentinel.current = await navigator.wakeLock.request('screen')
    } catch {
      /* denied or unsupported — the timer still works, the screen just may dim */
    }
  }, [])

  const release = useCallback(() => {
    active.current = false
    sentinel.current?.release().catch(() => {})
    sentinel.current = null
  }, [])

  useEffect(() => {
    const onVisible = () => {
      if (active.current && !sentinel.current && document.visibilityState === 'visible') acquire()
    }
    document.addEventListener('visibilitychange', onVisible)
    return () => document.removeEventListener('visibilitychange', onVisible)
  }, [acquire])

  return useMemo(() => ({ acquire, release }), [acquire, release])
}

// --- Audio + haptic cues ---------------------------------------------------
// On a hangboard your hands are on the bar and the phone's on the floor, so the
// beeps are the point — you run this eyes-off. All guarded: silent where the
// APIs are missing (e.g. tests).
type Cue = { arm: () => void; tick: () => void; go: () => void; target: () => void }

function useCue(): Cue {
  const ctx = useRef<AudioContext | null>(null)

  const arm = useCallback(() => {
    try {
      const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
      if (Ctor && !ctx.current) ctx.current = new Ctor()
      ctx.current?.resume?.()
    } catch {
      /* no audio available */
    }
  }, [])

  const beep = useCallback((freq: number, ms: number, vibe: number | number[]) => {
    const c = ctx.current
    if (c) {
      try {
        const osc = c.createOscillator()
        const gain = c.createGain()
        osc.frequency.value = freq
        osc.connect(gain)
        gain.connect(c.destination)
        gain.gain.setValueAtTime(0.15, c.currentTime)
        gain.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + ms / 1000)
        osc.start()
        osc.stop(c.currentTime + ms / 1000)
      } catch {
        /* ignore */
      }
    }
    try {
      if ('vibrate' in navigator) navigator.vibrate(vibe)
    } catch {
      /* ignore */
    }
  }, [])

  const tick = useCallback(() => beep(660, 90, 30), [beep])
  const go = useCallback(() => beep(880, 220, 80), [beep])
  const target = useCallback(() => beep(990, 260, [60, 40, 140]), [beep])
  return useMemo(() => ({ arm, tick, go, target }), [arm, tick, go, target])
}
