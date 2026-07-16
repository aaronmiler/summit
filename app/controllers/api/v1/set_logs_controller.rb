module Api
  module V1
    # Individual logged sets — the source-of-truth actuals. Logged post-hoc into
    # the active workout; `set_number` defaults to the next one for that exercise
    # so the widget doesn't have to track it.
    class SetLogsController < BaseController
      before_action :require_current_user!

      # POST /api/v1/workouts/:workout_id/set_logs
      def create
        workout = current_user.workouts.find(params[:workout_id])
        attrs = set_log_params.to_h.symbolize_keys
        attrs[:set_number] ||= next_set_number(workout, attrs[:exercise_id])
        set_log = workout.set_logs.create!(attrs)
        render json: set_log.as_log_json, status: :created
      end

      # DELETE /api/v1/set_logs/:id — remove a mislog. Scoped to the user's own
      # workouts so you can only delete your own sets.
      def destroy
        set_log = SetLog.joins(:workout)
          .where(workouts: { user_id: current_user.id })
          .find(params[:id])
        set_log.destroy!
        head :no_content
      end

      private

      def set_log_params
        params.permit(:exercise_id, :routine_exercise_id, :progression_phase_id,
                      :set_number, :reps, :weight, :duration_seconds, :rpe, :notes)
      end

      # Next set for this exercise within the workout (1-based). Explicit numbers
      # keep superset/hangboard ordering stable (insertion order is too fragile).
      def next_set_number(workout, exercise_id)
        workout.set_logs.where(exercise_id: exercise_id).count + 1
      end
    end
  end
end
