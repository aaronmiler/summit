Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # JSON API consumed by the React frontend.
  namespace :api do
    namespace :v1 do
      get "health", to: "health#show", defaults: { export: true }
    end
  end

  # HTML shell that boots the React app.
  root "pages#index"
end
