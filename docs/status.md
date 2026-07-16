# Summit — Project Status

> Snapshot: **2026-07-15.** The app now has two working verticals over the data
> model + shell: **Library browse** (routines + exercises, read-only, seeded) and
> **Workout logging** (the live start→log→finish loop). This is the "where are
> we" doc — schema rationale lives in [`data_model.md`](./data_model.md), parked
> UX in [`open_questions.md`](./open_questions.md).

## Done

### Data model — implemented (first pass)
11 tables, models, factories, and a behavior spec pinning the load-bearing rules
(XOR on `RoutineExercise`, derived state, restrict FK). See
[`data_model.md`](./data_model.md).

### Library seed — implemented
`db/seeds.rb` (idempotent) seeds the current 4-week program's two **strength**
days: **Pull/Core** (Mon) and **Push/Legs** (Fri), 14 exercises, and the
"Pull-ups" progression (3 phases) with real targets/graduation criteria. Cardio
(Wed) and bouldering (Tu/Th) are **not** seeded — they arrive via the Apple
Health import. Freely editable in-app.

### Library browse — implemented (read-only)
The first feature vertical, and the **copy-me pattern** for the next ones:
seeded data → typed endpoint → `useX` query → screen.

- **Routes:** `/library` (routines as cards), `/library/routines/:id` (the
  ordered slots — target, rest, form notes; progression slots render the phase
  ladder inline), `/library/exercises` (grouped by muscle group). No editing yet.
- **Serialization** is inline `as_json` in the controllers (matching the identity
  ones); `routines#show` hand-builds the nested slot JSON so exercise **and**
  progression branches both resolve (name, modality, phases).
- **Derived state stays derived:** the progression ladder is shown as options,
  *not* a highlighted "current phase" — current phase is per-user and a logging
  concern, not a library one.

### Frontend shell — implemented
A running skeleton: pick a user, get a themed, routed app. No feature screens.

- **Identity = session cookie, not client state.** The "which of the 2 are you"
  picker sets `session[:user_id]`; `Api::V1::BaseController#current_user` reads
  it; the cookie rides along same-origin (app served from Rails :3200). No auth —
  homelab + Tailscale is the boundary. api_only strips session middleware, so
  it's re-added in `config/application.rb`.
- **Users seeded:** Aaron, Bree (`db/seeds.rb`, idempotent).
- **Stack:** react-router + TanStack Query over the generated `js_from_routes`
  typed helpers. `frontend/api/queries.ts` is the copy-me convention
  (`useSession` / `useUsers` / `useSelectUser` / `useSwitchUser`).
