import { useSyncExternalStore } from 'react'

// Transient confirmations for async work (LLM estimates, the background parse,
// item edits) + a generic error surface for any failed mutation. A tiny external
// store so `toast()` is callable from anywhere — call sites and the QueryClient's
// MutationCache alike — without threading a context through. Styles: Cascadia's
// `.toast-stack` / `.toast` (variant adds `.toast--error`).

export type ToastVariant = 'success' | 'error'
type Toast = { id: number; message: string; variant: ToastVariant }

const DURATION = 3500

let toasts: Toast[] = []
let nextId = 1
const listeners = new Set<() => void>()

function emit() {
  for (const l of listeners) l()
}

export function toast(message: string, variant: ToastVariant = 'success') {
  const id = nextId++
  toasts = [...toasts, { id, message, variant }]
  emit()
  setTimeout(() => dismiss(id), DURATION)
  return id
}

export function dismiss(id: number) {
  toasts = toasts.filter((t) => t.id !== id)
  emit()
}

function subscribe(cb: () => void) {
  listeners.add(cb)
  return () => {
    listeners.delete(cb)
  }
}

function getSnapshot() {
  return toasts
}

// Mount once, above the routed screens. Fixed-positioned via `.toast-stack`.
export function Toaster() {
  const items = useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
  if (items.length === 0) return null

  return (
    <div className="toast-stack" role="status" aria-live="polite">
      {items.map((t) => (
        <div key={t.id} className={`toast ${t.variant === 'error' ? 'toast--error' : ''}`}>
          <span>{t.message}</span>
          <button className="toast-action" onClick={() => dismiss(t.id)} aria-label="Dismiss">
            ✕
          </button>
        </div>
      ))}
    </div>
  )
}
