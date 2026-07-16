# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# The two users. Identity is a picker, not auth (see docs/data_model.md). These
# are Context, and the picker needs someone to pick.
%w[Aaron Bree].each { |name| User.find_or_create_by!(name: name) }

# ---------------------------------------------------------------------------
# Library (shared, evergreen). Seeded so there's something to browse and, later,
# train against. Idempotent: keyed on the unique-by-name library objects, so
# re-running never duplicates. This is a *starter* library, freely editable in
# the app — not an authoritative catalog.
# ---------------------------------------------------------------------------

# Exercises — specific movements (modality is load-bearing; it drives the future
# logging widget). muscle_group is a loose grouping for the browser + LLM.
exercises = [
  { name: "Pull-up",              modality: "bodyweight", muscle_group: "Back" },
  { name: "Scapular Pull-up",     modality: "bodyweight", muscle_group: "Back" },
  { name: "Negative Pull-up",     modality: "bodyweight", muscle_group: "Back" },
  { name: "Chin-up",              modality: "bodyweight", muscle_group: "Back" },
  { name: "Barbell Bent-over Row", modality: "barbell",   muscle_group: "Back" },
  { name: "Dumbbell Row",         modality: "dumbbell",   muscle_group: "Back" },
  { name: "Lat Pulldown",         modality: "machine",    muscle_group: "Back" },
  { name: "Face Pull",            modality: "band",       muscle_group: "Shoulders" },
  { name: "Barbell Bicep Curl",   modality: "barbell",    muscle_group: "Arms" },
  { name: "Dumbbell Bicep Curl",  modality: "dumbbell",   muscle_group: "Arms" },
  { name: "Hanging Leg Raise",    modality: "bodyweight", muscle_group: "Core" },
  { name: "Plank",                modality: "bodyweight", muscle_group: "Core" },
  { name: "Cable Crunch",         modality: "machine",    muscle_group: "Core" },
  { name: "Half-crimp Hang",      modality: "hangboard",  muscle_group: "Grip" },
  { name: "Open-hand Hang",       modality: "hangboard",  muscle_group: "Grip" },
  { name: "Zone 2 Run",           modality: "cardio",     muscle_group: "Cardio" },
  { name: "Stationary Bike",      modality: "cardio",     muscle_group: "Cardio" },
  { name: "Bouldering",           modality: "climbing",   muscle_group: "Full body" }
].map { |attrs| Exercise.find_or_create_by!(name: attrs[:name]) { |e| e.assign_attributes(attrs) } }
  .index_by(&:name)

# A real multi-phase progression: the pull-up ladder. Named after the
# destination movement. Phases span *different* exercises.
pullups = Progression.find_or_create_by!(name: "Pull-ups")
[
  { exercise: exercises["Scapular Pull-up"], target: "3 × 8",       graduation_criteria: "3 × 8 clean, full depth" },
  { exercise: exercises["Negative Pull-up"], target: "3 × 5 slow",  graduation_criteria: "3 × 5 with a 5s lower" },
  { exercise: exercises["Pull-up"],          target: "3 × 5",       graduation_criteria: "3 × 5 dead-hang, no kip" }
].each_with_index do |attrs, i|
  phase = pullups.progression_phases.find_or_initialize_by(position: i)
  phase.update!(attrs)
end

# Routines — the drop-in training blocks. Slots reference an exercise XOR a
# progression. Idempotent on (routine, position): re-seeding rewrites the slot
# in place rather than appending.
def slot!(routine, position, target:, exercise: nil, progression: nil, rest_seconds: nil, notes: nil, progression_note: nil)
  re = routine.routine_exercises.find_or_initialize_by(position: position)
  re.update!(
    exercise: exercise, progression: progression, target: target,
    rest_seconds: rest_seconds, notes: notes, progression_note: progression_note
  )
end

pull_core = Routine.find_or_create_by!(name: "Pull/Core") do |r|
  r.notes = "Vertical + horizontal pull, then core. Warm up shoulders first."
  r.tags = %w[pull core strength]
  r.preferred_frequency = "2×/week"
end
slot!(pull_core, 0, progression: pullups, target: "3 × 5", rest_seconds: 120,
      progression_note: "When you graduate a phase, log against the next one.")
slot!(pull_core, 1, exercise: exercises["Barbell Bent-over Row"], target: "4 × 8", rest_seconds: 120, notes: "Flat back, pull to the navel.")
slot!(pull_core, 2, exercise: exercises["Face Pull"], target: "3 × 15", rest_seconds: 60)
slot!(pull_core, 3, exercise: exercises["Barbell Bicep Curl"], target: "3 × 10", rest_seconds: 90)
slot!(pull_core, 4, exercise: exercises["Hanging Leg Raise"], target: "3 × 10", rest_seconds: 60, notes: "Slow, no swing.")
slot!(pull_core, 5, exercise: exercises["Plank"], target: "3 × max time", rest_seconds: 60)

zone2 = Routine.find_or_create_by!(name: "Zone 2 Cardio") do |r|
  r.notes = "Conversational pace — keep HR in zone 2 the whole way."
  r.tags = %w[cardio recovery]
  r.preferred_frequency = "2–3×/week"
end
slot!(zone2, 0, exercise: exercises["Zone 2 Run"], target: "1 × 40 min", notes: "Nose-breathing pace.")
slot!(zone2, 1, exercise: exercises["Stationary Bike"], target: "1 × 30 min", notes: "Alt for high-impact days — protect fingers/joints.")

bouldering = Routine.find_or_create_by!(name: "Bouldering") do |r|
  r.notes = "Session logs as an off-script workout + Health import; hangs are prehab."
  r.tags = %w[climbing grip]
  r.preferred_frequency = "2×/week"
end
slot!(bouldering, 0, exercise: exercises["Half-crimp Hang"], target: "5 × 10s", rest_seconds: 120, notes: "Warm, never to failure.")
slot!(bouldering, 1, exercise: exercises["Open-hand Hang"], target: "5 × 10s", rest_seconds: 120)
slot!(bouldering, 2, exercise: exercises["Bouldering"], target: "session", notes: "Climb by feel; log the session, not grades.")
