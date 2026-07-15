require "rails_helper"

# The "which of the 2 are you" picker, backed by the session cookie that
# api_only mode strips and config/application.rb adds back. These specs pin that
# the cookie actually round-trips (middleware present) and drives current_user.
RSpec.describe "Api::V1::Sessions", type: :request do
  let!(:aaron) { create(:user, name: "Aaron") }
  let!(:bree)  { create(:user, name: "Bree") }

  describe "GET /api/v1/users" do
    it "lists the users to pick from" do
      get "/api/v1/users"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to contain_exactly(
        { "id" => aaron.id, "name" => "Aaron" },
        { "id" => bree.id, "name" => "Bree" },
      )
    end
  end

  describe "GET /api/v1/session" do
    it "is null before anyone is picked" do
      get "/api/v1/session"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_nil
    end
  end

  describe "picking a user" do
    it "sets the session cookie so current_user persists across requests" do
      post "/api/v1/session", params: { user_id: bree.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("id" => bree.id, "name" => "Bree")

      # The cookie from the POST rides along; the next request knows who we are.
      get "/api/v1/session"
      expect(response.parsed_body).to eq("id" => bree.id, "name" => "Bree")
    end
  end

  describe "DELETE /api/v1/session" do
    it "clears the current user (switch back to the picker)" do
      post "/api/v1/session", params: { user_id: aaron.id }
      delete "/api/v1/session"
      expect(response).to have_http_status(:no_content)

      get "/api/v1/session"
      expect(response.parsed_body).to be_nil
    end
  end
end
