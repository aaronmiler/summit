# Summit — Nutrition Parsing (LLM)

> Status: **eval done, design decided, build deferred.** The `vault-assistant`
> model was battle-tested for napkin-nutrition parsing (see the eval below); the
> parsing approach is settled. `MealParser` itself isn't built yet — it's specced
> here. Input method and trigger UX are still open (see bottom). Captured 2026-07-19.

The job: turn a freeform `Meal.raw_text` ("2 eggs, sausage, toast") into structured
`FoodEntry` rows (per-item macros). Text stays the truth; macros are derived and
optional — a meal can live text-only forever (`data_model.md` § Nutrition).

---

## What we proved (the eval)

Harness lives at **`script/nutrition_eval/`** (standalone Ruby, no Rails boot —
`ruby script/nutrition_eval/run.rb`). It pits parsing strategies against
`vault-assistant` (Qwen 3.5 9B on tars, via LiteLLM) over a banded dataset and
scores parse-validity, calorie/macro bands, 4/4/9 coherence, adversarial handling,
confidence calibration, portion legibility, and cost. Files: `client`, `cases`,
`prompts`, `strategies`, `grader`, `run`, `scaling`.

**Verdict: the 9B handles this — ~87% usable, stable across uncached draws, ~1.5-4s/parse.**

