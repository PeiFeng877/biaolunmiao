import { z } from "zod/v4"

const optionalUrlSchema = z.string().trim().url("请输入有效 URL").nullable().or(z.literal(""))
const optionalTextSchema = z.string().trim().nullable().or(z.literal(""))
const optionalIdSchema = z.string().trim().nullable().or(z.literal(""))

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

export const adminUserPickerSchema = z.object({
  id: z.string(),
  publicId: z.string(),
  nickname: z.string(),
  avatarUrl: z.string().nullable().optional(),
  status: z.number().optional(),
  email: z.string().nullable().optional(),
})

export const userEditSchema = z.object({
  nickname: z.string().min(1, "昵称不能为空").max(50, "昵称不能超过 50 字"),
  avatar_url: optionalUrlSchema,
  status: z.number(),
})

export const userCreateSchema = userEditSchema.extend({
  public_id: z.string().trim().max(20, "publicId 不能超过 20 字").or(z.literal("")),
})

export const teamMemberSchema = z.object({
  id: z.string(),
  teamId: z.string(),
  userId: z.string(),
  role: z.number(),
  status: z.number().optional(),
  joinTime: z.string(),
  nickname: z.string(),
  publicId: z.string(),
  avatarUrl: z.string().nullable().optional(),
})

export const teamJoinRequestSchema = z.object({
  id: z.string(),
  teamId: z.string(),
  teamPublicId: z.string(),
  teamName: z.string(),
  applicantUserId: z.string(),
  applicantPublicId: z.string(),
  applicantNickname: z.string(),
  applicantAvatarUrl: z.string().nullable().optional(),
  personalNote: z.string(),
  reason: z.string().nullable(),
  status: z.string(),
  createdAt: z.string(),
  reviewedAt: z.string().nullable(),
  reviewedByUserId: z.string().nullable(),
  reviewedByNickname: z.string().nullable(),
})

export const adminTeamPickerSchema = z.object({
  id: z.string(),
  publicId: z.string(),
  name: z.string(),
  status: z.number().optional(),
  memberCount: z.number().optional(),
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
  members: z.array(teamMemberSchema).optional(),
  joinRequests: z.array(teamJoinRequestSchema).optional(),
})

export const adminTeamsListSchema = z.object({
  items: z.array(adminTeamSchema),
  nextCursor: z.string().nullable(),
})

export const teamEditSchema = z.object({
  name: z.string().min(1, "队伍名称不能为空").max(50, "队伍名称不能超过 50 字"),
  intro: z.string().max(500, "简介不能超过 500 字").nullable().or(z.literal("")),
  avatar_url: optionalUrlSchema,
  status: z.number(),
})

export const teamCreateSchema = teamEditSchema.extend({
  owner_id: z.string().trim().min(1, "请输入队长用户 ID"),
})

export const teamMemberCreateSchema = z.object({
  user_id: z.string().trim().min(1, "请选择成员"),
  role: z.number().default(0),
})

export const tournamentParticipantSchema = z.object({
  id: z.string(),
  tournamentId: z.string(),
  teamId: z.string(),
  status: z.string(),
  seed: z.number(),
  teamName: z.string().nullable().optional(),
  teamPublicId: z.string().nullable().optional(),
})

export const tournamentParticipantAddSchema = z.object({
  team_id: z.string().trim().min(1, "请选择队伍"),
})

export const adminJoinRequestsListSchema = z.object({
  items: z.array(teamJoinRequestSchema),
  nextCursor: z.string().nullable(),
})

export const adminTournamentParticipantsListSchema = z.object({
  items: z.array(tournamentParticipantSchema),
  nextCursor: z.string().nullable(),
})

export const matchRosterAssignmentSchema = z.object({
  user_id: z.string().trim().min(1, "请选择队员"),
  position: z.string().trim().min(1, "请输入辩位"),
})

export const adminMatchSchema = z.object({
  id: z.string(),
  tournamentId: z.string(),
  tournamentName: z.string().nullable().optional(),
  name: z.string(),
  topic: z.string().nullable(),
  startTime: z.string(),
  endTime: z.string(),
  location: z.string().nullable(),
  opponentTeamName: z.string().nullable(),
  teamAId: z.string().nullable(),
  teamBId: z.string().nullable(),
  teamAName: z.string().nullable().optional(),
  teamAPublicId: z.string().nullable().optional(),
  teamBName: z.string().nullable().optional(),
  teamBPublicId: z.string().nullable().optional(),
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
      nickname: z.string().nullable().optional(),
      publicId: z.string().nullable().optional(),
      teamName: z.string().nullable().optional(),
      teamPublicId: z.string().nullable().optional(),
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
  matches: z.array(adminMatchSchema).optional(),
})

