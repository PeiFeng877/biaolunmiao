//
//  MockData.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 初始化所需的基础实体数据。
//  OUTPUT: 本地可重复的 Mock 数据集。
//  POS: 数据层 Mock。
//

import Foundation

class MockData {
    static let shared = MockData()
    static let empty = MockData(seedSampleData: false)

    // Mock Data Store
    let currentUser: User
    var myTeams: [Team] = []
    var discoverableTeams: [Team] = []
    var teamJoinRequests: [TeamJoinRequest] = []
    var inboxMessages: [InboxMessage] = []
    var tournaments: [Tournament] = []
    var matches: [Match] = []
    var rosters: [Roster] = []

    // Mock Users for members
    let userA = User(id: UUID(), publicId: "U1111", nickname: "张三", avatarUrl: nil, status: .normal)
    let userB = User(id: UUID(), publicId: "U2222", nickname: "李四", avatarUrl: nil, status: .normal)
    let userC = User(id: UUID(), publicId: "U3333", nickname: "王五", avatarUrl: nil, status: .normal)
    let userD = User(id: UUID(), publicId: "U4444", nickname: "赵六", avatarUrl: nil, status: .normal)
    let userE = User(id: UUID(), publicId: "U5555", nickname: "孙七", avatarUrl: nil, status: .normal)

