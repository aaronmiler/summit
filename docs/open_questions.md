# Summit — Open Questions (beyond the data model)

> Status: **parking lot.** These are things we haven't workshopped yet — mostly
> *flow / UX / behavior*, not schema. Schema-level opens live in
> [`data_model.md`](./data_model.md) under "Still open" and aren't repeated here.
> Captured 2026-07-14.

## Nutrition (schema decided, usage not)

> **Update 2026-07-19:** the *parsing* approach is now decided and specced in
> [`nutrition_parsing.md`](./nutrition_parsing.md) (eval-backed: totals-mode single-shot
> on `vault-assistant`, structured `amount`/`unit`, correction = code-side rescale,
> async parse). The questions below are the parts still open — mainly input method,
> trigger UX, and targets.

We settled `Meal` (raw text = truth) → `FoodEntry` (nullable LLM-derived macros),
but never discussed how it's actually used:

1. **Parse trigger** — manual ("parse this meal" button) or automatic on save?
   Can a meal stay text-only indefinitely and get parsed later?
2. **Entry modes** — text only, or also photo-of-plate / barcode down the line?
3. **Summaries** — daily/weekly macro rollups: what's the view? (Decided
   *computed on the fly*, but the UX is undefined.)
4. **Targets** — are there macro/calorie goals to track against, or is this pure
   logging with no target? (Ties to the training goal — cutting vs. building.)
5. **Hydration / water** — in scope at all?

## LLM assistance (the headline feature, barely designed)

The README calls out "LLM assistance for building and interpreting routines." We
modeled the *output* (`Routine`) but never the *interaction*:

1. **Generation flow** — chat interface? A form + generate? What context gets
   assembled into the prompt (User equipment/goals/prefs + existing library)?
2. **Interpretation / coaching** — does the LLM read logged `Workout`/`SetLog`
   history and offer feedback ("you've hit the top of the range 3x, add weight")?
   Is that on-demand or surfaced proactively?
3. **Where it runs** — homelab-hosted; sync vs. async job; streaming responses?
4. **Model / provider / cost** — which model, and any budget concerns for a
   2-user app?
5. **Editing** — after generation, is the routine hand-editable, or regenerate-only?

## Apple Health / Fitness import — scope reframed (2026-07-15)

**Reframing:** the Health/Fitness import is *not* meant to be "a workout." It's a
**holistic health signal** — calories in vs. out, effort/load over weeks, workout
cadence — that stands on its own, separate from whether a training session
happened.

This breaks the current model. Today **`HealthImport belongs_to :workout`**
(`workout_id NOT NULL`), so every import must hang off a training `Workout` — and
climbing was modeled as an off-script `Workout` + a `HealthImport`. If health data
is its own picture, it shouldn't require a `Workout` at all.

**Direction (decided):** the dependency **flips** — the *import* is the primary
artifact, and a session is **inferred** from it (you don't pre-declare "I climbed";
the app reads it out of the Fitness data). Same instinct as deriving current
routine / working weight from the Log.

**Materialize vs. stand-alone (decided): materialize.** An inferred activity
**creates a `Workout`(-equivalent) entry** so History/summaries stay one list — we
explicitly chose this over a purist "import stands alone, query across both"
model. Rationale is the top constraint: **low-friction logging** (see
[[low-friction-logging-priority]]); the union-query approach risked more friction
and plumbing for little user benefit. Storing a derived entry is an accepted
trade here.

Open decisions (schema-level — revisit `data_model.md`):
1. **Where does health data live?** Leaning: make `HealthImport.workout_id`
   nullable + add `user_id`/`recorded_on` so an import can **stand alone or
   materialize/attach a session**. A separate per-day `HealthDay`/`HealthMetric`
   rollup (energy, HR, effort keyed on user+date) may still be worth it for the
   holistic view — decide when the vertical starts.
2. **Granularity:** per-day rollups (calories in/out, active energy, avg HR,
   cadence count) vs. per-activity rows? The "computed on the fly" instinct
   suggests storing what Apple gives us and aggregating in queries.
3. **Calories in** comes from **nutrition** (`Meal`/`FoodEntry`), **calories out**
   from Health — the "in vs. out" view is a *cross-source query*, not a table.
   Where does it surface (a Health/Dashboard tab)?
4. **Effort/cadence over weeks** = the weekly-summary surface we said we'd compute
   on the fly. Does that now pull from Health data + the Log together?
5. **Ingestion:** screenshot + LLM parse (the raw-artifact-next-to-parse pattern),
   a shortcut/export, or manual entry? (Ties to `HealthImport` parse depth.)

**Status (2026-07-15): workouts ingestion is built.** Health Auto Export pushes
its v2 payload to `POST /api/v1/health_imports` (Bearer token); each workout
materializes an off-script `Workout`, idempotent on the HealthKit id, verbatim
payload kept on `raw`. `HealthImport` is now standalone (see `data_model.md`).

**Still open — the *metrics* / holistic side:**
1. **Daily rollups.** The `metrics` array (active/resting energy, HR, effort,
   dietary energy…) is *not* ingested yet — the current automation is
   workouts-only (`includeHealthMetrics: false`). A per-day `HealthDay`/`HealthMetric`
   store (keyed user+date) is still the likely shape; decide when we build the
   "calories in vs out / effort over weeks" dashboard.
2. **Calories in vs out** stays a cross-source query: *in* from `Meal`/`FoodEntry`,
   *out* from Health metrics. Where does it surface?
3. **History display** of imported (off-script) workouts is plain ("0 sets") —
   wants an activity/distance/calorie summary line.
4. **Bodyweight** (below) likely folds into the daily-metric store.

## Bodyweight & measurements (not mentioned all session)

A training app usually tracks bodyweight over time (progress, load calc, cutting/
bulking). We have nothing for this.

1. Do we track **bodyweight** weigh-ins? As a `HealthImport`, a dedicated log, or
   pulled from Apple Health?
2. Other measurements (waist, etc.) — in scope or ignore?

## Climbing / bouldering logging depth

We treat bouldering as a `cardio`/`climbing` modality with a duration, but
climbers often want more:

1. Log **grades / sends** (V-scale), or just session duration + notes?
2. Hangboard is modeled as timed sets — is that enough, or do we want
   edge-size / added-weight as first-class fields?

## PWA / offline

It's a phone-first PWA used *at the gym* — signal may be bad.

1. **Offline logging** — do we need offline-first / queue-and-sync, or is a live
   connection assumed?
2. Install prompt, home-screen icon (Oregon Gold), splash.
3. **Push notifications** — only really relevant if rest timers matter (they were
   deprioritized).

## Multi-user visibility

2 shared users, shared library. Undecided on the *log* side:

1. Do the two users **see each other's** workouts / progress / meals, or are logs
   private-per-user with only the library shared?
2. Any comparison / friendly-competition surface, or fully independent?

## Smaller / deferred

- **Rest timers** — deprioritized ("keep me honest"), UX unspecified. Nice-to-have.
- **Deload / test weeks** — the plan had a "test max reps" week; how (if at all)
  does the app surface periodization prompts, given we made scheduling soft?
- **Units at entry** — storage decided (canonical + convert on display); the
  entry/display toggle UX is unspecified.
