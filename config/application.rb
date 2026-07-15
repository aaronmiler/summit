require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Summit
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    # HTML shell pages are still served by a dedicated ActionController::Base
    # controller (see PagesController); everything else is JSON under /api.
    config.api_only = true

    # API-only strips session/cookie middleware. Identity is the "which of the 2
    # are you" picker, stored in an encrypted session cookie so current_user is
    # derived server-side — no per-request user plumbing on the client. The React
    # app is served same-origin (Rails :3200), so the cookie rides along
    # automatically. Add the middleware back:
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore,
                          key: "_summit_session", same_site: :lax

    # RSpec + FactoryBot for generated specs; skip the specs we don't write.
    config.generators do |g|
      g.test_framework :rspec, fixtures: false, view_specs: false,
                               helper_specs: false, routing_specs: false
      g.factory_bot dir: "spec/factories"
    end
  end
end
