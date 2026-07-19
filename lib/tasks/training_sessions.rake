namespace :training_sessions do
  # One-off (idempotent) backfill: replay `absorb` over every existing workout in
  # time order so history groups retroactively. Safe to re-run — absorb re-picks
  # the best session and drops any it empties. Run after deploying the migration.
  desc "Assign existing workouts to training sessions (idempotent)"
  task backfill: :environment do
    workouts = Workout.order(:started_at).to_a
    workouts.each { |w| TrainingSession.absorb(w) }
    puts "  done — #{TrainingSession.count} sessions across #{workouts.size} workouts"
  end
end
