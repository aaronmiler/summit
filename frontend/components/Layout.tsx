import type { ReactNode } from 'react'
import { NavLink } from 'react-router-dom'
import type { User } from '~/types'
import { useSwitchUser } from '~/api/queries'

// Cascadia nav shell: sticky green bar, "Summit" in Oregon Gold, active-link
// underline. The current-user chip on the right switches user (back to picker).
export default function Layout({ user, children }: { user: User; children: ReactNode }) {
  const switchUser = useSwitchUser()

  return (
    <>
      <nav className="nav-bar">
        <NavLink to="/" className="app-name">
          Summit
        </NavLink>
        <ul className="nav-links">
          <li>
            <NavLink to="/" end>
              Today
            </NavLink>
          </li>
          <li>
            <NavLink to="/library">Library</NavLink>
          </li>
          <li>
            <NavLink to="/nutrition">Nutrition</NavLink>
          </li>
        </ul>
        <button
          className="btn btn--ghost btn--compact nav-user"
          onClick={() => switchUser.mutate()}
          title="Switch user"
        >
          {user.name}
        </button>
      </nav>
      <main className="page-container">{children}</main>
    </>
  )
}
