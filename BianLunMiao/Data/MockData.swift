//
//  MockData.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
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
    var tournaments: [Tournament] = []
    var matches: [Match] = []
    var rosters: [Roster] = []

    // Mock Users for members
    let userA = User(id: UUID(), publicId: "U1111", nickname: "张三", avatarUrl: nil, status: .normal)
    let userB = User(id: UUID(), publicId: "U2222", nickname: "李四", avatarUrl: nil, status: .normal)
    let userC = User(id: UUID(), publicId: "U3333", nickname: "王五", avatarUrl: nil, status: .normal)

    init() {
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

        // Mock Members
        let memberMeOwner = TeamMember(
            id: UUID(),
            teamId: team1Id,
            userId: currentUser.id,
            role: .owner,
            joinTime: Date(),
            user: currentUser
        )
        let memberMeMember = TeamMember(
            id: UUID(),
            teamId: team2Id,
            userId: currentUser.id,
            role: .member,
            joinTime: Date(),
            user: currentUser
        )

        let memberA1 = TeamMember(
            id: UUID(),
            teamId: team1Id,
            userId: userA.id,
            role: .admin,
            joinTime: Date(),
            user: userA
        )
        let memberB1 = TeamMember(
            id: UUID(),
            teamId: team1Id,
            userId: userB.id,
            role: .member,
            joinTime: Date(),
            user: userB
        )
        let memberC1 = TeamMember(
            id: UUID(),
            teamId: team1Id,
            userId: userC.id,
            role: .member,
            joinTime: Date(),
            user: userC
        )
        let memberA2 = TeamMember(
            id: UUID(),
            teamId: team2Id,
            userId: userA.id,
            role: .owner,
            joinTime: Date(),
            user: userA
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
            members: [memberA2, memberMeMember]
        )

        self.myTeams = [team1, team2]

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
