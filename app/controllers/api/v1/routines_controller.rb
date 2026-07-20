module Api
  module V1
    # The shared routine library + the hand editor. `show`/`create`/`update` all
    # return the same nested shape (routine + ordered slots, each an exercise XOR
    # a progression; see data_model.md). Editing a routine never touches the Log —
    # a slot carries its own `exercise_id` onto every SetLog, so history is correct
    # even after a swap, and removing a logged slot only nullifies the breadcrumb.
    class RoutinesController < BaseController
      def index
        render json: Routine.includes(:program).order(:name).map { |r| routine_summary_json(r) }
      end

      def show
        render json: routine_detail_json(load_routine(params[:id]))
      end

      # POST /api/v1/routines — new routine, optionally with its slots inline.
      def create
        routine = Routine.create!(routine_params)
        render json: routine_detail_json(load_routine(routine.id)), status: :created
      end

      # PATCH /api/v1/routines/:id — the whole edit in one call: metadata plus the
      # slot list (adds have no id, edits/swaps/reorders carry id + fields,
      # removals carry id + _destroy). Wrapped so a bad slot rolls the lot back.
      def update
        routine = Routine.find(params[:id])
        routine.update!(routine_params)
        render json: routine_detail_json(load_routine(routine.id))
      end

      # DELETE /api/v1/routines/:id — drop a routine. Slots cascade; their SetLog
      # breadcrumbs nullify (FK); past workouts keep their data with routine_id
      # nulled. Nothing in the Log is lost.
      def destroy
        Routine.find(params[:id]).destroy!
        head :no_content
      end

      private

      def load_routine(id)
        Routine.includes(
          :program,
          routine_exercises: [ :exercise, { progression: { progression_phases: :exercise } } ]
        ).find(id)
      end

      def routine_params
        params.permit(
          :name, :notes, :preferred_frequency, :program_id, tags: [],
          routine_exercises_attributes: %i[
            id exercise_id progression_id position target rest_seconds
            notes progression_note _destroy
          ]
        )
      end

      # The library-list shape: routine metadata + its program (id + name), no slots.
      def routine_summary_json(routine)
        routine
          .as_json(only: %i[id name notes tags preferred_frequency])
          .merge("program" => routine.program&.as_json(only: %i[id name]))
      end

      def routine_detail_json(routine)
        routine_summary_json(routine)
          .merge("routine_exercises" => routine.routine_exercises.map { |re| slot_json(re) })
      end

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
