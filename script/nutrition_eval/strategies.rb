# Strategies = the architectures under test. Each takes a meal string, makes one
# or more model calls, and returns a normalized result the grader can score:
#   { items: [ {name,calories,protein,carbs,fat,confidence,parse_notes} ],
#     parse_ok: bool, calls: int, latency_ms: int, raw: [...] }
# Keeping the interface uniform lets single-shot and two-pass compete head to head.
require_relative "prompts"

module NutritionEval
  module Extract
    module_function

    # Tolerant JSON pull: strip qwen <think> blocks, prefer a fenced block, else
    # take the outermost {...} (or [...]). Returns parsed object or nil.
    def json(text)
      return nil if text.nil? || text.strip.empty?
      t = text.gsub(%r{<think>.*?</think>}m, "").strip
      if (m = t.match(/```(?:json)?\s*(\{.*\}|\[.*\])\s*```/m))
        t = m[1]
      end
      obj_s = balanced(t, "{", "}")
      arr_s = balanced(t, "[", "]")
      candidate = obj_s || arr_s
      return nil unless candidate
      JSON.parse(candidate)
    rescue JSON::ParserError
      nil
    end

    def balanced(str, open, close)
      s = str.index(open)
      e = str.rindex(close)
      return nil unless s && e && e > s
      str[s..e]
    end

    NUM_KEYS = %w[calories protein carbs fat confidence].freeze

    # Coerce any parsed shape into a clean items array. Accepts {items:[...]},
    # a bare [...], or a single item hash.
    def items(parsed)
      list =
        if parsed.is_a?(Hash) && parsed["items"].is_a?(Array) then parsed["items"]
        elsif parsed.is_a?(Array) then parsed
        elsif parsed.is_a?(Hash) && parsed.key?("name") then [parsed]
        elsif parsed.is_a?(Hash) && parsed["items"] == [] then []
        else nil
        end
      return nil if list.nil?
      list.map { |it| item(it) }.compact
    end

    def item(h)
      return nil unless h.is_a?(Hash)
      out = { "name" => h["name"].to_s, "amount" => num(h["amount"]), "unit" => h["unit"].to_s }
      NUM_KEYS.each { |k| out[k] = num(h[k]) }
      out["parse_notes"] = h["parse_notes"].to_s
      out
    end

    def num(v)
      return nil if v.nil? || v == ""
      Float(v)
    rescue ArgumentError, TypeError
      # strip stray units like "12g"
      s = v.to_s[/-?\d+(\.\d+)?/]
      s ? s.to_f : nil
    end

    MACRO_KEYS = %w[calories protein carbs fat].freeze

    # Per-unit → total: multiply each macro by amount, keeping the per-unit value
    # for inspection. This is the code-side multiply that the 9B skips.
    def scale_by_amount(i)
      a = i["amount"].to_f
      a = 1.0 unless a.positive?
      MACRO_KEYS.each do |k|
        i["#{k}_per_unit"] = i[k]
        i[k] = i[k].nil? ? nil : (i[k] * a).round(1)
      end
      i
    end
  end

  class SingleShot
    def initialize(client, style:, json_mode:, per_unit: false)
      @client = client
      @style = style
      @json_mode = json_mode
      @per_unit = per_unit
    end

    def name = "single_#{@style}#{@json_mode ? '_json' : ''}"

    def run(text)
      msgs = [{ role: "system", content: Prompts::SINGLE.fetch(@style) }]
      msgs.concat(@per_unit ? Prompts::FEWSHOT_PERUNIT : Prompts::FEWSHOT) unless @style == :min
      msgs << { role: "user", content: text }

      content, ms = @client.chat(msgs, json_mode: @json_mode)
      parsed = Extract.json(content)
      items = Extract.items(parsed)
      items = items.map { |i| Extract.scale_by_amount(i) } if @per_unit && items
      { items: items || [], parse_ok: !items.nil?, calls: 1, latency_ms: ms, raw: [content] }
    end
  end

  class TwoPass
    def initialize(client, json_mode:)
      @client = client
      @json_mode = json_mode
    end

    def name = "twopass#{@json_mode ? '_json' : ''}"

    def run(text)
      raw = []
      total_ms = 0
      calls = 0

      # Pass 1: decompose into components.
      dc, ms = @client.chat(
        [{ role: "system", content: Prompts::DECOMPOSE }, { role: "user", content: text }],
        json_mode: @json_mode
      )
      raw << dc; total_ms += ms; calls += 1
      parsed = Extract.json(dc)
      comps = parsed.is_a?(Hash) ? parsed["components"] : nil
      return { items: [], parse_ok: false, calls: calls, latency_ms: total_ms, raw: raw } unless comps.is_a?(Array)
      return { items: [], parse_ok: true, calls: calls, latency_ms: total_ms, raw: raw } if comps.empty?

      # Pass 2: pointed macro estimate per component.
      items = []
      parse_ok = true
      comps.first(8).each do |c|
        cname = (c.is_a?(Hash) ? c["name"] : c).to_s
        portion = (c.is_a?(Hash) ? c["portion"] : "typical serving").to_s
        next if cname.strip.empty?

        prompt = Prompts.estimate_item(cname, portion)
        ic, ims = @client.chat(
          [{ role: "system", content: prompt }, { role: "user", content: "#{cname} (#{portion})" }],
          json_mode: @json_mode, max_tokens: 300
        )
        raw << ic; total_ms += ims; calls += 1
        it = Extract.item(Extract.json(ic))
        if it
          items << it
        else
          parse_ok = false
        end
      end

      { items: items, parse_ok: parse_ok, calls: calls, latency_ms: total_ms, raw: raw }
    end
  end
end
