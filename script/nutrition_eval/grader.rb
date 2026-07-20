# Strategy-agnostic grader. Scores a strategy's normalized result against a case's
# reference bands. "usable" is the headline bar (the napkin definition of good
# enough); the per-dimension flags explain *why* a case passed or failed.
module NutritionEval
  module Grader
    module_function

    def score(kase, result)
      e = kase[:expect]
      items = result[:items] || []
      n = items.size
      cal = sum(items, "calories")
      pro = sum(items, "protein")
      carb = sum(items, "carbs")
      fat = sum(items, "fat")
      confs = items.map { |i| i["confidence"] }.compact
      avg_conf = confs.empty? ? nil : (confs.sum / confs.size)

      base = {
        parse_ok: result[:parse_ok], n_items: n, cal: cal.round,
        protein: pro.round(1), carbs: carb.round(1), fat: fat.round(1),
        avg_conf: avg_conf&.round(2), calls: result[:calls], latency_ms: result[:latency_ms]
      }

      # Adversarial: the only right answer is no food.
      if e[:adversarial]
        handled = result[:parse_ok] && n.zero?
        return base.merge(kind: :adversarial, usable: handled, handled: handled)
      end

      # Soft-vague: empty OR a low-confidence guess is acceptable.
      if e[:soft]
        handled = result[:parse_ok] && (n.zero? || (avg_conf && avg_conf <= 0.6))
        return base.merge(kind: :soft, usable: handled, handled: handled,
                          items_ok: e[:items].include?(n))
      end

      # Portion legibility: every item carries a usable, rescalable portion.
      portion_ok = n.positive? && items.all? { |i| i["amount"].to_f.positive? && !i["unit"].to_s.strip.empty? }
      items_ok = e[:items].include?(n)
      cal_ok = in_band?(e[:calories], cal)
      p_ok = in_band?(e[:protein], pro)
      c_ok = in_band?(e[:carbs], carb)
      f_ok = in_band?(e[:fat], fat)
      coherence_ok = coherent?(cal, pro, carb, fat)
      conf_ok = conf_dir?(e[:conf], avg_conf)
      usable = result[:parse_ok] && n.positive? && cal_ok && coherence_ok

      base.merge(
        kind: :normal, usable: usable,
        items_ok: items_ok, cal_ok: cal_ok, portion_ok: portion_ok,
        protein_ok: p_ok, carbs_ok: c_ok, fat_ok: f_ok,
        macro_ok: (p_ok && c_ok && f_ok), coherence_ok: coherence_ok, conf_ok: conf_ok
      )
    end

    def sum(items, key) = items.sum { |i| i[key].to_f }

    def in_band?(range, v) = range && range.include?(v)

    # Do the reported macros reconcile with reported calories (4/4/9 rule)?
    # Cheap nonsense detector, independent of the reference bands.
    def coherent?(cal, pro, carb, fat)
      implied = 4 * pro + 4 * carb + 9 * fat
      return true if (implied - cal).abs <= 25 # absolute floor: near-zero items (black coffee) are noise
      return false if cal <= 0
      (implied - cal).abs / cal <= 0.30
    end

    def conf_dir?(expected, avg)
      return true if expected.nil? || avg.nil?
      case expected
      when :high then avg >= 0.6
      when :med  then avg.between?(0.35, 0.9)
      when :low  then avg <= 0.6
      else true
      end
    end
  end
end
