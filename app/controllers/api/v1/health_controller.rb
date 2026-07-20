module Api
  module V1
    class HealthController < BaseController
      def show
        # version is the build's git SHA (baked in as BUILD_SHA at image build;
        # "dev" when unset). The frontend remembers the SHA it loaded with and
        # prompts a refresh once this value moves past it — i.e. a deploy landed
        # while the app was open.
        render json: { status: "ok", version: ENV.fetch("BUILD_SHA", "dev") }
      end
    end
  end
end
