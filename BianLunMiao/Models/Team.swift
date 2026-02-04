import Foundation

enum TeamStatus: Int, Codable {
    case normal = 0
    case disbanded = 1
    case banned = 2
}

enum TeamRole: Int, Codable, Comparable {
    case member = 0
    case admin = 1
    case owner = 2
    
    static func < (lhs: TeamRole, rhs: TeamRole) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var title: String {
        switch self {
        case .member: return "队员"
        case .admin: return "管理员"
        case .owner: return "队长"
        }
    }
}

struct Team: Identifiable, Codable, Hashable {
    let id: UUID
    let publicId: String
    var name: String
    var intro: String?
    var avatarUrl: String?
    let ownerId: UUID
    var status: TeamStatus
    
    // UI Helpers
    var members: [TeamMember] = []
    
    var memberCount: Int {
        members.count
    }
}

struct TeamMember: Identifiable, Codable, Hashable {
    let id: UUID // Relation ID
    let teamId: UUID
    let userId: UUID
    var role: TeamRole
    let joinTime: Date
    let user: User // Embedding User for easier UI access in Mock
}
