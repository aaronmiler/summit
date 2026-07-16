import { render, screen, fireEvent, act } from '@testing-library/react'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'
import HoldTimer from './HoldTimer'

// Count-in (5s) + hold, timestamp-based, so faking Date + timers drives it.
beforeEach(() => vi.useFakeTimers())
afterEach(() => vi.useRealTimers())

function advance(ms: number) {
  act(() => vi.advanceTimersByTime(ms))
}

function startHold() {
  fireEvent.click(screen.getByRole('button', { name: /start hold/i }))
}

// Nudge the encoder by N seconds via its keyboard path (jsdom doesn't carry
// clientX on pointer events, so the drag itself is verified in-browser).
function nudge(seconds: number) {
  const enc = screen.getByRole('spinbutton')
  const key = seconds < 0 ? 'ArrowDown' : 'ArrowUp'
  for (let i = 0; i < Math.abs(seconds); i++) fireEvent.keyDown(enc, { key })
}

test('logs held time minus the shave when stopped short of the target', () => {
  const onLog = vi.fn()
  render(<HoldTimer seedTarget={30} pending={false} onLog={onLog} />)

  startHold()
  advance(5000 + 20000) // 5s count-in + 20s held
  fireEvent.click(screen.getByRole('button', { name: 'Stop' }))
  fireEvent.click(screen.getByRole('button', { name: 'Log set' }))

  expect(onLog).toHaveBeenCalledWith(17) // round(20) - 3 shave
})

test('keeps counting into overtime past the target', () => {
  const onLog = vi.fn()
  render(<HoldTimer seedTarget={30} pending={false} onLog={onLog} />)

  startHold()
  advance(5000 + 35000) // 5s count-in + 35s held (5s over a 30s target)
  fireEvent.click(screen.getByRole('button', { name: 'Stop' }))
  fireEvent.click(screen.getByRole('button', { name: 'Log set' }))

  expect(onLog).toHaveBeenCalledWith(32) // round(35) - 3 shave
})

test('the encoder can edit the held result before logging', () => {
  const onLog = vi.fn()
  render(<HoldTimer seedTarget={30} pending={false} onLog={onLog} />)

  startHold()
  advance(5000 + 20000)
  fireEvent.click(screen.getByRole('button', { name: 'Stop' }))
  // result is 17; nudge +2s to 19, then log.
  nudge(2)
  fireEvent.click(screen.getByRole('button', { name: 'Log set' }))

  expect(onLog).toHaveBeenCalledWith(19)
})

test('a stop during the count-in aborts without a result', () => {
  const onLog = vi.fn()
  render(<HoldTimer seedTarget={30} pending={false} onLog={onLog} />)

  startHold()
  advance(3000) // still in the 5s count-in
  fireEvent.click(screen.getByRole('button', { name: 'Cancel' }))

  expect(screen.queryByRole('button', { name: 'Log set' })).toBeNull()
  expect(screen.getByRole('button', { name: /start hold/i })).toBeInTheDocument()
  expect(onLog).not.toHaveBeenCalled()
})

test('Start is disabled once the target is dragged to zero', () => {
  render(<HoldTimer seedTarget={30} pending={false} onLog={vi.fn()} />)

  nudge(-30) // -30s from a 30s target, clamped at 0
  expect(screen.getByRole('button', { name: /start hold/i })).toBeDisabled()
})
