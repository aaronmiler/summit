// React Query hooks over the generated js_from_routes helpers. This is the
// convention every screen should follow: a typed helper from `~/api` wrapped in
// a query/mutation, keyed so the cache can be invalidated. The session cookie
// rides along with same-origin requests, so nothing here passes a user id.
//
// Casing: the frontend is camelCase throughout. js-from-routes deserializes
// responses to camelCase and serializes request bodies back to snake_case, so
// we read/write camelCase here and the Rails serializers stay snake_case.

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  apiV1Health,
  apiV1Sessions,
  apiV1Users,
  apiV1Exercises,
  apiV1Progressions,
  apiV1Programs,
  apiV1Routines,
  apiV1Workouts,
  apiV1SetLogs,
  apiV1Meals,
  apiV1FoodEntries,
} from '~/api'
import type {
  User,
  Exercise,
  ExerciseInput,
  Routine,
  RoutineDetail,
  RoutineInput,
  Program,
  ProgramInput,
  ProgressionSummary,
  Workout,
  SetLog,
  LogSetInput,
  SessionSummary,
  WorkoutDetail,
  HealthImportSetup,
  IntegrationEvent,
  Meal,
  MealInput,
  FoodEntry,
  FoodEntryInput,
} from '~/types'

// The current user (from the session cookie), or null before one is picked.
export function useSession() {
  return useQuery({
    queryKey: ['session'],
    queryFn: () => apiV1Sessions.show<User | null>(),
  })
}

// The two users, for the picker.
export function useUsers() {
  return useQuery({
    queryKey: ['users'],
    queryFn: () => apiV1Users.index<User[]>(),
  })
}

// Pick a user -> sets the session cookie server-side, primes the session cache.
export function useSelectUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (userId: number) =>
      apiV1Sessions.create<User>({ data: { userId } }),
    onSuccess: (user) => queryClient.setQueryData(['session'], user),
  })
}

// Switch user -> clears the session cookie, drops back to the picker.
export function useSwitchUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: () => apiV1Sessions.destroy(),
    onSuccess: () => queryClient.setQueryData(['session'], null),
  })
}

// --- Library (shared, read-only for now) --------------------------------

// The whole movement library, ordered by muscle group then name.
export function useExercises() {
  return useQuery({
    queryKey: ['exercises'],
    queryFn: () => apiV1Exercises.index<Exercise[]>(),
  })
}

// Add a movement to the library -> refresh the list.
export function useCreateExercise() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: ExerciseInput) => apiV1Exercises.create<Exercise>({ data: input }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['exercises'] }),
  })
}

// Rename / retype / regroup a movement -> refresh the list. Renames are safe
// server-side (FKs are by id), so history is untouched. id rides inside `data`.
export function useUpdateExercise(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: ExerciseInput) =>
      apiV1Exercises.update<Exercise>({ data: { id, ...input } }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['exercises'] }),
  })
}

// Delete a movement -> refresh the list. The server 422s (with a message on
// `error.body.error`) when it's used by a routine, progression, or logged set.
export function useDeleteExercise() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => apiV1Exercises.destroy({ id }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['exercises'] }),
  })
}

// All routines (no slots) for the library landing.
export function useRoutines() {
  return useQuery({
    queryKey: ['routines'],
    queryFn: () => apiV1Routines.index<Routine[]>(),
  })
}

// One routine with its ordered slots, for the detail + edit screens.
export function useRoutine(id: string | undefined) {
  return useQuery({
    queryKey: ['routines', id],
    queryFn: () => apiV1Routines.show<RoutineDetail>({ id: id! }),
    enabled: id != null,
  })
}

// All progressions (id + name), for the routine editor's slot picker.
export function useProgressions() {
  return useQuery({
    queryKey: ['progressions'],
    queryFn: () => apiV1Progressions.index<ProgressionSummary[]>(),
  })
}

