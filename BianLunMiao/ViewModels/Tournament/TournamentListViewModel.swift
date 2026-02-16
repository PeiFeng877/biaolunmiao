//
//  TournamentListViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: AppStore 的赛事与赛程数据。
//  OUTPUT: 赛事列表状态与筛选结果。
//  POS: 赛事首页视图模型。
//

import Foundation
import Combine



@MainActor
final class TournamentListViewModel: ObservableObject {
    struct TournamentCard: Identifiable, Hashable {
        let id: UUID
        let title: String
        let intro: String
        let status: TournamentStatus
        let participantCount: Int
        let matchCount: Int
    }

    @Published private(set) var cards: [TournamentCard] = []

    private let store: AppStore

    init(store: AppStore) {
        self.store = store
        self.cards = Self.buildCards(tournaments: store.tournaments, matches: store.matches)

        Publishers.CombineLatest(store.$tournaments, store.$matches)
            .receive(on: DispatchQueue.main)
            .map { tournaments, matches in
                Self.buildCards(tournaments: tournaments, matches: matches)
            }
            .assign(to: &$cards)
    }

    func createTournament(name: String, intro: String, status: TournamentStatus = .open) -> Tournament {
        store.createTournament(name: name, intro: intro, status: status)
    }

    func filteredCards(searchText: String, filter: TournamentFilter) -> [TournamentCard] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return cards.filter { card in
            let passesFilter = filter.matches(status: card.status)
            guard passesFilter else { return false }

            guard !keyword.isEmpty else { return true }
            return card.title.localizedStandardContains(keyword) || card.intro.localizedStandardContains(keyword)
        }
    }

    private static func buildCards(tournaments: [Tournament], matches: [Match]) -> [TournamentCard] {
        let groupedMatches = Dictionary(grouping: matches) { $0.tournamentId }

        return tournaments.map { tournament in
            let tournamentMatches = groupedMatches[tournament.id] ?? []
            return TournamentCard(
                id: tournament.id,
                title: tournament.name,
                intro: normalizedIntro(tournament.intro),
                status: tournament.status,
                participantCount: tournament.confirmedParticipants.count,
                matchCount: tournamentMatches.count
            )
        }
    }

    private static func normalizedIntro(_ intro: String?) -> String {
        let trimmed = intro?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "暂无赛事简介" : trimmed
    }
}
