import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useMeals, useLogMeal } from '~/api/queries'
import type { Meal } from '~/types'
import { mealCalories, parseStatusLabel } from './mealMath'

// The Nutrition tab: log a meal as freeform text (parsed into macros in the
// background), and browse the log. Tapping a meal opens its detail/editor.
export default function Nutrition() {
  const navigate = useNavigate()
  const { data: meals, isLoading } = useMeals()
  const log = useLogMeal()
  const [text, setText] = useState('')

  function handleLog() {
    const raw = text.trim()
    if (raw === '') return
    log.mutate(raw, {
      onSuccess: (meal) => {
        setText('')
        navigate(`/nutrition/${meal.id}`)
      },
    })
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
          placeholder="2 eggs, sausage, toast"
        />
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
        <ul className="meal-list mt-6">
          {meals.map((meal) => (
            <MealRow key={meal.id} meal={meal} />
          ))}
        </ul>
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
        <span className="meal-row__cals caption text-muted">
          {cals != null ? `${cals} cal` : status.label}
        </span>
      </Link>
    </li>
  )
}
