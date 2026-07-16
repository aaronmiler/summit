# Summit — Data Model (Working Draft v2)

> Status: **implemented (first pass).** The schema is generated and migrated — 11
> tables with models, factories, and a behavior spec pinning the load-bearing
> decisions (`spec/models/data_model_spec.rb`). The library ships **empty** (no
> seeds). Remaining unknowns are flagged under "Still open."

## The core split: **Library** vs **Log** (vs **Context**)

Everything sorts into three buckets. Getting this split right is what makes the
rest fall out:

- **Library** — reusable *definitions*, evergreen. Edited freely. `Routine`,
  `RoutineExercise`, `Exercise`, `Progression`, `ProgressionPhase`.
- **Log** — immutable *events*, what actually happened. Never rewritten by a plan
  edit. `Workout`, `SetLog`, `HealthImport`, `Meal`, `FoodEntry`.
- **Context** — who the user is and where they're headed; the LLM prompt payload.
  `User`.

There is **no per-user state table.** Everything personal — working weight,
current routine, current progression phase — is *derived from the Log*, never
stored on the plan. This is the single idea the whole model turns on.

```
Context:  User  (equipment, direction/goals, preferences, units, notes)
Library:  Routine → RoutineExercise → Exercise / Progression → ProgressionPhase
Log:      Workout → SetLog          (+ HealthImport, + off-script cardio)
          Meal → FoodEntry
```

The LLM reads **Context** → generates/edits **Library** (`Routine`s). The user
runs a routine → writes to the **Log**. The Library is a mutable *guide*; the Log
is the source of truth.

---

## Entities

### Context

