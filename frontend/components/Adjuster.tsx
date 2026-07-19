import {
  useRef,
  type CSSProperties,
  type KeyboardEvent as ReactKeyboardEvent,
  type PointerEvent as ReactPointerEvent,
} from 'react'

const PX_PER_UNIT = 10 // horizontal drag distance (px) that changes the value by 1s.

// The adjuster bar: [−] encoder [+]. The encoder is a jog wheel — drag left/right
// for a *relative* delta (no anchor, effectively infinite), with scrolling ticks
// and a fixed center line. Steppers and arrow keys nudge by 1s; a spinbutton role
// keeps it accessible without pretending to have a fixed range. Shared by the
// hangboard hold timer and the rest-length editor — both edit a value in seconds.
export default function Adjuster({
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
