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

      # Library (read-only for now): browse the shared exercises and routines.
      resources :exercises, only: %i[index], defaults: { export: true }
      resources :routines, only: %i[index show], defaults: { export: true }

      # Logging. `current` is the active (unfinished) workout for the picked user
      # — the live session. Sets are logged into it; `destroy` removes a mislog.
      resources :workouts, only: %i[index show create update], defaults: { export: true } do
        get :current, on: :collection, defaults: { export: true }
        resources :set_logs, only: %i[create], defaults: { export: true }
      end
      resources :set_logs, only: %i[destroy], defaults: { export: true }

      # Apple Health push (Health Auto Export). `create` is headless: Bearer-token
      # auth, not the session cookie — so it's not exported. `setup` is the
      # opposite: session-authed, it hands the frontend the values to paste into
      # the Health Auto Export app (URL + this user's token).
      resources :health_imports, only: %i[create] do
        get :setup, on: :collection
      end
    end
  end

  # HTML shell that boots the React app.
  root "pages#index"
end
