import type { Modality } from '~/types'

// modality is load-bearing: it picks the logging widget and which fields a set
// has. The 8 modalities collapse into 4 field layouts.
export type Widget = 'weighted' | 'reps' | 'timed' | 'duration'

export function widgetFor(modality: Modality): Widget {
  switch (modality) {
    case 'barbell':
    case 'dumbbell':
    case 'kettlebell':
    case 'machine':
      return 'weighted' // reps + weight (+ rpe)
    case 'bodyweight':
    case 'band':
      return 'reps' // reps + optional added/assist weight
    case 'hangboard':
      return 'timed' // a hold, in seconds
    case 'cardio':
    case 'climbing':
      return 'duration' // minutes + a note
  }
}
