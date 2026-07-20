Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # JSON API consumed by the React frontend.
  namespace :api do
    namespace :v1 do
      get "health", to: "health#show", defaults: { export: true }

      # The "which of the 2 are you" picker. `session` is identity (cookie-backed),
      # `users` is the list of choices. `export: true` emits typed JS helpers.
      resource :session, only: %i[show create destroy], defaults: { export: true }
      resources :users, only: %i[index], defaults: { export: true }

      # Library: browse the shared exercises + progressions, and full CRUD on
      # routines (the hand editor; the LLM builder comes later). `progressions`
      # is index-only — it backs the routine editor's slot picker.
      resources :exercises, only: %i[index create update destroy], defaults: { export: true }
      resources :progressions, only: %i[index], defaults: { export: true }
      # Programs group routines for the Today picker; full CRUD from the Library.
      resources :programs, only: %i[index create update destroy], defaults: { export: true }
      resources :routines, only: %i[index show create update destroy], defaults: { export: true }

      # Logging. `current` is the active (unfinished) workout for the picked user
      # — the live session. Sets are logged into it; `destroy` removes a mislog.
      resources :workouts, only: %i[index show create update destroy], defaults: { export: true } do
        get :current, on: :collection, defaults: { export: true }
        resources :set_logs, only: %i[create], defaults: { export: true }
      end
      resources :set_logs, only: %i[destroy], defaults: { export: true }

      # Nutrition. A meal is logged as freeform text and parsed into per-item
      # macros asynchronously; `parse` re-runs it, `update` edits it (re-parsing on
      # a text change). Items are hand-correctable: edit name/unit (`update`),
      # add/remove (`create`/`destroy`), `rescale` a portion (no LLM), or
      # `estimate` one item's macros (one LLM call). See docs/nutrition_parsing.md.
      resources :meals, only: %i[index create show update], defaults: { export: true } do
        post :parse, on: :member, defaults: { export: true }
        resources :food_entries, only: %i[create], defaults: { export: true }
      end
      resources :food_entries, only: %i[update destroy], defaults: { export: true } do
        member do
          post :rescale, defaults: { export: true }
          post :estimate, defaults: { export: true }
        end
      end

      # Apple Health push (Health Auto Export). `create` is headless: Bearer-token
      # auth, not the session cookie — so it's not exported. `setup` is the
      # opposite: session-authed, it hands the frontend the values to paste into
      # the Health Auto Export app (URL + this user's token).
      resources :health_imports, only: %i[create] do
        get :setup, on: :collection
      end

      # Read-only monitoring feed over the integration audit log (session-authed,
      # shows all events). Plain fetch on the frontend, so it isn't exported.
      resources :integration_events, only: %i[index]
    end
  end

  # HTML shell that boots the React app.
  root "pages#index"

  # SPA fallback: any other HTML GET (a deep-linked client route like /history
  # refreshed or opened cold) renders the same shell, so react-router can take
  # over. Constrained to HTML requests that aren't the API or framework paths,
  # so unknown /api calls and missing assets still 404 instead of getting HTML.
  get "*path", to: "pages#index", constraints: ->(req) {
    req.format.html? && !req.path.start_with?("/api", "/rails", "/up")
  }
end
