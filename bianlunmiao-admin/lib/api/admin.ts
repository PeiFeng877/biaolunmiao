import {
  adminJoinRequestsListSchema,
  adminMatchSchema,
  adminMatchesListSchema,
  adminMutationSchema,
  adminTeamSchema,
  adminTeamsListSchema,
  adminTournamentParticipantsListSchema,
  adminTournamentSchema,
  adminTournamentsListSchema,
  teamJoinRequestSchema,
  adminUserSchema,
  adminUsersListSchema,
  authBundleSchema,
  overviewSchema,
  type AdminSession,
  type LoginValues,
  type MatchCreateValues,
  type MatchEditValues,
  type MatchResultUpdateValues,
  type MatchRosterUpdateValues,
  type MatchStatusAdvanceValues,
  type TeamMemberCreateValues,
  type TeamCreateValues,
  type TeamEditValues,
  type TournamentParticipantAddValues,
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

function nullableText(value?: string | null) {
  const text = value?.trim()
  return text ? text : null
}

function normalizeMatchValues(values: MatchCreateValues | MatchEditValues) {
  return {
    ...values,
    topic: nullableText(values.topic),
    start_time: new Date(values.start_time).toISOString(),
    end_time: new Date(values.end_time).toISOString(),
    location: nullableText(values.location),
    opponent_team_name: nullableText(values.opponent_team_name),
    team_a_id: nullableText(values.team_a_id),
    team_b_id: nullableText(values.team_b_id),
  }
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
  return adminTeamSchema.parse(payload)
}

export async function updateTeam(request: RequestFn, id: string, values: TeamEditValues) {
  const payload = await rpcRequest(request, "admin.teams.update", {
    id,
    ...values,
    intro: values.intro || null,
    avatar_url: values.avatar_url || null,
  })

  return adminTeamSchema.parse(payload)
}

export async function createTeam(request: RequestFn, values: TeamCreateValues) {
  const payload = await rpcRequest(request, "admin.teams.create", {
    ...values,
    intro: values.intro || null,
    avatar_url: values.avatar_url || null,
  })

  return adminTeamSchema.parse(payload)
}

export async function deleteTeam(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.teams.delete", { id })
  return adminMutationSchema.parse(payload)
}

export async function getTeamJoinRequests(
  request: RequestFn,
  params: {
    team_id?: string
    applicant_user_id?: string
    status?: string
    q?: string
  } = {}
) {
  const payload = await rpcRequest(request, "admin.team_join_requests.list", params)
  return adminJoinRequestsListSchema.parse(payload)
}

export async function approveTeamJoinRequest(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.team_join_requests.approve", { id })
  return teamJoinRequestSchema.parse(payload)
}

export async function rejectTeamJoinRequest(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.team_join_requests.reject", { id })
  return teamJoinRequestSchema.parse(payload)
}

export async function addTeamMember(request: RequestFn, teamId: string, values: TeamMemberCreateValues) {
  const payload = await rpcRequest(request, "admin.team_members.add", {
    team_id: teamId,
    ...values,
  })
  return adminTeamSchema.parse(payload)
}

export async function removeTeamMember(request: RequestFn, teamId: string, memberId: string) {
  const payload = await rpcRequest(request, "admin.team_members.remove", {
    team_id: teamId,
    member_id: memberId,
  })
  return adminTeamSchema.parse(payload)
}

export async function toggleTeamMemberAdmin(
  request: RequestFn,
  teamId: string,
  memberId: string,
  isAdmin: boolean
) {
  const payload = await rpcRequest(request, "admin.team_members.set_admin", {
    team_id: teamId,
    member_id: memberId,
    is_admin: isAdmin,
  })
  return adminTeamSchema.parse(payload)
}

export async function transferTeamOwner(request: RequestFn, teamId: string, memberId: string) {
  const payload = await rpcRequest(request, "admin.team_members.transfer_owner", {
    team_id: teamId,
    member_id: memberId,
  })
  return adminTeamSchema.parse(payload)
}

export async function getTournaments(request: RequestFn, params: ListParams) {
  const payload = await rpcRequest(request, "admin.tournaments.list", params)
  return adminTournamentsListSchema.parse(payload)
}

export async function getTournamentDetail(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.tournaments.detail", { id })
  return adminTournamentSchema.parse(payload)
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

  return adminTournamentSchema.parse(payload)
}

export async function createTournament(request: RequestFn, values: TournamentCreateValues) {
  const payload = await rpcRequest(request, "admin.tournaments.create", {
    ...values,
    intro: values.intro || null,
    cover_url: values.cover_url || null,
    start_date: values.start_date || null,
    end_date: values.end_date || null,
  })

  return adminTournamentSchema.parse(payload)
}

export async function deleteTournament(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.tournaments.delete", { id })
  return adminMutationSchema.parse(payload)
}

export async function getTournamentParticipants(request: RequestFn, tournamentId: string) {
  const payload = await rpcRequest(request, "admin.tournament_participants.list", {
    tournament_id: tournamentId,
  })
  return adminTournamentParticipantsListSchema.parse(payload)
}

export async function addTournamentParticipant(
  request: RequestFn,
  tournamentId: string,
  values: TournamentParticipantAddValues
) {
  const payload = await rpcRequest(request, "admin.tournament_participants.add", {
    tournament_id: tournamentId,
    ...values,
  })
  return adminTournamentSchema.parse(payload)
}

export async function removeTournamentParticipant(
  request: RequestFn,
  tournamentId: string,
  participantId: string
) {
  const payload = await rpcRequest(request, "admin.tournament_participants.remove", {
    tournament_id: tournamentId,
    participant_id: participantId,
  })
  return adminTournamentSchema.parse(payload)
}

export async function getMatches(
  request: RequestFn,
  paramsOrTournamentId:
    | string
    | {
    tournament_id?: string
    q?: string
    status?: string
    team_id?: string
  } = {}
) {
  const params =
    typeof paramsOrTournamentId === "string"
      ? { tournament_id: paramsOrTournamentId }
      : paramsOrTournamentId
  const payload = await rpcRequest(request, "admin.matches.list", params)
  return adminMatchesListSchema.parse(payload)
}

export async function getMatchDetail(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.matches.detail", { id })
  return adminMatchSchema.parse(payload)
}

export async function createMatch(
  request: RequestFn,
  tournamentId: string,
  values: MatchCreateValues
) {
  const payload = await rpcRequest(request, "admin.matches.create", {
    tournament_id: tournamentId,
    ...normalizeMatchValues(values),
  })

  return adminMatchSchema.parse(payload)
}

export async function updateMatch(request: RequestFn, id: string, values: MatchEditValues) {
  const payload = await rpcRequest(request, "admin.matches.update", {
    id,
    ...normalizeMatchValues(values),
  })

  return adminMatchSchema.parse(payload)
}

export async function deleteMatch(request: RequestFn, id: string) {
  const payload = await rpcRequest(request, "admin.matches.delete", { id })
  return adminMutationSchema.parse(payload)
}

export async function updateMatchRoster(
  request: RequestFn,
  matchId: string,
  teamId: string,
  values: MatchRosterUpdateValues
) {
  const payload = await rpcRequest(request, "admin.match_rosters.update", {
    match_id: matchId,
    team_id: teamId,
    assignments: values.assignments,
  })
  return adminMatchSchema.parse(payload)
}

export async function updateMatchResult(
  request: RequestFn,
  matchId: string,
  values: MatchResultUpdateValues
) {
  const payload = await rpcRequest(request, "admin.match_results.update", {
    match_id: matchId,
    ...values,
    result_note: nullableText(values.result_note),
    best_debater_position: nullableText(values.best_debater_position),
  })
  return adminMatchSchema.parse(payload)
}

export async function advanceMatchStatus(
  request: RequestFn,
  matchId: string,
  values: MatchStatusAdvanceValues
) {
  const payload = await rpcRequest(request, "admin.matches.advance_status", {
    match_id: matchId,
    ...values,
  })
  return adminMatchSchema.parse(payload)
}