    init(seedSampleData: Bool = true) {
        guard seedSampleData else {
            self.currentUser = User(
                id: UUID(),
                publicId: "",
                nickname: "",
                avatarUrl: nil,
                status: .normal
            )
            return
        }

        let now = Date()
        let calendar = Calendar.current

        func slot(dayOffset: Int, hour: Int, minute: Int = 0, durationMinutes: Int = 90) -> (start: Date, end: Date) {
            let baseDay = calendar.startOfDay(for: now)
            let day = calendar.date(byAdding: .day, value: dayOffset, to: baseDay) ?? baseDay
            let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
            let end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
            return (start, end)
        }

        // Initialize Current User
        self.currentUser = User(
            id: UUID(),
            publicId: "U9527",
            nickname: "培风",
            avatarUrl: nil,
            status: .normal
        )

        let team1Id = UUID()
        let team2Id = UUID()
        let team3Id = UUID()
        let team4Id = UUID()

        // Mock Members
        let memberMeOwner = TeamMember(
            id: UUID(),
            teamId: team1Id,
            userId: currentUser.id,
            role: .owner,
            joinTime: now,
            user: currentUser
        )
        let memberMeMember = TeamMember(
            id: UUID(),
            teamId: team2Id,
            userId: currentUser.id,
            role: .member,
            joinTime: now,
            user: currentUser
        )

        let memberA1 = TeamMember(
            id: UUID(),
            teamId: team1Id,
            userId: userA.id,
            role: .admin,
            joinTime: now,
            user: userA
        )
        let memberB1 = TeamMember(
            id: UUID(),
            teamId: team1Id,
            userId: userB.id,
            role: .member,
            joinTime: now,
            user: userB
        )
        let memberC1 = TeamMember(
            id: UUID(),
            teamId: team1Id,
            userId: userC.id,
            role: .member,
            joinTime: now,
            user: userC
        )
        let memberA2 = TeamMember(
            id: UUID(),
            teamId: team2Id,
            userId: userA.id,
            role: .owner,
            joinTime: now,
            user: userA
        )
        let memberB2 = TeamMember(
            id: UUID(),
            teamId: team2Id,
            userId: userB.id,
            role: .member,
            joinTime: now,
            user: userB
        )
        let memberC3 = TeamMember(
            id: UUID(),
            teamId: team3Id,
            userId: userC.id,
            role: .owner,
            joinTime: now,
            user: userC
        )
        let memberB4 = TeamMember(
            id: UUID(),
            teamId: team4Id,
            userId: userB.id,
            role: .owner,
            joinTime: now,
            user: userB
        )

        // Initialize Mock Teams
        let team1 = Team(
            id: team1Id,
            publicId: "1001",
            name: "复仇者辩论队",
            slogan: "我们要打十个！专注于攻辩技术的提升。",
            about: "队伍成立于 2018 年，擅长攻辩与盘问，强调节奏控制与团队协作。",
            avatarStyle: .paw,
            avatarUrl: nil,
            ownerId: self.currentUser.id,
            status: .normal,
            members: [memberMeOwner, memberA1, memberB1, memberC1]
        )

        let team2 = Team(
            id: team2Id,
            publicId: "1002",
            name: "佛系养生队",
            slogan: "友谊第一，比赛第二",
            about: "慢热型队伍，擅长价值输出与节奏拉满的结辩。",
            avatarStyle: .leaf,
            avatarUrl: nil,
            ownerId: userA.id,
            status: .normal,
            members: [memberA2, memberMeMember, memberB2]
        )

        let team3 = Team(
            id: team3Id,
            publicId: "1003",
            name: "黑白交锋",
            slogan: "快节奏攻防，打满每一分钟",
            about: "校园跨校联队，擅长攻辩与反驳，强调结构化表达。",
            avatarStyle: .bolt,
            avatarUrl: nil,
            ownerId: userC.id,
            status: .normal,
            members: [memberC3]
        )

        let team4 = Team(
            id: team4Id,
            publicId: "1004",
            name: "北辰论衡",
            slogan: "价值先行，体系制胜",
            about: "以立论深度见长，擅长价值框架与比较分析。",
            avatarStyle: .crown,
            avatarUrl: nil,
            ownerId: userB.id,
            status: .normal,
            members: [memberB4]
        )

        self.myTeams = [team1, team2]
        self.discoverableTeams = [team3, team4]
        self.teamJoinRequests = [
            TeamJoinRequest(
                id: UUID(),
                teamId: team1.id,
                teamPublicId: team1.publicId,
                teamName: team1.name,
                applicantUserId: userD.id,
                applicantPublicId: userD.publicId,
                applicantNickname: userD.nickname,
                personalNote: "赵六",
                reason: "想补强一辩位，长期在线训练。",
                createdAt: now.addingTimeInterval(-3600),
                status: .pending,
                reviewedAt: nil,
                reviewedByUserId: nil,
                reviewedByNickname: nil
            ),
            TeamJoinRequest(
                id: UUID(),
                teamId: team1.id,
                teamPublicId: team1.publicId,
                teamName: team1.name,
                applicantUserId: userE.id,
                applicantPublicId: userE.publicId,
                applicantNickname: userE.nickname,
                personalNote: "孙七",
                reason: "擅长结辩，周末可稳定参赛。",
                createdAt: now.addingTimeInterval(-5400),
                status: .pending,
                reviewedAt: nil,
                reviewedByUserId: nil,
                reviewedByNickname: nil
            ),
            TeamJoinRequest(
                id: UUID(),
                teamId: team3.id,
                teamPublicId: team3.publicId,
                teamName: team3.name,
                applicantUserId: currentUser.id,
                applicantPublicId: currentUser.publicId,
                applicantNickname: currentUser.nickname,
                personalNote: "培风",
                reason: "想参与跨校联赛。",
                createdAt: now.addingTimeInterval(-10_800),
                status: .approved,
                reviewedAt: now.addingTimeInterval(-8_400),
                reviewedByUserId: userC.id,
                reviewedByNickname: userC.nickname
            ),
            TeamJoinRequest(
                id: UUID(),
                teamId: team4.id,
                teamPublicId: team4.publicId,
                teamName: team4.name,
                applicantUserId: currentUser.id,
                applicantPublicId: currentUser.publicId,
                applicantNickname: currentUser.nickname,
                personalNote: "培风",
                reason: "希望学习价值比较打法。",
                createdAt: now.addingTimeInterval(-14_400),
                status: .rejected,
                reviewedAt: now.addingTimeInterval(-12_600),
                reviewedByUserId: userB.id,
                reviewedByNickname: userB.nickname
            )
        ]

        // Initialize Mock Tournament
        let tournamentAId = UUID()
        let tournamentA = Tournament(
            id: tournamentAId,
            name: "2026 星火杯",
            intro: "最硬核的辩论赛事",
            coverUrl: nil,
            creatorId: currentUser.id,
            status: .open,
            participants: [
                TournamentParticipant(
                    id: UUID(),
                    tournamentId: tournamentAId,
                    teamId: team1.id,
                    status: .confirmed,
                    seed: 0,
                    team: team1
                ),
                TournamentParticipant(
                    id: UUID(),
                    tournamentId: tournamentAId,
                    teamId: team2.id,
                    status: .confirmed,
                    seed: 1,
                    team: team2
                ),
                TournamentParticipant(
                    id: UUID(),
                    tournamentId: tournamentAId,
                    teamId: team3.id,
                    status: .confirmed,
                    seed: 2,
                    team: team3
                )
            ]
        )

        let tournamentBId = UUID()
        let tournamentB = Tournament(
            id: tournamentBId,
            name: "城市对抗赛",
            intro: "周末赛程更密集，适合演示日历视图。",
            coverUrl: nil,
            creatorId: currentUser.id,
            status: .open,
            participants: [
                TournamentParticipant(
                    id: UUID(),
                    tournamentId: tournamentBId,
                    teamId: team2.id,
                    status: .confirmed,
                    seed: 0,
                    team: team2
                ),
                TournamentParticipant(
                    id: UUID(),
                    tournamentId: tournamentBId,
                    teamId: team4.id,
                    status: .confirmed,
                    seed: 1,
                    team: team4
                )
            ]
        )
        self.tournaments = [tournamentA, tournamentB]

        // Initialize Mock Matches (for schedule showcase)
        let lastWeekSlot = slot(dayOffset: -2, hour: 20)
        let todaySlotA = slot(dayOffset: 0, hour: 12)
        let todaySlotB = slot(dayOffset: 0, hour: 19, minute: 30)
        let tomorrowSlot = slot(dayOffset: 1, hour: 14)
        let twoDaysLaterSlot = slot(dayOffset: 2, hour: 20)
        let fourDaysLaterSlot = slot(dayOffset: 4, hour: 10)
        let nextWeekSlot = slot(dayOffset: 8, hour: 15)
        let nextMonthBase = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let nextMonthStart = calendar.startOfDay(for: nextMonthBase)
        let nextMonthStartAdjusted = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: nextMonthStart) ?? nextMonthStart
        let nextMonthEnd = nextMonthStartAdjusted.addingTimeInterval(90 * 60)

