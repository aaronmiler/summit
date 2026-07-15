import { render, screen, waitFor } from '@testing-library/react'
import { expect, test, vi } from 'vitest'
import App from './App'

vi.mock('~/api', () => ({
  apiV1Health: { show: vi.fn().mockResolvedValue({ status: 'ok' }) },
}))

test('renders the app title and reports API health', async () => {
  render(<App />)
  expect(screen.getByRole('heading', { name: 'Summit' })).toBeInTheDocument()
  await waitFor(() => expect(screen.getByText('API health: ok')).toBeInTheDocument())
})
