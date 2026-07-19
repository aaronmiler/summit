# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_19_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "exercises", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "modality", null: false
    t.string "muscle_group"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_exercises_on_name", unique: true
  end

  create_table "food_entries", force: :cascade do |t|
    t.integer "calories"
    t.decimal "carbs", precision: 6, scale: 2
    t.decimal "confidence", precision: 3, scale: 2
    t.datetime "created_at", null: false
    t.decimal "fat", precision: 6, scale: 2
    t.bigint "meal_id", null: false
    t.string "name"
    t.text "parse_notes"
    t.decimal "protein", precision: 6, scale: 2
    t.datetime "updated_at", null: false
    t.index ["meal_id"], name: "index_food_entries_on_meal_id"
  end

  create_table "health_imports", force: :cascade do |t|
    t.string "activity_type"
    t.integer "avg_hr"
    t.integer "calories"
    t.decimal "confidence", precision: 3, scale: 2
    t.datetime "created_at", null: false
    t.decimal "distance", precision: 8, scale: 2
    t.integer "duration_seconds"
    t.string "external_id"
    t.text "parse_notes"
    t.jsonb "raw"
    t.datetime "recorded_at"
    t.string "source"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workout_id"
    t.index ["user_id", "external_id"], name: "index_health_imports_on_user_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["user_id"], name: "index_health_imports_on_user_id"
    t.index ["workout_id"], name: "index_health_imports_on_workout_id"
  end

  create_table "integration_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "direction"
    t.integer "duration_ms"
    t.text "error"
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "remote_ip"
    t.string "source"
    t.string "status", null: false
    t.string "summary"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["kind", "created_at"], name: "index_integration_events_on_kind_and_created_at"
    t.index ["user_id"], name: "index_integration_events_on_user_id"
  end

  create_table "meals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "eaten_at"
    t.text "notes"
    t.text "raw_text", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_meals_on_user_id"
  end

  create_table "progression_phases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "exercise_id", null: false
    t.text "graduation_criteria"
    t.integer "position", null: false
    t.bigint "progression_id", null: false
    t.string "target"
    t.datetime "updated_at", null: false
    t.index ["exercise_id"], name: "index_progression_phases_on_exercise_id"
    t.index ["progression_id", "position"], name: "index_progression_phases_on_progression_id_and_position", unique: true
    t.index ["progression_id"], name: "index_progression_phases_on_progression_id"
  end

  create_table "progressions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "routine_exercises", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "exercise_id"
    t.text "notes"
    t.integer "position", null: false
    t.bigint "progression_id"
    t.text "progression_note"
    t.integer "rest_seconds"
    t.bigint "routine_id", null: false
    t.string "target"
    t.datetime "updated_at", null: false
    t.index ["exercise_id"], name: "index_routine_exercises_on_exercise_id"
    t.index ["progression_id"], name: "index_routine_exercises_on_progression_id"
    t.index ["routine_id", "position"], name: "index_routine_exercises_on_routine_id_and_position"
    t.index ["routine_id"], name: "index_routine_exercises_on_routine_id"
    t.check_constraint "num_nonnulls(exercise_id, progression_id) = 1", name: "routine_exercises_exactly_one_target"
  end

  create_table "routines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.string "preferred_frequency"
    t.string "tags", default: [], null: false, array: true
    t.datetime "updated_at", null: false
  end

  create_table "set_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.bigint "exercise_id", null: false
    t.text "notes"
    t.bigint "progression_phase_id"
    t.integer "reps"
    t.bigint "routine_exercise_id"
    t.decimal "rpe", precision: 3, scale: 1
    t.integer "set_number", null: false
    t.datetime "updated_at", null: false
    t.decimal "weight", precision: 6, scale: 2
    t.bigint "workout_id", null: false
    t.index ["exercise_id"], name: "index_set_logs_on_exercise_id"
    t.index ["progression_phase_id"], name: "index_set_logs_on_progression_phase_id"
    t.index ["routine_exercise_id"], name: "index_set_logs_on_routine_exercise_id"
    t.index ["workout_id"], name: "index_set_logs_on_workout_id"
  end

  create_table "training_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_training_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "api_token", null: false
    t.datetime "created_at", null: false
    t.text "equipment"
    t.text "goals"
    t.string "name", null: false
    t.text "notes"
    t.text "preferences"
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
  end

  create_table "workouts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.text "notes"
    t.bigint "routine_id"
    t.datetime "started_at", null: false
    t.bigint "training_session_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["routine_id"], name: "index_workouts_on_routine_id"
    t.index ["training_session_id"], name: "index_workouts_on_training_session_id"
    t.index ["user_id", "started_at"], name: "index_workouts_on_user_id_and_started_at"
    t.index ["user_id"], name: "index_workouts_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "food_entries", "meals"
  add_foreign_key "health_imports", "users"
  add_foreign_key "health_imports", "workouts"
  add_foreign_key "integration_events", "users"
  add_foreign_key "meals", "users"
  add_foreign_key "progression_phases", "exercises"
  add_foreign_key "progression_phases", "progressions"
  add_foreign_key "routine_exercises", "exercises"
  add_foreign_key "routine_exercises", "progressions"
  add_foreign_key "routine_exercises", "routines"
  add_foreign_key "set_logs", "exercises"
  add_foreign_key "set_logs", "progression_phases"
  add_foreign_key "set_logs", "routine_exercises", on_delete: :nullify
  add_foreign_key "set_logs", "workouts"
  add_foreign_key "training_sessions", "users"
  add_foreign_key "workouts", "routines"
  add_foreign_key "workouts", "training_sessions", on_delete: :nullify
  add_foreign_key "workouts", "users"
end
