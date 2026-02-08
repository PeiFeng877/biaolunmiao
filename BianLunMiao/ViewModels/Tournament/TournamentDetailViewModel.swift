//
//  TournamentDetailViewModel.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: AppStore 与赛事卡片数据。
//  OUTPUT: 赛事详情页展示状态与赛程分组。
//  POS: 赛事详情视图模型。
//

import Foundation
import Combine

final class TournamentDetailViewModel: ObservableObject {
    struct TeamSnapshot: Identifiable, Hashable {
        let id: UUID
        let name: String
        let seed: Int
    }

    enum TeamStatus: String, CaseIterable {
        case confirmed
        case pending
        case waitlist

        var label: String {
            switch self {
            case .confirmed:
                return "已确认"
            case .pending:
                return "审核中"
            case .waitlist:
                return "候补"
            }
        }
    }

    struct TeamEntry: Identifiable, Hashable {
        let id: UUID
        let name: String
        let school: String
        let seed: Int
        let status: TeamStatus
        let isVerified: Bool
    }

    struct ScheduleMatch: Identifiable, Hashable {
        let id: UUID
        let stage: String
        let matchTitle: String
        let time: String
        let topic: String
        let location: String
        let teamA: TeamSnapshot
        let teamB: TeamSnapshot
    }

    struct ScheduleSession: Identifiable, Hashable {
        let id: UUID
        let title: String
        let timeLabel: String
        let matches: [ScheduleMatch]
    }

    struct ScheduleDay: Identifiable, Hashable {
        let id: UUID
        let date: Date
        let sessions: [ScheduleSession]
    }

    let card: TournamentListViewModel.TournamentCard
    @Published private(set) var teams: [TeamSnapshot] = []
    @Published private(set) var teamEntries: [TeamEntry] = []
    @Published private(set) var scheduleDays: [ScheduleDay] = []
    @Published private(set) var overviewText: String = ""
    @Published private(set) var dateRangeText: String = ""

    private let store: AppStore

    init(store: AppStore, card: TournamentListViewModel.TournamentCard) {
        self.store = store
        self.card = card
        let tournamentTeams = store.tournaments.first(where: { $0.id == card.id })?.teams ?? []
        if tournamentTeams.isEmpty {
            self.teamEntries = Self.sampleTeamEntries
            self.teams = Self.sampleTeams
        } else {
            self.teamEntries = tournamentTeams.enumerated().map { index, team in
                TeamEntry(
                    id: team.id,
                    name: team.name,
                    school: "待补充学校",
                    seed: index,
                    status: .confirmed,
                    isVerified: index == 0
                )
            }
            self.teams = teamEntries.map { TeamSnapshot(id: $0.id, name: $0.name, seed: $0.seed) }
        }

        self.scheduleDays = Self.buildSchedule(teams: teams)
        self.overviewText = card.subheadline
        self.dateRangeText = Self.buildDateRange(from: scheduleDays)
    }
}

private extension TournamentDetailViewModel {
    static func buildDateRange(from days: [ScheduleDay]) -> String {
        guard let first = days.first?.date, let last = days.last?.date else {
            return "日期待定"
        }
        return "\(dateFormatter.string(from: first)) - \(dateFormatter.string(from: last))"
    }

    static func buildSchedule(teams: [TeamSnapshot]) -> [ScheduleDay] {
        let calendar = Calendar.current
        let base = DateComponents(calendar: calendar, year: 2026, month: 10, day: 24)
        let dates = (0..<4).compactMap { dayOffset -> Date? in
            calendar.date(byAdding: .day, value: dayOffset, to: base.date ?? Date())
        }

        let safeTeams = teams.isEmpty ? sampleTeams : teams
        let pairs = zip(safeTeams, safeTeams.dropFirst()).map { ($0, $1) }

        let morningMatches = [
            buildMatch(
                stage: "初赛 A组",
                matchTitle: "第一场对决",
                time: "09:30",
                topic: "在此刻，我们更需要超人还是蝙蝠侠？",
                location: "第一报告厅",
                teams: pairs
            ),
            buildMatch(
                stage: "初赛 B组",
                matchTitle: "第二场对决",
                time: "10:20",
                topic: "当今世界，文化融合比文化保护更重要",
                location: "多功能厅 C",
                teams: Array(pairs.dropFirst())
            )
        ]

        let afternoonMatches = [
            buildMatch(
                stage: "初赛 C组",
                matchTitle: "焦点之战",
                time: "14:00",
                topic: "人工智能的发展对人类文明是福音还是灾难？",
                location: "第一报告厅",
                teams: pairs.reversed()
            )
        ]

        return dates.enumerated().map { index, date in
            let sessions: [ScheduleSession]
            if index == 0 {
                sessions = [
                    ScheduleSession(
                        id: UUID(),
                        title: "上午场",
                        timeLabel: "09:30",
                        matches: morningMatches
                    ),
                    ScheduleSession(
                        id: UUID(),
                        title: "下午场",
                        timeLabel: "14:00",
                        matches: afternoonMatches
                    )
                ]
            } else {
                let session = ScheduleSession(
                    id: UUID(),
                    title: "下午场",
                    timeLabel: "14:00",
                    matches: afternoonMatches
                )
                sessions = [session]
            }

            return ScheduleDay(id: UUID(), date: date, sessions: sessions)
        }
    }

    static func buildMatch(
        stage: String,
        matchTitle: String,
        time: String,
        topic: String,
        location: String,
        teams: [(TeamSnapshot, TeamSnapshot)]
    ) -> ScheduleMatch {
        let defaultTeams = sampleTeams
        let pair = teams.first ?? (defaultTeams[0], defaultTeams[1])
        return ScheduleMatch(
            id: UUID(),
            stage: stage,
            matchTitle: matchTitle,
            time: time,
            topic: topic,
            location: location,
            teamA: pair.0,
            teamB: pair.1
        )
    }

    static var sampleTeams: [TeamSnapshot] {
        [
            TeamSnapshot(id: UUID(), name: "辩论喵队", seed: 1),
            TeamSnapshot(id: UUID(), name: "逻辑狐队", seed: 2),
            TeamSnapshot(id: UUID(), name: "沉默雷霆", seed: 3),
            TeamSnapshot(id: UUID(), name: "智龙战队", seed: 4),
            TeamSnapshot(id: UUID(), name: "北辰星", seed: 5),
            TeamSnapshot(id: UUID(), name: "南风过境", seed: 6)
        ]
    }

    static var sampleTeamEntries: [TeamEntry] {
        [
            TeamEntry(id: UUID(), name: "这里是队名", school: "北京大学", seed: 0, status: .confirmed, isVerified: true),
            TeamEntry(id: UUID(), name: "对方辩友说得对", school: "清华大学", seed: 1, status: .pending, isVerified: false),
            TeamEntry(id: UUID(), name: "喵喵队", school: "复旦大学", seed: 2, status: .confirmed, isVerified: false),
            TeamEntry(id: UUID(), name: "不吃香菜", school: "中国人民大学", seed: 3, status: .confirmed, isVerified: false),
            TeamEntry(id: UUID(), name: "言之有理", school: "北京航空航天大学", seed: 4, status: .waitlist, isVerified: false),
            TeamEntry(id: UUID(), name: "随便起个名", school: "南开大学", seed: 5, status: .confirmed, isVerified: false)
        ]
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter
    }()
}