**`User`** — 2 users, fat model, **no auth.**
- Identity + everything the LLM needs as context, all on one table. No `Profile`.
- Fields: `name`, plus context: `equipment`, `goals`/`direction`, `preferences`,
  `notes` (freeform is fine — this is prompt fuel, e.g. "low-impact, protect
  fingers for climbing days").
- **No `unit_preference`.** Both users log in pounds; weight is stored and
  displayed in lbs, no conversion. (Add the column + a display helper later if
  someone ever wants kg — trivially reversible.)
- **No username/password.** "Which of the 2 are you?" is a lightweight picker
  (cookie / `?as=`), not an auth system. The security boundary is the homelab +
  Tailscale, not the app.

### Library

**`Routine`** — the reusable, drop-in training block ("Pull/Core", "Bouldering",
"Zone 2 cardio"). The unit you pick and *do*. Order-independent, run forever.
- Fields: `name`, `notes` (format, rest guidance, warmup, periodization flavor),
  optional soft hints for the generator (`tags` — Postgres `text[]`,
  `preferred_frequency`).
- **No `active` column.** "What am I running now" is emergent and *per-user* —
  the routine on your most recent `Workout`. A shared boolean couldn't express
  "she's on Bouldering, he's on Pull/Core" anyway.
- `has_many :routine_exercises` (ordered).

**`RoutineExercise`** — one exercise slot within a routine.
- Fields: `routine_id`, `position` (the *suggested* order — biased to, not
  binding), `exercise_id` **XOR** `progression_id` (two nullable FKs; exactly
  one set — model validation **plus** a DB check `num_nonnulls(...) = 1`),
  `target` (freeform string: "4 × 8–10", "3 × AMRAP", "2 × max time",
  "5–8 × 1–3" — guidance, never parsed), `rest_seconds` (nullable),
  `notes` (form cues), `progression_note` (the *lightweight* "when 25s easy, add
  tempo" cue — not a multi-phase progression).

**`Exercise`** — the movement library. **Single, shared, seeded + user-addable.**
- Rows are *specific movements*: "Barbell Bicep Curl" and "Dumbbell Bicep Curl"
  are separate rows. The name is self-describing (great for the LLM), logging
  points at one `exercise_id`, no compound key.
- Fields: `name`, `modality` (enum: `barbell`, `dumbbell`, `machine`,
  `bodyweight`, `band`, `hangboard`, `cardio`, `climbing`, …), `muscle_group`
  (loose grouping so the LLM can reason about substitutions).
- `modality` is load-bearing: it picks the **logging widget** (timer for
  `hangboard`/holds, reps+weight for lifts, duration/zone for `cardio`) and
  whether a set even *has* reps/weight.
- **Deletion:** the library is small and stable ("a pull-up is a pull-up"), so no
  archive flag. `SetLog.exercise_id` uses a **restrict** FK — a movement with
  logged sets simply can't be hard-deleted, so history can never be orphaned.
  (Renames are always safe; the FK is by id.)

**`Progression`** — a real multi-phase progression (the pull-up ladder), shared.
- Distinct from the lightweight `progression_note` above. Standalone library
  object — it spans *different* exercises across phases, so it's not a child of
  `Exercise`.
- Fields: `name` ("Pull-up progression"). `has_many :progression_phases` (ordered).

**`ProgressionPhase`** — one phase in a progression.
- Fields: `progression_id`, `position`, `exercise_id` (the movement for this
  phase — scap pull-ups → negatives → pull-ups), `target`, `graduation_criteria`
  (freeform: "4 × 10 clean + 45 sec dead hang").

**Current phase is derived, not stored — there is no `UserProgression`.** Same
pattern as last-used weight: pick a progression → the app finds your most recent
`SetLog` whose `progression_phase_id` belongs to it → pre-selects that phase and
shows the rest of the ladder as options (default to `position 0` if you've never
logged one). Logging against a higher phase *is* advancement — no state
transition, no per-user row to keep in sync. `graduation_criteria` feeds a soft
**nudge** ("4 × 10 clean — ready for pull-ups?"), never an automatic gate. This
is per-user for free (she's derived to Phase 1, he's derived to Phase 2).

### Log

**`Workout`** — the day's log; *what you actually did.* (This is "a workout" in
the everyday sense — the event, not the plan.)
- Created when you enter a routine to start training. Holds everything that
  happened that day, including imported/off-script activity.
- Fields: `user_id`, `routine_id` (nullable — off-script / ad-hoc allowed),
  `started_at`, `finished_at`, `notes`.
- **No `SetLog`s are pre-created.** You never pre-commit reps/weight ("to failure"
  / "to max" are ambiguous) — every set is logged *post-hoc* as actuals.

**`SetLog`** — one row per set. Actuals = source of truth.
- Fields: `workout_id`, `exercise_id` (carries its own movement, so off-script /
  "next man up" logging just works), `routine_exercise_id` (nullable context),
  `progression_phase_id` (nullable — how current phase is derived above),
  `set_number` (explicit; superset/hangboard ordering needs it, insertion order
  is too fragile), `reps?`, `weight?` (**lbs**, `decimal(6,2)` — stored and
  displayed as-is), `duration_seconds?`, `rpe?`, `notes`. Modality-specific
  numbers are nullable.
- **Prefill = last-used**: the user's own most recent `SetLog` for that exercise
  (any workout). This is why loads are personalized *without* per-user prescription
  rows — personalization is derived from history, not stored on the plan.

**`HealthImport`** — a pushed Apple Health / Fitness event (or a screenshot).
**First-class per-user event** (updated 2026-07-15): the import is primary and a
`Workout` is *inferred/materialized* from it — the dependency flipped, so it no
longer requires a `Workout`.
- Fields: `user_id`, `workout_id` (**nullable** — set when a session is
  materialized), `source`, `external_id` (HealthKit id, for **idempotent**
  re-imports), `activity_type`, `recorded_at`, parsed summary (`calories`,
  `avg_hr`, `distance`, `duration_seconds`), `raw` (jsonb — the **verbatim
  payload**, lossless), raw artifact (screenshot via ActiveStorage),
  `parse_notes`/`confidence`.
- **Ingestion:** `POST /api/v1/health_imports` (Bearer-token, headless) accepts
  Health Auto Export's v2 payload; each workout materializes an off-script,
  already-finished `Workout`. Keeps the **raw next to the parse** — parse off
  `raw`, re-parse anytime.
- **Climbing lands here.** An Apple Health climbing session imports as an
  off-script `Workout` (nullable `routine_id`) materialized from a
  `HealthImport` — duration/calories in the summary, no grade fields (V-scale is
  a vanity metric, out of scope).
- **Metrics** (daily rollups: energy in/out, HR, effort) are **not** modeled yet
  — workouts ingest; the per-day health picture is deferred (see
  `open_questions.md`).

**`IntegrationEvent`** — one durable row per interaction with an external
system (added 2026-07-16). A **general** audit log, not health-specific: inbound
webhooks (Health Auto Export pushes) today, outbound LLM calls (workout
building, nutrition parsing) as those land. Resolves open-question #2.
- Fields: `user_id` (**nullable** — unauth/system events have none), `kind`
  (dotted namespace: `health.push`, `llm.workout_build`, `llm.nutrition_parse`
  — the discriminator, so new event types need no migration), `source`
  (`health_auto_export`, `anthropic`, …), `direction` (`inbound`/`outbound`),
  `status` (`ok`/`error`/`unauthorized`/`bad_request`), `summary` (one-line),
  `metadata` (jsonb — kind-specific detail: push counts + per-item outcomes;
  model + token usage), `duration_ms`, `error`, `remote_ip`.
- **The seam is `IntegrationEvent.record!`** — any integration logs itself in one
  call, and monitoring is a query over `kind` + `status`. It **never raises**:
  audit logging must not take down the thing it observes.
- **Not for domain data.** Parsed results still live in their own tables
  (`HealthImport.raw`, `Meal`/`FoodEntry`) — this is the interaction log *around*
  them (who called, when, cost, success), not a second copy of the payload.

### Nutrition ("napkin-style")

**`Meal`** — a freeform entry; the raw text *is* the artifact.
- Fields: `user_id`, `raw_text` ("2 eggs, sausage, toast"), `eaten_at`, `notes`.
- **Can stay text-only forever** — parsing is optional, never required.

**`FoodEntry`** — LLM-derived per-item macros; belongs to `Meal`.
- Fields: `meal_id`, `name`, `calories?`, `protein?`, `carbs?`, `fat?` (all
  nullable), `confidence`/`parse_notes`. Text is truth; macros are derived.

---

## Decisions locked (and why)

1. **No auth.** Homelab + Tailscale is the boundary; identity is a picker.
2. **Fat `User`.** Context payload lives on it.
3. **Units:** weight is `decimal(6,2)` **lbs**, stored and displayed as-is — no
   `unit_preference`, no conversion layer (both users log in pounds).
4. **Single shared library** (Exercises, Progressions, Routines). 2 users who
   share everything — no per-user duplication.
5. **Prescription demoted.** Routines prescribe *structure/intent* (rep range,
   sets, RPE target, rest), never a fixed load. Working weight = last-used prefill.
6. **History integrity is free — no snapshot.** The Log records actuals
   independently; editing/deleting a `Routine` never rewrites past `Workout`s.
7. **Per-set logging** (`SetLog`), not JSON-per-exercise — rest timer, per-set RPE,
   and hangboard all want addressable sets.
8. **"Next man up" logging.** Routine order is a *bias*, not a constraint; log any
   exercise in any order; off-script and ad-hoc (warmup cardio) are first-class.
9. **`modality` drives the UI.** Picks the logging widget and which fields exist.
10. **No level above `Routine`.** Intent = `User` context; "what am I running" =
    recency (most recent `Workout`); grouping = a tag if ever needed. A real
    `Plan` wrapper is deferred (see Not modeling yet).
13. **No per-user state tables.** Current routine, current progression phase, and
    working weight are all *derived from the Log*, never stored. `UserProgression`
    was dropped for this reason.
11. **Weekly summaries computed on the fly**, not materialized (2 users, small data).
12. **Periodization / weekly scheduling is soft** — freeform notes + LLM
    system-prompt logic at generation time, not schema (no `Program`, no rigid
    day-of-week binding).

---

## Still open

1. **`HealthImport` parse depth.** Store the raw screenshot only, or LLM-extract
   HR / calories / duration into the summary columns? (Leaning: raw first, parse
   when the flow exists — summary columns nullable so no migration is needed when
   parsing arrives.)
2. ~~**LLM audit / re-parse table.**~~ **Resolved 2026-07-16** →
   `IntegrationEvent` (see Log). One general interaction log covers inbound
   webhooks and outbound LLM calls; parsed results still live in their own
   tables, this logs the interaction around them.
3. **Cross-user visibility** (progress, logs, meals) is a *policy / query*
   question, not schema — `Workout` and every derived phase are already per-user.
   Decide when the UI needs it.

## Not modeling yet

- A rigid `Program`/schedule wrapper above `Routine` (grouping is emergent for now).
- **Bodyweight / measurements** — tracked in Apple Health today; pull in later as
  a small dedicated table (`user_id`, `weight`, `measured_at`) when the flow exists.
- **Climbing grade / send detail** (V-scale) — sessions come in as `HealthImport`;
  grades are vanity metrics, out of scope.
- PWA/offline-sync specifics.
- Auth specifics (none planned).
- Advanced health metrics beyond the `HealthImport` summary.
