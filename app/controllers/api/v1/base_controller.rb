module Api
  module V1
    # Base class for all JSON API controllers. Inherits the lean
    # ActionController::API stack (via ApplicationController).
    class BaseController < ApplicationController
    end
  end
end
