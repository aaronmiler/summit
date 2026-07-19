module Api
  module V1
    # The shared progression library. Index-only for now — it backs the routine
    # editor's slot picker (add a multi-phase progression to a routine). The full
    # phase editor lives with the routine editor's later pass; here just id + name
    # is enough to pick one.
    class ProgressionsController < BaseController
      def index
        render json: Progression.order(:name).as_json(only: %i[id name])
      end
    end
  end
end
