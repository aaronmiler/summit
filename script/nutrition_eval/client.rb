# Thin LiteLLM chat client for the nutrition eval — shaped like Delta's
# LitellmClient but self-contained (Net::HTTP, no gems) so the harness runs
# outside a Rails boot. Reads LITELLM_BASE_URL / LITELLM_API_KEY from the env,
# falling back to Delta's .env.development so it "just works" on this machine.
require "net/http"
require "json"
require "uri"

module NutritionEval
  class Client
    class Error < StandardError; end

    def initialize(model:, temperature: 0.2, no_cache: false)
      @model = model
      @temperature = temperature
      @no_cache = no_cache
      load_env_fallback!
      @base = ENV.fetch("LITELLM_BASE_URL")
      @key  = ENV.fetch("LITELLM_API_KEY", "none")
    end

    # messages: [{role:, content:}]. json_mode: nil | "json_object".
    # Returns [content_string, latency_ms].
    def chat(messages, json_mode: nil, temperature: nil, max_tokens: 900)
      body = { model: @model, messages: messages, temperature: temperature || @temperature, max_tokens: max_tokens }
      body[:response_format] = { type: json_mode } if json_mode
      body[:cache] = { "no-cache" => true } if @no_cache

      uri = URI("#{@base}/v1/chat/completions")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 15
      http.read_timeout = 300

      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{@key}"
      req["Content-Type"]  = "application/json"
      req.body = JSON.generate(body)

      t0 = Time.now
      res = http.request(req)
      latency_ms = ((Time.now - t0) * 1000).round

      unless res.code.to_i == 200
        raise Error, "HTTP #{res.code}: #{res.body.to_s[0, 300]}"
      end
      parsed = JSON.parse(res.body)
      content = parsed.dig("choices", 0, "message", "content").to_s
      [ content, latency_ms ]
    end

    private

    def load_env_fallback!
      return if ENV["LITELLM_BASE_URL"]
      delta_env = File.expand_path("../../../delta/.env.development", __dir__)
      return unless File.exist?(delta_env)

      File.foreach(delta_env) do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#") || !line.include?("=")
        k, v = line.split("=", 2)
        next unless k.start_with?("LITELLM_")
        ENV[k] ||= v.gsub(/\A["']|["']\z/, "")
      end
    end
  end
end
