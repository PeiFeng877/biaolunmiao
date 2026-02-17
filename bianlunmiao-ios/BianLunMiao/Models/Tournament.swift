//
//  Tournament.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 agents.md
//  INPUT: 赛事的基础数据。
//  OUTPUT: Tournament 模型与状态枚举。
//  POS: 模型层-赛事域。
//

import Foundation

enum TournamentStatus: Int, Codable, CaseIterable {
    case open = 0 // 报名中
    case ongoing = 1 // 进行中
    case ended = 2 // 已结束

    var title: String {
        switch self {
        case .open:
            return "报名中"
        case .ongoing:
            return "进行中"
        case .ended:
            return "已结束"
        }
    }
}

enum TournamentParticipantStatus: Int, Codable, CaseIterable {
    case confirmed = 0
    case pending = 1
    case rejected = 2
}

struct TournamentParticipant: Identifiable, Codable, Hashable {
    let id: UUID
    let tournamentId: UUID
    let teamId: UUID
    var status: TournamentParticipantStatus
    var seed: Int

    // UI Helpers
    var team: Team?
}

struct Tournament: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var intro: String?
    var coverUrl: String?
    let creatorId: UUID
    var status: TournamentStatus
    var participants: [TournamentParticipant] = []

    var confirmedParticipants: [TournamentParticipant] {
        participants
            .filter { $0.status == .confirmed }
            .sorted { $0.seed < $1.seed }
    }

    var confirmedTeams: [Team] {
        confirmedParticipants
            .compactMap(\.team)
    }
}
