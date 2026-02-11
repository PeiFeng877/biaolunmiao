//
//  Roster.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 队员指派数据。
//  OUTPUT: Roster 模型定义。
//  POS: 模型层-指派域。
//

import Foundation

struct RosterAssignment: Hashable {
    let userId: UUID
    let position: String
}

// 指派记录：谁在哪个队哪场比赛打了什么位置
struct Roster: Identifiable, Codable, Hashable {
    let id: UUID
    let matchId: UUID
    let teamId: UUID
    let userId: UUID
    var position: String // "一辩"
    
    // Helper
    var user: User? // Resolved user
}
