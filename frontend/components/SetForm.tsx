import { useState, type FormEvent } from 'react'
import type { Prefill } from '~/types'
import type { Widget } from '~/lib/modality'
import HoldTimer from './HoldTimer'

// The numbers a logged set carries (before the exercise/slot context is added).
export type SetFields = {
  reps: number | null
  weight: number | null
  durationSeconds: number | null
  rpe: number | null
  notes: string | null
}

// The modality-driven logging widget. The `widget` decides which inputs show;
// values seed from last-used prefill and *stay* after logging so repeating a set
// is one tap. Remount (via a key on the exercise) to reseed for a new movement.
export default function SetForm({
  widget,
  prefill,
  pending,
  onLog,
}: {
  widget: Widget
  prefill: Prefill | null
  pending: boolean
  onLog: (fields: SetFields) => void
}) {
  const [reps, setReps] = useState(str(prefill?.reps))
  const [weight, setWeight] = useState(str(prefill?.weight))
  const [minutes, setMinutes] = useState(str(secondsToMinutes(prefill?.durationSeconds)))
  const [rpe, setRpe] = useState(str(prefill?.rpe))
  const [notes, setNotes] = useState('')

  // A hold (hangboard) is its own self-contained widget — an active timer that
  // logs directly, not a number to type into the shared form.
  if (widget === 'timed') {
    return (
      <HoldTimer
        seedTarget={prefill?.durationSeconds ?? null}
        pending={pending}
        onLog={(seconds) => onLog({ reps: null, weight: null, durationSeconds: seconds, rpe: null, notes: null })}
      />
    )
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault()
    onLog({
      reps: widget === 'weighted' || widget === 'reps' ? num(reps) : null,
      weight: widget === 'weighted' || widget === 'reps' ? num(weight) : null,
      durationSeconds: widget === 'duration' ? minutesToSeconds(num(minutes)) : null,
      rpe: widget === 'weighted' ? num(rpe) : null,
      notes: widget === 'duration' ? notes.trim() || null : null,
    })
  }

  return (
    <form className="set-form" onSubmit={handleSubmit}>
      {(widget === 'weighted' || widget === 'reps') && (
        <Field label="reps">
          <input className="form-input" type="number" inputMode="numeric" value={reps} onChange={(e) => setReps(e.target.value)} />
        </Field>
      )}
      {(widget === 'weighted' || widget === 'reps') && (
        <Field label={widget === 'reps' ? 'added lb' : 'lb'}>
          <input className="form-input" type="number" inputMode="decimal" step="any" value={weight} onChange={(e) => setWeight(e.target.value)} />
        </Field>
      )}
      {widget === 'weighted' && (
        <Field label="rpe">
          <input className="form-input" type="number" inputMode="decimal" step="0.5" value={rpe} onChange={(e) => setRpe(e.target.value)} />
        </Field>
      )}
      {widget === 'duration' && (
        <Field label="minutes">
          <input className="form-input" type="number" inputMode="decimal" step="any" value={minutes} onChange={(e) => setMinutes(e.target.value)} />
        </Field>
      )}
      {widget === 'duration' && (
        <Field label="note">
          <input className="form-input" type="text" value={notes} onChange={(e) => setNotes(e.target.value)} />
        </Field>
      )}
      <button className="btn btn--primary btn--compact set-form__log" type="submit" disabled={pending}>
        Log set
      </button>
    </form>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="set-field">
      <span className="set-field__label caption text-muted">{label}</span>
      {children}
    </label>
  )
}

// '' -> null, else Number. NaN guards against garbage input.
function num(value: string): number | null {
  if (value.trim() === '') return null
  const n = Number(value)
  return Number.isNaN(n) ? null : n
}

function str(value: number | null | undefined): string {
  return value == null ? '' : String(value)
}

function secondsToMinutes(seconds: number | null | undefined): number | null {
  return seconds == null ? null : seconds / 60
}

function minutesToSeconds(minutes: number | null): number | null {
  return minutes == null ? null : Math.round(minutes * 60)
}
