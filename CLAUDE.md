# Summit — Project Guide

Personal **2-user** health & training PWA: workouts, multi-phase progressions,
napkin-style nutrition, and LLM-assisted routine building. PNW-flavored.
Rails 8.1 API-only + React/TS (Vite). See `README.md` for setup.

## Source-of-truth docs
- `docs/data_model.md` — the schema and **why** it's shaped this way. Read it
  before touching models or migrations; it's authoritative over this file.
- `docs/open_questions.md` — parked UX/flow decisions (nutrition usage, the LLM
  interaction, PWA/offline). Behavior, not schema.

## The one idea the model turns on
**Personal state is derived from the Log, never stored — there are no per-user
state tables.** Working weight, current routine, and current progression phase are
all queries over history, not columns:
- `User#current_routine` → routine on the most recent `Workout`.
- `Progression#current_phase_for(user)` → phase of the user's most recent `SetLog`
  against it (else the first phase).
- Working weight → the user's last `SetLog` for that exercise.

Before adding a `current_*`, `active`, or preference column, check whether it can
be derived instead. (We dropped `UserProgression` and `Routine.active` for this.)

## Data model shape
Three buckets (`docs/data_model.md` is authoritative):
- **Context** — `User` (fat model, no separate `Profile`).
- **Library** (shared, evergreen, freely edited) — `Routine → RoutineExercise →
  Exercise / Progression → ProgressionPhase`.
- **Log** (immutable events) — `Workout → SetLog` (+ `HealthImport`,
  `Meal → FoodEntry`).

Conventions worth not re-deriving:
- **No auth.** Homelab + Tailscale is the security boundary; "which of the 2 are
  you" is a picker, not a login.
- **Single shared library** — both users share everything; no per-user copies.
- **`RoutineExercise` = `exercise_id` XOR `progression_id`** — a plain movement or
  a progression, never both. Enforced by a model validation (checks the
  association objects, not `*_id`, so it holds on `build`) **and** a DB check
  constraint.
- **`Exercise.modality`** (string enum) is load-bearing: it drives the logging
  widget and which set fields exist. Name progressions after the destination
  movement (`"Pull-ups"`, not `"Pull-up progression"`).
- **`SetLog.exercise_id` is a restrict FK** — a movement with logged sets can't be
  hard-deleted (protects history). Renames are always safe.
- **Units: lbs only.** `weight` is `decimal(6,2)`, stored and displayed as-is — no
  `unit_preference`, no kg conversion.
- **Climbing = a `HealthImport`** on an off-script `Workout` (nullable
  `routine_id`); no V-grade fields (vanity metrics, out of scope).

## Testing
RSpec + FactoryBot (per global prefs). `spec/models/data_model_spec.rb` pins the
load-bearing DB/model behaviors (XOR, derived state, restrict FK) — extend it when
those rules change.

## Dev servers — non-default ports
This machine runs many projects at once, so Summit avoids the framework defaults:
- Rails **:3200**, Vite dev **:3236**, Vite test **:3237** (a `+36/+37` mnemonic
  off the base port).
- Ports live in `Procfile.dev`, `config/vite.json`, `config/puma.rb`, and
  `config/environments/development.rb` — keep them in sync.
- **Don't** use `${PORT:-…}` in `Procfile.dev`: foreman injects its own `PORT`
  (base 5000) into each process and shadows the default. Hardcode the Rails port.

## Design — Cascadia
Summit uses the Cascadia design system; reserved accent is **Oregon Gold**
(`#E4A520`). Details in `README.md` and the Cascadia skill.
