FactoryBot.define do
  factory :integration_event do
    kind { "health.push" }
    source { "health_auto_export" }
    direction { "inbound" }
    status { "ok" }
    metadata { {} }
  end
end
