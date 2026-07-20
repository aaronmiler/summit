require "rails_helper"

# The HTML shell that boots the React app. It references the current build's
# digest-stamped asset filenames, so it must never be served from cache —
# otherwise iOS boots a stale build pointing at old/missing assets.
RSpec.describe "Pages", type: :request do
  describe "GET /" do
    it "renders the SPA shell" do
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="app"')
    end

    it "forbids caching of the shell" do
      get "/"

      expect(response.headers["Cache-Control"]).to eq("no-store")
    end
  end

  describe "GET /history (SPA deep link)" do
    it "serves the same non-cacheable shell for client routes" do
      get "/history"

      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end
  end
end
