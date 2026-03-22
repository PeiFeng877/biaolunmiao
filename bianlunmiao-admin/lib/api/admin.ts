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

async function rpcRequest<T>(
  request: RequestFn,
  action: string,
  params: Record<string, unknown> = {},
  init: RequestInit & { auth?: boolean; retryOnAuth?: boolean } = {}
) {
  return request<T>("/rpc", {
    method: "POST",
    ...init,
    body: JSON.stringify({
      action,
      params,
    }),
  })
}

export async function loginAdmin(request: RequestFn, values: LoginValues) {
  const payload = await rpcRequest<AdminSession>(request, "admin.auth.login", values, {
    auth: false,
  })

  return authBundleSchema.parse(payload)
}

export async function refreshAdmin(request: RequestFn, refreshToken: string) {
  const payload = await rpcRequest<AdminSession>(request, "admin.auth.refresh", { refreshToken }, {
    auth: false,
    retryOnAuth: false,
  })

  return authBundleSchema.parse(payload)
}

export async function logoutAdmin(request: RequestFn, refreshToken: string) {
  return rpcRequest<{ ok: boolean }>(request, "admin.auth.logout", { refreshToken }, {
    auth: false,
    retryOnAuth: false,
  })
}

export async function getOverview(request: RequestFn) {
  const payload = await rpcRequest(request, "admin.overview.get")
  return overviewSchema.parse(payload)
}

export async function getUsers(request: RequestFn, params: ListParams) {
  const payload = await rpcRequest(request, "admin.users.list", params)
  return adminUsersListSchema.parse(payload)
}

export async function getUserDetail(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.users.detail", { id })
  return adminUserSchema.parse(payload)
}

export async function updateUser(request: RequestFn, id: string, values: UserEditValues) {
  const payload = await rpcRequest(request, "admin.users.update", {
    id,
    ...values,
    avatar_url: values.avatar_url || null,
  })

  return adminUserSchema.parse(payload)
}

export async function createUser(request: RequestFn, values: UserCreateValues) {
  const payload = await rpcRequest(request, "admin.users.create", {
    ...values,
    public_id: values.public_id || null,
    avatar_url: values.avatar_url || null,
  })

  return adminUserSchema.parse(payload)
}

export async function deleteUser(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.users.delete", { id })
  return adminMutationSchema.parse(payload)
}

export async function getTeams(request: RequestFn, params: ListParams) {
  const payload = await rpcRequest(request, "admin.teams.list", params)
  return adminTeamsListSchema.parse(payload)
}

export async function getTeamDetail(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.teams.detail", { id })
  return adminTeamsListSchema.shape.items.element.parse(payload)
}

export async function updateTeam(request: RequestFn, id: string, values: TeamEditValues) {
  const payload = await rpcRequest(request, "admin.teams.update", {
    id,
    ...values,
    intro: values.intro || null,
    avatar_url: values.avatar_url || null,
  })

  return adminTeamsListSchema.shape.items.element.parse(payload)
}

export async function createTeam(request: RequestFn, values: TeamCreateValues) {
  const payload = await rpcRequest(request, "admin.teams.create", {
    ...values,
    intro: values.intro || null,
    avatar_url: values.avatar_url || null,
  })

  return adminTeamsListSchema.shape.items.element.parse(payload)
}

export async function deleteTeam(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.teams.delete", { id })
  return adminMutationSchema.parse(payload)
}

export async function getTournaments(request: RequestFn, params: ListParams) {
  const payload = await rpcRequest(request, "admin.tournaments.list", params)
  return adminTournamentsListSchema.parse(payload)
}

export async function getTournamentDetail(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.tournaments.detail", { id })
  return adminTournamentsListSchema.shape.items.element.parse(payload)
}

export async function updateTournament(
  request: RequestFn,
  id: string,
  values: TournamentEditValues
) {
  const payload = await rpcRequest(request, "admin.tournaments.update", {
    id,
    ...values,
    intro: values.intro || null,
    cover_url: values.cover_url || null,
    start_date: values.start_date || null,
    end_date: values.end_date || null,
  })

  return adminTournamentsListSchema.shape.items.element.parse(payload)
}

export async function createTournament(request: RequestFn, values: TournamentCreateValues) {
  const payload = await rpcRequest(request, "admin.tournaments.create", {
    ...values,
    intro: values.intro || null,
    cover_url: values.cover_url || null,
    start_date: values.start_date || null,
    end_date: values.end_date || null,
  })

  return adminTournamentsListSchema.shape.items.element.parse(payload)
}

export async function deleteTournament(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.tournaments.delete", { id })
  return adminMutationSchema.parse(payload)
}
