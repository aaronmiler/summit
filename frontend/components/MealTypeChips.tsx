import { MEAL_TYPES } from './mealMath'

// The four meal-types as tap-to-select chips. `selected` is highlighted; when
// `isAuto`, the highlight is the derived default (not a stored override), so
// tapping any chip sets an override. Tapping the active override again clears it
// back to auto (onSelect(null)).
export default function MealTypeChips({
  selected,
  isAuto = false,
  disabled = false,
  onSelect,
}: {
  selected: string
  isAuto?: boolean
  disabled?: boolean
  onSelect: (type: string | null) => void
}) {
  return (
    <div className="meal-type-chips">
      {MEAL_TYPES.map((type) => {
        const active = type === selected
        return (
          <button
            key={type}
            type="button"
            className={`badge meal-type-chip ${active ? 'badge--accent' : 'badge--neutral'}`}
            aria-pressed={active && !isAuto}
            disabled={disabled}
            onClick={() => onSelect(active && !isAuto ? null : type)}
          >
            {type}
          </button>
        )
      })}
    </div>
  )
}
