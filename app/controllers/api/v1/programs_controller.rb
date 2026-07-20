module Api
  module V1
    # Programs group routines for the Today picker — a small, flat Library CRUD
    # (name + notes, no slots). Deleting one nullifies its routines' program_id
    # (FK on_delete: :nullify), so those routines fall back to ungrouped; nothing
    # else is touched. Routines carry their program (id + name) in their own JSON.
    class ProgramsController < BaseController
      def index
        render json: Program.order(:name).map { |p| program_json(p) }
      end

      def create
        program = Program.new(program_params)
        if program.save
          render json: program_json(program), status: :created
        else
          render json: { errors: program.errors.full_messages }, status: 422
        end
      end

      def update
        program = Program.find(params[:id])
        if program.update(program_params)
          render json: program_json(program)
        else
          render json: { errors: program.errors.full_messages }, status: 422
        end
      end

      def destroy
        Program.find(params[:id]).destroy!
        head :no_content
      end

      private

      def program_params
        params.permit(:name, :notes)
      end

      def program_json(program)
        program.as_json(only: %i[id name notes])
      end
    end
  end
end