Findings that drive the design (don't re-litigate without new eval data):

1. **Single-shot beats two-pass.** A decompose→estimate pipeline scored *lower*
   (≈72-83%) at ~3× the calls/latency and *inflated* multi-component restaurant
   meals. Not worth it.
2. **Forced structured-output is unnecessary.** Parse was 100% valid JSON from
   instructions alone across every config. Use free-form + a tolerant extractor
   (strip qwen `<think>` blocks and markdown fences).
3. **Checklist prompt > prose.** Enumerated imperatives give the best confidence
   calibration on the 9B (matches Delta's router note that this model "ignores prose
   judgment rules"). Accuracy is a wash; calibration isn't.
4. **Anti-flatten rule is mandatory.** Without it, the model collapses a named dish
   with listed components ("Italian sub: roll, salami, provolone…") into a single
   low-anchored blob. A checklist rule + a component few-shot fixed it (n=1 → n=7).
5. **Portion is the dominant error term — and the model won't do the multiply.**
   It reliably captures `amount`+`unit` ("3 slices") but leaves calories at the
   *one-unit* value — "3 slices of pizza" comes back amount=3, calories=280 (one
   slice). Classic 9B arithmetic miss.
6. **Per-unit mode was tested and rejected.** Having the model emit per-unit macros
   and multiplying in code fixes isolated scaling (5/5) but **tanks real-meal
   accuracy (63% vs 87%)** — it amplifies per-unit noise by the amount (black coffee
   → 80 kcal, 2 eggs → 412). The model is inconsistent about whether `calories` means
   per-unit or total, so no pure mode is trustworthy. Totals-mode — one gestalt
   estimate per item — is its single most reliable output.

Gotcha for future runs: **LiteLLM caching is on** (hit ≈24ms, miss ≈4s). Identical
requests replay cached output, so `--samples N` without a cache-bust gives N copies.
Use `--no-cache` for independent draws / real latency. Creds auto-load from
`../delta/.env.development` (`LITELLM_BASE_URL=http://litellm.tars`).

---

## The decided approach

**Totals-mode is the primary estimate. Portion is a first-class, correctable value —
corrections are a code-side linear rescale, never a re-estimate.**

- **Ingest** with the proven `checklist` prompt (totals mode). The model returns, per
  item: `name`, `amount`, `unit`, **total** `calories`/`protein`/`carbs`/`fat`,
  `confidence`, `parse_notes`. All come back reliably (portion legibility was 100%).
- **Correct** by editing `amount`. The macros rescale in code:
  `new_total = total × (new_amount / old_amount)`. No LLM round-trip.
- This answers the "does it represent reality?" worry the right way: the *initial*
  number is the model's best-accuracy output, and the portion — the lever that
  actually moves the answer — is visible and one-tap fixable. We do **not** trust the
  model's multiplication; the human owns the portion.

The one thing totals-mode gets wrong is an explicit multi-count typed into the
original text ("3 slices" arriving at 1-slice value). That's rare in low-friction
logging and the correctable `amount` catches it. A refined hybrid (detect an explicit
count, scale only those items) is a possible later tweak — deferred, not needed.

---

## Schema — `FoodEntry` additions

Current `FoodEntry`: `meal_id`, `name`, `calories?`, `protein?`, `carbs?`, `fat?`,
`confidence`, `parse_notes`. Add:

- **`amount`** — `decimal(6,2)`, the portion count (e.g. `3`).
- **`unit`** — `string`, what one unit is (`"slice"`, `"oz"`, `"cup"`, `"egg"`,
  `"serving"`).

Macros stay **stored totals** — deliberately *not* derived. Unlike personal state
(working weight, current routine), the macros are the LLM's primary output, not a
query over the Log, so the "derive, don't store" rule (`data_model.md` #13) doesn't
apply. `amount`/`unit` exist to make the total *rescalable*, not to recompute it.

---

## `MealParser` — spec (not yet built)

Async by decision — we'll LLM-ize meals in the background, and the input method
(typed text now; photo-of-plate / barcode later) isn't chosen, so nothing here
assumes a synchronous request/response.

1. **`LitellmClient`** (`app/services/litellm_client.rb`) — port Delta's thin
   OpenAI-compatible client + the tolerant JSON extractor. ENV:
   `LITELLM_BASE_URL`, `LITELLM_API_KEY`, and a model pointer (Setting or ENV). The
   proven checklist prompt + few-shot become a `NutritionPrompt` constant.
2. **`MealParser`** (`app/services/meal_parser.rb`) — `Meal → [FoodEntry]`: one
   totals-mode call, parse, upsert entries (name, amount, unit, macro totals,
   confidence, parse_notes). Re-parsing a meal replaces its prior derived entries;
   `raw_text` is untouched.
3. **Async trigger** — a background job (`ParseMealJob`) enqueued when a meal is
   saved *or* on an explicit "parse" action — TBD with the input method. A meal is
   valid and viewable before/without parse; entries fill in when the job lands.
   Log the exchange as an `IntegrationEvent` (`llm.nutrition_parse`, per
   `data_model.md`).
4. **Endpoints** (`Api::V1`, `export: true`, hand-rolled `as_json`, camelCase bridge):
   - trigger a parse (enqueue the job) and read a meal's entries + parse status.
   - `PATCH /food_entries/:id` — **rescale**: set `amount`, recompute macro totals in
     code (`× new/old`). Pure arithmetic, no LLM.
5. **Tests** — `meal_parser_spec` with a stubbed LLM response; request specs for the
   parse trigger and the rescale; extend `frontend/types.ts`. Keep the load-bearing
   rules in `spec/models/data_model_spec.rb` if any DB constraint is added.

Frontend (a parse affordance + an editable-amount widget that shows the rescale) is a
separate pass, gated on the input-method decision.

---

## Still open (UX / product, not schema)

- **Input method** — typed text now; photo-of-plate / barcode later. Undecided;
  the async design stays agnostic to it. (`open_questions.md` § Nutrition #2.)
- **Parse trigger** — auto-on-save vs. an explicit button. Leaning auto+async since
  the parse is cheap and a meal is useful before it lands. (`open_questions.md` #1.)
- **Targets** — macro/calorie goals to track against, or pure logging? Ties to the
  training goal (cut vs. build). (`open_questions.md` #4.)
- **Calories in vs. out** — the "in" side is this (`Meal`/`FoodEntry`) summed; "out"
  is Health import. That view is a cross-source query, surfaced somewhere TBD.

See also: `data_model.md` § Nutrition, `open_questions.md` § Nutrition, and the memory
note `nutrition-parse-eval`.
