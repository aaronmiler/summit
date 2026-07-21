import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useMeals, useLogMeal } from '~/api/queries'
import type { Meal } from '~/types'
import {
  mealCalories,
  mealType,
  parseStatusLabel,
  groupMealsByDay,
  dayLabel,
  derivedMealTypeFor,
} from './mealMath'
import MealTypeChips from './MealTypeChips'

// The Nutrition tab: log a meal as freeform text (parsed into macros in the
// background), and browse the log. Tapping a meal opens its detail/editor.
export default function Nutrition() {
  const navigate = useNavigate()
  const { data: meals, isLoading } = useMeals()
  const log = useLogMeal()
  const [text, setText] = useState('')
  // null = auto (derive from the log time); a value = explicit override.
  const [typeOverride, setTypeOverride] = useState<string | null>(null)
  const autoType = derivedMealTypeFor(new Date())

  function handleLog() {
    const raw = text.trim()
    if (raw === '') return
    log.mutate(
      { rawText: raw, mealType: typeOverride },
      {
        onSuccess: (meal) => {
          setText('')
          setTypeOverride(null)
          navigate(`/nutrition/${meal.id}`)
        },
      },
    )
  }

  return (
    <section>
      <h1 className="page-heading text-green mb-4">Nutrition</h1>

      <div className="form-group meal-log">
        <label className="form-label" htmlFor="meal-text">
          What did you eat?
        </label>
        <textarea
          id="meal-text"
          className="form-input meal-log__input"
          rows={2}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') handleLog()
          }}
          placeholder="2 eggs, sausage, toast"
        />
        <div className="meal-log__type">
          <span className="form-label">
            Type {typeOverride == null && <span className="text-muted">· auto</span>}
          </span>
          <MealTypeChips
            selected={typeOverride ?? autoType}
            isAuto={typeOverride == null}
            onSelect={setTypeOverride}
          />
        </div>
        <button
          className="btn btn--primary meal-log__submit"
          disabled={text.trim() === '' || log.isPending}
          onClick={handleLog}
        >
          {log.isPending ? 'Logging…' : 'Log meal'}
        </button>
      </div>

      {isLoading ? (
        <p className="text-muted">Loading…</p>
      ) : meals && meals.length > 0 ? (
        <div className="meal-timeline mt-6">
          {groupMealsByDay(meals).map((day) => (
            <section key={day.key} className="meal-day">
              <header className="meal-day__header">
                <span className="meal-day__date text-green">{dayLabel(day.date)}</span>
                <span className="meal-day__totals caption text-driftwood">
                  {Math.round(day.totals.calories)} cal · {Math.round(day.totals.protein)}p /{' '}
                  {Math.round(day.totals.carbs)}c / {Math.round(day.totals.fat)}f
                </span>
              </header>
              <ul className="meal-list">
                {day.meals.map((meal) => (
                  <MealRow key={meal.id} meal={meal} />
                ))}
              </ul>
            </section>
          ))}
        </div>
      ) : (
        <p className="text-muted mt-6">No meals logged yet.</p>
      )}
    </section>
  )
}

function MealRow({ meal }: { meal: Meal }) {
  const status = parseStatusLabel(meal.parseStatus)
  const cals = mealCalories(meal)

  return (
    <li>
      <Link to={`/nutrition/${meal.id}`} className="meal-row card card--surface">
        <div className="meal-row__main">
          <span className={`status-dot ${status.dotClass}`} />
          <span className="meal-row__text">{meal.rawText}</span>
        </div>
        <div className="meal-row__meta">
          <span className="badge badge--neutral meal-row__type">{mealType(meal)}</span>
          <span className="meal-row__cals caption text-muted">
            {cals != null ? `${cals} cal` : status.label}
          </span>
        </div>
      </Link>
    </li>
  )
}