export const adminTournamentsListSchema = z.object({
  items: z.array(adminTournamentSchema),
  nextCursor: z.string().nullable(),
})

export const tournamentEditSchema = z.object({
  name: z.string().min(1, "赛事名称不能为空").max(100, "赛事名称不能超过 100 字"),
  intro: optionalTextSchema,
  cover_url: optionalUrlSchema,
  status: z.number(),
  start_date: z.string().nullable().or(z.literal("")),
  end_date: z.string().nullable().or(z.literal("")),
})

export const tournamentCreateSchema = tournamentEditSchema.extend({
  creator_id: z.string().trim().min(1, "请输入创建者用户 ID"),
})

export const matchEditSchema = z
  .object({
    name: z.string().trim().min(1, "场次名称不能为空").max(100, "场次名称不能超过 100 字"),
    topic: optionalTextSchema,
    start_time: z.string().trim().min(1, "请选择开始时间"),
    end_time: z.string().trim().min(1, "请选择结束时间"),
    location: optionalTextSchema,
    format: z.string().trim().min(1, "请选择赛制"),
    opponent_team_name: optionalTextSchema,
    team_a_id: optionalIdSchema,
    team_b_id: optionalIdSchema,
  })
  .superRefine((value, context) => {
    const start = new Date(value.start_time)
    const end = new Date(value.end_time)

    if (Number.isNaN(start.getTime())) {
      context.addIssue({
        code: "custom",
        path: ["start_time"],
        message: "开始时间格式无效",
      })
    }

    if (Number.isNaN(end.getTime())) {
      context.addIssue({
        code: "custom",
        path: ["end_time"],
        message: "结束时间格式无效",
      })
    }

    if (!Number.isNaN(start.getTime()) && !Number.isNaN(end.getTime()) && end <= start) {
      context.addIssue({
        code: "custom",
        path: ["end_time"],
        message: "结束时间必须晚于开始时间",
      })
    }
  })

export const matchCreateSchema = matchEditSchema

export const adminMatchesListSchema = z.object({
  items: z.array(adminMatchSchema),
  nextCursor: z.string().nullable(),
})

export const matchRosterUpdateSchema = z.object({
  assignments: z.array(matchRosterAssignmentSchema),
})

export const matchResultUpdateSchema = z.object({
  winner_team_id: z.string().trim().min(1, "请选择胜方"),
  team_a_score: z.number().int().min(0, "请输入有效分数"),
  team_b_score: z.number().int().min(0, "请输入有效分数"),
  result_note: optionalTextSchema,
  best_debater_position: optionalTextSchema,
})

export const matchStatusAdvanceSchema = z.object({
  status: z.string().trim().min(1, "请选择目标状态"),
})

export const adminMutationSchema = z.object({
  ok: z.boolean(),
  resourceId: z.string(),
})

export type AdminSession = z.infer<typeof authBundleSchema>
export type AdminOverview = z.infer<typeof overviewSchema>
export type AdminUser = z.infer<typeof adminUserSchema>
export type AdminUserPicker = z.infer<typeof adminUserPickerSchema>
export type AdminTeam = z.infer<typeof adminTeamSchema>
export type AdminTeamMember = z.infer<typeof teamMemberSchema>
export type AdminTeamJoinRequest = z.infer<typeof teamJoinRequestSchema>
export type AdminTeamPicker = z.infer<typeof adminTeamPickerSchema>
export type AdminTournament = z.infer<typeof adminTournamentSchema>
export type AdminTournamentParticipant = z.infer<typeof tournamentParticipantSchema>
export type AdminMatch = z.infer<typeof adminMatchSchema>
export type LoginValues = z.infer<typeof loginSchema>
export type UserEditValues = z.infer<typeof userEditSchema>
export type UserCreateValues = z.infer<typeof userCreateSchema>
export type TeamEditValues = z.infer<typeof teamEditSchema>
export type TeamCreateValues = z.infer<typeof teamCreateSchema>
export type TeamMemberCreateValues = z.infer<typeof teamMemberCreateSchema>
export type TournamentEditValues = z.infer<typeof tournamentEditSchema>
export type TournamentCreateValues = z.infer<typeof tournamentCreateSchema>
export type TournamentParticipantAddValues = z.infer<typeof tournamentParticipantAddSchema>
export type MatchEditValues = z.infer<typeof matchEditSchema>
export type MatchCreateValues = z.infer<typeof matchCreateSchema>
export type MatchRosterAssignmentValues = z.infer<typeof matchRosterAssignmentSchema>
export type MatchRosterUpdateValues = z.infer<typeof matchRosterUpdateSchema>
export type MatchResultUpdateValues = z.infer<typeof matchResultUpdateSchema>
export type MatchStatusAdvanceValues = z.infer<typeof matchStatusAdvanceSchema>
