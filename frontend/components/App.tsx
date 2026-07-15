import { Routes, Route } from 'react-router-dom'
import { useSession } from '~/api/queries'
import UserPicker from './UserPicker'
import Layout from './Layout'
import Placeholder from './Placeholder'

// The shell. Identity gates everything: no user in session -> picker; otherwise
// the nav + routed screens. Feature screens are stubs for now.
export default function App() {
  const { data: user, isLoading } = useSession()

  if (isLoading) {
    return <p className="page-container text-muted">Loading…</p>
  }

  if (!user) {
    return <UserPicker />
  }

  return (
    <Layout user={user}>
      <Routes>
        <Route path="/" element={<Placeholder title="Today" />} />
        <Route path="/library" element={<Placeholder title="Library" />} />
        <Route path="/nutrition" element={<Placeholder title="Nutrition" />} />
      </Routes>
    </Layout>
  )
}
