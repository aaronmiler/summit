#!/usr/bin/env ruby
# Napkin-nutrition eval runner. Pits parsing strategies (single-shot in 3 prompt
# styles, plus two-pass decompose→estimate) against vault-assistant over a banded
# dataset, and scores each on parse reliability, macro accuracy, coherence,
# adversarial handling, confidence calibration, and cost (calls + latency).
#
# Usage:
#   ruby script/nutrition_eval/run.rb                 # full matrix, 1 sample each
#   ruby script/nutrition_eval/run.rb --configs single_checklist,twopass
#   ruby script/nutrition_eval/run.rb --case t2_sandwich --samples 3
#   ruby script/nutrition_eval/run.rb --dry-run
require "json"
require "optparse"
require_relative "client"
require_relative "cases"
require_relative "strategies"
require_relative "grader"

module NutritionEval
  DEFAULT_CONFIGS = %w[
    single_min single_prose single_checklist single_checklist_json twopass twopass_json
  ].freeze

  def self.build_strategy(name, client)
    case name
    when "single_min"           then SingleShot.new(client, style: :min, json_mode: nil)
    when "single_prose"         then SingleShot.new(client, style: :prose, json_mode: nil)
    when "single_checklist"     then SingleShot.new(client, style: :checklist, json_mode: nil)
    when "single_checklist_perunit" then SingleShot.new(client, style: :checklist_perunit, json_mode: nil, per_unit: true)
    when "single_checklist_json" then SingleShot.new(client, style: :checklist, json_mode: "json_object")
    when "twopass"              then TwoPass.new(client, json_mode: nil)
    when "twopass_json"         then TwoPass.new(client, json_mode: "json_object")
    else raise "unknown config: #{name}"
    end
  end

  class Runner
    def initialize(opts)
      @opts = opts
      @client = Client.new(model: opts[:model], temperature: opts[:temp], no_cache: opts[:no_cache])
      @cases = CASES.select do |c|
        (opts[:cases].nil? || opts[:cases].include?(c[:id])) &&
          (opts[:tier].nil? || c[:tier] == opts[:tier])
      end
      @configs = opts[:configs]
    end

    def run
      if @opts[:dry_run]
        puts "Model: #{@opts[:model]}"
        puts "Configs: #{@configs.join(', ')}"
        puts "Cases: #{@cases.map { |c| c[:id] }.join(', ')} (#{@cases.size})"
        puts "Samples/case: #{@opts[:samples]}"
        est = @configs.size * @cases.size * @opts[:samples]
        puts "Model calls (single-shot): ~#{est}; two-pass adds ~#{@cases.size * @opts[:samples] * 3} per two-pass config"
        return
      end

      results = {} # config => [rows]
      @configs.each do |cfg|
        strat = NutritionEval.build_strategy(cfg, @client)
        rows = []
        puts "\n=== #{cfg} ==="
        @cases.each do |kase|
          @opts[:samples].times do |s|
            row = grade_one(strat, kase)
            rows << row
            tag = row[:error] ? "ERR " : (row[:usable] ? "ok  " : "MISS")
            extra = row[:error] || "cal=#{row[:cal]} n=#{row[:n_items]} #{row[:latency_ms]}ms/#{row[:calls]}c"
            puts "  [#{tag}] #{kase[:id]}#{@opts[:samples] > 1 ? "##{s}" : ''}  #{extra}"
          end
        end
        results[cfg] = rows
      end

      report(results)
      save(results)
    end

    def grade_one(strat, kase)
      res = strat.run(kase[:text])
      Grader.score(kase, res).merge(id: kase[:id], tier: kase[:tier], config: strat.name, items: res[:items])
    rescue Client::Error, StandardError => e
      { id: kase[:id], tier: kase[:tier], config: strat.name, error: e.message[0, 120],
        usable: false, parse_ok: false, calls: 0, latency_ms: 0 }
    end

    # ---- reporting ----
    def report(results)
      puts "\n" + "=" * 78
      puts "SCORECARD  (model: #{@opts[:model]}, #{@cases.size} cases x #{@opts[:samples]} sample(s))"
      puts "=" * 78
      hdr = format("%-22s %6s %6s %6s %6s %7s %6s  %5s %7s %7s", "config", "USABLE", "parse", "cal", "coher", "portion", "conf", "calls", "med_ms", "p95_ms")
      puts hdr
      puts "-" * hdr.length
      results.each do |cfg, rows|
        normal = rows.reject { |r| r[:error] }
        puts format("%-22s %6s %6s %6s %6s %7s %6s  %5s %7s %7s",
                    cfg,
                    pct(rows) { |r| r[:usable] },
                    pct(rows) { |r| r[:parse_ok] },
                    pct(applicable(normal)) { |r| r[:cal_ok] },
                    pct(applicable(normal)) { |r| r[:coherence_ok] },
                    pct(applicable(normal)) { |r| r[:portion_ok] },
                    pct(applicable(normal)) { |r| r[:conf_ok] },
                    avg(rows.map { |r| r[:calls] }).round(1),
                    median(rows.map { |r| r[:latency_ms] }).round,
                    p95(rows.map { |r| r[:latency_ms] }).round)
      end

      best = results.max_by { |_, rows| rows.count { |r| r[:usable] } }
      return unless best
      cfg, rows = best
      puts "\nBest by usable-rate: #{cfg}"
      puts "  Per-tier usable%:  " + (1..6).map { |t|
        tr = rows.select { |r| r[:tier] == t }
        "T#{t} #{pct(tr) { |r| r[:usable] }}"
      }.join("  ")
      puts "  Misses / errors:"
      rows.reject { |r| r[:usable] }.each do |r|
        why = r[:error] ? "error: #{r[:error]}" : miss_reason(r)
        puts "    - #{r[:id]}: #{why}"
      end
    end

    def miss_reason(r)
      return "parse failed (invalid/absent JSON)" unless r[:parse_ok]
      reasons = []
      reasons << "cal #{r[:cal]} out of band" if r[:cal_ok] == false
      reasons << "macros don't reconcile (coherence)" if r[:coherence_ok] == false
      reasons << "no items returned" if r[:n_items].to_i.zero? && r[:kind] == :normal
      reasons << "hallucinated food on non-food input" if r[:kind] == :adversarial && r[:n_items].to_i.positive?
      reasons.empty? ? "usable=false" : reasons.join("; ")
    end

    def applicable(rows) = rows.select { |r| r[:kind] == :normal }
    def pct(rows)
      xs = rows.reject { |r| r[:error] }
      return "  -  " if xs.empty?
      "#{(100.0 * xs.count { |r| yield(r) } / xs.size).round}%"
    end
    def avg(xs) = xs.empty? ? 0 : xs.sum.to_f / xs.size
    def median(xs) = xs.empty? ? 0 : xs.sort[xs.size / 2]
    def p95(xs) = xs.empty? ? 0 : xs.sort[(xs.size * 0.95).ceil - 1] || xs.max

    def save(results)
      ts = Time.now.strftime("%Y%m%d-%H%M%S")
      path = File.join(__dir__, "results", "#{ts}.json")
      File.write(path, JSON.pretty_generate(model: @opts[:model], samples: @opts[:samples], results: results))
      puts "\nRaw results -> #{path}"
    end
  end
end

opts = { model: "vault-assistant", samples: 1, configs: NutritionEval::DEFAULT_CONFIGS,
         cases: nil, dry_run: false, temp: 0.2, no_cache: false }
OptionParser.new do |o|
  o.on("--model M") { |v| opts[:model] = v }
  o.on("--samples N", Integer) { |v| opts[:samples] = v }
  o.on("--configs LIST") { |v| opts[:configs] = v.split(",").map(&:strip) }
  o.on("--case LIST") { |v| opts[:cases] = v.split(",").map(&:strip) }
  o.on("--tier N", Integer) { |v| opts[:tier] = v }
  o.on("--temp T", Float) { |v| opts[:temp] = v }
  o.on("--no-cache", "Bypass LiteLLM cache — required for independent samples") { opts[:no_cache] = true }
  o.on("--dry-run") { opts[:dry_run] = true }
end.parse!

NutritionEval::Runner.new(opts).run
