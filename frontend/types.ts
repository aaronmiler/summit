// Shared frontend types. Mirror the JSON the API renders, but in camelCase:
// js-from-routes deserializes every response snake_case -> camelCase (and
// serializes request bodies back to snake_case), so the frontend is camelCase
// throughout while the Rails serializers stay snake_case.

export type User = { id: number; name: string }

// modality is load-bearing: it drives the logging widget. Kept as a string union
// mirroring the Exercise#modality enum.
export type Modality =
  | 'barbell'
  | 'dumbbell'
  | 'machine'
  | 'bodyweight'
  | 'band'
  | 'hangboard'
  | 'cardio'
  | 'climbing'

export type Exercise = {
  id: number
  name: string
  modality: Modality
  muscleGroup: string | null
}

// Routine as it comes back from the index (no slots).
export type Routine = {
  id: number
  name: string
  notes: string | null
  tags: string[]
  preferredFrequency: string | null
}

// One phase of a progression, as nested in a routine slot.
export type ProgressionPhase = {
  position: number
  target: string | null
  graduationCriteria: string | null
  exerciseName: string
}

export type Progression = {
  id: number
  name: string
  phases: ProgressionPhase[]
}

// A slot in a routine: an exercise XOR a progression (exactly one is non-null).
export type RoutineExercise = {
  id: number
  position: number
  target: string | null
  restSeconds: number | null
  notes: string | null
  progressionNote: string | null
  exercise: Exercise | null
  progression: Progression | null
}

// Routine#show: the routine plus its ordered slots.
export type RoutineDetail = Routine & {
  routineExercises: RoutineExercise[]
}

// --- Logging (the live workout session) ---------------------------------

// One logged set. Modality-specific numbers are nullable; setNumber is explicit.
export type SetLog = {
  id: number
  setNumber: number
  exerciseId: number
  routineExerciseId: number | null
  progressionPhaseId: number | null
  reps: number | null
  weight: number | null
  durationSeconds: number | null
  rpe: number | null
  notes: string | null
}

// Last-used numbers for an exercise, to pre-fill the widget.
export type Prefill = {
  reps: number | null
  weight: number | null
  durationSeconds: number | null
  rpe: number | null
}

// A progression phase as the logging screen sees it — carries the full exercise
// so switching phase re-picks the modality widget. id is stamped onto the set
// (progression_phase_id) so the next current phase can be derived.
export type WorkoutPhase = {
  id: number
  position: number
  target: string | null
  graduationCriteria: string | null
  exercise: Exercise
}

// A routine slot inside the active workout: what to log against (exercise XOR
// progression), the prefill, and the sets logged into this workout so far.
export type WorkoutSlot = {
  id: number
  position: number
  target: string | null
  restSeconds: number | null
  notes: string | null
  progressionNote: string | null
  exercise: Exercise | null
  progression: {
    id: number
    name: string
    currentPhasePosition: number | null
    phases: WorkoutPhase[]
  } | null
  prefill: Prefill | null
  sets: SetLog[]
}

// The active (unfinished) workout — everything the logging screen needs.
export type Workout = {
  id: number
  startedAt: string
  notes: string | null
  routine: { id: number; name: string } | null
  slots: WorkoutSlot[]
}

// Params for logging a set (setNumber defaults server-side). camelCase; the
// client serializes to snake_case on the way out.
export type LogSetInput = {
  workoutId: number
  exerciseId: number
  routineExerciseId?: number | null
  progressionPhaseId?: number | null
  reps?: number | null
  weight?: number | null
  durationSeconds?: number | null
  rpe?: number | null
  notes?: string | null
}

// --- History (past workouts) --------------------------------------------

// A finished workout as a list row (no sets).
export type WorkoutSummary = {
  id: number
  startedAt: string
  finishedAt: string | null
  routine: { id: number; name: string } | null
  setCount: number
  // Present only for off-script workouts materialized from a health import.
  activity: string | null
  calories: number | null
}

// The logged sets for one movement within a past workout (grouped off the Log).
export type LoggedExercise = {
  exercise: Exercise
  sets: SetLog[]
}

// A past workout's detail: its sets grouped by exercise.
export type WorkoutDetail = {
  id: number
  startedAt: string
  finishedAt: string | null
  notes: string | null
  routine: { id: number; name: string } | null
  exercises: LoggedExercise[]
}

// The values to paste into the Health Auto Export app (from GET
// /api/v1/health_imports/setup). url auto-reflects the host you're on.
export type HealthImportSetup = {
  url: string
  headerKey: string
  headerValue: string
}

// --- Integration monitoring ---------------------------------------------

// One row of the integration audit log (GET /api/v1/integration_events): an
// inbound push or an outbound LLM call. `kind` is a dotted namespace and
// `metadata` is kind-specific, so this type stays stable as event types grow.
export type IntegrationEvent = {
  id: number
  kind: string
  source: string | null
  direction: string | null
  status: string
  summary: string | null
  metadata: Record<string, unknown>
  durationMs: number | null
  error: string | null
  user: string | null // the user's name, or null for system/unauth rows
  createdAt: string
}
