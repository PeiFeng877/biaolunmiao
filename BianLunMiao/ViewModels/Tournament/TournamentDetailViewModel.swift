//
//  TournamentDetailViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: AppStore 与赛事 ID。
//  OUTPUT: 赛事管理页展示状态。
//  POS: 赛事详情视图模型。
//

import Foundation
import Combine

final class TournamentDetailViewModel: ObservableObject {
    @Published private(set) var tournament: Tournament
    @Published private(set) var matches: [Match] = []

    private let store: AppStore
    private let tournamentId: UUID
    private var cancellables = Set<AnyCancellable>()

    init(store: AppStore, tournamentId: UUID) {
        self.store = store
        self.tournamentId = tournamentId
        self.tournament = store.tournament(id: tournamentId) ?? Tournament(
            id: tournamentId,
            name: "未知赛事",
            intro: nil,
            coverUrl: nil,
            creatorId: store.currentUser.id,
            status: .draft,
            participants: []
        )
        self.matches = store.matches(for: tournamentId)

        Publishers.CombineLatest(store.$tournaments, store.$matches)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    var canManage: Bool {
        store.canCurrentUserManageTournament(tournamentId: tournamentId)
    }

    var participantTeams: [Team] {
        tournament.confirmedTeams
    }

    var introText: String {
        let trimmed = tournament.intro?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "暂无赛事简介" : trimmed
    }

    var statusText: String {
        switch tournament.status {
        case .draft:
            return "待发布"
        case .open:
            return "报名中"
        case .ongoing:
            return "进行中"
        case .ended:
            return "已结束"
        case .cancelled:
            return "已取消"
        }
    }

    var statusColor: ColorToken {
        switch tournament.status {
        case .draft:
            return .secondary
        case .open:
            return .primary
        case .ongoing:
            return .info
        case .ended:
            return .secondary
        case .cancelled:
            return .danger
        }
    }

    func teamName(for id: UUID?) -> String {
        guard let id else { return "待定" }
        return store.team(by: id)?.name ?? "待定"
    }

    func scoreText(for match: Match) -> String {
        guard let teamAScore = match.teamAScore, let teamBScore = match.teamBScore else {
            return "未录入"
        }
        return "\(teamAScore) : \(teamBScore)"
    }

    func winnerName(for match: Match) -> String {
        teamName(for: match.winnerTeamId)
    }

    private func refresh() {
        if let updated = store.tournament(id: tournamentId) {
            tournament = updated
        }
        matches = store.matches(for: tournamentId)
    }
}

enum ColorToken {
    case primary
    case secondary
    case info
    case danger
}
