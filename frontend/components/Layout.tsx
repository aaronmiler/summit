import { type ReactNode, useEffect, useState } from 'react'
import { NavLink } from 'react-router-dom'
import type { User } from '~/types'
import { useSwitchUser } from '~/api/queries'
import UpdateBanner from './UpdateBanner'

// Cascadia nav shell: sticky green bar, gold Summit mark + wordmark (wordmark
// hidden on mobile). On desktop the links + user chip sit inline; on mobile they
// collapse behind a hamburger into a right-side drawer, so the bar never wraps
// and the bottom stays clear for the rest timer.
export default function Layout({ user, children }: { user: User; children: ReactNode }) {
  const switchUser = useSwitchUser()
  const [menuOpen, setMenuOpen] = useState(false)
  const closeMenu = () => setMenuOpen(false)

  // Close the mobile drawer on Escape.
  useEffect(() => {
    if (!menuOpen) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setMenuOpen(false)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [menuOpen])

  return (
    <>
      <nav className="nav-bar">
        <NavLink to="/" className="app-name" onClick={closeMenu}>
          <img src="/mark.png" alt="" className="app-logo" />
          <span className="app-name__text">Summit</span>
        </NavLink>

        <button
          type="button"
          className="nav-toggle"
          aria-label="Menu"
          aria-expanded={menuOpen}
          aria-controls="nav-menu"
          onClick={() => setMenuOpen((open) => !open)}
        >
          <svg width="24" height="24" viewBox="0 0 24 24" aria-hidden="true"
            fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            <line x1="3" y1="6" x2="21" y2="6" />
            <line x1="3" y1="12" x2="21" y2="12" />
            <line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>

        {menuOpen && <div className="nav-overlay" onClick={closeMenu} />}

        <div id="nav-menu" className={`nav-menu${menuOpen ? ' nav-menu--open' : ''}`}>
          <ul className="nav-links" onClick={closeMenu}>
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
            onClick={() => {
              switchUser.mutate()
              closeMenu()
            }}
            title="Switch user"
          >
            {user.name}
          </button>
        </div>
      </nav>
      <UpdateBanner />
      <main className="page-container">{children}</main>
    </>
  )
}
