module Api
  module V1
    # The live logging session. A workout is the day's Log event; `current` is
    # the active (unfinished) one for the picked user — everything the logging
    # screen needs in one payload: the routine's slots, last-used prefill, the
    # derived current progression phase, and whatever's been logged so far.
    class WorkoutsController < BaseController
      before_action :require_current_user!

      # GET /api/v1/workouts -> history: this user's finished workouts, most
      # recent first, as lightweight summaries (the History tab list).
      def index
        workouts = current_user.workouts.where.not(finished_at: nil)
          .includes(:routine).order(started_at: :desc)
        set_counts = SetLog.where(workout_id: workouts.map(&:id)).group(:workout_id).count

        render json: workouts.map { |w|
          {
            "id" => w.id,
            "started_at" => w.started_at,
            "finished_at" => w.finished_at,
            "routine" => w.routine&.as_json(only: %i[id name]),
            "set_count" => set_counts[w.id] || 0
          }
        }
      end

      # GET /api/v1/workouts/:id -> one past workout's detail, sets grouped by
      # exercise. Grouping is off the *Log* (each set carries its own
      # exercise_id), so history is correct even if the routine later changes.
      def show
        workout = current_user.workouts.includes(set_logs: :exercise).find(params[:id])
        groups = workout.set_logs.sort_by(&:id).group_by(&:exercise)

        render json: workout.as_json(only: %i[id started_at finished_at notes]).merge(
          "routine" => workout.routine&.as_json(only: %i[id name]),
          "exercises" => groups.map do |exercise, sets|
            { "exercise" => exercise_json(exercise), "sets" => sets.map(&:as_log_json) }
          end
        )
      end

      # GET /api/v1/workouts/current -> active workout payload, or null.
      def current
        workout = current_user.active_workout
        render json: workout && workout_payload(workout)
      end

      # POST /api/v1/workouts { routine_id? } -> start a session. Guards against a
      # double-start: if one's already live, return it rather than orphan another.
      def create
        workout = current_user.active_workout ||
          current_user.workouts.create!(routine_id: params[:routine_id], started_at: Time.current)
        render json: workout_payload(workout), status: :created
      end

      # PATCH /api/v1/workouts/:id -> finish (finished_at) or annotate (notes).
      def update
        workout = current_user.workouts.find(params[:id])
        workout.update!(params.permit(:finished_at, :notes))
        render json: workout.as_json(only: %i[id started_at finished_at notes])
      end

      private

      def workout_payload(workout)
        routine = workout.routine
        slots = routine ? routine.routine_exercises.includes(:exercise, progression: { progression_phases: :exercise }) : []
        sets_by_slot = workout.set_logs.order(:set_number).group_by(&:routine_exercise_id)

        {
          "id" => workout.id,
          "started_at" => workout.started_at,
          "notes" => workout.notes,
          "routine" => routine&.as_json(only: %i[id name]),
          "slots" => slots.map { |re| slot_payload(re, sets_by_slot[re.id] || []) }
        }
      end

      # A slot as the logging screen sees it: the routine_exercise fields, the
      # movement to log against (exercise XOR progression, phases carry full
      # exercise objects so switching phase re-picks the widget), last-used
      # prefill, and the sets already logged into this workout.
      def slot_payload(re, sets)
        base = {
          "id" => re.id,
          "position" => re.position,
          "target" => re.target,
          "rest_seconds" => re.rest_seconds,
          "notes" => re.notes,
          "progression_note" => re.progression_note,
          "sets" => sets.map(&:as_log_json)
        }

        if re.exercise
          base.merge(
            "exercise" => exercise_json(re.exercise),
            "progression" => nil,
            "prefill" => prefill_json(re.exercise)
          )
        else
          prog = re.progression
          current_phase = prog.current_phase_for(current_user)
          base.merge(
            "exercise" => nil,
            "progression" => {
              "id" => prog.id,
              "name" => prog.name,
              "current_phase_position" => current_phase&.position,
              "phases" => prog.progression_phases.map do |phase|
                {
                  # id rides along: logging a set stamps progression_phase_id,
                  # which is how the *next* current phase is derived.
                  "id" => phase.id,
                  "position" => phase.position,
                  "target" => phase.target,
                  "graduation_criteria" => phase.graduation_criteria,
                  "exercise" => exercise_json(phase.exercise)
                }
              end
            },
            "prefill" => current_phase && prefill_json(current_phase.exercise)
          )
        end
      end

      def exercise_json(exercise)
        exercise.as_json(only: %i[id name modality muscle_group])
      end

      # Last-used numbers for an exercise (this user, any workout). Decimals are
      # coerced to numbers so the frontend widget gets clean values.
      def prefill_json(exercise)
        set = current_user.last_set_for(exercise)
        return nil unless set

        { "reps" => set.reps, "weight" => set.weight&.to_f,
          "duration_seconds" => set.duration_seconds, "rpe" => set.rpe&.to_f }
      end
    end
  end
end
