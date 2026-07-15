import { useEffect, useState } from 'react'
import { apiV1Health } from '~/api'

type Health = { status: string }

export default function App() {
  const [health, setHealth] = useState<string>('checking…')

  useEffect(() => {
    apiV1Health
      .show<Health>()
      .then((data) => setHealth(data.status))
      .catch(() => setHealth('unreachable'))
  }, [])

  return (
    <main>
      <h1>Summit</h1>
      <p>API health: {health}</p>
    </main>
  )
}
