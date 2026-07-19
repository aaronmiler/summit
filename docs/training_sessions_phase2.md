# Training sessions — Phase 2 (parked)

Phase 1 shipped **derived-then-persisted** session grouping: a `TrainingSession`
collects a day's Log events, assigned by `TrainingSession.absorb` at two write
boundaries (health-import ingest, routine finish) using single-linkage / 1h-gap
clustering. See `docs/data_model.md` → Log → `TrainingSession` and
`spec/models/training_session_spec.rb`.

Phase 2 is deliberately **not built**. Phase 1's stored row (`workouts.training_session_id`)
is what leaves room for it — none of the below needs a schema rethink, just
additive columns + endpoints.

## Why it's parked

The 1h auto-grouping is conservative on purpose. It will occasionally be wrong in
two directions, and both are better fixed by a human than by a looser threshold:

- **False split** — one real session with a break longer than an hour (the
  motivating case: a bike ride broken up by a long lunch → bike · lunch · bike).
  Widening the gap to catch this would wrongly merge genuinely separate sessions
  (Thursday's morning climb + evening golf). The right fix is a **manual merge**,
  not a bigger number.
- **False join** — two distinct activities that happen to sit within an hour but
  aren't one session. Needs a **manual split**.

We're waiting to see how often the 1h rule actually bites in real use before
building the manual tools. Friday was real; the bike-ride case is hypothetical.

## What Phase 2 adds

1. **Manual merge / split.** Move a workout's `training_session_id` (merge = point
   the workouts at one session, drop the emptied one; split = open a new session
   and reassign). A `manually_grouped` flag on the session (or a nullable
   `pinned_at`) so `absorb` **stops re-clustering** a session a human has curated —
   otherwise a later import could re-split what was merged. This is the key
   interaction between auto and manual: **manual wins, and sticks.**
2. **Session-owned metadata.** A nullable `name` and `notes` on `training_sessions`
   — a custom title ("Long PNW brick") overriding the derived header name, and a
   session-level note distinct from any one workout's. Cheap once the row exists.
3. **Endpoints + UI.** A `TrainingSessionsController` (the v1 grouping lives inside
   `workouts#index` and needs no resource; manual merge does — likely
   `PATCH /api/v1/training_sessions/:id` and a workout→session reassignment).
   History gains a merge affordance (select rows → "combine"), and the FST↔routine
   link (below) rides on the same reassignment path.

## Related: the FST ↔ routine link

Friday's watch "Functional Strength Training" import still spawns its own workout
that sits *inside* the Push/Legs session as a redundant-looking row. We chose
**not** to auto-fold it (the "overlapping FST import ⇒ this routine workout"
heuristic is unreliable). The manual reassignment machinery above is the honest
way to let a user say "this import is that workout's calorie record" — same tool,
one level down (workout↔workout rather than workout↔session).

## Not re-deriving these

- Grouping is stored, not a per-read query — assigned at the write boundary off
  recorded times. Manual edits are the reason it *can't* be purely derived.
- `dependent: :nullify` throughout: losing a session never deletes its immutable
  Log events.
