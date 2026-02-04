//
//  TournamentScheduleSetupViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: 赛事名称与赛程轮次配置。
//  OUTPUT: 赛程设定页面状态。
//  POS: 赛事设定视图模型。
//

import Foundation
import Combine

final class TournamentScheduleSetupViewModel: ObservableObject {
    struct RoundConfig: Identifiable, Hashable {
        let id: UUID
        var index: Int
        var title: String
        var date: String
        var time: String
        var location: String
    }

    @Published var rounds: [RoundConfig]
    let tournamentName: String

    init(tournamentName: String) {
        self.tournamentName = tournamentName
        self.rounds = [
            RoundConfig(
                id: UUID(),
                index: 1,
                title: "初赛 (Preliminaries)",
                date: "2023-11-15",
                time: "09:00",
                location: "线上 - 腾讯会议 A厅"
            ),
            RoundConfig(
                id: UUID(),
                index: 2,
                title: "",
                date: "",
                time: "--:--",
                location: ""
            )
        ]
    }

    func addRound() {
        let newIndex = rounds.count + 1
        rounds.append(
            RoundConfig(
                id: UUID(),
                index: newIndex,
                title: "",
                date: "",
                time: "--:--",
                location: ""
            )
        )
    }

    func removeRound(id: UUID) {
        rounds.removeAll { $0.id == id }
        for index in rounds.indices {
            rounds[index].index = index + 1
        }
    }

    func resetRounds() {
        for index in rounds.indices {
            rounds[index].title = ""
            rounds[index].date = ""
            rounds[index].time = "--:--"
            rounds[index].location = ""
        }
    }

    var summary: TournamentPublishViewModel.Summary {
        let dates = rounds.map(\.date).filter { !$0.isEmpty }
        let dateRange: String
        if let first = dates.first, let last = dates.last {
            dateRange = "\(first) - \(last)"
        } else {
            dateRange = "日期待定"
        }
        let location = rounds.first(where: { !$0.location.isEmpty })?.location ?? "地点待定"
        return TournamentPublishViewModel.Summary(
            tournamentName: tournamentName.isEmpty ? "未命名赛事" : tournamentName,
            roundsCount: rounds.count,
            dateRange: dateRange,
            location: location
        )
    }
}
