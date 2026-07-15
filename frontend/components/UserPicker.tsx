import { useUsers, useSelectUser } from '~/api/queries'

// "Which of the 2 are you?" — the app's only sign-in. Picking sets the session
// cookie; there's no password (homelab + Tailscale is the boundary).
export default function UserPicker() {
  const { data: users, isLoading } = useUsers()
  const selectUser = useSelectUser()

  return (
    <div className="picker">
      <div>
        <h1 className="page-heading text-green">Summit</h1>
        <p className="text-muted">Who's training?</p>
      </div>
      {isLoading ? (
        <p className="text-muted">Loading…</p>
      ) : (
        <div className="picker__choices">
          {users?.map((user) => (
            <button
              key={user.id}
              className="btn btn--primary"
              disabled={selectUser.isPending}
              onClick={() => selectUser.mutate(user.id)}
            >
              {user.name}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
