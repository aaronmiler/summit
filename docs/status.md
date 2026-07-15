# Summit — Project Status

> Snapshot: **2026-07-15.** Two things exist: the data model (schema + specs) and
> a running **frontend shell** (identity, nav, routing) with no feature screens
> yet. This is the "where are we" doc — schema rationale lives in
> [`data_model.md`](./data_model.md), parked UX in
> [`open_questions.md`](./open_questions.md).

## Done

### Data model — implemented (first pass)
11 tables, models, factories, and a behavior spec pinning the load-bearing rules
(XOR on `RoutineExercise`, derived state, restrict FK). Library ships **empty**
(no seeds beyond users). See [`data_model.md`](./data_model.md).

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

### API surface (so far)
| Route | Purpose |
|-------|---------|
| `GET /api/v1/health` | Liveness — `{status:"ok"}` |
| `GET /api/v1/users` | The two picker choices |
| `GET /api/v1/session` | Current user, or `null` |
| `POST /api/v1/session` | Pick a user (sets cookie) |
| `DELETE /api/v1/session` | Switch user (clears cookie) |

### Verified
- `spec/requests/api/v1/sessions_spec.rb` — session cookie round-trips
  end-to-end; `current_user` derives from it.
- Full suite green: **rspec** (0 failures; empty model-spec stubs are pending),
  **vitest**, **tsc --noEmit**.

## Not built yet
- **Any feature vertical.** The three tabs are placeholders. Likely first:
  workout logging (pick routine → start `Workout` → log `SetLog`s with last-used
  prefill), which exercises the modality widget and the derived-state queries.
- **CRUD API** beyond identity — no Routine/Exercise/Workout/Meal endpoints.
- **LLM assistance** — the headline feature; unmodeled interaction
  (see [`open_questions.md`](./open_questions.md)).
- **PWA bits** — install prompt, offline, icons.
- Everything under "Still open" / "Not modeling yet" in
  [`data_model.md`](./data_model.md).
