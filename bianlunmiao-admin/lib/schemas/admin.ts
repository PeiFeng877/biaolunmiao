import { z } from "zod/v4"

export const adminSchema = z.object({
  id: z.string(),
  email: z.string(),
  displayName: z.string(),
  role: z.string(),
  status: z.number(),
  lastLoginAt: z.string().nullable(),
  createdAt: z.string(),
  updatedAt: z.string(),
})

export const authBundleSchema = z.object({
  accessToken: z.string(),
  refreshToken: z.string(),
  tokenType: z.string(),
  accessTokenExpiresAt: z.string(),
  refreshTokenExpiresAt: z.string(),
  admin: adminSchema,
})

export const loginSchema = z.object({
  email: z.string().email("请输入有效邮箱"),
  password: z.string().min(8, "密码至少 8 位"),
})

export const overviewSchema = z.object({
  users: z.object({
    total: z.number(),
    normal: z.number(),
    deleted: z.number(),
    banned: z.number(),
  }),
  teams: z.object({
    total: z.number(),
    active: z.number(),
    inactive: z.number(),
  }),
  tournaments: z.object({
    total: z.number(),
    open: z.number(),
    ongoing: z.number(),
    ended: z.number(),
  }),
  latestActivityAt: z.string().nullable(),
})

export const adminUserSchema = z.object({
  id: z.string(),
  publicId: z.string(),
  nickname: z.string(),
  avatarUrl: z.string().nullable(),
  status: z.number(),
  deletedAt: z.string().nullable(),
  createdAt: z.string(),
  updatedAt: z.string(),
  appleSub: z.string().nullable().optional(),
})

export const adminUsersListSchema = z.object({
  items: z.array(adminUserSchema),
  nextCursor: z.string().nullable(),
})

export const userEditSchema = z.object({
  nickname: z.string().min(1, "昵称不能为空").max(50, "昵称不能超过 50 字"),
  avatar_url: z.string().trim().url("请输入有效 URL").nullable().or(z.literal("")),
  status: z.number(),
})

export const userCreateSchema = userEditSchema.extend({
  public_id: z.string().trim().max(20, "publicId 不能超过 20 字").or(z.literal("")),
})

const memberSchema = z.object({
  id: z.string(),
  teamId: z.string(),
  userId: z.string(),
  role: z.number(),
  joinTime: z.string(),
  nickname: z.string(),
  publicId: z.string(),
})

export const adminTeamSchema = z.object({
  id: z.string(),
  publicId: z.string(),
  name: z.string(),
  intro: z.string().nullable(),
  avatarUrl: z.string().nullable(),
  ownerId: z.string(),
  ownerNickname: z.string().nullable(),
  status: z.number(),
  memberCount: z.number(),
  createdAt: z.string(),
  updatedAt: z.string(),
  members: z.array(memberSchema).optional(),
})

export const adminTeamsListSchema = z.object({
  items: z.array(adminTeamSchema),
  nextCursor: z.string().nullable(),
})

export const teamEditSchema = z.object({
  name: z.string().min(1, "队伍名称不能为空").max(50, "队伍名称不能超过 50 字"),
  intro: z.string().max(500, "简介不能超过 500 字").nullable().or(z.literal("")),
  avatar_url: z.string().trim().url("请输入有效 URL").nullable().or(z.literal("")),
  status: z.number(),
})

export const teamCreateSchema = teamEditSchema.extend({
  owner_id: z.string().trim().min(1, "请输入队长用户 ID"),
})

const tournamentParticipantSchema = z.object({
  id: z.string(),
  tournamentId: z.string(),
  teamId: z.string(),
  status: z.string(),
  seed: z.number(),
})

const matchSchema = z.object({
  id: z.string(),
  tournamentId: z.string(),
  name: z.string(),
  topic: z.string().nullable(),
  startTime: z.string(),
  endTime: z.string(),
  location: z.string().nullable(),
  opponentTeamName: z.string().nullable(),
  teamAId: z.string().nullable(),
  teamBId: z.string().nullable(),
  format: z.string(),
  status: z.string(),
  winnerTeamId: z.string().nullable(),
  teamAScore: z.number().nullable(),
  teamBScore: z.number().nullable(),
  resultRecordedAt: z.string().nullable(),
  resultNote: z.string().nullable(),
  bestDebaterPosition: z.string().nullable(),
  rosters: z.array(
    z.object({
      id: z.string(),
      matchId: z.string(),
      teamId: z.string(),
      userId: z.string(),
      position: z.string(),
      status: z.number(),
    })
  ),
})

export const adminTournamentSchema = z.object({
  id: z.string(),
  name: z.string(),
  intro: z.string().nullable(),
  coverUrl: z.string().nullable(),
  creatorId: z.string(),
  creatorNickname: z.string().nullable(),
  status: z.number(),
  startDate: z.string().nullable(),
  endDate: z.string().nullable(),
  participantCount: z.number(),
  matchCount: z.number(),
  createdAt: z.string(),
  updatedAt: z.string(),
  participants: z.array(tournamentParticipantSchema).optional(),
  matches: z.array(matchSchema).optional(),
})

export const adminTournamentsListSchema = z.object({
  items: z.array(adminTournamentSchema),
  nextCursor: z.string().nullable(),
})

export const tournamentEditSchema = z.object({
  name: z.string().min(1, "赛事名称不能为空").max(100, "赛事名称不能超过 100 字"),
  intro: z.string().nullable().or(z.literal("")),
  cover_url: z.string().trim().url("请输入有效 URL").nullable().or(z.literal("")),
  status: z.number(),
  start_date: z.string().nullable().or(z.literal("")),
  end_date: z.string().nullable().or(z.literal("")),
})

export const tournamentCreateSchema = tournamentEditSchema.extend({
  creator_id: z.string().trim().min(1, "请输入创建者用户 ID"),
})

export const adminMutationSchema = z.object({
  ok: z.boolean(),
  resourceId: z.string(),
})

export type AdminSession = z.infer<typeof authBundleSchema>
export type AdminOverview = z.infer<typeof overviewSchema>
export type AdminUser = z.infer<typeof adminUserSchema>
export type AdminTeam = z.infer<typeof adminTeamSchema>
export type AdminTournament = z.infer<typeof adminTournamentSchema>
export type LoginValues = z.infer<typeof loginSchema>
export type UserEditValues = z.infer<typeof userEditSchema>
export type UserCreateValues = z.infer<typeof userCreateSchema>
export type TeamEditValues = z.infer<typeof teamEditSchema>
export type TeamCreateValues = z.infer<typeof teamCreateSchema>
export type TournamentEditValues = z.infer<typeof tournamentEditSchema>
export type TournamentCreateValues = z.infer<typeof tournamentCreateSchema>
