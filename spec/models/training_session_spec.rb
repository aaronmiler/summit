require "rails_helper"

# Pins the session-grouping rule: workouts cluster into one TrainingSession by
# time proximity (single-linkage, 1h gap), assigned via `absorb` at the write
# boundary. The load-bearing cases are the two real days that motivated it —
# Friday's warmup + lift + watch strength collapse to one; Thursday's morning
# climb and evening golf stay two.
RSpec.describe TrainingSession, type: :model do
  let(:user) { create(:user) }
  let(:day) { Time.zone.local(2026, 7, 17, 6, 0, 0) }

  # A finished workout in [start, finish], absorbed into a session like the app's
  # write boundaries do.
  def logged(start, finish = start, **attrs)
    workout = create(:workout, user: user, started_at: start, finished_at: finish, **attrs)
    TrainingSession.absorb(workout)
    workout.reload
  end

  it "groups two workouts within the gap into one session" do
    a = logged(day, day + 10.minutes)
    b = logged(day + 40.minutes, day + 55.minutes) # 30-min gap < 1h

    expect(b.training_session_id).to eq(a.training_session_id)
    expect(TrainingSession.count).to eq(1)
  end

  it "splits workouts more than the gap apart into separate sessions" do
    a = logged(day, day + 10.minutes)
    b = logged(day + 3.hours, day + 3.hours + 10.minutes) # well past 1h

    expect(b.training_session_id).not_to eq(a.training_session_id)
    expect(TrainingSession.count).to eq(2)
  end

  it "groups overlapping workouts (the routine + its watch import)" do
    routine = logged(day, day + 32.minutes)
    watch = logged(day + 1.minute, day + 33.minutes) # overlaps entirely

    expect(watch.training_session_id).to eq(routine.training_session_id)
  end

  it "chains a broken-up day: each hop under the gap, ends far apart (single-linkage)" do
    a = logged(day, day + 5.minutes)
    b = logged(day + 50.minutes, day + 55.minutes)   # 45-min gap from a
    c = logged(day + 100.minutes, day + 105.minutes) # 45-min gap from b, 95 from a

    expect([ b.training_session_id, c.training_session_id ]).to all(eq(a.training_session_id))
    expect(TrainingSession.count).to eq(1)
  end

  it "collapses Friday: warmup + routine + watch strength -> one session" do
    warmup = logged(day, day + 12.minutes)                    # 06:00 cardio
    push_legs = logged(day + 15.minutes, day + 47.minutes)    # 06:15 routine
    strength = logged(day + 16.minutes, day + 47.minutes)     # 06:16 watch FST

    ids = [ warmup, push_legs, strength ].map(&:training_session_id)
    expect(ids.uniq.size).to eq(1)
  end

  it "keeps Thursday apart: morning climb, evening golf -> two sessions" do
    climb = logged(day, day + 49.minutes)                     # 06:00
    golf = logged(day + 10.hours, day + 11.hours + 13.minutes) # 16:00

    expect(golf.training_session_id).not_to eq(climb.training_session_id)
    expect(TrainingSession.count).to eq(2)
  end

  it "is idempotent: re-absorbing leaves the grouping (and session count) stable" do
    a = logged(day, day + 10.minutes)
    b = logged(day + 40.minutes, day + 55.minutes)

    expect { [ a, b ].each { |w| TrainingSession.absorb(w) } }
      .not_to change(TrainingSession, :count)
    expect(a.reload.training_session_id).to eq(b.reload.training_session_id)
  end
end
