import { Routes, Route } from 'react-router-dom'
import { useSession } from '~/api/queries'
import UserPicker from './UserPicker'
import Layout from './Layout'
import Placeholder from './Placeholder'
import Today from './Today'
import History from './History'
import WorkoutDetail from './WorkoutDetail'
import HealthImportSetup from './HealthImportSetup'
import Integrations from './Integrations'
import Library from './Library'
import RoutineDetail from './RoutineDetail'
import Exercises from './Exercises'

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
        <Route path="/" element={<Today />} />
        <Route path="/history" element={<History />} />
        <Route path="/history/:id" element={<WorkoutDetail />} />
        <Route path="/settings/health-import" element={<HealthImportSetup />} />
        <Route path="/settings/integrations" element={<Integrations />} />
        <Route path="/library" element={<Library />} />
        <Route path="/library/exercises" element={<Exercises />} />
        <Route path="/library/routines/:id" element={<RoutineDetail />} />
        <Route path="/nutrition" element={<Placeholder title="Nutrition" />} />
      </Routes>
    </Layout>
  )
}
