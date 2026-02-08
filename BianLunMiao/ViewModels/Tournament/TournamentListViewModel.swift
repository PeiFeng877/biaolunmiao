//
//  TournamentListViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: AppStore 的赛事列表。
//  OUTPUT: 赛事瀑布流卡片状态。
//  POS: 赛事首页视图模型。
//

import Foundation
import Combine

final class TournamentListViewModel: ObservableObject {
    struct TournamentCard: Identifiable {
        let id: UUID
        let headline: String
        let subheadline: String
        let status: TournamentStatus
        let participantCount: Int
        let dateText: String
        let locationText: String
        let isFeatured: Bool
    }

    @Published private(set) var cards: [TournamentCard] = []

    private let store: AppStore

    init(store: AppStore) {
        self.store = store
        self.cards = Self.buildCards(from: store.tournaments)

        store.$tournaments
            .receive(on: DispatchQueue.main)
            .map { Self.buildCards(from: $0) }
            .assign(to: &$cards)
    }

    func createTournament(name: String, intro: String) {
        _ = store.createTournament(name: name, intro: intro)
    }

    private static func buildCards(from tournaments: [Tournament]) -> [TournamentCard] {
        var cards = tournaments.map { TournamentCard(tournament: $0) }
        if cards.count < 6 {
            let needed = 6 - cards.count
            cards.append(contentsOf: sampleCards.prefix(needed))
        }
        if let featuredIndex = cards.firstIndex(where: { $0.isFeatured }) {
            let featured = cards.remove(at: featuredIndex)
            cards.insert(featured, at: 0)
        } else if let first = cards.first {
            cards[0] = first.withFeatured(true)
        }
        return cards
    }

    private static let sampleCards: [TournamentCard] = [
        TournamentCard(
            id: UUID(),
            headline: "2024 夏季全国辩论锦标赛",
            subheadline: "全国总决赛 · 线下赛区",
            status: .open,
            participantCount: 320,
            dateText: "10月24日 - 11月01日",
            locationText: "线下 · 主赛场",
            isFeatured: true
        ),
        TournamentCard(
            id: UUID(),
            headline: "第十届华语辩论世界杯 (World Cup)",
            subheadline: "全球邀请 · 公开报名",
            status: .open,
            participantCount: 186,
            dateText: "10月24日 - 11月01日",
            locationText: "线上 · 腾讯会议",
            isFeatured: false
        ),
        TournamentCard(
            id: UUID(),
            headline: "高校邀请赛",
            subheadline: "半决赛 · 线下场馆",
            status: .ongoing,
            participantCount: 64,
            dateText: "11月08日 - 11月12日",
            locationText: "线下 · 城市会堂",
            isFeatured: false
        ),
        TournamentCard(
            id: UUID(),
            headline: "新生辩论公开赛",
            subheadline: "决赛夜 · 最后一战",
            status: .ended,
            participantCount: 48,
            dateText: "09月03日 - 09月07日",
            locationText: "线下 · A座礼堂",
            isFeatured: false
        ),
        TournamentCard(
            id: UUID(),
            headline: "地区交流赛",
            subheadline: "分组抽签 · 等待开始",
            status: .draft,
            participantCount: 36,
            dateText: "日期待定",
            locationText: "线上 · 待定",
            isFeatured: false
        ),
        TournamentCard(
            id: UUID(),
            headline: "年终挑战赛",
            subheadline: "八强突围 · 赛点来临",
            status: .ongoing,
            participantCount: 80,
            dateText: "12月02日 - 12月06日",
            locationText: "线下 · 中央场",
            isFeatured: false
        )
    ]
}

private extension TournamentListViewModel.TournamentCard {
    init(tournament: Tournament) {
        let subheadline = tournament.intro?.isEmpty == false ? tournament.intro! : "赛事火热进行中"
        let participantCount = tournament.teams.reduce(0) { $0 + $1.memberCount }

        self.init(
            id: tournament.id,
            headline: tournament.name,
            subheadline: subheadline,
            status: tournament.status,
            participantCount: max(participantCount, 0),
            dateText: "日期待定",
            locationText: "线上 · 待定",
            isFeatured: false
        )
    }

    func withFeatured(_ isFeatured: Bool) -> TournamentListViewModel.TournamentCard {
        TournamentListViewModel.TournamentCard(
            id: id,
            headline: headline,
            subheadline: subheadline,
            status: status,
            participantCount: participantCount,
            dateText: dateText,
            locationText: locationText,
            isFeatured: isFeatured
        )
    }
}
