// React Query hooks over the generated js_from_routes helpers. This is the
// convention every screen should follow: a typed helper from `~/api` wrapped in
// a query/mutation, keyed so the cache can be invalidated. The session cookie
// rides along with same-origin requests, so nothing here passes a user id.

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { apiV1Sessions, apiV1Users } from '~/api'
import type { User } from '~/types'

// The current user (from the session cookie), or null before one is picked.
export function useSession() {
  return useQuery({
    queryKey: ['session'],
    queryFn: () => apiV1Sessions.show<User | null>(),
  })
}

// The two users, for the picker.
export function useUsers() {
  return useQuery({
    queryKey: ['users'],
    queryFn: () => apiV1Users.index<User[]>(),
  })
}

// Pick a user -> sets the session cookie server-side, primes the session cache.
export function useSelectUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (userId: number) =>
      apiV1Sessions.create<User>({ data: { user_id: userId } }),
    onSuccess: (user) => queryClient.setQueryData(['session'], user),
  })
}

// Switch user -> clears the session cookie, drops back to the picker.
export function useSwitchUser() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: () => apiV1Sessions.destroy(),
    onSuccess: () => queryClient.setQueryData(['session'], null),
  })
}
