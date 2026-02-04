import Foundation

class MockData {
    static let shared = MockData()
    
    // Mock Data Store
    let currentUser: User // Restore this line
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
        
        // Mock Members
        let memberMeOwner = TeamMember(id: UUID(), teamId: UUID(), userId: currentUser.id, role: .owner, joinTime: Date(), user: currentUser)
        let memberMeMember = TeamMember(id: UUID(), teamId: UUID(), userId: currentUser.id, role: .member, joinTime: Date(), user: currentUser)
        
        let memberA = TeamMember(id: UUID(), teamId: UUID(), userId: userA.id, role: .admin, joinTime: Date(), user: userA)
        let memberB = TeamMember(id: UUID(), teamId: UUID(), userId: userB.id, role: .member, joinTime: Date(), user: userB)
        let memberC = TeamMember(id: UUID(), teamId: UUID(), userId: userC.id, role: .member, joinTime: Date(), user: userC)
        
        // Initialize Mock Teams
        let team1 = Team(
            id: UUID(),
            publicId: "1001",
            name: "复仇者辩论队",
            intro: "我们要打十个！专注于攻辩技术的提升。",
            avatarUrl: nil,
            ownerId: self.currentUser.id,
            status: .normal,
            members: [memberMeOwner, memberA, memberB, memberC]
        )
        
        let team2 = Team(
            id: UUID(),
            publicId: "1002",
            name: "佛系养生队",
            intro: "友谊第一，比赛第二",
            avatarUrl: nil,
            ownerId: userA.id, 
            status: .normal,
            members: [memberA, memberMeMember]
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
            teams: [team1, team2] // Mock: Both teams joined
        )
        self.tournaments = [tour]
        
        // Initialize Mock Match
        let match = Match(
            id: UUID(),
            tournamentId: tour.id,
            name: "初赛第一场",
            startTime: Date().addingTimeInterval(86400 * 2), // 2 days later
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
    
    func addTeam(name: String, intro: String) {
        let newTeam = Team(
            id: UUID(),
            publicId: String(Int.random(in: 1000...9999)),
            name: name,
            intro: intro,
            avatarUrl: nil,
            ownerId: currentUser.id,
            status: .normal,
            members: [
                TeamMember(id: UUID(), teamId: UUID(), userId: currentUser.id, role: .owner, joinTime: Date(), user: currentUser)
            ]
        )
        myTeams.insert(newTeam, at: 0)
    }
}