// --- Programs (grouping for the Today picker) ---------------------------

// All programs, for the Today sections + the editor's program picker.
export function usePrograms() {
  return useQuery({
    queryKey: ['programs'],
    queryFn: () => apiV1Programs.index<Program[]>(),
  })
}

// Program writes touch routines too: routines embed the program's name, and a
// delete nullifies their program_id — so both caches refresh.
function invalidatePrograms(queryClient: ReturnType<typeof useQueryClient>) {
  queryClient.invalidateQueries({ queryKey: ['programs'] })
  queryClient.invalidateQueries({ queryKey: ['routines'] })
}

export function useCreateProgram() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: ProgramInput) => apiV1Programs.create<Program>({ data: input }),
    onSuccess: () => invalidatePrograms(queryClient),
  })
}

export function useUpdateProgram(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: ProgramInput) => apiV1Programs.update<Program>({ data: { id, ...input } }),
    onSuccess: () => invalidatePrograms(queryClient),
  })
}

export function useDeleteProgram() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => apiV1Programs.destroy({ id }),
    onSuccess: () => invalidatePrograms(queryClient),
  })
}

// --- Routine editing (the hand editor) ----------------------------------

// Create a routine (+ its slots) -> refresh the library list.
export function useCreateRoutine() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: RoutineInput) =>
      apiV1Routines.create<RoutineDetail>({ data: input }),
    onSuccess: (routine) => {
      queryClient.invalidateQueries({ queryKey: ['routines'] })
      queryClient.setQueryData(['routines', String(routine.id)], routine)
    },
  })
}

// Save an edit (metadata + the whole slot list) -> refresh the detail + list.
// id rides inside `data` so it fills :id (see the path-param note on useLogSet).
export function useUpdateRoutine(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: RoutineInput) =>
      apiV1Routines.update<RoutineDetail>({ data: { id, ...input } }),
    onSuccess: (routine) => {
      queryClient.setQueryData(['routines', String(id)], routine)
      queryClient.invalidateQueries({ queryKey: ['routines'] })
    },
  })
}

// Delete a routine -> drop it from the library (history is untouched server-side).
export function useDeleteRoutine() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => apiV1Routines.destroy({ id }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['routines'] }),
  })
}

// --- Logging (the live workout session) ---------------------------------

// The active (unfinished) workout for the picked user, or null before one starts.
export function useCurrentWorkout() {
  return useQuery({
    queryKey: ['workout', 'current'],
    queryFn: () => apiV1Workouts.current<Workout | null>(),
  })
}

// Start a workout on a routine -> primes the current-workout cache.
export function useStartWorkout() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (routineId: number) =>
      apiV1Workouts.create<Workout>({ data: { routineId } }),
    onSuccess: (workout) => queryClient.setQueryData(['workout', 'current'], workout),
  })
}

// Log a set into the active workout -> refetch so the sets + prefill update.
// NOTE: js-from-routes resolves URL path params from `data` when a body is
// present (params = options.data || options), so path params must live *inside*
// `data`, not as siblings of it. Here workoutId fills :workout_id and is ignored
// by the controller's strong params.
export function useLogSet() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: LogSetInput) => apiV1SetLogs.create<SetLog>({ data: input }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['workout', 'current'] }),
  })
}

// Remove a mislogged set -> refetch the active workout.
export function useDeleteSet() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (setId: number) => apiV1SetLogs.destroy({ id: setId }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['workout', 'current'] }),
  })
}

// Finish the active workout -> current becomes null (back to the start screen).
// id lives inside `data` so it fills :id (see the path-param note on useLogSet).
export function useFinishWorkout() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (workoutId: number) =>
      apiV1Workouts.update({ data: { id: workoutId, finishedAt: new Date().toISOString() } }),
    onSuccess: () => {
      queryClient.setQueryData(['workout', 'current'], null)
      // The finished workout now belongs in History.
      queryClient.invalidateQueries({ queryKey: ['workouts', 'history'] })
    },
  })
}

