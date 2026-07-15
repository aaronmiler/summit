# Summit — Open Questions (beyond the data model)

> Status: **parking lot.** These are things we haven't workshopped yet — mostly
> *flow / UX / behavior*, not schema. Schema-level opens live in
> [`data_model.md`](./data_model.md) under "Still open" and aren't repeated here.
> Captured 2026-07-14.

## Nutrition (schema decided, usage not)

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
