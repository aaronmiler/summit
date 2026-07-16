import { useState } from 'react'
import type { Workout, WorkoutSlot } from '~/types'
import { useDeleteSet, useFinishWorkout, useLogSet } from '~/api/queries'
import { widgetFor } from '~/lib/modality'
import { describeSet, formatTime } from '~/lib/format'
import SetForm, { type SetFields } from './SetForm'

// The live logging session, stepped one exercise at a time. Opens on an overview
// checklist; tap a slot to focus it. The focused step is jumpable (dots + prev/
// next) rather than a strict wizard — routine order is a bias, not a constraint
// ("next man up"). Finishing sets finished_at, so `current` goes null.
export default function WorkoutSession({ workout }: { workout: Workout }) {
  const finish = useFinishWorkout()
  // null = overview; a number = the focused slot index.
  const [focused, setFocused] = useState<number | null>(null)

  const slots = workout.slots
  const focusedSlot = focused == null ? null : slots[focused]

  return (
    <section>
      <div className="session-head">
        <div>
          <h1 className="page-heading text-green">{workout.routine?.name ?? 'Workout'}</h1>
          <p className="caption text-muted">Started {formatTime(workout.startedAt)}</p>
        </div>
        <button className="btn btn--primary" disabled={finish.isPending} onClick={() => finish.mutate(workout.id)}>
          Finish
        </button>
      </div>

      {focusedSlot ? (
        <FocusedStep
          workoutId={workout.id}
          slots={slots}
          index={focused!}
          onIndex={setFocused}
          onExit={() => setFocused(null)}
        />
      ) : (
        <Overview slots={slots} onPick={setFocused} />
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
}: {
  workoutId: number
  slots: WorkoutSlot[]
  index: number
  onIndex: (index: number) => void
  onExit: () => void
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

      <SlotCard workoutId={workoutId} slot={slots[index]} />

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
function SlotCard({ workoutId, slot }: { workoutId: number; slot: WorkoutSlot }) {
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
