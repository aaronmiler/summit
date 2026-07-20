# Thin OpenAI-compatible chat client for our LiteLLM gateway (Qwen on tars).
# Ported from Delta's LitellmClient, but on Net::HTTP (Summit has no httpx) so
# there's no gem to add. Class methods — this is a stateless utility, not an
# ApplicationService.
#
# The eval proved free-form output beats forced structured-output on this 9B, so
# there's no json_mode: callers ask for text and run it through `extract_json`,
# which tolerates qwen `<think>` blocks and markdown fences.
require "net/http"
require "json"
require "uri"

class LitellmClient
  class Error < StandardError; end

  class << self
    # messages: [{ role:, content: }]. Returns the assistant message content string.
    def chat(messages, model:, temperature: 0.2, max_tokens: 900)
      raise Error, "LITELLM_BASE_URL is not set" if base_url.to_s.strip.empty?

      body = { model: model, messages: messages, temperature: temperature, max_tokens: max_tokens }

      uri = URI("#{base_url}/v1/chat/completions")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 15
      http.read_timeout = 300

      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{api_key}"
      req["Content-Type"]  = "application/json"
      req.body = JSON.generate(body)

      res = http.request(req)
      unless res.code.to_i == 200
        raise Error, "LiteLLM chat error #{res.code}: #{res.body.to_s[0, 300]}"
      end

      JSON.parse(res.body).dig("choices", 0, "message", "content").to_s
    end

    # Tolerant JSON pull: strip qwen <think> blocks, prefer a fenced block, else
    # take the outermost {...} (or [...]). Returns the parsed object or nil.
    def extract_json(text)
      return nil if text.nil? || text.strip.empty?

      t = text.gsub(%r{<think>.*?</think>}m, "").strip
      if (m = t.match(/```(?:json)?\s*(\{.*\}|\[.*\])\s*```/m))
        t = m[1]
      end
      candidate = balanced(t, "{", "}") || balanced(t, "[", "]")
      return nil unless candidate

      JSON.parse(candidate)
    rescue JSON::ParserError
      nil
    end

    private

    def base_url = ENV["LITELLM_BASE_URL"]
    def api_key  = ENV.fetch("LITELLM_API_KEY", "none")

    # Outermost balanced-ish slice between the first `open` and last `close`.
    def balanced(str, open, close)
      s = str.index(open)
      e = str.rindex(close)
      return nil unless s && e && e > s

      str[s..e]
    end
  end
end
