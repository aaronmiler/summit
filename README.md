# Summit

A personal (2-user) health & training PWA — tracking workouts, progressions, and
napkin-style nutrition logging, with LLM assistance for building and interpreting
routines. PNW-flavored, goal-oriented.

## Stack

- Ruby 3.4.9, Rails 8.1 (API-only, serving a React app shell)
- Postgres 16 (shared local container in dev)
- React + TypeScript in `frontend/`, built by Vite
- Typed API/path helpers generated from routes via `js_from_routes`
- RSpec + FactoryBot (Ruby), Vitest + Testing Library (frontend)

## Getting started

```bash
bin/setup   # install deps, prepare the database
bin/dev     # boots Rails (:3200) + Vite (:3236) via foreman
```

Config lives in `.env` (copy from `.env.example`). Dev connects to the shared local
Postgres container on `localhost:5432`.

Tests: `bundle exec rspec` and `yarn test`.

## Design — Cascadia

Summit uses **Cascadia**, the household design system (Pacific Northwest palette,
Inter type, sentence case, 6–8px radius).

**Reserved accent: Oregon Gold** — Summit's identity color (a golden summit / the
achievement of reaching the top).

```css
:root {
  --app-accent: #E4A520;        /* Oregon Gold */
  --app-accent-hover: #FFB81C;  /* Portland Yellow — gold's hover in the system */
}
```

Shared Cascadia constants (unchanged across apps): Cascadia Green `#00573F` for
navigation and structure, Inter at weights 300 / 400 / 500 only, sentence case
everywhere, and Portland Blue `#418FDE` focus rings. The accent drives interactive
elements — primary buttons, active nav indicators, key highlights, and the app icon
tint.
