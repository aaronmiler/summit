import { useCurrentWorkout } from '~/api/queries'
import StartWorkout from './StartWorkout'
import WorkoutSession from './WorkoutSession'

// The Today tab. One active workout at a time (derived: most recent unfinished).
// If one's live, log into it; otherwise offer to start one.
export default function Today() {
  const { data: workout, isLoading } = useCurrentWorkout()

  if (isLoading) return <p className="text-muted">Loading…</p>
  return workout ? <WorkoutSession workout={workout} /> : <StartWorkout />
}
