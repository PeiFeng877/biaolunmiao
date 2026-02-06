//
//  Team.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 队伍与成员相关的基础数据。
//  OUTPUT: Team / TeamMember / TeamAvatarStyle 模型与枚举。
//  POS: 模型层-队伍域。
//

import Foundation

enum TeamAvatarStyle: String, Codable, CaseIterable, Identifiable {
    case paw
    case shield
    case crown
    case bolt
    case flame
    case leaf

    var id: String { rawValue }

    var systemName: String {
        switch self {
        case .paw:
            return "pawprint.fill"
        case .shield:
            return "shield.fill"
        case .crown:
            return "crown.fill"
        case .bolt:
            return "bolt.fill"
        case .flame:
            return "flame.fill"
        case .leaf:
            return "leaf.fill"
        }
    }
}

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
    var slogan: String?
    var about: String?
    var avatarStyle: TeamAvatarStyle
    var avatarUrl: String?
    var ownerId: UUID
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
