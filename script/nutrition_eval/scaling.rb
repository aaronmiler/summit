#!/usr/bin/env ruby
# Scaling-sanity check: does an explicitly stated quantity actually DRIVE the
# estimate, or is the portion decorative? For each food we ask at a base quantity
# and a multiple, and check total calories scale roughly proportionally. A model
# that ignores quantity (flattening) shows a ratio near 1; a good one tracks the
# multiplier. Run: ruby script/nutrition_eval/scaling.rb
require_relative "client"
require_relative "strategies"

# [food, base phrase, scaled phrase, multiplier]
TRIALS = [
  [ "pizza",          "1 slice of cheese pizza",   "3 slices of cheese pizza",   3 ],
  [ "white rice",     "1 cup of white rice",       "2 cups of white rice",       2 ],
  [ "chicken breast", "4 oz grilled chicken breast", "8 oz grilled chicken breast", 2 ],
  [ "almonds",        "1 oz of almonds",           "3 oz of almonds",            3 ],
  [ "banana",         "1 banana",                  "2 bananas",                  2 ]
].freeze

client = NutritionEval::Client.new(model: ENV.fetch("EVAL_MODEL", "vault-assistant"), no_cache: true)
per_unit = ENV["PER_UNIT"] == "1"
strat = per_unit ?
  NutritionEval::SingleShot.new(client, style: :checklist_perunit, json_mode: nil, per_unit: true) :
  NutritionEval::SingleShot.new(client, style: :checklist, json_mode: nil)
puts "mode: #{per_unit ? 'per-unit (code multiplies by amount)' : 'single-shot totals'}"

cals = ->(text) { strat.run(text)[:items].sum { |i| i["calories"].to_f } }

puts format("%-16s %8s %8s %6s %6s  %s", "food", "base", "scaled", "mult", "ratio", "verdict")
puts "-" * 62
oks = 0
TRIALS.each do |food, base_p, scaled_p, mult|
  b = cals.call(base_p)
  s = cals.call(scaled_p)
  ratio = b.zero? ? 0 : (s / b)
  # "tracks" if the observed ratio is within ~35% of the intended multiplier
  ok = b.positive? && (ratio - mult).abs <= mult * 0.35
  oks += 1 if ok
  puts format("%-16s %8d %8d %5dx %5.1fx  %s", food, b.round, s.round, mult, ratio, ok ? "ok" : "IGNORES QTY")
end
puts "-" * 62
puts "Quantity drives the estimate in #{oks}/#{TRIALS.size} trials"
