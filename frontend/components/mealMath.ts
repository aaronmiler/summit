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

// The timestamp a meal sits at on the timeline: when eaten if known, else when
// logged (eatenAt is nullable — only set via the editor).
export function mealTime(meal: Meal): Date {
  return new Date(meal.eatenAt ?? meal.createdAt)
}

// The four meal-types, in day order (also the chip order). Keep in sync with
// Meal::MEAL_TYPES on the Ruby side.
export const MEAL_TYPES = ['Breakfast', 'Lunch', 'Dinner', 'Snack'] as const

// Meal-type derived from a time-of-day — the sensible default when unset.
export function derivedMealTypeFor(date: Date): string {
  const h = date.getHours()
  if (h < 11) return 'Breakfast'
  if (h < 16) return 'Lunch'
  if (h < 21) return 'Dinner'
  return 'Snack'
}

// Effective meal-type: the human's override if set, else derived from the time.
// (Storing an override handles logging late — see the meal_type column.)
export function mealType(meal: Meal): string {
  return meal.mealType ?? derivedMealTypeFor(mealTime(meal))
}

export type DayTotals = { calories: number; protein: number; carbs: number; fat: number }
export type MealDay = { key: string; date: Date; meals: Meal[]; totals: DayTotals }

// Local calendar-day key ("YYYY-MM-DD") for grouping.
function dayKey(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

// Group meals into calendar days (local time), newest day first; within a day
// meals run chronologically (morning → night). Each day carries summed totals.
export function groupMealsByDay(meals: Meal[]): MealDay[] {
  const byKey = new Map<string, Meal[]>()
  for (const meal of meals) {
    const key = dayKey(mealTime(meal))
    const list = byKey.get(key)
    if (list) list.push(meal)
    else byKey.set(key, [meal])
  }

  const days: MealDay[] = []
  for (const [key, dayMeals] of byKey) {
    dayMeals.sort((a, b) => mealTime(a).getTime() - mealTime(b).getTime())
    const [y, mo, d] = key.split('-').map(Number)
    days.push({ key, date: new Date(y, mo - 1, d), meals: dayMeals, totals: dayTotals(dayMeals) })
  }
  days.sort((a, b) => b.date.getTime() - a.date.getTime())
  return days
}

function dayTotals(meals: Meal[]): DayTotals {
  return meals.reduce(
    (acc, m) => {
      const mac = mealMacros(m)
      return {
        calories: acc.calories + (mealCalories(m) ?? 0),
        protein: acc.protein + mac.protein,
        carbs: acc.carbs + mac.carbs,
        fat: acc.fat + mac.fat,
      }
    },
    { calories: 0, protein: 0, carbs: 0, fat: 0 },
  )
}

// "Today" / "Yesterday" / "Mon Jul 20" for a day-section header.
export function dayLabel(date: Date): string {
  const today = new Date()
  const key = dayKey(date)
  if (key === dayKey(today)) return 'Today'
  const yest = new Date(today)
  yest.setDate(today.getDate() - 1)
  if (key === dayKey(yest)) return 'Yesterday'
  return date.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })
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
