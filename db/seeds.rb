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
# Library (shared, evergreen). Seeded from the current 4-week strength program —
# the two *strength* days (Mon Pull/Core, Fri Push/Legs). Cardio (Wed) and
# bouldering (Tu/Th) arrive via the Apple Health import, not as logged routines.
# Idempotent: keyed on unique-by-name library objects, so re-running updates in
# place. Freely editable in the app.
# ---------------------------------------------------------------------------

# Exercises — specific movements (modality drives the logging widget).
exercises = [
  # Pull-up ladder (the progression phases)
  { name: "Scapular Pull-up",           modality: "bodyweight", muscle_group: "Back" },
  { name: "Negative Pull-up",           modality: "bodyweight", muscle_group: "Back" },
  { name: "Pull-up",                    modality: "bodyweight", muscle_group: "Back" },
  # Monday — Pull/Core
  { name: "One-arm Dumbbell Row",       modality: "dumbbell",   muscle_group: "Back" },
  { name: "TRX Inverted Row",           modality: "bodyweight", muscle_group: "Back" },
  { name: "Hanging Leg Raise",          modality: "bodyweight", muscle_group: "Core" },
  { name: "Pallof Press",               modality: "band",       muscle_group: "Core" },
  { name: "Dead Hang",                  modality: "hangboard",  muscle_group: "Grip" },
  # Friday — Push/Legs/Antagonist
  { name: "Dumbbell Bench Press",       modality: "dumbbell",   muscle_group: "Chest" },
  { name: "Dumbbell Goblet Squat",      modality: "dumbbell",   muscle_group: "Legs" },
  { name: "Dumbbell Overhead Press",    modality: "dumbbell",   muscle_group: "Shoulders" },
  { name: "Dumbbell Romanian Deadlift", modality: "dumbbell",   muscle_group: "Hamstrings" },
  { name: "Push-up",                    modality: "bodyweight", muscle_group: "Chest" },
  { name: "Face Pull",                  modality: "band",       muscle_group: "Shoulders" }
].map { |attrs| Exercise.find_or_create_by!(name: attrs[:name]) { |e| e.assign_attributes(attrs) } }
  .index_by(&:name)

# The pull-up ladder: pick your current phase, graduate when the criteria are met.
# Current phase is derived from your most recent logged set against it.
pullups = Progression.find_or_create_by!(name: "Pull-ups")
[
  { exercise: exercises["Scapular Pull-up"], target: "4 × 8–10",  graduation_criteria: "4 × 10 clean + 45 sec dead hang" },
  { exercise: exercises["Negative Pull-up"], target: "4 × 3–5",   graduation_criteria: "5-sec negatives clean 4 × 5 (or 4 × 8 with lightest band)" },
  { exercise: exercises["Pull-up"],          target: "5–8 × 1–3", graduation_criteria: "5 clean reps unbroken → then 4 × AMRAP-1, add weight at 8+" }
].each_with_index do |attrs, i|
  phase = pullups.progression_phases.find_or_initialize_by(position: i)
  phase.update!(attrs)
end

# Routines — the drop-in training blocks. Slots reference an exercise XOR a
# progression. Idempotent on (routine, position): re-seeding rewrites the slot.
def slot!(routine, position, target:, exercise: nil, progression: nil, rest_seconds: nil, notes: nil, progression_note: nil)
  re = routine.routine_exercises.find_or_initialize_by(position: position)
  re.update!(
    exercise: exercise, progression: progression, target: target,
    rest_seconds: rest_seconds, notes: notes, progression_note: progression_note
  )
end

# Monday — Pull/Core
pull_core = Routine.find_or_create_by!(name: "Pull/Core")
pull_core.update!(
  notes: "Mondays. Straight sets. Warm up first.",
  tags: %w[pull core strength],
  preferred_frequency: "Mondays"
)
slot!(pull_core, 0, progression: pullups, target: "4 sets · current phase", rest_seconds: 120,
      progression_note: "Pick your current phase; graduate when its criteria are met. Add a dead-hang set at the end.")
slot!(pull_core, 1, exercise: exercises["One-arm Dumbbell Row"], target: "4 × 8/side", rest_seconds: 90,
      notes: "Hand + knee on bench, flat back, pull to hip (not armpit), elbow tight, squeeze lat, full stretch.",
      progression_note: "When 25s easy, add tempo (3s down, 1s pause at bottom).")
slot!(pull_core, 2, exercise: exercises["TRX Inverted Row"], target: "3 × 10", rest_seconds: 60,
      notes: "Body plank-straight, pull chest to handles, elbows ~45°, squeeze scaps.",
      progression_note: "Feet flat → elevated on bench → pause at top.")
slot!(pull_core, 3, exercise: exercises["Hanging Leg Raise"], target: "3 × 8–12", rest_seconds: 60,
      notes: "No swing; initiate from the lower abs (posterior tilt first), control down.",
      progression_note: "Tuck knees → straight leg to 90° → toes to bar → windshield wipers.")
slot!(pull_core, 4, exercise: exercises["Pallof Press"], target: "3 × 10/side", rest_seconds: 45,
      notes: "Band at chest height, press straight out, resist the rotation, hold 2s. Hips square.")
slot!(pull_core, 5, exercise: exercises["Dead Hang"], target: "2 × max time", rest_seconds: 120,
      notes: "Full grip, shoulders active. Build to 60s. Stop ~5s before failure to save grip for climbing.")

# Friday — Push/Legs/Antagonist
push_legs = Routine.find_or_create_by!(name: "Push/Legs")
push_legs.update!(
  notes: "Fridays. Push / legs / antagonist. Warm up first.",
  tags: %w[push legs strength],
  preferred_frequency: "Fridays"
)
slot!(push_legs, 0, exercise: exercises["Dumbbell Bench Press"], target: "4 × 8", rest_seconds: 90,
      notes: "DBs from chest, elbows ~45° (not flared), press up and slightly together, control to chest-touch.",
      progression_note: "When 25s easy → single-arm floor press or tempo (3s down).")
slot!(push_legs, 1, exercise: exercises["Dumbbell Goblet Squat"], target: "4 × 10", rest_seconds: 90,
      notes: "DB vertical at chest, feet shoulder-width, sit back + down below parallel, knees track toes, drive heels.",
      progression_note: "Tempo (3s down, 2s pause) → Bulgarian split squats.")
slot!(push_legs, 2, exercise: exercises["Dumbbell Overhead Press"], target: "3 × 8", rest_seconds: 90,
      notes: "Standing, DBs at shoulders, press straight up, don't over-arch, lock out with biceps by the ears.",
      progression_note: "Tempo, then single-arm (adds anti-lateral core work).")
slot!(push_legs, 3, exercise: exercises["Dumbbell Romanian Deadlift"], target: "3 × 10", rest_seconds: 90,
      notes: "Soft knees, hinge at the hips (push butt back), DBs slide to just below the knees, flat back, squeeze glutes up.",
      progression_note: "Tempo (3s down) — much harder without more weight.")
slot!(push_legs, 4, exercise: exercises["Push-up"], target: "3 × AMRAP", rest_seconds: 60,
      notes: "Hands slightly wider than shoulders, plank-straight, elbows ~45°, chest to floor, full lockout.",
      progression_note: "Feet on bench (decline) → deficit (hands on DBs) → archer.")
slot!(push_legs, 5, exercise: exercises["Face Pull"], target: "3 × 15", rest_seconds: 45,
      notes: "Band at forehead height, pull to forehead, elbows high, externally rotate at the end (thumbs back). Non-negotiable for climber shoulders.")
