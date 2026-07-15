import { render, screen, waitFor, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, expect, test, vi } from 'vitest'
import App from './App'

const show = vi.fn()
const create = vi.fn()
const index = vi.fn()

vi.mock('~/api', () => ({
  apiV1Sessions: {
    show: () => show(),
    create: (opts: unknown) => create(opts),
    destroy: vi.fn(),
  },
  apiV1Users: { index: () => index() },
}))

function renderApp() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <App />
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

beforeEach(() => {
  show.mockReset()
  create.mockReset()
  index.mockReset()
})

test('shows the picker with no session, then the nav after picking a user', async () => {
  show.mockResolvedValue(null)
  index.mockResolvedValue([
    { id: 1, name: 'Aaron' },
    { id: 2, name: 'Bree' },
  ])
  create.mockResolvedValue({ id: 2, name: 'Bree' })

  renderApp()

  await waitFor(() => expect(screen.getByText("Who's training?")).toBeInTheDocument())
  fireEvent.click(await screen.findByRole('button', { name: 'Bree' }))

  await waitFor(() =>
    expect(screen.getByRole('link', { name: 'Library' })).toBeInTheDocument(),
  )
  expect(create).toHaveBeenCalledWith({ data: { user_id: 2 } })
})

test('renders the nav directly when a user is already in session', async () => {
  show.mockResolvedValue({ id: 1, name: 'Aaron' })

  renderApp()

  await waitFor(() =>
    expect(screen.getByRole('button', { name: 'Aaron' })).toBeInTheDocument(),
  )
  expect(screen.getByRole('link', { name: 'Today' })).toBeInTheDocument()
})
