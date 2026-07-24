import { useEffect, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import {
  useMeal,
  useUpdateMeal,
  useReparseMeal,
  useAddFoodEntry,
  useUpdateFoodEntry,
  useDeleteFoodEntry,
  useRescaleFoodEntry,
  useEstimateFoodEntry,
} from '~/api/queries'
import type { Meal, FoodEntry } from '~/types'
import { mealCalories, mealMacros, hasMacros, mealType, parseStatusLabel, toNum } from './mealMath'
import { toast } from './Toast'
import MealTypeChips from './MealTypeChips'

// One meal's detail + editor. The text is the truth (editing it re-parses); the
// items are derived and hand-correctable — the human owns name/portion/unit, the
// LLM owns macros (rescale is code-side math, Estimate is one LLM call).
export default function MealDetail() {
  const { id } = useParams()
  const { data: meal, isLoading, isError } = useMeal(id)
  const [editing, setEditing] = useState(false)

  // The parse runs in a background job; useMeal polls while it's pending. Toast
  // the pending -> terminal transition so the result lands even if you look away.
  const prevStatus = useRef<string | undefined>(undefined)
  useEffect(() => {
    const status = meal?.parseStatus
    const prev = prevStatus.current
    prevStatus.current = status
    if (prev === 'pending' && status && status !== 'pending') {
      if (status === 'ok') toast('Meal parsed')
      else toast("Couldn't parse the meal", 'error')
    }
  }, [meal?.parseStatus])

  if (isLoading) return <p className="text-muted">Loading…</p>
  if (isError || !meal) return <p className="text-muted">Meal not found.</p>

  const status = parseStatusLabel(meal.parseStatus)
  const cals = mealCalories(meal)
  const macros = mealMacros(meal)

  return (
    <section>
      <Link to="/nutrition" className="text-accent body-small">
        ← Nutrition
      </Link>

      {editing ? (
        <MealEditor meal={meal} onClose={() => setEditing(false)} />
      ) : (
        <div className="detail-header mt-4">
          <div className="meal-detail__title">
            <h1 className="page-heading text-green meal-detail__text">
              {meal.summary || meal.rawText}
            </h1>
            {meal.summary && <p className="caption text-muted meal-detail__raw">{meal.rawText}</p>}
          </div>
          <div className="detail-header__actions">
            <button className="btn btn--secondary btn--compact" onClick={() => setEditing(true)}>
              Edit
            </button>
            <ReparseButton meal={meal} />
          </div>
        </div>
      )}

      <div className="badge-row mt-2 mb-3">
        <span className="caption text-muted">
          <span className={`status-dot ${status.dotClass}`} /> {status.label}
        </span>
        {cals != null && (
          <span className="caption text-driftwood">
            {cals} cal · {Math.round(macros.protein)}p / {Math.round(macros.carbs)}c /{' '}
            {Math.round(macros.fat)}f
          </span>
        )}
      </div>

      <MealTypeRetag meal={meal} />

      <ul className="item-list">
        {meal.foodEntries.map((entry) => (
          <ItemRow key={entry.id} entry={entry} />
        ))}
      </ul>
      {meal.foodEntries.length === 0 && meal.parseStatus !== 'pending' && (
        <p className="text-muted mb-4">No items. Add one below, or re-parse.</p>
      )}

      <AddItemForm mealId={meal.id} />
    </section>
  )
}

function ReparseButton({ meal }: { meal: Meal }) {
  const reparse = useReparseMeal(meal.id)
  return (
    <button
      className="btn btn--ghost btn--compact"
      disabled={reparse.isPending || meal.parseStatus === 'pending'}
      onClick={() => reparse.mutate()}
      title="Re-run the parse on the same text"
    >
      {reparse.isPending ? 'Retrying…' : 'Re-parse'}
    </button>
  )
}

// One-tap re-tag: fixes the meal-type when you logged late (or early) without
// entering edit mode. null override = auto (derived from the time).
function MealTypeRetag({ meal }: { meal: Meal }) {
  const update = useUpdateMeal(meal.id)
  return (
    <div className="meal-retag mb-6">
      <span className="form-label">
        Type {meal.mealType == null && <span className="text-muted">· auto</span>}
      </span>
      <MealTypeChips
        selected={mealType(meal)}
        isAuto={meal.mealType == null}
        disabled={update.isPending}
        onSelect={(type) => update.mutate({ mealType: type })}
      />
    </div>
  )
}

// Editing the text re-parses; notes/eaten_at are corrections that don't.
function MealEditor({ meal, onClose }: { meal: Meal; onClose: () => void }) {
  const update = useUpdateMeal(meal.id)
  const [rawText, setRawText] = useState(meal.rawText)
  const [summary, setSummary] = useState(meal.summary ?? '')
  const [notes, setNotes] = useState(meal.notes ?? '')
  const [eatenAt, setEatenAt] = useState(toLocalInput(meal.eatenAt))

  function handleSave() {
    update.mutate(
      {
        rawText: rawText.trim(),
        summary: summary.trim() || null,
        notes: notes.trim() || null,
        eatenAt: eatenAt === '' ? null : eatenAt,
      },
      { onSuccess: onClose },
    )
  }

  return (
    <div className="meal-editor card card--surface mt-4">
      <div className="form-group">
        <label className="form-label" htmlFor="meal-summary">
          Title
        </label>
        <input
          id="meal-summary"
          className="form-input"
          value={summary}
          onChange={(e) => setSummary(e.target.value)}
          placeholder="Auto from the parse"
        />
      </div>
      <div className="form-group">
        <label className="form-label" htmlFor="meal-raw">
          Meal (editing re-parses)
        </label>
        <textarea
          id="meal-raw"
          className="form-input"
          rows={2}
          value={rawText}
          onChange={(e) => setRawText(e.target.value)}
        />
      </div>
      <div className="form-row">
        <div className="form-group">
          <label className="form-label" htmlFor="meal-eaten">
            When eaten
          </label>
          <input
            id="meal-eaten"
            type="datetime-local"
            className="form-input"
            value={eatenAt}
            onChange={(e) => setEatenAt(e.target.value)}
          />
        </div>
        <div className="form-group">
          <label className="form-label" htmlFor="meal-notes">
            Notes
          </label>
          <input
            id="meal-notes"
            className="form-input"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="post-workout"
          />
        </div>
      </div>
      <div className="modal-actions">
        <button className="btn btn--ghost" onClick={onClose}>
          Cancel
        </button>
        <button
          className="btn btn--primary"
          disabled={rawText.trim() === '' || update.isPending}
          onClick={handleSave}
        >
          {update.isPending ? 'Saving…' : 'Save'}
        </button>
      </div>
    </div>
  )
}

function ItemRow({ entry }: { entry: FoodEntry }) {
  const [editing, setEditing] = useState(false)
  const estimate = useEstimateFoodEntry()

  const portion = [toNum(entry.amount), entry.unit].filter((v) => v != null && v !== '').join(' ')

  return (
    <li className="card card--surface item-row">
      <div className="item-row__head">
        <span className="item-row__name text-green">{entry.name}</span>
        {portion && <span className="caption text-muted">{portion}</span>}
      </div>

      <div className="item-row__macros caption text-driftwood">
        {hasMacros(entry) ? (
          <>
            {toNum(entry.calories)} cal · {toNum(entry.protein) ?? 0}p / {toNum(entry.carbs) ?? 0}c /{' '}
            {toNum(entry.fat) ?? 0}f
            {entry.confidence != null && ` · conf ${entry.confidence}`}
          </>
        ) : (
          <span className="text-muted">no macros yet</span>
        )}
      </div>
      {entry.parseNotes && <p className="body-small text-muted item-row__note">{entry.parseNotes}</p>}

      <div className="item-row__actions">
        <button
          className="btn btn--ghost btn--compact"
          disabled={estimate.isPending}
          onClick={() => estimate.mutate(entry.id, { onSuccess: () => toast('Macros estimated') })}
          title="Ask the LLM to estimate this item's macros"
        >
          {estimate.isPending ? 'Estimating…' : hasMacros(entry) ? 'Re-estimate' : 'Estimate'}
        </button>
        <button className="btn btn--ghost btn--compact" onClick={() => setEditing((v) => !v)}>
          {editing ? 'Close' : 'Edit'}
        </button>
      </div>

      {editing && <ItemEditor entry={entry} onClose={() => setEditing(false)} />}
    </li>
  )
}

// Inline item editor: fix name/unit, rescale the portion (macros scale in code),
// or delete. Macros themselves aren't typed here — that's Estimate's job.
function ItemEditor({ entry, onClose }: { entry: FoodEntry; onClose: () => void }) {
  const updateEntry = useUpdateFoodEntry()
  const rescale = useRescaleFoodEntry()
  const del = useDeleteFoodEntry()
  const estimate = useEstimateFoodEntry()

  const [name, setName] = useState(entry.name)
  const [unit, setUnit] = useState(entry.unit ?? '')
  const [amount, setAmount] = useState(String(toNum(entry.amount) ?? ''))
  // Empty = don't pin; a value = "I measured this, fill the macros to match".
  const [knownCals, setKnownCals] = useState('')

  function handleSaveFields() {
    updateEntry.mutate({ id: entry.id, name: name.trim(), unit: unit.trim() || null })
  }

  function handleRescale() {
    const next = toNum(amount)
    if (next == null || next <= 0) return
    rescale.mutate({ id: entry.id, amount: next }, { onSuccess: () => toast('Rescaled') })
  }

  function handleFillMacros() {
    const cals = toNum(knownCals)
    if (cals == null || cals <= 0) return
    estimate.mutate(
      { id: entry.id, calories: cals },
      {
        onSuccess: () => {
          toast('Macros filled')
          onClose()
        },
      },
    )
  }

  function handleDelete() {
    if (!window.confirm(`Remove "${entry.name}"?`)) return
    del.mutate(entry.id, {
      onSuccess: () => {
        toast('Item removed')
        onClose()
      },
    })
  }

  return (
    <div className="item-editor">
      <div className="form-row">
        <div className="form-group">
          <label className="form-label" htmlFor={`name-${entry.id}`}>
            Name
          </label>
          <input
            id={`name-${entry.id}`}
            className="form-input"
            value={name}
            onChange={(e) => setName(e.target.value)}
            onBlur={handleSaveFields}
          />
        </div>
        <div className="form-group">
          <label className="form-label" htmlFor={`unit-${entry.id}`}>
            Unit
          </label>
          <input
            id={`unit-${entry.id}`}
            className="form-input"
            value={unit}
            onChange={(e) => setUnit(e.target.value)}
            onBlur={handleSaveFields}
            placeholder="slice"
          />
        </div>
      </div>

      <div className="item-editor__rescale">
        <div className="form-group">
          <label className="form-label" htmlFor={`amount-${entry.id}`}>
            Amount
          </label>
          <input
            id={`amount-${entry.id}`}
            className="form-input"
            type="number"
            inputMode="decimal"
            step="any"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
          />
        </div>
        <button
          className="btn btn--secondary btn--compact"
          disabled={rescale.isPending || toNum(amount) == null}
          onClick={handleRescale}
          title="Scale the macros to this amount"
        >
          {rescale.isPending ? 'Rescaling…' : 'Rescale'}
        </button>
        <button
          className="btn btn--ghost btn--compact text-danger"
          disabled={del.isPending}
          onClick={handleDelete}
        >
          Delete
        </button>
      </div>

      <div className="item-editor__rescale">
        <div className="form-group">
          <label className="form-label" htmlFor={`cals-${entry.id}`}>
            Known calories
          </label>
          <input
            id={`cals-${entry.id}`}
            className="form-input"
            type="number"
            inputMode="numeric"
            step="any"
            value={knownCals}
            onChange={(e) => setKnownCals(e.target.value)}
            placeholder="e.g. 240"
          />
        </div>
        <button
          className="btn btn--secondary btn--compact"
          disabled={estimate.isPending || toNum(knownCals) == null}
          onClick={handleFillMacros}
          title="Pin this calorie total; the LLM fills the macros to match"
        >
          {estimate.isPending ? 'Filling…' : 'Fill macros'}
        </button>
      </div>
      <p className="body-small text-muted item-editor__hint">
        Measured a serving? Pin the calories and the estimate fills protein/carbs/fat to match.
      </p>
    </div>
  )
}

// Add an item the parse missed. Save it, then Estimate fills its macros.
function AddItemForm({ mealId }: { mealId: number }) {
  const add = useAddFoodEntry(mealId)
  const [open, setOpen] = useState(false)
  const [name, setName] = useState('')
  const [amount, setAmount] = useState('')
  const [unit, setUnit] = useState('')

  function handleAdd() {
    if (name.trim() === '') return
    add.mutate(
      { name: name.trim(), amount: toNum(amount), unit: unit.trim() || null },
      {
        onSuccess: () => {
          toast('Item added')
          setName('')
          setAmount('')
          setUnit('')
          setOpen(false)
        },
      },
    )
  }

  if (!open) {
    return (
      <button className="btn btn--ghost btn--compact add-item-toggle" onClick={() => setOpen(true)}>
        + Add item
      </button>
    )
  }

  return (
    <div className="add-item card card--surface">
      <div className="form-row">
        <div className="form-group add-item__name">
          <label className="form-label" htmlFor="add-name">
            Item
          </label>
          <input
            id="add-name"
            className="form-input"
            autoFocus
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="side salad"
          />
        </div>
        <div className="form-group add-item__amount">
          <label className="form-label" htmlFor="add-amount">
            Amount
          </label>
          <input
            id="add-amount"
            className="form-input"
            type="number"
            inputMode="decimal"
            step="any"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="1"
          />
        </div>
        <div className="form-group add-item__unit">
          <label className="form-label" htmlFor="add-unit">
            Unit
          </label>
          <input
            id="add-unit"
            className="form-input"
            value={unit}
            onChange={(e) => setUnit(e.target.value)}
            placeholder="serving"
          />
        </div>
      </div>
      <div className="modal-actions">
        <button className="btn btn--ghost" onClick={() => setOpen(false)}>
          Cancel
        </button>
        <button
          className="btn btn--primary"
          disabled={name.trim() === '' || add.isPending}
          onClick={handleAdd}
        >
          {add.isPending ? 'Adding…' : 'Add'}
        </button>
      </div>
    </div>
  )
}

// ISO string -> the value a datetime-local input wants ("YYYY-MM-DDTHH:mm"),
// in local time. '' when unset.
function toLocalInput(iso: string | null): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}
