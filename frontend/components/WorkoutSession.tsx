import { useCallback, useEffect, useState } from 'react'
import type { Workout, WorkoutSlot } from '~/types'
import { useDeleteSet, useDiscardWorkout, useFinishWorkout, useLogSet } from '~/api/queries'
import { widgetFor } from '~/lib/modality'
import { useCue } from '~/lib/cue'
import { describeSet, formatDuration, formatTime } from '~/lib/format'
import SetForm, { type SetFields } from './SetForm'
import RestTimer from './RestTimer'
import RestEditor from './RestEditor'

// Rest length is a front-end-only preference (no backend): the timer opens at
// this default and remembers whatever you set it to, across reloads and sessions.
const DEFAULT_REST_SECONDS = 45
const MIN_REST_SECONDS = 5
const REST_KEY = 'summit.restSeconds'

function readRestPref(): number {
  try {
    const n = parseInt(localStorage.getItem(REST_KEY) ?? '', 10)
    if (Number.isFinite(n) && n >= MIN_REST_SECONDS) return n
  } catch {
    /* no localStorage (e.g. tests) — fall back to the default */
  }
  return DEFAULT_REST_SECONDS
}

function writeRestPref(seconds: number) {
  try {
    localStorage.setItem(REST_KEY, String(seconds))
  } catch {
    /* ignore — the in-memory value still drives this session */
  }
}

// The live logging session, stepped one exercise at a time. Opens on an overview
// checklist; tap a slot to focus it. The focused step is jumpable (dots + prev/
// next) rather than a strict wizard — routine order is a bias, not a constraint
// ("next man up"). Finishing sets finished_at, so `current` goes null.
export default function WorkoutSession({ workout }: { workout: Workout }) {
  const finish = useFinishWorkout()
  const discard = useDiscardWorkout()
  // null = overview; a number = the focused slot index.
  const [focused, setFocused] = useState<number | null>(null)

  // Rest timer state lives at the session so it survives slot-to-slot jumps.
  // `cue` is created here (not per-slot) so the AudioContext armed on one log
  // is still around to beep later. restStartedAt = the current rest's start.
  const cue = useCue()
  const [restSeconds, setRestSeconds] = useState(readRestPref)
  const [restStartedAt, setRestStartedAt] = useState<number | null>(null)
  const [editingRest, setEditingRest] = useState(false)
  useEffect(() => writeRestPref(restSeconds), [restSeconds]) // remember the setting.

  // Called from within the log tap, so arming the audio context is a valid
  // user gesture; the fresh timestamp (re)starts the rest bar.
  function onSetLogged() {
    cue.arm()
    setRestStartedAt(Date.now())
  }

  // Stable so RestTimer's run effect isn't retriggered every session render.
  const dismissRest = useCallback(() => setRestStartedAt(null), [])

  const slots = workout.slots
  const focusedSlot = focused == null ? null : slots[focused]
  // Nothing logged yet -> a mis-pick is recoverable: discard and pick again.
  const empty = !slots.some((slot) => slot.sets.length > 0)

  return (
    <section>
      <div className="session-head">
        <div>
          <h1 className="page-heading text-green">{workout.routine?.name ?? 'Workout'}</h1>
          <p className="caption text-muted">Started {formatTime(workout.startedAt)}</p>
        </div>
        <div className="session-actions">
          <button className="btn btn--ghost btn--compact" onClick={() => setEditingRest(true)} title="Set rest between sets">
            Rest {formatDuration(restSeconds)}
          </button>
          {empty && (
            <button className="btn btn--ghost" disabled={discard.isPending} onClick={() => discard.mutate(workout.id)}>
              Change routine
            </button>
          )}
          <button className="btn btn--primary" disabled={finish.isPending} onClick={() => finish.mutate(workout.id)}>
            Finish
          </button>
        </div>
      </div>

      {focusedSlot ? (
        <FocusedStep
          workoutId={workout.id}
          slots={slots}
          index={focused!}
          onIndex={setFocused}
          onExit={() => setFocused(null)}
          onSetLogged={onSetLogged}
        />
      ) : (
        <Overview slots={slots} onPick={setFocused} />
      )}

      <RestTimer startedAt={restStartedAt} duration={restSeconds} onDismiss={dismissRest} cue={cue} />

      {editingRest && (
        <RestEditor
          seconds={restSeconds}
          min={MIN_REST_SECONDS}
          onSave={setRestSeconds}
          onClose={() => setEditingRest(false)}
        />
      )}
    </section>
  )
}

