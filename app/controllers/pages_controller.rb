# Serves the HTML shell that boots the React app. This is the only
# view-rendering controller; all data flows through Api::V1 (JSON).
class PagesController < ActionController::Base
  # Inherits ActionController::Base directly (ApplicationController is API-only),
  # so the "application" layout must be declared explicitly rather than implied.
  layout "application"

  def index; end
end
