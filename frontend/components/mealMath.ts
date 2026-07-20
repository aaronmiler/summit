import type { Meal, FoodEntry } from '~/types'

// Decimals arrive from Rails as strings ("3.0"); coerce for arithmetic/display.
// (Same bridge the SetForm uses for weight.)
export function toNum(value: number | string | null | undefined): number | null {
  if (value == null || value === '') return null
  const n = Number(value)
  return Number.isNaN(n) ? null : n
}

// Total calories across a meal's items, or null if nothing's been estimated yet.
export function mealCalories(meal: Meal): number | null {
  const withCals = meal.foodEntries.filter((e) => e.calories != null)
  if (withCals.length === 0) return null
  return withCals.reduce((sum, e) => sum + (toNum(e.calories) ?? 0), 0)
}

// A meal's macro totals (grams), summed over its items.
export function mealMacros(meal: Meal): { protein: number; carbs: number; fat: number } {
  return meal.foodEntries.reduce(
    (acc, e) => ({
      protein: acc.protein + (toNum(e.protein) ?? 0),
      carbs: acc.carbs + (toNum(e.carbs) ?? 0),
      fat: acc.fat + (toNum(e.fat) ?? 0),
    }),
    { protein: 0, carbs: 0, fat: 0 },
  )
}

// Does this item have any macros yet? (Hand-added items start empty.)
export function hasMacros(entry: FoodEntry): boolean {
  return entry.calories != null
}

type StatusView = { label: string; dotClass: string }

// Map the derived parse_status to a label + status-dot modifier.
export function parseStatusLabel(status: string): StatusView {
  switch (status) {
    case 'ok':
      return { label: 'Parsed', dotClass: 'status-dot--done' }
    case 'error':
      return { label: 'Parse failed', dotClass: 'status-dot--bad' }
    case 'parse_error':
      return { label: "Couldn't read result", dotClass: 'status-dot--bad' }
    default:
      return { label: 'Parsing…', dotClass: '' }
  }
}
