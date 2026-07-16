# A durable record of one interaction with an external system — an inbound
# Health Auto Export push today, an outbound LLM call (workout building,
# nutrition parsing) later. The seam is `record!`: any integration logs itself
# with a single call, and monitoring is a query over `kind` + `status`.
#
# `kind` is a dotted namespace ("health.push", "llm.workout_build") so new event
# types need no migration; `metadata` (jsonb) holds whatever that kind cares
# about (push counts + per-item outcomes; model + token usage; …).
class IntegrationEvent < ApplicationRecord
  belongs_to :user, optional: true # inbound/unauth events have no user

  OK = "ok".freeze

  validates :kind, :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :of_kind, ->(kind) { where(kind: kind) }
  scope :succeeded, -> { where(status: OK) }
  scope :failed, -> { where.not(status: OK) }

  # The one-call recorder every integration uses. Never raises — audit logging
  # must not take down the thing it's observing, so a failure to log is swallowed
  # (and reported to the Rails log) rather than propagated.
  def self.record!(kind:, status: OK, user: nil, source: nil, direction: nil,
                   summary: nil, metadata: {}, duration_ms: nil, error: nil, remote_ip: nil)
    create!(
      kind: kind, status: status, user: user, source: source, direction: direction,
      summary: summary, metadata: metadata || {}, duration_ms: duration_ms,
      error: error, remote_ip: remote_ip
    )
  rescue => e
    Rails.logger.error("IntegrationEvent.record! failed: #{e.class}: #{e.message}")
    nil
  end

  def succeeded?
    status == OK
  end
end
