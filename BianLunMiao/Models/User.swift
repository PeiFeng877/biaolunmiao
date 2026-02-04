//
//  User.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 用户基础数据。
//  OUTPUT: User 模型与状态枚举。
//  POS: 模型层-用户域。
//

import Foundation

enum UserStatus: Int, Codable {
    case normal = 0
    case deleted = 1
    case banned = 2
}

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    let publicId: String // 用户可见 ID
    var nickname: String
    var avatarUrl: String?
    var status: UserStatus
}