        let matchA = Match(
            id: UUID(),
            tournamentId: tournamentA.id,
            name: "初赛第一场",
            startTime: todaySlotA.start,
            endTime: todaySlotA.end,
            location: "腾讯会议 888 888 888",
            teamAId: team1.id,
            teamBId: team2.id,
            format: .f3v3,
            status: .scheduled,
            winnerTeamId: nil,
            teamAScore: nil,
            teamBScore: nil,
            resultRecordedAt: nil,
            teamA: team1,
            teamB: team2
        )

        let matchB = Match(
            id: UUID(),
            tournamentId: tournamentA.id,
            name: "复赛资格争夺",
            startTime: todaySlotB.start,
            endTime: todaySlotB.end,
            location: "线上会议室 A-12",
            teamAId: team1.id,
            teamBId: team3.id,
            format: .f3v3,
            status: .ready,
            winnerTeamId: nil,
            teamAScore: nil,
            teamBScore: nil,
            resultRecordedAt: nil,
            teamA: team1,
            teamB: team3
        )

        let matchC = Match(
            id: UUID(),
            tournamentId: tournamentA.id,
            name: "攻防训练赛",
            startTime: tomorrowSlot.start,
            endTime: tomorrowSlot.end,
            location: "线下活动室 302",
            teamAId: team2.id,
            teamBId: team1.id,
            format: .f3v3,
            status: .scheduled,
            winnerTeamId: nil,
            teamAScore: nil,
            teamBScore: nil,
            resultRecordedAt: nil,
            teamA: team2,
            teamB: team1
        )

        let matchD = Match(
            id: UUID(),
            tournamentId: tournamentA.id,
            name: "八强预演",
            startTime: twoDaysLaterSlot.start,
            endTime: twoDaysLaterSlot.end,
            location: "腾讯会议 666 777 999",
            teamAId: team1.id,
            teamBId: team2.id,
            format: .f3v3,
            status: .scheduled,
            winnerTeamId: nil,
            teamAScore: nil,
            teamBScore: nil,
            resultRecordedAt: nil,
            teamA: team1,
            teamB: team2
        )

        let matchE = Match(
            id: UUID(),
            tournamentId: tournamentB.id,
            name: "城市赛小组轮",
            startTime: fourDaysLaterSlot.start,
            endTime: fourDaysLaterSlot.end,
            location: "报告厅 1F",
            teamAId: team2.id,
            teamBId: team4.id,
            format: .f3v3,
            status: .scheduled,
            winnerTeamId: nil,
            teamAScore: nil,
            teamBScore: nil,
            resultRecordedAt: nil,
            teamA: team2,
            teamB: team4
        )

        let matchF = Match(
            id: UUID(),
            tournamentId: tournamentB.id,
            name: "周末公开表演赛",
            startTime: nextWeekSlot.start,
            endTime: nextWeekSlot.end,
            location: "线上直播间",
            teamAId: team1.id,
            teamBId: team4.id,
            format: .f3v3,
            status: .scheduled,
            winnerTeamId: nil,
            teamAScore: nil,
            teamBScore: nil,
            resultRecordedAt: nil,
            teamA: team1,
            teamB: team4
        )

