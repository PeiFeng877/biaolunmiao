//
//  MockData.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 初始化所需的基础实体数据。
//  OUTPUT: 本地可重复的 Mock 数据集。
//  POS: 数据层 Mock。
//

import Foundation

class MockData {
    static let shared = MockData()

    // Mock Data Store
    let currentUser: User
    var myTeams: [Team] = []
    var discoverableTeams: [Team] = []
    var teamJoinRequests: [TeamJoinRequest] = []
    var tournaments: [Tournament] = []
    var matches: [Match] = []
    var rosters: [Roster] = []

    // Mock Users for members
    let userA = User(id: UUID(), publicId: "U1111", nickname: "张三", avatarUrl: nil, status: .normal)
    let userB = User(id: UUID(), publicId: "U2222", nickname: "李四", avatarUrl: nil, status: .normal)
    let userC = User(id: UUID(), publicId: "U3333", nickname: "王五", avatarUrl: nil, status: .normal)
    let userD = User(id: UUID(), publicId: "U4444", nickname: "赵六", avatarUrl: nil, status: .normal)
    let userE = User(id: UUID(), publicId: "U5555", nickname: "孙七", avatarUrl: nil, status: .normal)

    init() {
        let now = Date()

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
        let tour = Tournament(
            id: UUID(),
            name: "2026 星火杯",
            intro: "最硬核的辩论赛事",
            coverUrl: nil,
            creatorId: currentUser.id,
            status: .open,
            teams: [team1, team2]
        )
        self.tournaments = [tour]

        // Initialize Mock Match
        let match = Match(
            id: UUID(),
            tournamentId: tour.id,
            name: "初赛第一场",
            startTime: Date().addingTimeInterval(86400 * 2),
            endTime: Date().addingTimeInterval(86400 * 2 + 3600),
            location: "腾讯会议 888 888 888",
            teamAId: team1.id,
            teamBId: team2.id,
            format: .f3v3,
            status: .scheduled,
            teamA: team1,
            teamB: team2
        )
        self.matches = [match]
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
