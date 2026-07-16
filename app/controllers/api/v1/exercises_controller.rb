module Api
  module V1
    # The shared movement library. Read-only for now (browse); CRUD comes with
    # user-addable exercises. modality/muscle_group ride along — modality drives
    # the future logging widget, muscle_group groups the browser.
    class ExercisesController < BaseController
      def index
        render json: Exercise.order(:muscle_group, :name)
          .as_json(only: %i[id name modality muscle_group])
      end
    end
  end
end
