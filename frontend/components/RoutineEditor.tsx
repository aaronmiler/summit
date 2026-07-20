import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import {
  useRoutine,
  useExercises,
  useProgressions,
  usePrograms,
  useCreateRoutine,
  useUpdateRoutine,
} from '~/api/queries'
import type { Exercise, RoutineDetail, RoutineInput, SlotInput } from '~/types'

// The hand editor for a routine: metadata plus the ordered slot list (add via a
// unified exercise/progression picker, swap in place, remove, reorder). Editing
// never touches the Log — a slot carries its own exercise_id onto every SetLog,
// so past workouts stay correct after a swap, and removing a logged slot only
// nullifies the breadcrumb server-side. Used for both /new and /:id/edit.
export default function RoutineEditor() {
  const { id } = useParams()
  // Edit mode loads the existing routine; /new starts blank. The query is gated
  // on id, so `isLoading` is only meaningful when editing.
  const { data: routine, isLoading } = useRoutine(id)

  if (id && isLoading) return <p className="text-muted">Loading…</p>
  if (id && !routine) return <p className="text-muted">Routine not found.</p>

  // Remount per routine (or for /new) so the form seeds once from server state.
  return <Editor key={id ?? 'new'} routine={routine} />
}

// A slot as the editor holds it: a stable client `key`, the server `id` if it
// already exists, and the movement (exercise XOR progression) plus its fields as
// editable text. Numbers stay as strings until save (matches SetForm).
type EditorSlot = {
  key: string
  id?: number
  exercise: Exercise | null
  progression: { id: number; name: string } | null
  target: string
  restSeconds: string
  notes: string
  progressionNote: string
}

let slotSeq = 0
const nextKey = () => `slot-${slotSeq++}`

