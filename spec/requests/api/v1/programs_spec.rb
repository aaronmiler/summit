require "rails_helper"

# Programs group routines for the Today picker. A flat Library CRUD (name +
# notes). The load-bearing rule is deletion: dropping a program must never delete
# its routines — the FK nullifies, so they fall back to ungrouped.
RSpec.describe "Api::V1::Programs", type: :request do
  describe "GET /api/v1/programs" do
    it "lists programs ordered by name" do
      create(:program, name: "Winter Strength")
      create(:program, name: "Climbing Base")

      get "/api/v1/programs"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |p| p["name"] }).to eq([ "Climbing Base", "Winter Strength" ])
    end
  end

  describe "POST /api/v1/programs" do
    it "creates a program" do
      expect {
        post "/api/v1/programs", params: { name: "Winter Strength", notes: "Nov–Feb block." }, as: :json
      }.to change(Program, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("name" => "Winter Strength", "notes" => "Nov–Feb block.")
    end

    it "422s a nameless program" do
      post "/api/v1/programs", params: { name: "" }, as: :json

      expect(response).to have_http_status(422)
      expect(response.parsed_body["errors"]).to be_present
    end
  end

  describe "PATCH /api/v1/programs/:id" do
    it "renames a program" do
      program = create(:program, name: "Winter Strength")

      patch "/api/v1/programs/#{program.id}", params: { name: "Spring Strength" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(program.reload.name).to eq("Spring Strength")
    end
  end

  describe "DELETE /api/v1/programs/:id" do
    it "deletes the program and unassigns (never deletes) its routines" do
      program = create(:program)
      routine = create(:routine, program:)

      expect {
        delete "/api/v1/programs/#{program.id}"
      }.to change(Program, :count).by(-1).and change(Routine, :count).by(0)

      expect(response).to have_http_status(:no_content)
      expect(routine.reload.program_id).to be_nil
    end
  end
end
