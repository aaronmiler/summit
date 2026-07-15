module Api
  module V1
    # The two users, for the "which of the 2 are you" picker. Read-only.
    class UsersController < BaseController
      def index
        render json: User.order(:name).as_json(only: %i[id name])
      end
    end
  end
end
