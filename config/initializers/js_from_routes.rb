# Generates typed API + path helpers under frontend/api from routes that opt in
# with `defaults: { export: true }`. Regenerates automatically on page refresh in
# development; the generated files are committed so test/prod don't need the gem.
if Rails.env.development?
  JsFromRoutes.config do |config|
    # Our frontend lives at repo-root frontend/, not app/frontend. The gem scans
    # app/{frontend,packs,javascript,assets} to pick a default output dir and
    # crashes if none exist (hence the inert app/frontend/.keep), so we point it
    # at the real location explicitly.
    config.output_folder = Rails.root.join("frontend/api")
    config.file_suffix = "Api.ts"
  end
end
