import type { ReactNode } from 'react'
import { NavLink } from 'react-router-dom'
import type { User } from '~/types'
import { useSwitchUser } from '~/api/queries'
import UpdateBanner from './UpdateBanner'

// Cascadia nav shell: sticky green bar, gold Summit mark + wordmark (wordmark
// hidden on mobile, mark stays as the brand anchor), active-link underline. The
// current-user chip on the right switches user (back to picker).
export default function Layout({ user, children }: { user: User; children: ReactNode }) {
  const switchUser = useSwitchUser()

  return (
    <>
      <nav className="nav-bar">
        <NavLink to="/" className="app-name">
          <img src="/mark.png" alt="" className="app-logo" />
          <span className="app-name__text">Summit</span>
        </NavLink>
        <ul className="nav-links">
          <li>
            <NavLink to="/" end>
              Today
            </NavLink>
          </li>
          <li>
            <NavLink to="/history">History</NavLink>
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
      <UpdateBanner />
      <main className="page-container">{children}</main>
    </>
  )
}