function Editor({ routine }: { routine?: RoutineDetail }) {
  const navigate = useNavigate()
  const create = useCreateRoutine()
  const update = useUpdateRoutine(routine?.id ?? 0)
  const saving = create.isPending || update.isPending

  const [name, setName] = useState(routine?.name ?? '')
  const [notes, setNotes] = useState(routine?.notes ?? '')
  const [tags, setTags] = useState((routine?.tags ?? []).join(', '))
  const [frequency, setFrequency] = useState(routine?.preferredFrequency ?? '')
  const [programId, setProgramId] = useState<number | null>(routine?.program?.id ?? null)
  const { data: programs } = usePrograms()
  const [slots, setSlots] = useState<EditorSlot[]>(() =>
    (routine?.routineExercises ?? []).map(seedSlot),
  )
  // Server ids of slots removed in this session — sent as _destroy on save.
  const [removedIds, setRemovedIds] = useState<number[]>([])
  const [picker, setPicker] = useState<PickerState>(null)

  function removeSlot(index: number) {
    const slot = slots[index]
    if (slot.id != null) setRemovedIds((ids) => [...ids, slot.id!])
    setSlots((s) => s.filter((_, i) => i !== index))
  }

  function moveSlot(index: number, delta: number) {
    const to = index + delta
    if (to < 0 || to >= slots.length) return
    setSlots((s) => {
      const next = [...s]
      ;[next[index], next[to]] = [next[to], next[index]]
      return next
    })
  }

  // Add a fresh slot, or swap the movement of an existing one, from the picker.
  function pickMovement(choice: PickChoice) {
    if (picker == null) return
    const movement =
      choice.kind === 'exercise'
        ? { exercise: choice.exercise, progression: null }
        : { exercise: null, progression: choice.progression }

    if (picker.mode === 'add') {
      setSlots((s) => [
        ...s,
        { key: nextKey(), target: '', restSeconds: '', notes: '', progressionNote: '', ...movement },
      ])
    } else {
      setSlots((s) =>
        s.map((slot, i) => (i === picker.index ? { ...slot, ...movement } : slot)),
      )
    }
    setPicker(null)
  }

  function setField(index: number, field: keyof EditorSlot, value: string) {
    setSlots((s) => s.map((slot, i) => (i === index ? { ...slot, [field]: value } : slot)))
  }

  function handleSave() {
    const kept: SlotInput[] = slots.map((slot, i) => ({
      id: slot.id,
      exerciseId: slot.exercise?.id ?? null,
      progressionId: slot.progression?.id ?? null,
      position: i,
      target: emptyToNull(slot.target),
      restSeconds: intOrNull(slot.restSeconds),
      notes: emptyToNull(slot.notes),
      progressionNote: emptyToNull(slot.progressionNote),
    }))
    const removed: SlotInput[] = removedIds.map((id) => ({ id, _destroy: true }))

    const input: RoutineInput = {
      name: name.trim(),
      notes: emptyToNull(notes),
      tags: tags.split(',').map((t) => t.trim()).filter(Boolean),
      preferredFrequency: emptyToNull(frequency),
      programId,
      routineExercisesAttributes: [...kept, ...removed],
    }

    const onSuccess = (saved: RoutineDetail) =>
      navigate(`/library/routines/${saved.id}`)
    if (routine) update.mutate(input, { onSuccess })
    else create.mutate(input, { onSuccess })
  }

  const canSave = name.trim() !== '' && slots.every(hasMovement) && !saving

  return (
    <section>
      <Link
        to={routine ? `/library/routines/${routine.id}` : '/library'}
        className="text-accent body-small"
      >
        ← {routine ? 'Cancel' : 'Library'}
      </Link>
      <h1 className="page-heading text-green mt-4 mb-6">
        {routine ? 'Edit routine' : 'New routine'}
      </h1>

      <div className="form-group">
        <label className="form-label" htmlFor="routine-name">Name</label>
        <input
          id="routine-name"
          className="form-input"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Pull/Core"
        />
      </div>

      <div className="form-group">
        <label className="form-label" htmlFor="routine-program">Program</label>
        <select
          id="routine-program"
          className="form-input"
          value={programId ?? ''}
          onChange={(e) => setProgramId(e.target.value === '' ? null : Number(e.target.value))}
        >
          <option value="">— No program —</option>
          {programs?.map((program) => (
            <option key={program.id} value={program.id}>
              {program.name}
            </option>
          ))}
        </select>
      </div>

      <div className="form-row">
        <div className="form-group">
          <label className="form-label" htmlFor="routine-frequency">Frequency</label>
          <input
            id="routine-frequency"
            className="form-input"
            value={frequency}
            onChange={(e) => setFrequency(e.target.value)}
            placeholder="2×/week"
          />
        </div>
        <div className="form-group">
          <label className="form-label" htmlFor="routine-tags">Tags</label>
          <input
            id="routine-tags"
            className="form-input"
            value={tags}
            onChange={(e) => setTags(e.target.value)}
            placeholder="pull, core"
          />
        </div>
      </div>

      <div className="form-group">
        <label className="form-label" htmlFor="routine-notes">Notes</label>
        <textarea
          id="routine-notes"
          className="form-input"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Format, rest guidance, warmup…"
        />
      </div>

      <h2 className="subsection-title">Slots</h2>
      <ol className="slot-list">
        {slots.map((slot, i) => (
          <SlotRow
            key={slot.key}
            slot={slot}
            first={i === 0}
            last={i === slots.length - 1}
            onSwap={() => setPicker({ mode: 'swap', index: i })}
            onRemove={() => removeSlot(i)}
            onMove={(delta) => moveSlot(i, delta)}
            onField={(field, value) => setField(i, field, value)}
          />
        ))}
      </ol>
      {slots.length === 0 && <p className="text-muted mb-4">No slots yet.</p>}

      <button className="btn btn--secondary" onClick={() => setPicker({ mode: 'add' })}>
        + Add slot
      </button>

      <div className="editor-actions">
        <button className="btn btn--primary" disabled={!canSave} onClick={handleSave}>
          {saving ? 'Saving…' : 'Save routine'}
        </button>
      </div>

      {picker != null && (
        <SlotPicker onPick={pickMovement} onClose={() => setPicker(null)} />
      )}
    </section>
  )
}