        let matchG = Match(
            id: UUID(),
            tournamentId: tournamentB.id,
            name: "跨月邀请赛",
            startTime: nextMonthStartAdjusted,
            endTime: nextMonthEnd,
            location: "腾讯会议 321 654 987",
            teamAId: team1.id,
            teamBId: team2.id,
            format: .f3v3,
            status: .scheduled,
            winnerTeamId: nil,
            teamAScore: nil,
            teamBScore: nil,
            resultRecordedAt: nil,
            teamA: team1,
            teamB: team2
        )

        let matchPast = Match(
            id: UUID(),
            tournamentId: tournamentA.id,
            name: "上周复盘赛",
            startTime: lastWeekSlot.start,
            endTime: lastWeekSlot.end,
            location: "历史讨论区",
            teamAId: team2.id,
            teamBId: team1.id,
            format: .f3v3,
            status: .finished,
            winnerTeamId: team1.id,
            teamAScore: 2,
            teamBScore: 3,
            resultRecordedAt: now.addingTimeInterval(-3600),
            teamA: team2,
            teamB: team1
        )

        self.matches = [matchPast, matchA, matchB, matchC, matchD, matchE, matchF, matchG]
        self.rosters = [
            Roster(
                id: UUID(),
                matchId: matchPast.id,
                teamId: team1.id,
                userId: currentUser.id,
                position: "一辩",
                user: currentUser
            ),
            Roster(
                id: UUID(),
                matchId: matchA.id,
                teamId: team1.id,
                userId: currentUser.id,
                position: "一辩",
                user: currentUser
            ),
            Roster(
                id: UUID(),
                matchId: matchB.id,
                teamId: team1.id,
                userId: currentUser.id,
                position: "二辩",
                user: currentUser
            ),
            Roster(
                id: UUID(),
                matchId: matchC.id,
                teamId: team2.id,
                userId: currentUser.id,
                position: "一辩",
                user: currentUser
            ),
            Roster(
                id: UUID(),
                matchId: matchD.id,
                teamId: team1.id,
                userId: currentUser.id,
                position: "三辩",
                user: currentUser
            ),
            Roster(
                id: UUID(),
                matchId: matchE.id,
                teamId: team2.id,
                userId: currentUser.id,
                position: "二辩",
                user: currentUser
            ),
            Roster(
                id: UUID(),
                matchId: matchF.id,
                teamId: team1.id,
                userId: currentUser.id,
                position: "一辩",
                user: currentUser
            ),
            Roster(
                id: UUID(),
                matchId: matchG.id,
                teamId: team1.id,
                userId: currentUser.id,
                position: "一辩",
                user: currentUser
            ),
            Roster(
                id: UUID(),
                matchId: matchA.id,
                teamId: team2.id,
                userId: userA.id,
                position: "一辩",
                user: userA
            )
        ]
        self.inboxMessages = [
            InboxMessage(
                id: UUID(),
                kind: .notification,
                title: "你被安排参加 \(matchA.name)",
                subtitle: "时间：今日 12:00 · 地点：腾讯会议 888 888 888",
                createdAt: now.addingTimeInterval(-1_800),
                isAcknowledged: false,
                relatedMatchId: matchA.id
            ),
            InboxMessage(
                id: UUID(),
                kind: .statusChange,
                title: "\(matchB.name) 赛程已调整",
                subtitle: "开赛时间改为 19:30，请及时确认",
                createdAt: now.addingTimeInterval(-1_200),
                isAcknowledged: false,
                relatedMatchId: matchB.id
            ),
            InboxMessage(
                id: UUID(),
                kind: .statusChange,
                title: "练习赛（上周）已取消",
                subtitle: "组织方临时取消，本场无需到场",
                createdAt: now.addingTimeInterval(-86_400),
                isAcknowledged: true,
                relatedMatchId: nil
            )
        ]
    }

    func addTeam(name: String, slogan: String, about: String, avatarStyle: TeamAvatarStyle) {
        let teamId = UUID()
        let owner = TeamMember(
            id: UUID(),
            teamId: teamId,
            userId: currentUser.id,
            role: .owner,
            joinTime: Date(),
            user: currentUser
        )
        let newTeam = Team(
            id: teamId,
            publicId: String(Int.random(in: 1000...9999)),
            name: name,
            slogan: slogan,
            about: about,
            avatarStyle: avatarStyle,
            avatarUrl: nil,
            ownerId: currentUser.id,
            status: .normal,
            members: [owner]
        )
        myTeams.insert(newTeam, at: 0)
    }
}
