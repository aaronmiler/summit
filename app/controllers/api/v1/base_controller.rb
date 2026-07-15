module Api
  module V1
    # Base class for all JSON API controllers. Inherits the lean
    # ActionController::API stack (via ApplicationController).
    class BaseController < ApplicationController
      # ActionController::API omits session/cookie access; add it back so
      # current_user can read the picker's choice from the session cookie.
      include ActionController::Cookies

      private

      # The current user is whoever the picker selected (session cookie), or nil.
      # This is the only notion of "who" in the app — there is no auth.
      def current_user
        @current_user ||= User.find_by(id: session[:user_id])
      end
    end
  end
end
