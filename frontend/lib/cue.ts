import { useCallback, useMemo, useRef } from 'react'

// Audio + haptic cues, shared by the hangboard hold timer and the rest timer.
// You run these eyes-off (hands on the bar, or phone in a pocket between sets),
// so the beeps are the point. All guarded: silent where the APIs are missing
// (e.g. tests). `arm()` must be called from a user gesture (a tap) to unlock the
// AudioContext — after that, later beeps fire without a gesture.
export type Cue = {
  arm: () => void
  tick: () => void
  go: () => void
  target: () => void
  done: () => void
}

export function useCue(): Cue {
  const ctx = useRef<AudioContext | null>(null)

  const arm = useCallback(() => {
    try {
      const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
      if (Ctor && !ctx.current) ctx.current = new Ctor()
      ctx.current?.resume?.()
    } catch {
      /* no audio available */
    }
  }, [])

  const beep = useCallback((freq: number, ms: number, vibe: number | number[]) => {
    const c = ctx.current
    if (c) {
      try {
        const osc = c.createOscillator()
        const gain = c.createGain()
        osc.frequency.value = freq
        osc.connect(gain)
        gain.connect(c.destination)
        gain.gain.setValueAtTime(0.15, c.currentTime)
        gain.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + ms / 1000)
        osc.start()
        osc.stop(c.currentTime + ms / 1000)
      } catch {
        /* ignore */
      }
    }
    try {
      if ('vibrate' in navigator) navigator.vibrate(vibe)
    } catch {
      /* ignore */
    }
  }, [])

  const tick = useCallback(() => beep(660, 90, 30), [beep])
  const go = useCallback(() => beep(880, 220, 80), [beep])
  const target = useCallback(() => beep(990, 260, [60, 40, 140]), [beep])
  // Rest is up: a warm, lower double-buzz — clearly not the sharp hangboard cue.
  const done = useCallback(() => beep(560, 320, [120, 80, 120]), [beep])
  return useMemo(() => ({ arm, tick, go, target, done }), [arm, tick, go, target, done])
}
