import {
  adminMutationSchema,
  adminTeamsListSchema,
  adminTournamentsListSchema,
  adminUserSchema,
  adminUsersListSchema,
  authBundleSchema,
  overviewSchema,
  type AdminSession,
  type LoginValues,
  type TeamCreateValues,
  type TeamEditValues,
  type TournamentCreateValues,
  type TournamentEditValues,
  type UserCreateValues,
  type UserEditValues,
} from "@/lib/schemas/admin"

export type RequestFn = <T>(
  path: string,
  init?: RequestInit & { auth?: boolean; retryOnAuth?: boolean }
) => Promise<T>

type ListParams = {
  q?: string
  status?: string
}

function toQueryString(params: ListParams) {
  const query = new URLSearchParams()

  if (params.q?.trim()) {
    query.set("q", params.q.trim())
  }

  if (params.status && params.status !== "all") {
    query.set("status", params.status)
  }

  return query.toString()
}

function withQuery(path: string, params: ListParams) {
  const query = toQueryString(params)
  return query ? `${path}?${query}` : path
}

export async function loginAdmin(request: RequestFn, values: LoginValues) {
  const payload = await request<AdminSession>("/admin/auth/login", {
    method: "POST",
    auth: false,
    body: JSON.stringify(values),
  })

  return authBundleSchema.parse(payload)
}

export async function refreshAdmin(request: RequestFn, refreshToken: string) {
  const payload = await request<AdminSession>("/admin/auth/refresh", {
    method: "POST",
    auth: false,
    retryOnAuth: false,
    body: JSON.stringify({ refreshToken }),
  })

  return authBundleSchema.parse(payload)
}

export async function logoutAdmin(request: RequestFn, refreshToken: string) {
  return request<{ ok: boolean }>("/admin/auth/logout", {
    method: "POST",
    auth: false,
    retryOnAuth: false,
    body: JSON.stringify({ refreshToken }),
  })
}

export async function getOverview(request: RequestFn) {
  const payload = await request("/admin/overview")
  return overviewSchema.parse(payload)
}

export async function getUsers(request: RequestFn, params: ListParams) {
  const payload = await request(withQuery("/admin/users", params))
  return adminUsersListSchema.parse(payload)
}

export async function getUserDetail(request: RequestFn, id: string) {
  const payload = await request(`/admin/users/${id}`)
  return adminUserSchema.parse(payload)
}

export async function updateUser(request: RequestFn, id: string, values: UserEditValues) {
  const payload = await request(`/admin/users/${id}`, {
    method: "PATCH",
    body: JSON.stringify({
      ...values,
      avatar_url: values.avatar_url || null,
    }),
  })

  return adminUserSchema.parse(payload)
}

export async function createUser(request: RequestFn, values: UserCreateValues) {
  const payload = await request("/admin/users", {
    method: "POST",
    body: JSON.stringify({
      ...values,
      public_id: values.public_id || null,
      avatar_url: values.avatar_url || null,
    }),
  })

  return adminUserSchema.parse(payload)
}

export async function deleteUser(request: RequestFn, id: string) {
  const payload = await request(`/admin/users/${id}`, {
    method: "DELETE",
  })

  return adminMutationSchema.parse(payload)
}

export async function getTeams(request: RequestFn, params: ListParams) {
  const payload = await request(withQuery("/admin/teams", params))
  return adminTeamsListSchema.parse(payload)
}

export async function getTeamDetail(request: RequestFn, id: string) {
  const payload = await request(`/admin/teams/${id}`)
  return adminTeamsListSchema.shape.items.element.parse(payload)
}

export async function updateTeam(request: RequestFn, id: string, values: TeamEditValues) {
  const payload = await request(`/admin/teams/${id}`, {
    method: "PATCH",
    body: JSON.stringify({
      ...values,
      intro: values.intro || null,
      avatar_url: values.avatar_url || null,
    }),
  })

  return adminTeamsListSchema.shape.items.element.parse(payload)
}

export async function createTeam(request: RequestFn, values: TeamCreateValues) {
  const payload = await request("/admin/teams", {
    method: "POST",
    body: JSON.stringify({
      ...values,
      intro: values.intro || null,
      avatar_url: values.avatar_url || null,
    }),
  })

  return adminTeamsListSchema.shape.items.element.parse(payload)
}

export async function deleteTeam(request: RequestFn, id: string) {
  const payload = await request(`/admin/teams/${id}`, {
    method: "DELETE",
  })

  return adminMutationSchema.parse(payload)
}

export async function getTournaments(request: RequestFn, params: ListParams) {
  const payload = await request(withQuery("/admin/tournaments", params))
  return adminTournamentsListSchema.parse(payload)
}

export async function getTournamentDetail(request: RequestFn, id: string) {
  const payload = await request(`/admin/tournaments/${id}`)
  return adminTournamentsListSchema.shape.items.element.parse(payload)
}

export async function updateTournament(
  request: RequestFn,
  id: string,
  values: TournamentEditValues
) {
  const payload = await request(`/admin/tournaments/${id}`, {
    method: "PATCH",
    body: JSON.stringify({
      ...values,
      intro: values.intro || null,
      cover_url: values.cover_url || null,
      start_date: values.start_date || null,
      end_date: values.end_date || null,
    }),
  })

  return adminTournamentsListSchema.shape.items.element.parse(payload)
}

export async function createTournament(request: RequestFn, values: TournamentCreateValues) {
  const payload = await request("/admin/tournaments", {
    method: "POST",
    body: JSON.stringify({
      ...values,
      intro: values.intro || null,
      cover_url: values.cover_url || null,
      start_date: values.start_date || null,
      end_date: values.end_date || null,
    }),
  })

  return adminTournamentsListSchema.shape.items.element.parse(payload)
}

export async function deleteTournament(request: RequestFn, id: string) {
  const payload = await request(`/admin/tournaments/${id}`, {
    method: "DELETE",
  })

  return adminMutationSchema.parse(payload)
}
