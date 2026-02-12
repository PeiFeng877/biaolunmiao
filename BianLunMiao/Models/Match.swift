//
//  Match.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: 比赛与赛制基础数据。
//  OUTPUT: Match 模型与相关枚举。
//  POS: 模型层-赛程域。
//

import Foundation

enum MatchStatus: Int, Codable {
    case scheduled = 0 // 未开始
    case ready = 1     // 双方人员已定
    case ongoing = 2
    case finished = 3
}

enum DebateSide: String, Codable, CaseIterable {
    case affirmative = "正方"
    case negative = "反方"
}

enum MatchFormat: String, Codable, CaseIterable {
    case f1v1 = "1v1"
    case f2v2 = "2v2"
    case f3v3 = "3v3"
    case f4v4 = "4v4"
    
    var positions: [String] {
        switch self {
        case .f1v1:
            return ["一辩"]
        case .f2v2:
            return ["一辩", "二辩"]
        case .f3v3:
            return ["一辩", "二辩", "三辩"]
        case .f4v4:
            return ["一辩", "二辩", "三辩", "四辩"]
        }
    }
}

struct MatchDraft: Hashable {
    var name: String
    var startTime: Date
    var endTime: Date
    var location: String
    var format: MatchFormat
    var topic: String = ""
    var opponentTeamName: String = ""
}

struct Match: Identifiable, Codable, Hashable {
    let id: UUID
    let tournamentId: UUID
    var name: String // "初赛第一场"
    var topic: String? = nil
    var startTime: Date
    var endTime: Date
    var location: String? // "腾讯会议 123"
    var opponentTeamName: String? = nil
    
    var teamAId: UUID?
    var teamBId: UUID?
    
    var format: MatchFormat
    var status: MatchStatus
    var winnerSide: DebateSide? = nil
    var winnerTeamId: UUID?
    var teamAScore: Int?
    var teamBScore: Int?
    var resultRecordedAt: Date?
    var resultNote: String? = nil
    var bestDebaterPosition: String? = nil
    
    // UI Helpers: Resolve real objects
    var teamA: Team?
    var teamB: Team?
}
