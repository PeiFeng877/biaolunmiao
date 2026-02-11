//
//  Tournament.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 赛事的基础数据。
//  OUTPUT: Tournament 模型与状态枚举。
//  POS: 模型层-赛事域。
//

import Foundation

enum TournamentStatus: Int, Codable {
    case draft = 0
    case open = 1 // 报名中
    case ongoing = 2
    case ended = 3
    case cancelled = 4
}

struct Tournament: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var intro: String?
    var coverUrl: String?
    let creatorId: UUID
    var status: TournamentStatus
    
    // UI Helpers (Mock)
    var teams: [Team] = [] // 已报名/审核通过的队伍
}
