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

  // Schedule one oscillator note `when` seconds from now. Splitting this out of
  // `beep` lets `done` play a timed sequence of notes on one AudioContext.
  const tone = useCallback((freq: number, ms: number, when: number, peak = 0.15) => {
    const c = ctx.current
    if (!c) return
    try {
      const osc = c.createOscillator()
      const gain = c.createGain()
      osc.frequency.value = freq
      osc.connect(gain)
      gain.connect(c.destination)
      const t0 = c.currentTime + when
      gain.gain.setValueAtTime(peak, t0)
      gain.gain.exponentialRampToValueAtTime(0.0001, t0 + ms / 1000)
      osc.start(t0)
      osc.stop(t0 + ms / 1000)
    } catch {
      /* ignore */
    }
  }, [])

  const vibrate = useCallback((vibe: number | number[]) => {
    try {
      if ('vibrate' in navigator) navigator.vibrate(vibe)
    } catch {
      /* ignore */
    }
  }, [])

  const beep = useCallback((freq: number, ms: number, vibe: number | number[]) => {
    tone(freq, ms, 0)
    vibrate(vibe)
  }, [tone, vibrate])

  const tick = useCallback(() => beep(660, 90, 30), [beep])
  const go = useCallback(() => beep(880, 220, 80), [beep])
  const target = useCallback(() => beep(990, 260, [60, 40, 140]), [beep])
  // Rest is up: a rising arpeggio capped by an octave leap, not a single tone —
  // several notes across the spectrum are far harder for music to mask when you
  // have headphones in. Longer, louder, and unmistakably "get up".
  const done = useCallback(() => {
    const notes: [number, number][] = [
      [587, 150], // D5
      [740, 150], // F#5
      [880, 150], // A5
      [1175, 320], // D6 — accent
    ]
    let when = 0
    for (const [freq, ms] of notes) {
      tone(freq, ms, when, freq === 1175 ? 0.2 : 0.15)
      when += (ms + 45) / 1000 // small gap so notes stay distinct
    }
    vibrate([120, 80, 120, 80, 220])
  }, [tone, vibrate])
  return useMemo(() => ({ arm, tick, go, target, done }), [arm, tick, go, target, done])
}
