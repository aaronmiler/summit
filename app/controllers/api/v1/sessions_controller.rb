module Api
  module V1
    # The picker's identity, held in the session cookie. Not auth — just which
    # of the two users you are. `show` bootstraps the frontend on load.
    class SessionsController < BaseController
      # GET /api/v1/session -> the current user, or null if none picked yet.
      def show
        render json: current_user&.as_json(only: %i[id name])
      end

      # POST /api/v1/session { user_id } -> set the current user.
      def create
        user = User.find(params[:user_id])
        session[:user_id] = user.id
        render json: user.as_json(only: %i[id name])
      end

      # DELETE /api/v1/session -> clear it (switch user).
      def destroy
        session[:user_id] = nil
        head :no_content
      end
    end
  end
end