// Discard a mis-started (empty) workout -> back to the routine picker. Plain
// fetch (the destroy helper isn't generated); the server 422s if it has sets.
export function useDiscardWorkout() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (workoutId: number) => {
      const res = await fetch(`/api/v1/workouts/${workoutId}`, {
        method: 'DELETE',
        credentials: 'same-origin',
      })
      if (!res.ok) throw new Error('Failed to discard workout')
    },
    onSuccess: () => queryClient.setQueryData(['workout', 'current'], null),
  })
}

// --- History (past workouts) --------------------------------------------

// The picked user's finished workouts, grouped into training sessions, newest
// first (the History tab).
export function useWorkoutHistory() {
  return useQuery({
    queryKey: ['workouts', 'history'],
    queryFn: () => apiV1Workouts.index<SessionSummary[]>(),
  })
}

// One past workout's detail (sets grouped by exercise).
export function useWorkoutDetail(id: string | undefined) {
  return useQuery({
    queryKey: ['workouts', id],
    queryFn: () => apiV1Workouts.show<WorkoutDetail>({ id: id! }),
    enabled: id != null,
  })
}

// --- Apple Health setup -------------------------------------------------

// The values to paste into Health Auto Export. Plain fetch (not a js-from-routes
// helper) so this works without regenerating helpers; map snake_case -> camelCase
// by hand since it skips the client's deserializer.
export function useHealthImportSetup() {
  return useQuery({
    queryKey: ['health-import-setup'],
    queryFn: async (): Promise<HealthImportSetup> => {
      const res = await fetch('/api/v1/health_imports/setup', { credentials: 'same-origin' })
      if (!res.ok) throw new Error('Failed to load setup')
      const data = await res.json()
      return { url: data.url, headerKey: data.header_key, headerValue: data.header_value }
    },
  })
}

// --- Nutrition ----------------------------------------------------------

// The picked user's meals, newest first (the nutrition log).
export function useMeals() {
  return useQuery({
    queryKey: ['meals'],
    queryFn: () => apiV1Meals.index<Meal[]>(),
  })
}

// One meal with its entries + parse status. Polls while the async parse is in
// flight so the entries appear as soon as the job lands.
export function useMeal(id: string | undefined) {
  return useQuery({
    queryKey: ['meals', id],
    queryFn: () => apiV1Meals.show<Meal>({ id: id! }),
    enabled: id != null,
    refetchInterval: (query) => (query.state.data?.parseStatus === 'pending' ? 1500 : false),
  })
}

// Log a meal (freeform text) -> kicks off the async parse; refresh the list.
export function useLogMeal() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: { rawText: string; mealType?: string | null }) =>
      apiV1Meals.create<Meal>({ data: input }),
    onSuccess: (meal) => {
      queryClient.invalidateQueries({ queryKey: ['meals'] })
      queryClient.setQueryData(['meals', String(meal.id)], meal)
    },
  })
}

// Edit a meal (text re-parses; notes/eaten_at don't). id rides inside `data`.
export function useUpdateMeal(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: MealInput) => apiV1Meals.update<Meal>({ data: { id, ...input } }),
    onSuccess: (meal) => {
      queryClient.setQueryData(['meals', String(id)], meal)
      queryClient.invalidateQueries({ queryKey: ['meals'] })
    },
  })
}

// Re-run the parse on the existing text (a bad LLM draw) -> refetch the meal.
export function useReparseMeal(id: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: () => apiV1Meals.parse<Meal>({ id }),
    onSuccess: (meal) => queryClient.setQueryData(['meals', String(id)], meal),
  })
}

// Entry writes all change a meal's derived items -> refetch that meal (+ list).
function invalidateMeals(queryClient: ReturnType<typeof useQueryClient>) {
  queryClient.invalidateQueries({ queryKey: ['meals'] })
}

