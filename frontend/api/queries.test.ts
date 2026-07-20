import { expect, test } from 'vitest'
import { nextVersionState } from './queries'

// The version-check decision: capture the first real SHA we see, then flag an
// update once the server reports a different one. "dev" and undefined stay quiet.

test('captures the first real SHA without flagging an update', () => {
  expect(nextVersionState(null, 'abc123')).toEqual({
    rendered: 'abc123',
    updateAvailable: false,
  })
})

test('flags an update when the server moves to a new SHA', () => {
  expect(nextVersionState('abc123', 'def456')).toEqual({
    rendered: 'abc123',
    updateAvailable: true,
  })
})

test('stays quiet while the SHA is unchanged', () => {
  expect(nextVersionState('abc123', 'abc123')).toEqual({
    rendered: 'abc123',
    updateAvailable: false,
  })
})

test('never captures or flags on the "dev" placeholder', () => {
  expect(nextVersionState(null, 'dev')).toEqual({ rendered: null, updateAvailable: false })
  expect(nextVersionState('abc123', 'dev')).toEqual({
    rendered: 'abc123',
    updateAvailable: false,
  })
})

test('stays quiet before the first response arrives', () => {
  expect(nextVersionState(null, undefined)).toEqual({ rendered: null, updateAvailable: false })
})
