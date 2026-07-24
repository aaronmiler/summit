import { expect, test } from 'vitest'
import { formatPace } from './format'

test('formatPace: m:ss per unit, seconds zero-padded', () => {
  expect(formatPace(1.95, 1980, 'mi')).toBe('16:55 /mi')
  expect(formatPace(2, 500, 'km')).toBe('4:10 /km')
})

test('formatPace: defaults units to mi', () => {
  expect(formatPace(1, 600, null)).toBe('10:00 /mi')
})

test('formatPace: null when distance/duration missing or zero', () => {
  expect(formatPace(null, 1980, 'mi')).toBeNull()
  expect(formatPace(1.95, null, 'mi')).toBeNull()
  expect(formatPace(0, 1980, 'mi')).toBeNull()
})
