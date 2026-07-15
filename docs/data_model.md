# Summit — Data Model (Working Draft)

> Status: **workshop starting point.** Nothing here is committed to schema.
> Purpose: get on the same page about how the app is actually used before we
> generate migrations.

## Entities (from the spec, rough)

**Users & profile**
- `User` (2 max): name/identity.
- Profile / LLM context: equipment, goals, notes. Fields on `User` or a separate
  `Profile`? Units preference (lbs/kg) lives here.

**Plan side (prescriptions)**
- `Routine` — named training plan ("Winter Base", "3-day split").
- `WorkoutTemplate` — a named workout within a routine ("Day A — Push").
- `ExercisePrescription` — a `WorkoutTemplate` × `Exercise` with prescribed targets
  (sets, reps, weight, RPE, rest, tempo, phase).
- `Exercise` — the movement itself (reusable library): name, equipment, muscle group.
- `Progression` — phases with freeform graduation criteria.

**Actuals side (logging)**
- `WorkoutSession` — a session instance: template, date, start/finish, notes.
- `SetLog` — an actual set: reps, weight, RPE, notes; ties session ↔ prescription.

**Nutrition**
- `Meal` — freeform entry ("2 eggs, sausage, toast") + timestamp; the raw text is the artifact.
- `FoodEntry` — LLM-derived per-item macros; belongs to `Meal`.

**Health (later)**
- `HealthImport?` — screenshot upload + parsed summary. Likely out of first schema pass.

## Relationships (spec's rough shape)

```
Routine → WorkoutTemplate → ExercisePrescription → Exercise / Progression
WorkoutSession → SetLog (actuals vs prescriptions)
Meal → FoodEntry
User → profile (equipment, goals, notes)
```

## Open questions to workshop

1. **Progression home:** attached to `Exercise` (movement-level) or `ExercisePrescription`
   (plan-level)? How does a phase advance — manual vs LLM-suggested + user-confirmed?
   Where does "current phase for this user" live?
2. **Prescription shape:** structured columns (sets/reps/weight/RPE) vs freeform text +
   structured-where-possible? Hangboard/climbing prescriptions differ from barbell.
3. **History integrity:** does a `WorkoutSession` snapshot the prescription at start time
   (so later plan edits don't rewrite history), or reference live prescriptions?
4. **Log granularity:** one row per set (`SetLog`), or per exercise-in-session with sets
   as JSON? (Rest timer + hangboard leans per-set.)
5. **Exercise library:** global canonical, per-user, or seeded + user-added hybrid?
6. **Multi-user sharing:** are routines/exercises shared between the 2 users or separate?
7. **Nutrition parsing:** can a `Meal` stay text-only (never parsed)? Macros nullable +
   confidence/notes field?
8. **Weekly summaries:** computed on the fly from `Meal`s, or materialized?
9. **Units:** lbs/kg per-user preference — where stored, how applied.
10. **Provenance:** keep the original pasted markdown / screenshot next to the parsed
    result for re-parsing? (Implies an import/LLM-request audit table — open question.)

## Not modeling yet

Auth specifics, PWA, LLM job/audit records (pending Q10), health imports.
