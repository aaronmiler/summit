module Api
  module V1
    # The shared movement library — now user-editable (create/rename/retype/delete).
    # modality/muscle_group ride along: modality drives the logging widget, so it's
    # required; muscle_group is a loose grouping for the browser. Renames are always
    # safe (FKs are by id). Deletion is guarded by restrict FKs — a movement in use
    # by a routine, progression, or logged set can't be dropped (protects history).
    class ExercisesController < BaseController
      def index
        render json: Exercise.order(:muscle_group, :name).map { |e| exercise_json(e) }
      end

      def create
        exercise = Exercise.new(exercise_params)
        if exercise.save
          render json: exercise_json(exercise), status: :created
        else
          render json: { errors: exercise.errors.full_messages }, status: 422
        end
      end

      def update
        exercise = Exercise.find(params[:id])
        if exercise.update(exercise_params)
          render json: exercise_json(exercise)
        else
          render json: { errors: exercise.errors.full_messages }, status: 422
        end
      end

      # A movement with any references (routine slot, progression phase, logged
      # set) can't be hard-deleted — the restrict FKs protect history. Surface
      # that as a 422 the UI can show, not a 500.
      def destroy
        exercise = Exercise.find(params[:id])
        exercise.destroy!
        head :no_content
      rescue ActiveRecord::DeleteRestrictionError
        render json: {
          error: "#{exercise.name} is used by a routine, progression, or logged set and can't be deleted."
        }, status: 422
      end

      private

      def exercise_params
        params.permit(:name, :modality, :muscle_group)
      end

      def exercise_json(exercise)
        exercise.as_json(only: %i[id name modality muscle_group])
      end
    end
  end
end
