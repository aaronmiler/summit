import { useCallback, useEffect, useMemo, useRef } from 'react'

// Screen wake lock, shared by the hold timer and the rest timer — keeps the
// screen from dimming/locking while a timer is live (a locked screen suspends
// both the countdown and its beep). Feature-detected; a no-op where unsupported.
// Browsers drop the lock when the tab is hidden, so re-acquire on return-to-
// foreground while we're still active.
export function useWakeLock() {
  const sentinel = useRef<WakeLockSentinel | null>(null)
  const active = useRef(false)

  const acquire = useCallback(async () => {
    active.current = true
    try {
      if ('wakeLock' in navigator) sentinel.current = await navigator.wakeLock.request('screen')
    } catch {
      /* denied or unsupported — the timer still works, the screen just may dim */
    }
  }, [])

  const release = useCallback(() => {
    active.current = false
    sentinel.current?.release().catch(() => {})
    sentinel.current = null
  }, [])

  useEffect(() => {
    const onVisible = () => {
      if (active.current && !sentinel.current && document.visibilityState === 'visible') acquire()
    }
    document.addEventListener('visibilitychange', onVisible)
    return () => document.removeEventListener('visibilitychange', onVisible)
  }, [acquire])

  return useMemo(() => ({ acquire, release }), [acquire, release])
}
