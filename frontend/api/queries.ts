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
  apiV1Sessions,
  apiV1Users,
  apiV1Exercises,
  apiV1Routines,
  apiV1Workouts,
  apiV1SetLogs,
} from '~/api'
import type {
  User,
  Exercise,
  Routine,
  RoutineDetail,
  Workout,
  SetLog,
  LogSetInput,
  WorkoutSummary,
  WorkoutDetail,
  HealthImportSetup,
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

// All routines (no slots) for the library landing.
export function useRoutines() {
  return useQuery({
    queryKey: ['routines'],
    queryFn: () => apiV1Routines.index<Routine[]>(),
  })
}

// One routine with its ordered slots, for the detail screen.
export function useRoutine(id: string | undefined) {
  return useQuery({
    queryKey: ['routines', id],
    queryFn: () => apiV1Routines.show<RoutineDetail>({ id: id! }),
    enabled: id != null,
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

// The picked user's finished workouts, newest first (the History tab).
export function useWorkoutHistory() {
  return useQuery({
    queryKey: ['workouts', 'history'],
    queryFn: () => apiV1Workouts.index<WorkoutSummary[]>(),
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