function SlotRow({
  slot,
  first,
  last,
  onSwap,
  onRemove,
  onMove,
  onField,
}: {
  slot: EditorSlot
  first: boolean
  last: boolean
  onSwap: () => void
  onRemove: () => void
  onMove: (delta: number) => void
  onField: (field: keyof EditorSlot, value: string) => void
}) {
  const isProgression = slot.progression != null
  const name = slot.exercise?.name ?? slot.progression?.name ?? 'Pick a movement'

  return (
    <li className="card card--surface slot">
      <div className="slot-head">
        <span className="slot-name text-green">
          {name}
          {isProgression && <span className="badge badge--neutral slot-tag">progression</span>}
          {slot.exercise && (
            <span className="badge badge--neutral slot-tag">{slot.exercise.modality}</span>
          )}
        </span>
        <div className="slot-controls">
          <button className="btn btn--ghost btn--compact" disabled={first} onClick={() => onMove(-1)} aria-label="Move up">↑</button>
          <button className="btn btn--ghost btn--compact" disabled={last} onClick={() => onMove(1)} aria-label="Move down">↓</button>
          <button className="btn btn--ghost btn--compact" onClick={onSwap}>Swap</button>
          <button className="btn btn--ghost btn--compact text-danger" onClick={onRemove} aria-label="Remove">✕</button>
        </div>
      </div>

      <div className="form-row">
        <div className="form-group">
          <label className="form-label">Target</label>
          <input
            className="form-input"
            value={slot.target}
            onChange={(e) => onField('target', e.target.value)}
            placeholder="4 × 8–10"
          />
        </div>
        <div className="form-group">
          <label className="form-label">Rest (sec)</label>
          <input
            className="form-input"
            type="number"
            inputMode="numeric"
            value={slot.restSeconds}
            onChange={(e) => onField('restSeconds', e.target.value)}
            placeholder="120"
          />
        </div>
      </div>

      <div className="form-group">
        <label className="form-label">Notes</label>
        <input
          className="form-input"
          value={slot.notes}
          onChange={(e) => onField('notes', e.target.value)}
          placeholder="Form cues…"
        />
      </div>

      {!isProgression && (
        <div className="form-group">
          <label className="form-label">Progression note</label>
          <input
            className="form-input"
            value={slot.progressionNote}
            onChange={(e) => onField('progressionNote', e.target.value)}
            placeholder="When 25s easy, add tempo…"
          />
        </div>
      )}
    </li>
  )
}

// --- Slot picker (unified exercise/progression chooser) -----------------

type PickerState = { mode: 'add' } | { mode: 'swap'; index: number } | null
type PickChoice =
  | { kind: 'exercise'; exercise: Exercise }
  | { kind: 'progression'; progression: { id: number; name: string } }

// A slot is exercise XOR progression, so one picker lists both. Filtered by a
// single search box; picking either resolves the choice.
function SlotPicker({
  onPick,
  onClose,
}: {
  onPick: (choice: PickChoice) => void
  onClose: () => void
}) {
  const { data: exercises } = useExercises()
  const { data: progressions } = useProgressions()
  const [query, setQuery] = useState('')
  const q = query.trim().toLowerCase()

  const matchExercises = (exercises ?? []).filter((e) => e.name.toLowerCase().includes(q))
  const matchProgressions = (progressions ?? []).filter((p) => p.name.toLowerCase().includes(q))

  return (
    <div className="modal-backdrop is-visible" onClick={onClose}>
      <div className="modal slot-picker" onClick={(e) => e.stopPropagation()}>
        <h2 className="modal-title text-green">Add a movement</h2>
        <input
          className="form-input mb-4"
          autoFocus
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search exercises & progressions…"
        />
        <div className="slot-picker__list">
          {matchProgressions.map((p) => (
            <button
              key={`p-${p.id}`}
              className="slot-picker__item"
              onClick={() => onPick({ kind: 'progression', progression: p })}
            >
              <span>{p.name}</span>
              <span className="badge badge--neutral">progression</span>
            </button>
          ))}
          {matchExercises.map((e) => (
            <button
              key={`e-${e.id}`}
              className="slot-picker__item"
              onClick={() => onPick({ kind: 'exercise', exercise: e })}
            >
              <span>{e.name}</span>
              <span className="badge badge--neutral">{e.modality}</span>
            </button>
          ))}
          {matchExercises.length === 0 && matchProgressions.length === 0 && (
            <p className="text-muted">No matches.</p>
          )}
        </div>
        <div className="modal-actions">
          <button className="btn btn--ghost" onClick={onClose}>Cancel</button>
        </div>
      </div>
    </div>
  )
}

// --- helpers ------------------------------------------------------------

function seedSlot(re: RoutineDetail['routineExercises'][number]): EditorSlot {
  return {
    key: nextKey(),
    id: re.id,
    exercise: re.exercise,
    progression: re.progression ? { id: re.progression.id, name: re.progression.name } : null,
    target: re.target ?? '',
    restSeconds: re.restSeconds == null ? '' : String(re.restSeconds),
    notes: re.notes ?? '',
    progressionNote: re.progressionNote ?? '',
  }
}

function hasMovement(slot: EditorSlot): boolean {
  return slot.exercise != null || slot.progression != null
}

function emptyToNull(value: string): string | null {
  const trimmed = value.trim()
  return trimmed === '' ? null : trimmed
}

function intOrNull(value: string): number | null {
  const trimmed = value.trim()
  if (trimmed === '') return null
  const n = Number(trimmed)
  return Number.isNaN(n) ? null : Math.round(n)
}
