import '@fontsource-variable/inter/index.css'
import '~/styles/cascadia.css'
import '~/styles/app.css'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { QueryClient, QueryClientProvider, MutationCache } from '@tanstack/react-query'
import { BrowserRouter } from 'react-router-dom'
import App from '../components/App'
import { Toaster, toast } from '../components/Toast'

// js-from-routes throws an Error carrying the (camelCased) response body; Rails
// renders `{ error: … }` (LLM/gateway failures) or `{ errors: [...] }` (validation).
function apiErrorMessage(error: unknown): string {
  const e = error as { body?: { error?: string; errors?: string[] }; message?: string }
  return e?.body?.error ?? e?.body?.errors?.[0] ?? e?.message ?? 'Something went wrong'
}

// Every failed mutation surfaces a toast by default; call sites still add their
// own success toasts (and may handle specific errors on top of this).
const queryClient = new QueryClient({
  mutationCache: new MutationCache({
    onError: (error) => toast(apiErrorMessage(error), 'error'),
  }),
})

const el = document.getElementById('app')
if (el) {
  createRoot(el).render(
    <StrictMode>
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <App />
          <Toaster />
        </BrowserRouter>
      </QueryClientProvider>
    </StrictMode>,
  )
}
