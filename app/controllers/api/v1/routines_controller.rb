module Api
  module V1
    # The shared routine library. Read-only for now (browse); the LLM-assisted
    # builder + hand editing come later. `show` nests the ordered slots, each of
    # which references an exercise XOR a progression (see data_model.md).
    class RoutinesController < BaseController
      def index
        render json: Routine.order(:name)
          .as_json(only: %i[id name notes tags preferred_frequency])
      end

      def show
        routine = Routine.includes(
          routine_exercises: [ :exercise, { progression: { progression_phases: :exercise } } ]
        ).find(params[:id])

        render json: routine
          .as_json(only: %i[id name notes tags preferred_frequency])
          .merge("routine_exercises" => routine.routine_exercises.map { |re| slot_json(re) })
      end

      private

      def slot_json(re)
        {
          "id" => re.id,
          "position" => re.position,
          "target" => re.target,
          "rest_seconds" => re.rest_seconds,
          "notes" => re.notes,
          "progression_note" => re.progression_note,
          "exercise" => re.exercise&.as_json(only: %i[id name modality muscle_group]),
          "progression" => re.progression && progression_json(re.progression)
        }
      end

      def progression_json(progression)
        {
          "id" => progression.id,
          "name" => progression.name,
          "phases" => progression.progression_phases.map do |phase|
            {
              "position" => phase.position,
              "target" => phase.target,
              "graduation_criteria" => phase.graduation_criteria,
              "exercise_name" => phase.exercise.name
            }
          end
        }
      end
    end
  end
end