- **Cascadia design system** wired in (`frontend/styles/cascadia.css`), accent is
  Oregon Gold (the system's default — no override needed), Inter self-hosted via
  `@fontsource-variable/inter` (no external CDN).
- **Layout:** sticky green nav, "Summit" in Oregon Gold, active-link underline,
  current-user chip that switches user. Three **stub** routes: Today / Library /
  Nutrition.

### Workout logging — implemented (the live loop)
The headline flow, second vertical: **Today → pick a routine → start a `Workout`
→ log `SetLog`s → finish.** Derived-state all the way down, no new state columns.

- **Stepped UI**, one exercise at a time: a workout opens on an **overview
  checklist** (done/todo dot per slot); tap a slot to **focus** it. The focused
  step is **jumpable** — progress dots + prev/next, any order — so it honors "next
  man up" rather than forcing a linear wizard. (Layout only; the API is unchanged.)

- **"Active workout" = most recent `Workout` with `finished_at IS NULL`** for the
  picked user (`User#active_workout`). Starting guards against a double-start
  (returns the live one); finishing stamps `finished_at`, so `current` goes null
  and Today drops back to the routine picker.
- **Prefill = last-used** (`User#last_set_for`): each slot arrives seeded with the
  user's most recent numbers for that movement. The set form keeps its values
  after logging, so repeating a set is one tap.
- **`modality` drives the widget**: the 8 modalities collapse to 4 field layouts
  (`frontend/lib/modality.ts` → weighted / reps / timed / duration).
- **Progression slots** render the ladder as a phase picker, defaulted to the
  derived `current_phase_for(user)`. The chosen phase is what you log against, and
  its id stamps `SetLog.progression_phase_id` — so **advancement is just the Log**,
  re-derived next session. No `UserProgression`.
- `set_number` auto-increments per exercise server-side; `set_logs#destroy`
  removes a mislog.

### Workout history — implemented (read-only)
A **History** nav tab (Today / History / Library / Nutrition): the picked user's
**finished** workouts, newest first, → a past-workout detail.

- **Scoped to you.** `workouts#index` lists only `current_user`'s finished
  workouts (the active one and the other user's are excluded); `#show` is scoped
  the same way (another user's id → 404). "Just mine," per the per-user Log.
- **Detail groups sets by exercise off the Log** — each `SetLog` carries its own
  `exercise_id`, so a past workout renders correctly even if the routine changed
  since. History integrity is free; no snapshotting.
- Finishing a workout invalidates the history cache, so it shows up immediately.

### Apple Health ingestion — implemented (workouts)
Push from the **Health Auto Export** iOS app → Summit. The import is the primary
artifact; the session is *inferred* (materialized), per the decided direction.

- **`POST /api/v1/health_imports`** is headless: **Bearer-token** auth (per-user
  `users.api_token`), not the session cookie. Parses HAE's v2
  `{ data: { workouts: […] } }`; each workout → a `HealthImport` + a materialized
  **off-script `Workout`** (nullable `routine_id`), always finished (never the
  active one). **Idempotent** on the HealthKit id (`external_id`), so HAE
  re-sending overlapping windows is a no-op. The verbatim payload is kept on
  `raw` (jsonb) — lossless; parse off it.
- **Model change:** `HealthImport` is now first-class — `user_id`, nullable
  `workout_id`, `activity_type`, `distance`, `recorded_at`, `external_id`, `raw`.
  `data_model.md` updated.
- **Setup from Summit:** `GET /api/v1/health_imports/setup` (session-authed)
  hands the frontend the ingest URL (built from the request host, so it's right on
  `aaron-macbook.local` now and the homelab later) + the auth header. A
  **Connect Apple Health** screen (linked from History) shows copy-paste values
  and generates an importable config file. HAE strips header values on export, so
  the auth header is always added by hand.
- **Dev host authorization** opened for `.local` / `*.ts.net` / private IPs so the
  phone can reach the dev server (network is the boundary).
- **Metrics** (daily rollups: active/resting energy, HR, effort) are **not**
  ingested yet — this pass is workouts-only (matches the automation's
  `includeHealthMetrics: false`). See `open_questions.md`.

### Frontend API casing — **camelCase throughout** (convention)
`js-from-routes` deserializes every response snake_case → **camelCase** and
serializes request bodies back to snake_case. So: **Rails serializers stay
snake_case; all frontend types + component reads + request payloads are
camelCase** (`exercise.muscleGroup`, `slot.restSeconds`, `{ data: { userId } }`).
tsc can't catch a mismatch here (the response is an asserted generic), so this is
a hard rule for every new endpoint — mirror the wire in camelCase.

### API surface (so far)
| Route | Purpose |
|-------|---------|
| `GET /api/v1/health` | Liveness — `{status:"ok"}` |
| `GET /api/v1/users` | The two picker choices |
| `GET /api/v1/session` | Current user, or `null` |
| `POST /api/v1/session` | Pick a user (sets cookie) |
| `DELETE /api/v1/session` | Switch user (clears cookie) |
| `GET /api/v1/exercises` | The movement library (ordered by muscle group) |
| `GET /api/v1/routines` | Routines, no slots (the library landing) |
| `GET /api/v1/routines/:id` | One routine + its ordered slots |
| `GET /api/v1/workouts/current` | Active workout: slots + prefill + phases + logged sets |
| `GET /api/v1/workouts` | History: your finished workouts (summaries) |
| `GET /api/v1/workouts/:id` | A past workout, sets grouped by exercise |
| `POST /api/v1/workouts` | Start a session (guards double-start) |
| `PATCH /api/v1/workouts/:id` | Finish / annotate |
| `POST /api/v1/health_imports` | Apple Health push (Bearer token) → materialized workout |
| `GET /api/v1/health_imports/setup` | HAE setup values for the picked user (session) |
| `POST /api/v1/workouts/:id/set_logs` | Log a set (auto set_number) |
| `DELETE /api/v1/set_logs/:id` | Remove a mislogged set |

### Verified
- `spec/requests/api/v1/sessions_spec.rb` — session cookie round-trips
  end-to-end; `current_user` derives from it.
- `spec/requests/api/v1/{exercises,routines}_spec.rb` — library ordering and the
  nested `routines#show` payload (both XOR branches: exercise + progression).
- `spec/requests/api/v1/workouts_spec.rb` — the logging loop end to end: active
  workout, double-start guard, auto set-numbering, **last-used prefill**,
  **progression-phase advancement**, and **history** (index scoping: excludes
  active + other users; detail grouped by exercise; cross-user `#show` → 404).
- The camelCase wire→frontend contract is proven directly (the `js-from-routes`
  deserializer camelCases a sample payload with no snake keys leaking).
- `spec/requests/api/v1/health_imports_spec.rb` — token auth, workout
  materialization, dedupe on `external_id`, history visibility, setup values. Also
  driven over real HTTP (with the `.local` host) end to end: host-auth, token,
  ingest, dedupe.
- Full suite green: **rspec** (0 failures; empty model-spec stubs are pending),
  **vitest**, **tsc --noEmit**, **`vite build`**.
- **Not yet eyeballed in a browser** — data contracts are proven, but the rendered
  Today/logging/History/Connect-Health screens want a manual click-through
  (`bin/dev` → pick user). The Apple Health push wants a real device test too
  (point Health Auto Export at the setup URL, confirm a walk materializes).

## Not built yet
- **Nutrition** is still a placeholder tab.
- **Logging follow-ups (deferred):** **off-script / ad-hoc** logging (nullable
  `routine_id`, add any exercise mid-workout). Rest timers still deprioritized.
  History is browse-only (no editing/deleting past workouts, no summaries/charts).
- **Apple Health *metrics*** — daily rollups (calories in/out, effort/cadence over
  weeks) aren't ingested; workouts land, but the holistic dashboard is unbuilt.
  Imported workouts also render plainly in History ("0 sets") — wants a nicer
  activity/distance/calorie summary. See `open_questions.md`.
- **Library CRUD** — browse + logging are read/append-only; no routine/exercise
  create/edit/delete yet, and no Meal endpoints.
- **LLM assistance** — the headline feature; unmodeled interaction
  (see [`open_questions.md`](./open_questions.md)).
- **PWA bits** — install prompt, offline, icons.
- Everything under "Still open" / "Not modeling yet" in
  [`data_model.md`](./data_model.md).