// Add an item the parse missed (macros come later via estimate).
export function useAddFoodEntry(mealId: number) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: FoodEntryInput) =>
      apiV1FoodEntries.create<FoodEntry>({ data: { mealId, ...input } }),
    onSuccess: () => invalidateMeals(queryClient),
  })
}

// Edit an item's name/unit. id rides inside `data`.
export function useUpdateFoodEntry() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, ...input }: FoodEntryInput & { id: number }) =>
      apiV1FoodEntries.update<FoodEntry>({ data: { id, ...input } }),
    onSuccess: () => invalidateMeals(queryClient),
  })
}

export function useDeleteFoodEntry() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => apiV1FoodEntries.destroy({ id }),
    onSuccess: () => invalidateMeals(queryClient),
  })
}

// Correct a portion -> macros rescale in code (no LLM). id rides inside `data`.
export function useRescaleFoodEntry() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, amount }: { id: number; amount: number }) =>
      apiV1FoodEntries.rescale<FoodEntry>({ data: { id, amount } }),
    onSuccess: () => invalidateMeals(queryClient),
  })
}

// Fill an item's macros with one (synchronous) LLM call.
export function useEstimateFoodEntry() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => apiV1FoodEntries.estimate<FoodEntry>({ id }),
    onSuccess: () => invalidateMeals(queryClient),
  })
}

// --- Integration monitoring ---------------------------------------------

// The integration audit log, newest first (the Sync activity page). Plain fetch
// (not a js-from-routes helper), so map snake_case -> camelCase by hand.
export function useIntegrationEvents() {
  return useQuery({
    queryKey: ['integration-events'],
    queryFn: async (): Promise<IntegrationEvent[]> => {
      const res = await fetch('/api/v1/integration_events', { credentials: 'same-origin' })
      if (!res.ok) throw new Error('Failed to load integration events')
      const data = await res.json()
      return data.map(
        (e: Record<string, unknown>): IntegrationEvent => ({
          id: e.id as number,
          kind: e.kind as string,
          source: e.source as string | null,
          direction: e.direction as string | null,
          status: e.status as string,
          summary: e.summary as string | null,
          metadata: (e.metadata as Record<string, unknown>) ?? {},
          durationMs: e.duration_ms as number | null,
          error: e.error as string | null,
          user: e.user as string | null,
          createdAt: e.created_at as string,
        }),
      )
    },
  })
}

// ---------------------------------------------------------------------------
// Version check
//
// The server reports the build's git SHA (Api::V1::Health#version; "dev" when
// BUILD_SHA is unset — local/dev). We remember the first SHA we see this
// session — the build this loaded bundle belongs to — and flag when the server
// moves past it, meaning a deploy landed while the app was open. "dev" never
// captures and never triggers, so it stays quiet in development.

// Pure decision, unit-tested: given the SHA we rendered with and the SHA the
// server now reports, return the (possibly newly-captured) rendered SHA and
// whether an update is available.
export function nextVersionState(
  rendered: string | null,
  server: string | undefined,
): { rendered: string | null; updateAvailable: boolean } {
  if (!server || server === 'dev') return { rendered, updateAvailable: false }
  if (rendered === null) return { rendered: server, updateAvailable: false }
  return { rendered, updateAvailable: server !== rendered }
}

let renderedVersion: string | null = null

export function useVersionCheck() {
  const { data } = useQuery({
    queryKey: ['health'],
    queryFn: () => apiV1Health.show<{ status: string; version: string }>(),
    // Poll periodically, and — the important one for the PWA — on window focus,
    // so bringing the app back to the foreground checks for a deploy at once.
    refetchInterval: 60_000,
    refetchOnWindowFocus: true,
  })

  const state = nextVersionState(renderedVersion, data?.version)
  renderedVersion = state.rendered
  return { updateAvailable: state.updateAvailable }
}
