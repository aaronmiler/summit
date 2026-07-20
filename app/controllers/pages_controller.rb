# Serves the HTML shell that boots the React app. This is the only
# view-rendering controller; all data flows through Api::V1 (JSON).
class PagesController < ActionController::Base
  # Inherits ActionController::Base directly (ApplicationController is API-only),
  # so the "application" layout must be declared explicitly rather than implied.
  layout "application"

  # The shell references the current build's digest-stamped asset filenames, so
  # it must never be reused from cache — otherwise iOS (esp. a home-screen web
  # app) boots a stale build pointing at old/missing assets. Assets themselves
  # stay far-future cached; only this tiny document is always refetched.
  before_action :no_store

  def index; end

  private

  def no_store
    response.headers["Cache-Control"] = "no-store"
  end
end