// The checklist: every slot with a done/todo dot; tap one to step into it.
function Overview({ slots, onPick }: { slots: WorkoutSlot[]; onPick: (index: number) => void }) {
  if (slots.length === 0) return <p className="text-muted mt-4">No exercises in this routine.</p>

  return (
    <ol className="overview-list mt-4">
      {slots.map((slot, index) => (
        <li key={slot.id}>
          <button className="overview-row" onClick={() => onPick(index)}>
            <span className={`status-dot ${slot.sets.length ? 'status-dot--done' : ''}`} aria-hidden />
            <span className="overview-name">{slotName(slot)}</span>
            {slot.target && <span className="overview-target caption text-muted">{slot.target}</span>}
            {slot.sets.length > 0 && (
              <span className="caption text-muted">
                {slot.sets.length} set{slot.sets.length > 1 ? 's' : ''}
              </span>
            )}
          </button>
        </li>
      ))}
    </ol>
  )
}

// One exercise, focused. Progress dots jump anywhere; prev/next walk the list.
function FocusedStep({
  workoutId,
  slots,
  index,
  onIndex,
  onExit,
  onSetLogged,
}: {
  workoutId: number
  slots: WorkoutSlot[]
  index: number
  onIndex: (index: number) => void
  onExit: () => void
  onSetLogged: () => void
}) {
  return (
    <div className="step mt-4">
      <div className="step-head">
        <button className="text-accent body-small step-back" onClick={onExit}>
          ‹ All exercises
        </button>
        <span className="caption text-muted">
          {index + 1} / {slots.length}
        </span>
      </div>

      <div className="step-dots">
        {slots.map((slot, i) => (
          <button
            key={slot.id}
            className={`step-dot ${i === index ? 'step-dot--current' : ''} ${slot.sets.length ? 'step-dot--done' : ''}`}
            onClick={() => onIndex(i)}
            aria-label={`Go to ${slotName(slot)}`}
            aria-current={i === index}
          />
        ))}
      </div>

      <SlotCard workoutId={workoutId} slot={slots[index]} onSetLogged={onSetLogged} />

      <div className="step-nav">
        <button className="btn btn--ghost" disabled={index === 0} onClick={() => onIndex(index - 1)}>
          ‹ Prev
        </button>
        <button className="btn btn--secondary" disabled={index === slots.length - 1} onClick={() => onIndex(index + 1)}>
          Next ›
        </button>
      </div>
    </div>
  )
}

// The logging body for one slot. Progression slots add a phase picker (defaulted
// to the derived current phase); the chosen phase is what you log against, and
// its id stamps the set so advancement derives from the Log.
function SlotCard({ workoutId, slot, onSetLogged }: { workoutId: number; slot: WorkoutSlot; onSetLogged: () => void }) {
  const logSet = useLogSet()
  const deleteSet = useDeleteSet()

  const phases = slot.progression?.phases ?? []
  const [phasePos, setPhasePos] = useState(
    slot.progression?.currentPhasePosition ?? phases[0]?.position ?? null,
  )
  const activePhase = slot.progression ? phases.find((p) => p.position === phasePos) ?? phases[0] : null
  const activeExercise = activePhase ? activePhase.exercise : slot.exercise!
  const widget = widgetFor(activeExercise.modality)

  function handleLog(fields: SetFields) {
    onSetLogged() // arm audio (still in the tap gesture) + start the rest timer.
    logSet.mutate({
      workoutId,
      exerciseId: activeExercise.id,
      routineExerciseId: slot.id,
      progressionPhaseId: activePhase?.id ?? null,
      ...fields,
    })
  }

  return (
    <div className="card card--surface slot">
      <div className="slot-head">
        <span className="slot-name text-green">
          {activeExercise.name}
          <span className="badge badge--neutral slot-tag">{activeExercise.modality}</span>
        </span>
        {slot.target && <span className="slot-target">{slot.target}</span>}
      </div>

      {slot.notes && <p className="body-small text-muted slot-note">{slot.notes}</p>}

      {slot.progression && (
        <div className="phase-picker">
          {phases.map((phase) => (
            <button
              key={phase.id}
              className={`btn btn--compact ${phase.position === phasePos ? 'btn--secondary' : 'btn--ghost'}`}
              onClick={() => setPhasePos(phase.position)}
            >
              {phase.exercise.name}
            </button>
          ))}
        </div>
      )}

      {slot.sets.length > 0 && (
        <ol className="logged-sets">
          {slot.sets.map((set) => (
            <li key={set.id} className="logged-set">
              <span className="logged-set__n caption text-muted">#{set.setNumber}</span>
              <span className="logged-set__val">{describeSet(set)}</span>
              <button
                className="btn btn--ghost btn--compact logged-set__del"
                onClick={() => deleteSet.mutate(set.id)}
                title="Remove set"
              >
                ×
              </button>
            </li>
          ))}
        </ol>
      )}

      {/* key on the exercise so the form reseeds when the phase changes. */}
      <SetForm key={activeExercise.id} widget={widget} prefill={slot.prefill} pending={logSet.isPending} onLog={handleLog} />
    </div>
  )
}

function slotName(slot: WorkoutSlot): string {
  return slot.exercise?.name ?? slot.progression?.name ?? 'Exercise'
}
